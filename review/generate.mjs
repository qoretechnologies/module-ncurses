// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import fs from 'node:fs/promises';
import { registry } from './native.mjs';
const stories = await registry(); const directory = new URL('./generated/', import.meta.url);
await fs.mkdir(directory, { recursive: true });
const widgets = new Map();
for (const story of stories) { if (!widgets.has(story.widget)) { widgets.set(story.widget, []); } widgets.get(story.widget).push(story); }
for (const [widget, entries] of widgets) {
  let source = '// Generated from the executable Qore registry. Copyright 2026 Qore Technologies, s.r.o.\n';
  source += 'import { renderStory } from "../terminal.mjs";\n';
  source += `export default { title: ${JSON.stringify('Native/' + widget)}, parameters: { layout: 'fullscreen' }, argTypes: { monochrome: { control: 'boolean' }, rows: { control: { type: 'number', min: 1, max: 100 } }, cols: { control: { type: 'number', min: 1, max: 240 } } } };\n`;
  for (const story of entries) {
    const name = story.id.split('.')[1].replace(/(^|-)(\w)/g, (_, separator, letter) => letter.toUpperCase());
    source += `export const ${name} = { name: ${JSON.stringify(story.id)}, args: { monochrome: false, rows: ${story.geometry.rows}, cols: ${story.geometry.cols} }, render: args => renderStory(${JSON.stringify(story)}, { monochrome: args.monochrome, geometry: { rows: args.rows, cols: args.cols } }) };\n`;
  }
  await fs.writeFile(new URL(`${widget}.stories.js`, directory), source);
}
await fs.writeFile(new URL('registry.json', directory), JSON.stringify(stories));
console.log(`Generated ${stories.length} native stories for ${widgets.size} widgets`);
