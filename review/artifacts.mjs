// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import fs from 'node:fs/promises';
import path from 'node:path';
import { gzipSync, gunzipSync } from 'node:zlib';
import { createHash } from 'node:crypto';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';

export const digest = data => createHash('sha256').update(data).digest('hex');
export function canonical(value) {
  if (Array.isArray(value)) { return value.map(canonical); }
  if (value && typeof value === 'object') { return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])])); }
  return value;
}
export const serialize = value => JSON.stringify(canonical(value));
export const pack = value => gzipSync(serialize(value), { level: 9 });
export const unpack = data => JSON.parse(gunzipSync(data));

export function validateEntries(manifest) {
  if (manifest.schema !== 1 || !Array.isArray(manifest.entries)) { throw new Error('Invalid artifact manifest'); }
  const keys = new Set();
  for (const entry of manifest.entries) {
    if (!/^[a-z0-9-]+(?:\.[a-z0-9-]+)*$/.test(entry.key) || keys.has(entry.key)
        || !['png', 'json.gz'].every(extension => /^[a-f0-9]{64}$/.test(entry.hashes?.[extension]))) {
      throw new Error('Invalid or duplicate artifact entry');
    }
    keys.add(entry.key);
  }
}

export function matrix(stories) {
  const cases = [];
  for (const story of stories) {
    for (const monochrome of [false, true]) {
      const mode = monochrome ? 'mono' : 'color';
      cases.push({ key: `${story.id}.${mode}.registered`, story, monochrome, geometry: story.geometry, steps: true });
      if (story.state === 'default') {
        for (const [name, geometry] of Object.entries({ tiny: { rows: 4, cols: 12 }, standard: { rows: 24, cols: 80 }, wide: { rows: 32, cols: 120 } })) {
          cases.push({ key: `${story.id}.${mode}.${name}`, story, monochrome, geometry, steps: false });
        }
      }
    }
  }
  return cases;
}

/** Exact semantic changes remain readable even when a single glyph changes. */
export function semanticDiff(before, after, prefix = '') {
  if (serialize(before) === serialize(after)) { return []; }
  if (!before || !after || typeof before !== 'object' || typeof after !== 'object' || Array.isArray(before) !== Array.isArray(after)) {
    return [{ path: prefix || '/', before, after }];
  }
  const changes = [];
  for (const key of new Set([...Object.keys(before), ...Object.keys(after)])) {
    changes.push(...semanticDiff(before[key], after[key], `${prefix}/${key}`));
  }
  return changes;
}

export function imageDiff(before, after) {
  const a = PNG.sync.read(before), b = PNG.sync.read(after);
  const width = Math.max(a.width, b.width), height = Math.max(a.height, b.height);
  const pad = source => {
    const result = new PNG({ width, height });
    PNG.bitblt(source, result, 0, 0, source.width, source.height, 0, 0); return result;
  };
  const diff = new PNG({ width, height });
  const pixels = pixelmatch(pad(a).data, pad(b).data, diff.data, width, height, { threshold: 0, includeAA: true });
  return { pixels, resized: a.width !== b.width || a.height !== b.height, png: PNG.sync.write(diff) };
}

/** Acceptance requires an identified reviewer and an existing, complete review record. */
export async function accept(current, baseline, reviewer, evidence) {
  if (!reviewer?.trim() || !evidence?.trim()) { throw new Error('Acceptance requires --reviewer and --evidence'); }
  const record = await fs.readFile(evidence);
  if (!record.length) { throw new Error('Review evidence is empty'); }
  const manifest = JSON.parse(await fs.readFile(path.join(current, 'manifest.json')));
  validateEntries(manifest);
  if (!manifest.complete || manifest.filtered || !manifest.entries.length) { throw new Error('Only a complete, unfiltered run can become a baseline'); }
  for (const entry of manifest.entries) {
    for (const extension of ['json.gz', 'png']) {
      const data = await fs.readFile(path.join(current, `${entry.key}.${extension}`));
      if (digest(data) !== entry.hashes[extension]) { throw new Error(`Artifact changed after review: ${entry.key}.${extension}`); }
    }
  }
  await fs.mkdir(baseline, { recursive: true });
  // Only explicit tracked baseline files are replaced. Old files are not deleted implicitly.
  for (const entry of manifest.entries) {
    for (const extension of ['json.gz', 'png']) { await fs.copyFile(path.join(current, `${entry.key}.${extension}`), path.join(baseline, `${entry.key}.${extension}`)); }
  }
  await fs.writeFile(path.join(baseline, 'manifest.json'), JSON.stringify({ ...manifest,
    acceptance: { reviewer: reviewer.trim(), evidence, evidence_sha256: digest(record) } }, null, 2) + '\n');
}
