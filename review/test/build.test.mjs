// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { digest } from '../artifacts.mjs';
import fs from 'node:fs/promises';
import { registry } from '../native.mjs';
const output = new URL('../storybook-static/', import.meta.url);
test('built Storybook exposes every native ID and stays within explicit asset budgets', async () => {
  const index = JSON.parse(await fs.readFile(new URL('index.json', output), 'utf8'));
  assert.deepEqual(Object.values(index.entries).map(entry => entry.name).sort(), (await registry()).map(story => story.id).sort());
  const assets = new URL('assets/', output);
  for (const name of await fs.readdir(assets)) {
    if (!name.endsWith('.js')) { continue; }
    const bytes = (await fs.stat(new URL(name, assets))).size;
    const budget = name.startsWith('storybook-') ? 900000 : 400000;
    assert.ok(bytes < budget, `${name}: ${bytes} bytes exceeds ${budget}`);
  }
});

test('vendored complete terminal fonts match their pinned upstream hashes', async () => {
  const directory = new URL('../fonts/', import.meta.url);
  const sources = JSON.parse(await fs.readFile(new URL('sources.json', directory)));
  for (const source of sources.files) {
    assert.equal(digest(await fs.readFile(new URL(source.file, directory))), source.sha256, source.file);
  }
});
