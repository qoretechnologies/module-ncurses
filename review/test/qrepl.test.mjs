// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { constants } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
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

test('qrepl streams output and accepts input, resize and quit cancellation during a blocked evaluation', { timeout: 30000 }, async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'ncurses-qrepl-bridge-'));
  const gate = path.join(dir, 'gate');
  await execute('mkfifo', [gate]);
  const story = (await registry()).find(story => story.id === 'qrepl.default');
  const native = new NativeStory(story);
  let released = false;
  let active = false;
  let stream = '';
  let resolveOutput;
  const output = new Promise(resolve => { resolveOutput = resolve; });
  native.on('terminal', data => {
    stream += Buffer.from(data, 'base64').toString();
    if (stream.includes('stream-marker')) { resolveOutput(); }
  });
  try {
    await native.ready;
    const source = `stdout.write("stream-" + "marker\\n"); ReadOnlyFile gate("${gate}"); gate.readLine();`;
    const started = await native.command('input', { data: '\x15' + source + '\r' });
    active = true;
    assert.equal(started.artifact.state.evaluating, true);
    await output; // The real capture reader wakes the UI; no timer or polling barrier.
    assert.equal((await native.command('capture')).artifact.state.evaluating, true);
    assert.ok(text((await native.command('capture')).artifact).includes('stream-marker'));
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
    if (active && !released) {
      try { const writer = await fs.open(gate, constants.O_WRONLY | constants.O_NONBLOCK);
        try { await writer.write('release\n'); } finally { await writer.close(); }
      } catch (error) { if (error.code !== 'ENXIO') { throw error; } }
    }
    await native.close();
    await fs.rm(dir, { recursive: true, force: true });
  }
});
