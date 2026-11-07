// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { PNG } from 'pngjs';
import { digest, pack, unpack } from '../artifacts.mjs';

const directory = fileURLToPath(new URL('../', import.meta.url));
function run(args, env = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, ['visual.mjs', ...args], { cwd: directory, env: { ...process.env, ...env }, stdio: ['ignore', 'pipe', 'pipe'] });
    let output = ''; child.stdout.on('data', data => { output += data; }); child.stderr.on('data', data => { output += data; });
    child.on('error', reject); child.on('close', code => resolve({ code, output }));
  });
}

test('visual command reports missing, unchanged, changed and invalid evidence without blessing it', { timeout: 60000 }, async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ncurses-visual-test-'));
  const output = path.join(root, 'report'), baseline = path.join(root, 'reference');
  const args = ['--filter', 'label.default.color.registered', '--output', output, '--baseline', baseline];
  let result = await run(args); assert.equal(result.code, 1, result.output);
  let report = JSON.parse(await fs.readFile(path.join(output, 'report.json')));
  assert.ok(report.some(item => item.status === 'missing baseline'));
  assert.match(await fs.readFile(path.join(output, 'index.html'), 'utf8'), /missing baseline/);
  // A temporary test reference exercises comparisons, never the production acceptance path.
  await fs.cp(path.join(output, 'current'), baseline, { recursive: true });
  result = await run(args); assert.equal(result.code, 0, result.output);
  assert.deepEqual(JSON.parse(await fs.readFile(path.join(output, 'report.json'))), []);
  const manifest = JSON.parse(await fs.readFile(path.join(baseline, 'manifest.json')));
  const key = manifest.entries[0].key;
  const framePath = path.join(baseline, `${key}.json.gz`), imagePath = path.join(baseline, `${key}.png`);
  const frame = unpack(await fs.readFile(framePath)); frame.frame.cells[0].text = 'Changed';
  await fs.writeFile(framePath, pack(frame));
  const png = PNG.sync.read(await fs.readFile(imagePath)); png.data[0] ^= 255; await fs.writeFile(imagePath, PNG.sync.write(png));
  manifest.entries[0].hashes = { 'json.gz': digest(await fs.readFile(framePath)), png: digest(await fs.readFile(imagePath)) };
  await fs.writeFile(path.join(baseline, 'manifest.json'), JSON.stringify(manifest));
  result = await run(args); assert.equal(result.code, 1, result.output);
  report = JSON.parse(await fs.readFile(path.join(output, 'report.json')));
  const changed = report.find(item => item.key === key); assert.equal(changed.semantic, 1); assert.equal(changed.pixels, 1);
  assert.ok((await fs.stat(path.join(output, 'diff', `${key}.png`))).size > 0);
  await fs.writeFile(framePath, 'corrupt');
  result = await run(args); assert.equal(result.code, 1); assert.match(await fs.readFile(path.join(output, 'report.json'), 'utf8'), /Invalid baseline integrity/);
  await fs.writeFile(path.join(baseline, 'manifest.json'), '{invalid');
  result = await run(args); assert.equal(result.code, 1);
  assert.equal(JSON.parse(await fs.readFile(path.join(output, 'current/manifest.json'))).complete, false);
  assert.match(await fs.readFile(path.join(output, 'index.html'), 'utf8'), /failed/);
  await fs.writeFile(path.join(baseline, 'manifest.json'), JSON.stringify(manifest));
  result = await run(args, { NCURSES_BUILD_DIR: path.join(root, 'missing-build') });
  assert.equal(result.code, 1); assert.equal(JSON.parse(await fs.readFile(path.join(output, 'current/manifest.json'))).complete, false);
  result = await run(['--accept'], { CI: 'true' }); assert.equal(result.code, 1); assert.match(result.output, /disabled in CI/);
});
