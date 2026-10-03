#!/usr/bin/python3
# Copyright (C) 2026 Qore Technologies, s.r.o.
# SPDX-License-Identifier: MIT
"""Check the public widget API and links in generated module documentation."""
from html.parser import HTMLParser
from pathlib import Path
import re
import sys
import unittest
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET

BUILD = Path(sys.argv.pop(1)).resolve()


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.links = []
        self.text = []
        self.ids = set()
        self.feed(path.read_text())

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            self.ids.add(attrs['id'])
        if tag == 'a' and 'href' in attrs:
            self.links.append(attrs['href'])

    def handle_data(self, data):
        self.text.append(data)


class DocsTest(unittest.TestCase):
    def test_initial_release_and_version_metadata(self):
        root = Path(__file__).resolve().parents[1]
        notes = (root / 'docs/release-notes.doxygen.tmpl').read_text()
        self.assertEqual(['initial release'], re.findall(r'^\s*- (.+)$', notes, re.M))
        self.assertEqual(1, notes.count('@section'))
        self.assertIn('ncurses Module Version 1.0', notes)
        self.assertIn('set(VERSION_MAJOR 1)', (root / 'CMakeLists.txt').read_text())
        self.assertIn('Version: 1.0.0', (root / 'qore-ncurses-module.spec').read_text())
        self.assertTrue((root / 'debian/changelog').read_text().startswith('qore-ncurses-module (1.0.0'))
        self.assertRegex((BUILD / 'Doxyfile').read_text(), r'PROJECT_NUMBER\s*=\s*1\.0\.0')
        page = Page(BUILD / 'docs/ncurses/html/ncursesreleasenotes.html')
        text = ''.join(page.text)
        self.assertIn('initial release', text)
        self.assertNotIn('Version 2.0', text)
        for directory in ('src', 'qlib'):
            for path in (root / directory).rglob('*'):
                if path.suffix in ('.qpp', '.qm', '.qc'):
                    self.assertNotRegex(path.read_text(), r'@since\s+%?ncurses\s+2\.', str(path))

    def test_mainpage_and_guide_links_resolve(self):
        directory = BUILD / 'docs/ncurses/html'
        pages = [directory / 'index.html', *directory.glob('ncurses_*guide.html')]
        self.assertEqual(10, len(pages))
        for path in pages:
            page = Page(path)
            self.assertNotIn('@ref ', ''.join(page.text), str(path))
            for link in page.links:
                url = urlsplit(link)
                if url.scheme or url.netloc:
                    continue
                with self.subTest(page=path.name, link=link):
                    target = path.parent / unquote(url.path) if url.path else path
                    self.assertTrue(target.is_file(), link)
                    if url.fragment:
                        self.assertIn(unquote(url.fragment), Page(target).ids, link)
        main = (Path(__file__).resolve().parents[1] / 'docs/mainpage.dox.tmpl').read_text()
        self.assertNotIn('@subpage', main)
        for name in ('quickstart', 'mouse', 'styles', 'ansi', 'tools', 'ui_widgets', 'testing', 'examples', 'api'):
            self.assertIn('@ref ncurses_' + name + 'guide', main)

    def test_public_widget_classes_and_methods_have_pages(self):
        compounds = {c.findtext('name'): c for c in ET.parse(BUILD / 'NcursesUi.tag').findall('compound')}
        for name, method in [('Widget', 'addChild'), ('Application', 'run'),
                             ('DialogWidget', 'confirm'), ('ListWidget', 'setItems'),
                             ('ScrollableWidget', 'setContent'), ('TableWidget', 'setColumns')]:
            with self.subTest(name=name):
                compound = compounds['NcursesUi::' + name]
                self.assertIn(method, [m.findtext('name') for m in compound.findall('member')])
                self.assertTrue((BUILD / 'docs/NcursesUi/html' / compound.findtext('filename')).is_file())
        widget_page = BUILD / 'docs/NcursesUi/html' / compounds['NcursesUi::Widget'].findtext('filename')
        self.assertIn('Base widget for the NcursesUi toolkit', ''.join(Page(widget_page).text))

    def test_cross_module_links_resolve_to_installed_sibling_pages(self):
        destinations = set()
        for module in ('ncurses', 'NcursesUi', 'NcursesReplUi'):
            for path in (BUILD / 'docs' / module / 'html').glob('*.html'):
                for link in Page(path).links:
                    url = urlsplit(link)
                    if not url.scheme and url.path.startswith('../../'):
                        destination = path.parent / unquote(url.path)
                        self.assertTrue(destination.is_file(), f'{path.name}: {link}')
                        destinations.add(url.path.split('/')[2])
        self.assertTrue({'ncurses', 'NcursesUi', 'NcursesReplUi'} <= destinations, destinations)

    def test_history_links_and_test_helper_example(self):
        pages = [Page(p) for p in (BUILD / 'docs/NcursesReplUi/html').glob('*.html')]
        self.assertTrue(any('/modules/QoreHistory/html/' in link for page in pages for link in page.links))
        overview = Page(BUILD / 'docs/NcursesUi/html/index.html')
        text = ''.join(overview.text)
        self.assertIn('test/TestHarness.qc', text)
        self.assertIn('%include', text)


if __name__ == '__main__':
    unittest.main()
