// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { chromium } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import { createBridgeServer } from '../server.mjs';
import { browserArgs, browserOptions, openStory, command } from '../browser.mjs';

test('native forms group fields and focus their values through label and help clicks', { timeout: 30000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  let browser;
  try {
    browser = await chromium.launch({ args: browserArgs });
    const page = await browser.newPage(browserOptions);
    const errors = []; page.on('pageerror', error => errors.push(error.message));
    const open = (id, mono) => openStory(page, `http://127.0.0.1:${server.port}`, server.stories.find(story => story.id === id), mono);
    const lines = ({ frame }) => Array.from({ length: frame.rows }, (_, y) =>
      frame.cells.slice(y * frame.cols, (y + 1) * frame.cols).map(cell => cell.text).join(''));
    const row = (frame, text) => {
      const index = lines(frame).findIndex(line => line.includes(text));
      assert.ok(index >= 0, `Missing visible field text: ${text}`); return index;
    };
    const click = async (frame, y, x = 5) => {
      const bounds = await page.locator('.xterm-screen').boundingBox();
      await page.mouse.click(bounds.x + (x + 0.5) * bounds.width / frame.frame.cols,
        bounds.y + (y + 0.5) * bounds.height / frame.frame.rows);
      return await command(page, 'capture');
    };
    for (const mono of [false, true]) {
      let frame = await open('form.default', mono);
      assert.ok(row(frame, 'Request name') < row(frame, 'A recognizable name'));
      assert.ok(row(frame, 'A recognizable name') < row(frame, '[Preview'));
      assert.equal(lines(frame)[row(frame, '[Preview') + 1].trim(), '');
      frame = await click(frame, row(frame, 'Attempts'));
      assert.equal(frame.frame.cursor.y, row(frame, '[3'));
      await page.keyboard.type('2'); frame = await command(page, 'capture'); row(frame, '[32');
      frame = await click(frame, row(frame, 'A recognizable name'));
      assert.equal(frame.frame.cursor.y, row(frame, '[Preview'));
      frame = await click(frame, row(frame, 'Include details'));
      assert.equal(frame.state.focus, 'FormCheckboxControl'); assert.equal(frame.state.include_details, true);
      await page.keyboard.press('Space'); frame = await command(page, 'capture'); assert.equal(frame.state.include_details, false);
      frame = await command(page, 'resize', 4, 12);
      row(frame, 'Include'); row(frame, '[ ]');
      frame = await command(page, 'resize', 8, 40);
      frame = await click(frame, row(frame, 'Include details'));
      assert.equal(frame.state.include_details, false);
      await page.keyboard.press('Tab'); frame = await command(page, 'capture'); row(frame, 'Submit');
      await page.keyboard.press('Enter'); frame = await command(page, 'capture');
      assert.equal(frame.state.activations, 1); row(frame, 'Submitted');
      await command(page, 'dispose');

      frame = await open('form.invalid', mono);
      const error = row(frame, 'Error: Use a unique');
      assert.ok(row(frame, 'A recognizable name') < error && error < row(frame, '[Preview'));
      frame = await click(frame, row(frame, 'Attempts'));
      frame = await click(frame, row(frame, 'Error: Use a unique'));
      assert.equal(frame.frame.cursor.y, row(frame, '[Preview'));
      await page.keyboard.type('x'); frame = await command(page, 'capture');
      row(frame, '[Previewx'); assert.ok(!lines(frame).some(line => line.includes('Error:')));
      frame = await command(page, 'resize', 2, 12);
      row(frame, 'Request'); assert.equal(frame.frame.cursor.visibility, 1);
      frame = await command(page, 'resize', 16, 64);
      row(frame, 'A recognizable name for this request.'); row(frame, '[Previewx');
      await command(page, 'dispose');

      frame = await open('form.disabled', mono);
      const before = frame.state;
      frame = await click(frame, row(frame, 'Attempts'));
      assert.deepEqual(frame.state, before); assert.equal(frame.frame.cursor.visibility, 0);
      await command(page, 'dispose');
    }
    assert.deepEqual(errors, []);
  } finally { if (browser) { await browser.close(); } await server.close(); }
  assert.equal(server.sessionCount, 0);
});
