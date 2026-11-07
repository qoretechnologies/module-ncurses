// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { spawn } from 'node:child_process';
import { NativeStory, dimensions, registry } from '../native.mjs';
const stories = await registry();
const story = id => stories.find(entry => entry.id === id);

test('PTY input, composed frames, resize and deterministic reset', async () => {
  const native = new NativeStory(story('table.scrolling'));
  let output = ''; native.on('terminal', data => { output += Buffer.from(data, 'base64').toString(); });
  try {
    const initial = await native.ready;
    assert.equal(initial.artifact.state.selected, 0);
    const last = await native.command('input', { data: '\x1bOF' });
    assert.equal(last.artifact.state.selected, 23); assert.ok(last.artifact.state.scroll > 0);
    const resized = await native.command('resize', { rows: 3, cols: 18 });
    assert.equal(resized.artifact.frame.rows, 3); assert.equal(resized.artifact.state.selected, 23);
    const reset = await native.command('reset'); assert.deepEqual(reset.artifact, initial.artifact);
    for (let i = 0; i < 3; ++i) {
      await native.command('input', { data: '\x1bOF' });
      assert.deepEqual((await native.command('reset')).artifact, initial.artifact);
    }
    await native.command('step'); const scripted = await native.command('step');
    assert.equal(scripted.artifact.checkpoint, 'last'); assert.equal(scripted.artifact.state.selected, 23);
    // Non-input command errors do not leave unread PTY bytes and remain recoverable.
    while (native.index + 1 < native.story.steps.length) { await native.command('step'); }
    await assert.rejects(native.command('step'), /GALLERY-STEP-ERROR/);
    assert.deepEqual((await native.command('reset')).artifact, initial.artifact);
    assert.ok(output.includes('Row 00'));
  } finally { assert.equal((await native.close()).code, 0); }
});

test('Unicode paste and standalone Escape cross the real PTY', async () => {
  const editor = new NativeStory(story('text-editor.empty'));
  try {
    await editor.ready;
    const paste = await editor.command('input', { data: '\x1b[200~界é\x1b[201~' });
    assert.equal(paste.artifact.state.text, '界é');
    assert.equal(paste.artifact.frame.cursor.visibility, 1);
    const large = '界'.repeat(4000);
    await editor.command('reset');
    assert.equal((await editor.command('input', { data: '\x1b[200~' + large + '\x1b[201~' })).artifact.state.text, large);
  } finally { await editor.close(); }
  const popup = new NativeStory(story('completion-popup.overlap'));
  try {
    assert.equal((await popup.ready).artifact.state.modal, true);
    const dismissed = await popup.command('input', { data: '\x1b' });
    assert.equal(dismissed.artifact.state.modal, false);
    assert.equal(dismissed.artifact.state.focus, 'TextEditorWidget');
    assert.equal(dismissed.artifact.frame.cursor.visibility, 1);
  } finally { await popup.close(); }
});

test('validation and failed startup leave no reusable process', async () => {
  assert.throws(() => dimensions({ rows: 0, cols: 80 }));
  const native = new NativeStory(story('label.default'));
  try {
    await native.ready;
    await assert.rejects(native.command('input', { data: '\x1e' }));
    await assert.rejects(native.command('input', { data: '界', encoding: 'latin1' }));
    await assert.rejects(native.command('input', { data: 'a', encoding: 'arbitrary' }));
    await assert.rejects(native.command('input', { data: 'x'.repeat(16385) }));
    await assert.rejects(native.command('resize', { rows: 1.5, cols: 80 }));
    await assert.rejects(native.command('resize', { rows: 101, cols: 80 }));
    await assert.rejects(native.command('resize', { rows: 24, cols: 241 }));
    await assert.rejects(native.command('arbitrary-command'));
    const minimum = await native.command('resize', { rows: 1, cols: 1 });
    assert.equal(minimum.artifact.frame.cells.length, 1);
    const maximum = await native.command('resize', { rows: 100, cols: 240 });
    assert.equal(maximum.artifact.frame.cells.length, 24000);
    await native.command('reset');
    assert.equal((await native.command('capture')).artifact.story, 'label.default');
  } finally { await native.close(); }
  await assert.rejects(native.command('capture'));
  const missing = new NativeStory(story('label.default'), { qore: '/nonexistent/qore' });
  await assert.rejects(missing.ready); await missing.close();
  const unknown = new NativeStory({ ...story('label.default'), id: '../invalid' });
  await assert.rejects(unknown.ready); await unknown.close();
});

test('a terminal carriage-return activates a checkbox once', async () => {
  const native = new NativeStory(story('checkbox.default'));
  try {
    assert.equal((await native.ready).artifact.state.checked, false);
    assert.equal((await native.command('input', { data: '\r' })).artifact.state.checked, true);
    assert.equal((await native.command('input', { data: '\r' })).artifact.state.checked, false);
  } finally { await native.close(); }
});

test('throwing PTY input closes the stream and rejects queued retry without consuming a stale fence', async () => {
  const native = new NativeStory(story('attachment.invalid'));
  let pid;
  try {
    await native.ready; pid = native.nativePid;
    const failed = native.command('input', { data: '\r' });
    const retry = native.command('input', { data: 'x' });
    await assert.rejects(failed, /GALLERY-FILE-ERROR/);
    await assert.rejects(retry, /Native story is closed/);
    await native.closed;
    assert.throws(() => process.kill(pid, 0), { code: 'ESRCH' });
  } finally { await native.close(); }
});

test('binary input preserves high bytes and unexpected native death is handled', async () => {
  const native = new NativeStory(story('text-editor.empty'));
  let pid;
  try {
    await native.ready;
    pid = native.nativePid;
    const pasted = await native.command('input', { data: '\x1b[200~' + Buffer.from('界é').toString('latin1') + '\x1b[201~', encoding: 'latin1' });
    assert.equal(pasted.artifact.state.text, '界é');
    const failed = once(native, 'failure');
    process.kill(native.nativePid, 'SIGKILL');
    assert.match((await failed)[0].message, /status|closed/);
    await assert.rejects(native.command('capture'));
  } finally { await native.close(); }
  assert.throws(() => process.kill(pid, 0), { code: 'ESRCH' });
});

test('supervisor death terminates Qore even without a delivered PID announcement', async () => {
  class UnannouncedStory extends NativeStory {
    receive(message) {
      if (message.type === 'process') { this.observedPid = message.pid; return; }
      super.receive(message);
    }
  }
  const native = new UnannouncedStory(story('label.default'));
  let watcher;
  try {
    await native.ready;
    assert.equal(native.nativePid, undefined);
    // Linux pidfd provides a process-exit event even when the failed supervisor
    // can no longer reap its child. There is no process-status polling.
    watcher = spawn('python3', ['-u', '-c', 'import os,select,sys; fd=os.pidfd_open(int(sys.argv[1])); print("ready",flush=True); sys.exit(0 if select.select([fd],[],[],10)[0] else 1)', String(native.observedPid)], { stdio: ['ignore', 'pipe', 'pipe'] });
    const exited = once(watcher, 'close'); await once(watcher.stdout, 'data');
    native.child.kill('SIGKILL');
    await native.closed; assert.equal((await exited)[0], 0);
    assert.equal(native.closing, true);
    const sequence = native.sequence;
    await assert.rejects(native.command('capture'), /Native story is closed/);
    assert.equal(native.sequence, sequence, 'closed sessions reject before issuing another request');
  } finally { if (watcher && watcher.exitCode === null) { watcher.kill('SIGKILL'); } await native.close(); }
});
