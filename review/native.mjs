// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import { spawn } from 'node:child_process';
import { EventEmitter } from 'node:events';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';

export const root = fileURLToPath(new URL('../', import.meta.url));
export const buildDir = path.resolve(process.env.NCURSES_BUILD_DIR ?? path.join(root, 'build-debug'));
const worker = fileURLToPath(new URL('pty_worker.py', import.meta.url));

function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  promise.catch(() => {});
  return { promise, resolve, reject };
}

export function dimensions(value) {
  if (!value || !Number.isInteger(value.rows) || !Number.isInteger(value.cols)
      || value.rows < 1 || value.rows > 100 || value.cols < 1 || value.cols > 240) {
    throw new Error('Geometry must be integer rows 1..100 and columns 1..240');
  }
  return { rows: value.rows, cols: value.cols };
}

export async function registry() {
  const binaries = (await fs.readdir(buildDir)).filter(name => /^ncurses-api-\d+\.\d+\.qmod$/.test(name));
  if (!binaries.length) { throw new Error(`No locally built ncurses module in ${buildDir}`); }
  const child = spawn('qore', ['--enable-debug', '--warnings-are-errors', 'examples/widget-gallery.qr', '--catalog'],
    { cwd: root, env: { ...process.env, QORE_MODULE_DIR: `${buildDir}:${path.join(root, 'qlib')}` }, stdio: ['ignore', 'pipe', 'pipe'] });
  const output = []; const errors = [];
  let size = 0; let failure;
  const stop = error => { failure ??= error; child.kill('SIGKILL'); };
  const deadline = setTimeout(() => stop(new Error('Registry startup deadline exceeded')), 15000);
  child.stdout.on('data', chunk => {
    size += chunk.length;
    if (size > 4 * 1024 * 1024) { stop(new Error('Registry exceeded 4 MiB')); }
    else { output.push(chunk); }
  });
  child.stderr.on('data', chunk => { if (!errors.length) { errors.push(chunk); } });
  return await new Promise((resolve, reject) => {
    child.on('error', error => { clearTimeout(deadline); reject(error); });
    child.on('close', code => {
      clearTimeout(deadline);
      try {
        if (failure) { throw failure; }
        if (code || errors.length) { throw new Error(Buffer.concat(errors).toString() || `Registry exited ${code}`); }
        resolve(JSON.parse(Buffer.concat(output).toString()));
      } catch (error) { reject(error); }
    });
  });
}

