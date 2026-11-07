// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { chromium } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import { createBridgeServer } from '../server.mjs';
import { browserArgs, browserOptions, openStory, command } from '../browser.mjs';

test('progress, table selection and chart modes remain legible through real input and resize', { timeout: 45000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  let browser;
  try {
    browser = await chromium.launch({ args: browserArgs });
    const page = await browser.newPage(browserOptions);
    const errors = []; page.on('pageerror', error => errors.push(error.message));
    const open = (id, mono) => openStory(page, `http://127.0.0.1:${server.port}`, server.stories.find(story => story.id === id), mono);
    const text = capture => capture.frame.cells.map(cell => cell.text).join('');
    for (const mono of [false, true]) {
      let frame = await open('progress.default', mono);
      assert.match(text(frame), /Pending/);
      await page.keyboard.press('Enter'); frame = await command(page, 'capture');
      assert.match(text(frame), /Running/); assert.match(text(frame), /25%/);
      assert.notEqual(frame.frame.cells[2 * frame.frame.cols + 1].attrs, frame.frame.cells[2 * frame.frame.cols + 11].attrs);
      await page.keyboard.press('c'); frame = await command(page, 'capture'); assert.match(text(frame), /Cancelled/);
      await page.keyboard.press('Enter'); frame = await command(page, 'capture'); assert.match(text(frame), /Running/);
      await command(page, 'dispose');

      frame = await open('table.scrolling', mono);
      assert.notEqual(frame.frame.cells[0].attrs, frame.frame.cells[frame.frame.cols].attrs);
      await page.keyboard.press('End'); frame = await command(page, 'capture'); assert.equal(frame.state.selected, 23);
      frame = await command(page, 'resize', 4, 12); assert.equal(frame.state.selected, 23);
      frame = await command(page, 'resize', 8, 32); assert.match(text(frame), /Row 23/);
      await command(page, 'dispose');

      for (const [id, expected] of [['text-chart.default', '▁▄?▂█'], ['text-chart.ascii', '.=?:@'], ['text-chart.expanded', 'Height: min to max']]) {
        frame = await open(id, mono); assert.ok(text(frame).includes(expected), id);
        if (id === 'text-chart.expanded') {
          const occupied = Array.from({ length: frame.frame.rows }, (_, y) => frame.frame.cells.slice(y * frame.frame.cols, (y + 1) * frame.frame.cols).some(cell => /[▁-█]/u.test(cell.text)));
          assert.equal(occupied.filter(Boolean).length, 6);
          frame = await command(page, 'resize', 4, 12);
          await page.keyboard.press('End'); frame = await command(page, 'capture'); assert.ok(frame.state.scroll > 0);
          frame = await command(page, 'resize', 16, 64);
          await page.keyboard.press('Home'); frame = await command(page, 'capture'); assert.ok(text(frame).includes(expected));
        }
        await command(page, 'dispose');
      }
    }
    assert.deepEqual(errors, []);
  } finally { if (browser) { await browser.close(); } await server.close(); }
  assert.equal(server.sessionCount, 0);
});
