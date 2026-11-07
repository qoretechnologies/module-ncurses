// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { chromium } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import { createBridgeServer } from '../server.mjs';
import { browserOptions, browserArgs, command, inputBytes, openStory } from '../browser.mjs';

test('every default and mouse story follows the same registry interactions through real PTY input', { timeout: 180000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  let browser;
  try {
    browser = await chromium.launch({ args: browserArgs });
    const page = await browser.newPage(browserOptions);
    const errors = []; page.on('pageerror', error => errors.push(error.message));
    for (const story of server.stories.filter(story => ['default', 'mouse'].includes(story.state))) {
      await openStory(page, `http://127.0.0.1:${server.port}`, story);
      const scripted = [];
      for (const step of story.steps) { scripted.push(await command(page, 'step')); }
      await command(page, 'reset');
      for (const [index, step] of story.steps.entries()) {
        if (step.size) { await command(page, 'resize', step.size.rows, step.size.cols); }
        if (step.event) { await command(page, 'input', inputBytes(step.event)); }
        const actual = await command(page, 'capture');
        assert.deepEqual(actual.state, scripted[index].state, `${story.id}/${step.checkpoint} state`);
        assert.deepEqual(actual.frame, scripted[index].frame, `${story.id}/${step.checkpoint} composed frame`);
      }
      await command(page, 'dispose');
    }
    assert.deepEqual(errors, []);
  } finally { if (browser) { await browser.close(); } await server.close(); }
  assert.equal(server.sessionCount, 0);
});

test('input encoding rejects unsupported event types', () => {
  assert.throws(() => inputBytes({ type: 99 }), /No PTY encoding/);
  assert.throws(() => inputBytes({ type: 2, name: 'unknown' }), /No PTY encoding/);
});
