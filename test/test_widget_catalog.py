#!/usr/bin/env python3
"""Exercise executable registry export, catalog drift and inventory validation.

Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
"""
import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
BUILD = Path(sys.argv.pop(1)).resolve() if len(sys.argv) > 1 else ROOT / 'build-debug'
spec = importlib.util.spec_from_file_location('widget_catalog', ROOT / 'tools/widget_catalog.py')
catalog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(catalog)


class CatalogTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.stories = catalog.load(BUILD)
        cls.env = dict(os.environ, QORE_MODULE_DIR=f'{BUILD}:{ROOT / "qlib"}')
        cls.command = ['qore', '--enable-debug', '--warnings-are-errors', 'examples/widget-gallery.qr']

    def test_generated_catalog_matches_registry(self):
        catalog.validate(self.stories)
        self.assertEqual((ROOT / 'docs/widget-catalog.dox').read_text(), catalog.render(self.stories))
        self.assertEqual(27, len({s['widget'] for s in self.stories}))
        self.assertGreater(len(self.stories), 150)
        self.assertTrue(all(s['steps'][0]['expected'] for s in self.stories))

    def test_new_widget_missing_registration_fails(self):
        public = {s['widget'] for s in self.stories} | {'FutureWidget'}
        with self.assertRaisesRegex(ValueError, 'FutureWidget'):
            catalog.validate(self.stories, public)

    def test_duplicate_id_and_incomplete_state_matrix_fail(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            catalog.validate(self.stories + [self.stories[0]])
        broken = copy.deepcopy(self.stories)
        del broken[0]['states']['invalid']
        with self.assertRaisesRegex(ValueError, 'incomplete state'):
            catalog.validate(broken)
        broken[0]['states']['invalid'] = 'missing.scenario'
        with self.assertRaisesRegex(ValueError, 'unregistered'):
            catalog.validate(broken)

    def test_malformed_configuration_fails(self):
        for mutate, message in [
            (lambda s: s.update(id='../arbitrary'), 'Invalid stable ID'),
            (lambda s: s['geometry'].update(rows=0), 'invalid geometry'),
            (lambda s: s['steps'].append(s['steps'][0]), 'duplicate or empty checkpoints'),
            (lambda s: s.update(fixture={}), 'missing fixture'),
        ]:
            with self.subTest(message=message):
                broken = copy.deepcopy(self.stories)
                mutate(broken[0])
                with self.assertRaisesRegex(ValueError, message):
                    catalog.validate(broken)

    def test_invalid_cli_fails_before_opening_terminal(self):
        for arguments in (['--story', '../bad'], ['--story'], ['--unknown']):
            with self.subTest(arguments=arguments):
                run = subprocess.run(self.command + arguments, cwd=ROOT, env=self.env,
                                     input='', capture_output=True, text=True, timeout=30)
                self.assertNotEqual(0, run.returncode)
                self.assertEqual('', run.stdout)
                self.assertIn('GALLERY-', run.stderr)
                self.assertNotIn('newterm', run.stderr)

    def test_actual_cli_runs_every_widget_and_repeats_pilots(self):
        for story in self.stories:
            if story['state'] != 'default':
                continue
            for monochrome in (False, True):
                with self.subTest(story=story['id'], monochrome=monochrome):
                    args = self.command + ['--headless', '--story', story['id']]
                    if monochrome:
                        args.append('--monochrome')
                    run = subprocess.run(args, cwd=ROOT, env=self.env, capture_output=True, text=True, timeout=30)
                    self.assertEqual(0, run.returncode, run.stderr)
                    self.assertEqual('', run.stderr)
                    frames = json.loads(run.stdout)
                    self.assertEqual([step['checkpoint'] for step in story['steps']], [f['checkpoint'] for f in frames])
                    for frame in frames:
                        self.assertEqual(story['id'], frame['story'])
                        self.assertEqual(not monochrome, frame['frame']['colors_enabled'])
                        self.assertEqual(frame['frame']['rows'] * frame['frame']['cols'], len(frame['frame']['cells']))
                    if story['id'] in {'text-editor.boundaries', 'table.scrolling', 'completion-popup.overlap'}:
                        repeat = subprocess.run(args, cwd=ROOT, env=self.env, capture_output=True, text=True, timeout=30)
                        self.assertEqual(0, repeat.returncode, repeat.stderr)
                        self.assertEqual(frames, json.loads(repeat.stdout))


if __name__ == '__main__':
    unittest.main()