/** One process/PTY per story. Requests serialize; every completion has a native frame. */
export class NativeStory extends EventEmitter {
  constructor(story, { monochrome = false, geometry = story.geometry, qore = 'qore', timeout = 15000 } = {}) {
    super();
    this.story = story; this.geometry = dimensions(geometry); this.initialGeometry = { ...this.geometry };
    this.timeout = timeout; this.sequence = 0; this.index = -1; this.pending = new Map();
    this.chain = Promise.resolve(); this.start = deferred(); this.ready = this.start.promise; this.exited = deferred();
    this.closed = this.exited.promise; this.closing = false;
    const args = [worker, '--story', story.id, '--rows', String(geometry.rows), '--cols', String(geometry.cols),
      '--build-dir', buildDir, '--qore', qore];
    if (monochrome) { args.push('--monochrome'); }
    this.child = spawn('python3', args, { cwd: root, stdio: ['pipe', 'pipe', 'pipe'], detached: true });
    this.startTimer = setTimeout(() => this.fail(new Error('Native startup deadline exceeded')), timeout);
    this.lines = createInterface({ input: this.child.stdout });
    this.lines.on('line', line => {
      try { this.receive(JSON.parse(line)); } catch (error) { this.fail(error); }
    });
    this.child.stderr.on('data', chunk => this.fail(new Error(`PTY supervisor: ${chunk.toString()}`)));
    this.child.stdin.on('error', error => { if (!this.closing) { this.fail(error); } });
    this.child.on('error', error => this.fail(error));
    this.child.on('close', (code, signal) => {
      const expected = this.closing || (this.intentionalExit && code === 0 && !signal);
      this.closing = true;
      clearTimeout(this.startTimer); clearTimeout(this.closeTimer); this.lines.close();
      // Qore inherits the supervisor's isolated process group. This also covers
      // a crash before Qore's PID announcement reaches this owner.
      if ((code !== 0 || signal) && this.child.pid) {
        try { process.kill(-this.child.pid, 'SIGKILL'); }
        catch (error) { if (error.code !== 'ESRCH') { this.emit('failure', error); } }
      }
      const error = new Error(`Native story closed (${code ?? signal})`);
      this.start.reject(error);
      for (const request of this.pending.values()) { request.reject(error); clearTimeout(request.timer); }
      this.pending.clear(); this.exited.resolve({ code, signal }); this.emit('closed', { code, signal });
      if (!expected) { this.emit('failure', error); }
    });
  }
  receive(message) {
    switch (message.type) {
      case 'process': this.nativePid = message.pid; break;
      case 'terminal': this.emit('terminal', message.data); break;
      case 'frame': {
        this.index = message.artifact.index;
        if (message.sequence === 0) { clearTimeout(this.startTimer); this.start.resolve(message); }
        else {
          const request = this.pending.get(message.sequence);
          if (!request) { throw new Error(`Unexpected native sequence ${message.sequence}`); }
          this.pending.delete(message.sequence); clearTimeout(request.timer); request.resolve(message);
        }
        this.emit('frame', message); break;
      }
      case 'error': {
        const error = new Error(message.error + (message.description ? `: ${message.description}` : ''));
        if (message.fatal) { this.fail(error); }
        else {
          const request = this.pending.get(message.sequence);
          if (!request) { throw error; }
          this.pending.delete(message.sequence); clearTimeout(request.timer); request.reject(error);
        }
        break;
      }
      case 'ended': this.intentionalExit = true; this.emit('ended'); break;
      case 'exit': this.nativePid = undefined; break;
      default: throw new Error('Unknown native response');
    }
  }
  fail(error) {
    clearTimeout(this.startTimer); this.start.reject(error);
    for (const request of this.pending.values()) { request.reject(error); clearTimeout(request.timer); }
    this.pending.clear(); this.emit('failure', error); void this.close();
  }
  command(action, values = {}) {
    const operation = this.chain.then(async () => {
      await this.ready;
      if (this.closing || this.intentionalExit) { throw new Error('Native story is closed'); }
      if (!['capture', 'input', 'resize', 'reset', 'step', 'settle'].includes(action)) { throw new Error('Unknown native action'); }
      const command = { action, sequence: ++this.sequence };
      if (action === 'input') {
        const encoding = values.encoding ?? 'utf8';
        if (!['utf8', 'latin1'].includes(encoding) || typeof values.data !== 'string' || values.data.includes('\x1e')
            || (encoding === 'latin1' && /[^\x00-\xff]/u.test(values.data)) || Buffer.byteLength(values.data, encoding) > 16384) {
          throw new Error('Input must be at most 16384 bytes, use utf8 or latin1, and cannot contain U+001E');
        }
        command.data = values.data; command.encoding = encoding;
      }
      let size;
      if (action === 'reset') { size = this.initialGeometry; }
      if (action === 'resize') { size = dimensions(values); Object.assign(command, size); }
      if (action === 'step') { size = this.story.steps[this.index + 1]?.size; }
      if (size) { command.geometry = dimensions(size); this.geometry = size; this.emit('geometry', size); }
      const request = deferred();
      request.timer = setTimeout(() => this.fail(new Error(`Native ${action} deadline exceeded`)), this.timeout);
      this.pending.set(command.sequence, request);
      this.child.stdin.write(JSON.stringify(command) + '\n');
      return await request.promise;
    });
    this.chain = operation.catch(() => {});
    return operation;
  }
  async close() {
    if (!this.closing) {
      this.closing = true; clearTimeout(this.startTimer); this.child.stdin.end();
      this.closeTimer = setTimeout(() => {
        const pid = this.child.pid;
        if (pid) { try { process.kill(-pid, 'SIGKILL'); } catch (error) { if (error.code !== 'ESRCH') { this.emit('failure', error); } } }
      }, 5000);
    }
    const result = await this.closed; clearTimeout(this.closeTimer); return result;
  }
}
