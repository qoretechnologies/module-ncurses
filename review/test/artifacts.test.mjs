// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { PNG } from 'pngjs';
import { accept, digest, imageDiff, matrix, pack, semanticDiff, serialize, unpack, validateEntries } from '../artifacts.mjs';

test('semantic diffs retain coordinates, attributes, cursor, focus and scroll', () => {
  const before = { frame: { cols: 2, cursor: { x: 1 }, cells: [{ text: '界', width: 2, attrs: 0 }, { continuation: true }] }, state: { focus: 'Editor', scroll: 1 } };
  const after = structuredClone(before); after.frame.cells[0].attrs = 4; after.frame.cursor.x = 0; after.state.focus = 'Popup'; after.state.scroll = 2;
  assert.deepEqual(semanticDiff(before, after).map(change => change.path), ['/frame/cursor/x', '/frame/cells/0/attrs', '/state/focus', '/state/scroll']);
  assert.deepEqual(unpack(pack(before)), before);
  assert.equal(serialize({ b: 1, a: 2 }), serialize({ a: 2, b: 1 }));
  assert.deepEqual(semanticDiff(before, before), []);
  assert.equal(semanticDiff([1, 2], [1])[0].path, '/1');
});

test('exact image diffs catch a single changed pixel and geometry changes', () => {
  const a = new PNG({ width: 2, height: 2 }); a.data.fill(255);
  const b = PNG.sync.read(PNG.sync.write(a)); b.data[0] = 0;
  assert.equal(imageDiff(PNG.sync.write(a), PNG.sync.write(a)).pixels, 0);
  assert.equal(imageDiff(PNG.sync.write(a), PNG.sync.write(b)).pixels, 1);
  const tiny = new PNG({ width: 1, height: 1 }); tiny.data.fill(255);
  assert.equal(imageDiff(PNG.sync.write(a), PNG.sync.write(tiny)).resized, true);
});

test('matrix covers every applicable story in both modes and default size presets', () => {
  const stories = [{ id: 'x.default', state: 'default', geometry: { rows: 2, cols: 8 } }, { id: 'x.empty', state: 'empty', geometry: { rows: 2, cols: 8 } }];
  const cases = matrix(stories); assert.equal(cases.length, 10);
  assert.equal(new Set(cases.map(item => item.key)).size, cases.length);
  assert.equal(cases.filter(item => item.monochrome).length, 5);
  assert.equal(cases.filter(item => item.steps).length, 4);
});

test('baseline acceptance rejects missing evidence, partial runs and modified artifacts', async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ncurses-artifact-test-'));
  const current = path.join(root, 'current'), baseline = path.join(root, 'baseline'), evidence = path.join(root, 'review.txt');
  await fs.mkdir(current); await fs.writeFile(evidence, 'Reviewed the fixture and focus transition.');
  await assert.rejects(accept(current, baseline, '', evidence), /reviewer/);
  const manifest = { schema: 1, complete: false, entries: [{ key: 'x', hashes: { 'json.gz': digest('frame'), png: digest('image') } }] };
  assert.throws(() => validateEntries({ ...manifest, entries: [{ ...manifest.entries[0], key: '../outside' }] }), /Invalid/);
  assert.throws(() => validateEntries({ ...manifest, entries: [...manifest.entries, ...manifest.entries] }), /duplicate/);
  const write = () => fs.writeFile(path.join(current, 'manifest.json'), JSON.stringify(manifest));
  await write(); await assert.rejects(accept(current, baseline, 'Reviewer', evidence), /complete/);
  manifest.complete = true; manifest.filtered = true; await write();
  await assert.rejects(accept(current, baseline, 'Reviewer', evidence), /unfiltered/);
  manifest.filtered = false; await write();
  await fs.writeFile(path.join(current, 'x.json.gz'), 'frame'); await fs.writeFile(path.join(current, 'x.png'), 'changed');
  await assert.rejects(accept(current, baseline, 'Reviewer', evidence), /changed after review/);
  await fs.writeFile(path.join(current, 'x.png'), 'image'); await accept(current, baseline, 'Reviewer', evidence);
  assert.equal(await fs.readFile(path.join(baseline, 'x.png'), 'utf8'), 'image');
  assert.equal(JSON.parse(await fs.readFile(path.join(baseline, 'manifest.json'))).acceptance.reviewer, 'Reviewer');
});
