// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { constants } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { once } from 'node:events';
import { registry, NativeStory } from '../native.mjs';

const execute = promisify(execFile);
const text = artifact => artifact.frame.cells.map(cell => cell.text).join('');

test('actual qrepl PTY stories complete their declared checkpoints', { timeout: 60000 }, async () => {
  for (const story of (await registry()).filter(story => story.application)) {
    const native = new NativeStory(story);
    try {
      await native.ready;
      for (const step of story.steps) {
        const frame = await native.command('step');
        assert.equal(frame.artifact.checkpoint, step.checkpoint);
      }
      await native.command('reset');
      assert.equal((await native.command('capture')).artifact.state.text, story.fixture.draft);
    } finally { await native.close(); }
  }
});

async function streamingScenario(marker = 'stream-marker', deadline = 10000) {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'ncurses-qrepl-bridge-'));
  const gate = path.join(dir, 'gate');
  await execute('mkfifo', [gate]);
  const story = (await registry()).find(story => story.id === 'qrepl.default');
  const native = new NativeStory(story);
  let released = false;
  let active = false;
  let stream = '';
  const output = once(native, 'output-marker', { signal: AbortSignal.timeout(deadline) });
  output.catch(() => {}); // A startup failure still enters cleanup without an unhandled rejection.
  native.on('terminal', data => {
    stream += Buffer.from(data, 'base64').toString();
    if (stream.includes(marker)) { native.emit('output-marker'); }
  });
  try {
    await native.ready;
    const source = `stdout.write("stream-" + "marker\\n"); ReadOnlyFile gate("${gate}"); gate.readLine();`;
    const started = await native.command('input', { data: '\x15' + source + '\r' });
    active = true;
    assert.equal(started.artifact.state.evaluating, true);
    await output; // Event barrier with a failure deadline so finally always releases the FIFO.
    assert.equal((await native.command('capture')).artifact.state.evaluating, true);
    assert.ok(text((await native.command('capture')).artifact).includes('stream-marker'));
    await native.command('resize', { rows: 10, cols: 50 });
    for (const action of ['reset', 'step']) {
      await assert.rejects(native.command(action), /GALLERY-BUSY/);
      assert.deepEqual(native.geometry, { rows: 10, cols: 50 });
      assert.equal((await native.command('capture')).artifact.state.evaluating, true);
    }
    const draft = await native.command('input', { data: '\x15next draft' });
    assert.equal(draft.artifact.state.text, 'next draft');
    const resized = await native.command('resize', { rows: 8, cols: 40 });
    assert.equal(resized.artifact.frame.cols, 40);
    const quitting = await native.command('input', { data: '\x1bq' });
    assert.equal(quitting.artifact.state.modal, true);
    const cancelled = await native.command('input', { data: '\x1b' });
    assert.equal(cancelled.artifact.state.modal, false);
    assert.equal(cancelled.artifact.state.evaluating, true);
    await fs.writeFile(gate, 'release\n'); released = true;
    const done = await native.command('settle');
    assert.equal(done.artifact.state.evaluating, false);
    assert.equal(done.artifact.state.text, 'next draft');
  } finally {
    try {
      if (active && !released) {
        try { const writer = await fs.open(gate, constants.O_WRONLY | constants.O_NONBLOCK);
          try { await writer.write('release\n'); } finally { await writer.close(); }
        } catch (error) { if (error.code !== 'ENXIO') { throw error; } }
      }
    } finally {
      try { await native.close(); }
      finally { await fs.rm(dir, { recursive: true, force: true }); }
    }
  }
}
test('qrepl streams output and accepts input, resize and quit cancellation during a blocked evaluation', { timeout: 30000 }, async () => {
  await streamingScenario();
});

for (const failure of [false, true]) {
  test(`finish-and-quit publishes the final ${failure ? 'error' : 'result'} after its input was acknowledged`, { timeout: 15000 }, async () => {
    const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'ncurses-final-result-'));
    const gate = path.join(dir, 'gate'); await execute('mkfifo', [gate]);
    const story = (await registry()).find(story => story.id === 'qrepl.default');
    const native = new NativeStory(story); let released = false; let active = false;
    try {
      await native.ready;
      const action = failure ? 'throw "FINAL-ERROR", "final error result";' : 'stdout.write("final-" + "result\\n");';
      const source = `ReadOnlyFile gate("${gate}"); gate.readLine(); ${action}`;
      assert.equal((await native.command('input', { data: '\x15' + source + '\r' })).artifact.state.evaluating, true);
      active = true;
      await native.command('input', { data: '\x11' });
      const accepted = await native.command('input', { data: '\r' });
      assert.equal(accepted.artifact.state.evaluating, true); assert.equal(accepted.artifact.state.modal, false);
      const final = once(native, 'final', { signal: AbortSignal.timeout(5000) });
      final.catch(() => {});
      await fs.writeFile(gate, 'release\n'); released = true;
      const [frame] = await final;
      assert.equal(frame.artifact.state.evaluating, false);
      assert.ok(text(frame.artifact).includes(failure ? 'FINAL-ERROR' : 'final-result'));
      assert.deepEqual(await native.closed, { code: 0, signal: null });
    } finally {
      try {
        if (active && !released) {
          const writer = await fs.open(gate, constants.O_WRONLY | constants.O_NONBLOCK);
          try { await writer.write('release\n'); } finally { await writer.close(); }
        }
      } finally { try { await native.close(); } finally { await fs.rm(dir, { recursive: true, force: true }); } }
    }
  });
}
test('missing streaming marker reaches FIFO and process cleanup', { timeout: 15000 }, async () => {
  await assert.rejects(streamingScenario('never-produced-marker', 1500), { name: 'AbortError' });
});


test('intentional qrepl quit acknowledges its input and closes without failure', { timeout: 15000 }, async () => {
  const story = (await registry()).find(story => story.id === 'qrepl.default');
  const native = new NativeStory(story);
  const failures = []; native.on('failure', error => failures.push(error));
  try {
    await native.ready;
    const dialog = await native.command('input', { data: '\x11' });
    assert.equal(dialog.artifact.state.modal, true);
    const ended = once(native, 'ended', { signal: AbortSignal.timeout(5000) });
    ended.catch(() => {}); // A failed input still enters cleanup before this deadline rejects.
    const frame = await native.command('input', { data: '\r' });
    assert.equal(frame.artifact.state.modal, false);
    await ended;
    assert.equal((await native.closed).code, 0);
    assert.deepEqual(failures, []);
    await assert.rejects(native.command('capture'), /closed/);
  } finally { await native.close(); }
});
