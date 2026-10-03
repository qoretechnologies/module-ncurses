#!/usr/bin/env python3
# Copyright (C) 2026 Qore Technologies, s.r.o.
# SPDX-License-Identifier: MIT
"""Run the complete guide examples with a headless terminal and deterministic input."""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

BUILD = Path(sys.argv.pop(1)).resolve()
ROOT = Path(__file__).resolve().parents[1]


class DocExamplesTest(unittest.TestCase):
    def test_complete_guide_examples(self):
        env = dict(os.environ)
        env.pop('LD_PRELOAD', None)
        env['QORE_MODULE_DIR'] = str(BUILD) + ':' + str(ROOT / 'qlib')
        count = 0
        for guide in sorted((ROOT / 'docs').glob('guide-*.dox.tmpl')):
            examples = re.findall(r'@code\{\.py\}\n(.*?)\s*@endcode', guide.read_text(), re.S)
            self.assertTrue(examples, f'{guide.name} needs a complete example')
            for index, code in enumerate(examples):
                with self.subTest(guide=guide.name, example=index):
                    self.assertTrue(code.startswith('%modern\n'), guide.name)
                    # Only replace the terminal acquisition. Drawing, layout, handlers, and
                    # assertions run exactly as published, including on_exit cleanup.
                    if 'Ncurses::Session session();' in code:
                        injected = 'session.injectEvent(<Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "q"});'
                        if 'guide-ncurses_mouse.' in guide.name:
                            injected = '''session.injectEvents((
    <Ncurses::InputEvent>{"type": Ncurses::InputType::Mouse,
     "mouse": <Ncurses::MouseEvent>{"x": 4, "y": 2, "button_state": Ncurses::BUTTON1_CLICKED}},
    <Ncurses::InputEvent>{"type": Ncurses::InputType::Resize},
    <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "q"},
));'''
                        elif 'DialogWidget dialog(' in code:
                            injected = 'session.injectEvent(<Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "\\n"});'
                        elif 'ListWidget choices(' in code:
                            injected = '''session.injectEvents((
    <Ncurses::InputEvent>{"type": Ncurses::InputType::Key, "code": Ncurses::KEY_DOWN},
    <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "q"},
));'''
                        code = code.replace('Ncurses::Session session();', '''Ncurses::TestTerminal doc_terminal(24, 80);
on_exit doc_terminal.close();
Ncurses::Session session({"test_terminal": doc_terminal});
''' + injected)
                    # Check visible output and event effects, not just successful execution.
                    if 'ListWidget choices(' in code:
                        code += '\n@assert(choices.getSelectedIndex() == 1);'
                        code += '\n@assert(session.screen().readText(0, 0, 80).find("Build") >= 0);'
                    elif 'DialogWidget dialog(' in code:
                        code += '\n@assert(!app.isRunning());'
                        code += '\n@assert(!app.getDispatcher().hasModal());'
                    elif 'guide-ncurses_quickstart.' in guide.name:
                        code += '\n@assert(window.readText(1, 2, 15) == "Hello, Ncurses!");'
                    elif 'guide-ncurses_styles.' in guide.name:
                        code += '\n@assert(window.readText(2, 1, 5) == "Ready");'
                    elif 'guide-ncurses_ansi.' in guide.name and index == 0:
                        code += '\n@assert(window.readText(1, 1, 9) == "Build: OK");'
                    elif 'guide-ncurses_api.' in guide.name:
                        code += '\n@assert(window.readText(0, 0, 14) == "Batched update");'
                    elif 'guide-ncurses_mouse.' in guide.name:
                        code += '\n@assert(window.readText(0, 0, 16) == "Terminal resized");'
                    elif 'guide-ncurses_examples.' in guide.name:
                        code += '\n@assert(first.window().readText(1, 1, 11) == "First panel");'
                    with tempfile.TemporaryDirectory(prefix='ncurses-doc-example-') as directory:
                        source = Path(directory) / 'example.qr'
                        source.write_text(code)
                        result = subprocess.run(
                            ['qore', '-b', '--enable-debug', '--warnings-are-errors', str(source)],
                            cwd=ROOT, env=env, capture_output=True, text=True, timeout=30)
                    self.assertEqual(0, result.returncode, result.stdout + result.stderr)
                    self.assertEqual('', result.stderr)
                    count += 1
        self.assertGreaterEqual(count, 12)


if __name__ == '__main__':
    unittest.main()
