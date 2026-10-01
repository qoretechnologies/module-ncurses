#!/usr/bin/python3
# Copyright (C) 2026 Qore Technologies, s.r.o.
# SPDX-License-Identifier: MIT
"""Check the public widget API and links in generated module documentation."""
from html.parser import HTMLParser
from pathlib import Path
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
        self.feed(path.read_text())

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'a' and 'href' in attrs:
            self.links.append(attrs['href'])

    def handle_data(self, data):
        self.text.append(data)


class DocsTest(unittest.TestCase):
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
