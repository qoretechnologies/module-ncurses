// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from '@playwright/test';
import { parseArgs } from 'node:util';
import { createBridgeServer } from './server.mjs';
import { browserOptions, browserArgs, openStory, command } from './browser.mjs';
import { accept, digest, imageDiff, matrix, pack, semanticDiff, serialize, unpack, validateEntries } from './artifacts.mjs';

const directory = fileURLToPath(new URL('./', import.meta.url));
const { values } = parseArgs({ options: {
  accept: { type: 'boolean' }, reviewer: { type: 'string' }, evidence: { type: 'string' },
  filter: { type: 'string' }, output: { type: 'string', default: path.join(directory, 'artifacts') },
  baseline: { type: 'string', default: path.join(directory, 'baselines') },
} });
if (values.accept) {
  if (process.env.CI) { throw new Error('Baseline acceptance is disabled in CI'); }
  await accept(path.join(values.output, 'current'), values.baseline, values.reviewer, values.evidence);
  console.log('Accepted the complete reviewed artifact set. Inspect and commit the baseline diff.');
} else {
  await run();
}

async function run() {
  const current = path.join(values.output, 'current'), differences = path.join(values.output, 'diff');
  await fs.mkdir(current, { recursive: true }); await fs.mkdir(differences, { recursive: true });
  let previous, server, browser;
  const manifest = { schema: 1, complete: false, filtered: !!values.filter, entries: [] };
  const report = [];
  // A failed new run cannot leave an older complete manifest available for acceptance.
  await fs.writeFile(path.join(current, 'manifest.json'), JSON.stringify(manifest) + '\n');
  try {
    try { previous = JSON.parse(await fs.readFile(path.join(values.baseline, 'manifest.json'))); }
    catch (error) { if (error.code !== 'ENOENT') { throw error; } }
    if (previous && (previous.schema !== 1 || !previous.complete || !Array.isArray(previous.entries) || !previous.environment)) {
      throw new Error('Invalid baseline manifest');
    }
    if (previous) { validateEntries(previous); }
    const references = new Map((previous?.entries ?? []).map(entry => [entry.key, entry]));
    server = await createBridgeServer({ port: 0, staticDir: path.join(directory, 'storybook-static') });
    browser = await chromium.launch({ args: browserArgs });
    const page = await browser.newPage(browserOptions);
    page.setDefaultTimeout(20000);
    const errors = []; page.on('pageerror', error => errors.push(error.message));
    manifest.environment = { browser: browser.version(), platform: process.platform, ...browserOptions,
      args: browserArgs, term: 'xterm-256color', locale: 'C.UTF-8', timezone: 'UTC',
      dependencies: digest(await fs.readFile(path.join(directory, 'package-lock.json'))),
      fonts: digest(await fs.readFile(path.join(directory, 'fonts/sources.json'))),
      renderer: digest(await fs.readFile(path.join(directory, 'terminal.mjs'))) };
    const cases = matrix(server.stories).filter(item => !values.filter || item.key.includes(values.filter));
    if (!cases.length) { throw new Error('No matching review scenarios'); }
    const environmentChanged = !previous || serialize(previous.environment) !== serialize(manifest.environment);
    if (environmentChanged) { report.push({ key: 'environment', status: 'changed or missing', changes: semanticDiff(previous?.environment, manifest.environment) }); }
    const save = async (item, artifact, checkpoint) => {
      const key = `${item.key}.${checkpoint}`;
      const semantic = pack(artifact);
      const png = await page.locator('.native-terminal').screenshot({ animations: 'disabled', caret: 'initial' });
      await fs.writeFile(path.join(current, `${key}.json.gz`), semantic);
      await fs.writeFile(path.join(current, `${key}.png`), png);
      manifest.entries.push({ key, story: item.story.id, widget: item.story.widget, hashes: { 'json.gz': digest(semantic), png: digest(png) } });
      try {
        const baselineData = await fs.readFile(path.join(values.baseline, `${key}.json.gz`));
        const baselinePng = await fs.readFile(path.join(values.baseline, `${key}.png`));
        const reference = references.get(key);
        if (!reference || reference.hashes['json.gz'] !== digest(baselineData) || reference.hashes.png !== digest(baselinePng)) {
          throw new Error(`Invalid baseline integrity: ${key}`);
        }
        const baselineFrame = unpack(baselineData);
        const changes = semanticDiff(baselineFrame, artifact), diff = imageDiff(baselinePng, png);
        await fs.writeFile(path.join(differences, `${key}.json`), JSON.stringify(changes, null, 2) + '\n');
        await fs.writeFile(path.join(differences, `${key}.png`), diff.png);
        if (changes.length || diff.pixels || diff.resized) { report.push({ key, status: 'changed', semantic: changes.length, pixels: diff.pixels, resized: diff.resized }); }
      } catch (error) {
        if (error.code !== 'ENOENT') { throw error; }
        report.push({ key, status: 'missing baseline' });
      }
    };
    for (const item of cases) {
      const initial = await openStory(page, `http://127.0.0.1:${server.port}`, item.story, item.monochrome, item.geometry);
      await save(item, initial, 'mounted');
      if (item.steps) {
        for (const step of item.story.steps) { await save(item, await command(page, 'step'), step.checkpoint); }
      }
      await command(page, 'dispose');
      if (errors.length) { throw new Error(errors.join('\n')); }
      console.log(`Captured ${item.key}`);
    }
    if (!values.filter) {
      const present = new Set(manifest.entries.map(entry => entry.key));
      for (const old of previous?.entries ?? []) { if (!present.has(old.key)) { report.push({ key: old.key, status: 'removed scenario' }); } }
    }
    manifest.complete = true;
  } catch (error) {
    report.push({ key: 'capture', status: 'failed', error: error.message });
    process.exitCode = 1;
  } finally {
    try { if (browser) { await browser.close(); } }
    finally {
      try { if (server) { await server.close(); } }
      finally {
        await fs.writeFile(path.join(current, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
        await fs.writeFile(path.join(values.output, 'report.json'), JSON.stringify(report, null, 2) + '\n');
      }
    }
  }
  const escape = value => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('"', '&quot;');
  const cards = manifest.entries.map(entry => `<details><summary>${escape(entry.key)}</summary><p>Baseline / current / exact pixel diff</p>${[
    path.relative(values.output, path.join(values.baseline, `${entry.key}.png`)), `current/${entry.key}.png`, `diff/${entry.key}.png`,
  ].map(src => `<img alt="${escape(src)}" src="${escape(src)}">`).join('')}<p><a href="diff/${escape(entry.key)}.json">Cell, attribute, cursor, focus and scroll changes</a></p></details>`).join('\n');
  await fs.writeFile(path.join(values.output, 'index.html'), `<!doctype html><meta charset="utf-8"><title>Native widget review</title><style>body{font:16px sans-serif;background:#ddd;color:#111}img{vertical-align:top;max-width:100%;margin:4px}details{padding:8px;border-bottom:1px solid #888}</style><h1>Native widget review</h1><p>${manifest.entries.length} artifacts; ${report.length} differences. Complete: ${manifest.complete}. Open report.json for the machine-readable result.</p><pre>${escape(JSON.stringify(report, null, 2))}</pre>${cards}`);
  console.log(`${manifest.entries.length} artifacts; ${report.length} differences. ${path.join(values.output, 'index.html')}`);
  if (report.length) { process.exitCode = 1; }
}
