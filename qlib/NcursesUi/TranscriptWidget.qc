#! @file TranscriptWidget.qc Searchable streaming transcript with stable anchors
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
#! A source position retained across wrapping, insertions and trimming.
public hashdecl TextAnchor { int line_id; int offset; }
#! One literal search match in a retained logical line.
public hashdecl TranscriptMatch { int line_id; int start; int end; }
#! A caller-defined link range. Targets are delivered to callbacks and never opened automatically.
public hashdecl TranscriptLink inherits TranscriptMatch { string target; }
#! Read-only metadata for a logical submitted-input or response block.
public hashdecl TranscriptBlockInfo { int id; string kind; string title; bool collapsed; list<int> line_ids; }
class TranscriptBlockState {
    public { int id; string kind; string title; bool collapsed = False; int first = 0; list<int> line_ids = (); list<string> text = (); }
    constructor(int id, string kind, string title) { self.id = id; self.kind = kind; self.title = title; }
}

/** Streaming transcript with literal search, stable selection and optional tail following.
    Up/PageUp/Home pause following; End or returnToLatest() resumes it. Appends
    preserve the reading anchor and increase unread count while paused. Copy and
    link handling are application callbacks; this widget performs no external I/O.
*/
public class TranscriptWidget inherits NcursesUi::ScrollableWidget {
    private {
        NcursesUi::LineListContent text();
        hash<string, NcursesUi::TranscriptBlockState> blocks = {};
        list<int> block_order = ();
        int block_start = 0;
        int pruned_lines = 0;
        int next_block = 1;
        *int retained_first;
        bool follow_tail = True;
        int unread = 0;
        *hash<NcursesUi::TextAnchor> mouse_anchor;
        hash<string, string> original_headers = {};
        *hash<NcursesUi::TextAnchor> selection_start;
        *hash<NcursesUi::TextAnchor> selection_end;
        string search = "";
        int searched_revision = -1;
        list<hash<NcursesUi::TranscriptMatch>> matches = ();
        hash<string, list<hash<NcursesUi::TranscriptMatch>>> match_lines = {};
        *hash<NcursesUi::TranscriptMatch> active_match;
        hash<string, list<hash<NcursesUi::TranscriptLink>>> links = {};
        *code<nothing(string)> copy_handler;
        *code<nothing(string)> link_handler;
    }
    constructor() { text.setWordWrap(True); setContent(text); }
    /** Returns the presentation provider, including stable line identities and collapse indicators. @return transcript content */
    NcursesUi::LineListContent getTranscriptContent() { return text; }
    /** Adds one logical block as a batch. Empty blocks retain one empty line.
        @param lines ANSI-styled logical lines @param kind application-defined block kind @param title metadata title
        @return stable block identity
    */
    int appendBlock(list<string> lines, string kind = "output", string title = "") {
        if (!lines) { lines = ("",); }
        NcursesUi::TranscriptBlockState block(next_block, kind, title);
        text.appendLines(lines);
        # Retention can remove part of a large incoming batch. Recover IDs from retained suffixes.
        int kept = min(lines.size(), text.lineCount()); int skip = lines.size() - kept;
        for (int i = 0; i < kept; ++i) { block.line_ids += text.getLineId(text.lineCount() - kept + i); block.text += lines[skip + i]; }
        blocks{string(next_block)} = block; block_order += next_block; ++next_block;
        changed(lines.size()); return block.id;
    }
    /** Appends a batch of output lines. @param lines ANSI-styled source lines */
    nothing appendLines(list<string> lines) { if (lines) { appendBlock(lines); } }
    /** Appends one output line. @param line ANSI-styled source */
    nothing appendLine(string line) { appendLines((line,)); }
    /** Adds lines to an existing block, preserving its retained line identities.
        Appending to the last block is incremental; insertion into an earlier block updates the source index.
        @param id block identity @param lines additional source lines
        @throw TRANSCRIPT-BLOCK-ERROR if the block was removed
    */
    nothing appendBlockLines(int id, list<string> lines) {
        prune(); NcursesUi::TranscriptBlockState block = getBlock(id);
        if (!lines) { return; }
        int insert_at = text.lineForId(block.line_ids[-1]) + 1; list<int> added = ();
        if (insert_at == text.lineCount()) {
            text.appendLines(lines);
            int kept = min(lines.size(), text.lineCount());
            for (int i = 0; i < kept; ++i) {
                int line_id = text.getLineId(text.lineCount() - kept + i);
                block.line_ids += line_id; added += line_id; block.text += lines[lines.size() - kept + i];
            }
        } else {
            foreach string line in (lines) {
                # Capture the new identity before any following insertion; retention may shift the logical index.
                int before = text.lineCount(); text.insertLine(insert_at, line);
                int index = insert_at - (before + 1 - text.lineCount());
                if (index >= 0) { int line_id = text.getLineId(index); block.line_ids += line_id; added += line_id; block.text += line; }
                insert_at = max(0, index + 1);
            }
        }
        changed(lines.size());
        if (exists blocks{string(id)} && block.collapsed) {
            foreach int line_id in (added) { text.setLineVisible(text.lineForId(line_id), False); }
            collapseHeader(block);
        }
    }
    /** Returns ordered retained block metadata. @return stable IDs, kinds, titles and line IDs */
    list<hash<NcursesUi::TranscriptBlockInfo>> getBlocks() {
        prune(); list<hash<NcursesUi::TranscriptBlockInfo>> result = ();
        foreach int id in (retainedOrder()) {
            NcursesUi::TranscriptBlockState block = blocks{string(id)};
            result += <NcursesUi::TranscriptBlockInfo>{"id": id, "kind": block.kind, "title": block.title,
                "collapsed": block.collapsed, "line_ids": block.line_ids[block.first .. block.line_ids.size() - 1]};
        }
        return result;
    }
    /** Returns unadorned source text for a logical block. @param id block ID @return ANSI-free text */
    string getBlockText(int id) {
        prune(); NcursesUi::TranscriptBlockState block = getBlock(id);
        return NcursesUi::TerminalText::plainAnsi(join("\n", block.text[block.first .. block.text.size() - 1]));
    }
    /** Expands/collapses a block; hidden source lines retain their IDs.
        @param id block identity @param value True to collapse to its first line
    */
    nothing setCollapsed(int id, bool value) { prune(); NcursesUi::TranscriptBlockState block = getBlock(id); block.collapsed = value; applyCollapse(block); markDirty(); }
    /** Navigates to the next/previous block boundary from the current top row.
        @param forward True for next @return target block ID or NOTHING at a boundary
    */
    *int moveBlock(bool forward = True) {
        prune(); getViewportRect();
        int top = text.visualToSource(getScrollY(), 0).y; *int target;
        foreach int id in (retainedOrder()) {
            int line = text.lineForId(blocks{string(id)}.line_ids[blocks{string(id)}.first]);
            if (forward && line > top) { target = id; break; }
            if (!forward && line < top) { target = id; }
        }
        if (exists target) { setScrollY(text.displayRowForLine(text.lineForId(blocks{string(target)}.line_ids[blocks{string(target)}.first]))); }
        return target;
    }
    /** Sets the retention bound. @param maximum nonnegative logical line limit; zero is unlimited */
    nothing setRetentionLimit(int maximum) { text.setRetentionLimit(maximum); prune(); markDirty(); }
    /** Toggles soft wrapping without changing selection/search identities. @param enabled True to wrap */
    nothing setWordWrap(bool enabled) { text.setWordWrap(enabled); markDirty(); }
    /** Returns tail-following policy. @return True while following appended content */
    bool isFollowing() { return follow_tail; }
    /** Sets tail-following policy. @param enabled True to return to the latest content */
    nothing setFollowTail(bool enabled) { if (enabled) { returnToLatest(); } else { follow_tail = False; } }
    /** Returns appended line count since following was paused. @return unread line count */
    int getUnreadCount() { return unread; }
    /** Resumes following and clears the unread indicator. */
    nothing returnToLatest() { follow_tail = True; unread = 0; ScrollableWidget::scrollTo(NcursesUi::ScrollDirection::End); }
    /** Sets an explicit reading position and pauses following. @param row first visible display row */
    nothing setScrollY(int row) { follow_tail = False; ScrollableWidget::setScrollY(row); }
    /** Scrolls manually; End and reaching the tail with Down/PageDown resume following.
        @param direction ScrollDirection @param amount row/page count
    */
    nothing scrollTo(int direction, int amount = 1) {
        ScrollableWidget::scrollTo(direction, amount);
        if (direction == NcursesUi::ScrollDirection::End) { follow_tail = True; unread = 0; }
        else if (direction != NcursesUi::ScrollDirection::Left && direction != NcursesUi::ScrollDirection::Right) {
            follow_tail = (direction == NcursesUi::ScrollDirection::Down || direction == NcursesUi::ScrollDirection::PageDown)
                && getScrollY() >= max(0, text.totalRows() - getViewportRect().rows);
            if (follow_tail) { unread = 0; }
        }
    }
    /** Clears all blocks, selection, search matches and unread state. */
    nothing clear() {
        text.clear(); ScrollableWidget::setContent(text); blocks = {}; block_order = (); block_start = 0; links = {}; selection_start = NOTHING; selection_end = NOTHING; mouse_anchor = NOTHING; original_headers = {};
        active_match = NOTHING; unread = 0; follow_tail = True; retained_first = NOTHING; markDirty();
    }
    /** Configures clipboard delivery. @param handler receives selected plain text */
    nothing setOnCopy(*code<nothing(string)> handler) { copy_handler = handler; }
    /** Selects retained source positions. @param first starting anchor @param last ending anchor
        @throw TRANSCRIPT-SELECTION-ERROR if either line identity is no longer retained
    */
    nothing select(hash<NcursesUi::TextAnchor> first, hash<NcursesUi::TextAnchor> last) {
        int start = text.lineForId(first.line_id); int end = text.lineForId(last.line_id);
        if (start < 0 || end < 0) { throw "TRANSCRIPT-SELECTION-ERROR", "Selection references removed lines"; }
        mouse_anchor = first;
        if (start > end || (start == end && first.offset > last.offset)) {
            hash<NcursesUi::TextAnchor> swap = first; first = last; last = swap;
        }
        first.offset = NcursesReplUi::TextPosition::snapOffset(getSourceLine(text.lineForId(first.line_id)), first.offset);
        last.offset = NcursesReplUi::TextPosition::snapOffset(getSourceLine(text.lineForId(last.line_id)), last.offset, True);
        selection_start = first; selection_end = last; markDirty();
    }
    /** Returns a retained logical source line without presentation indicators or ANSI styling.
        @param line zero-based retained line index @return original plain text
    */
    string getSourceLine(int line) {
        *int id = text.getLineId(line);
        return NcursesUi::TerminalText::plainAnsi(original_headers{string(id)} ?? text.getLine(line));
    }
    /** Returns selected text without ANSI escapes. @return selected source text, including hard newlines */
    string getSelectedText() {
        prune(); if (!selection_start || !selection_end) { return ""; }
        int first = text.lineForId(selection_start.line_id); int last = text.lineForId(selection_end.line_id); list<string> selected = ();
        for (int line = first; line <= last; ++line) {
            string value = getSourceLine(line);
            int start = line == first ? selection_start.offset : 0; int end = line == last ? selection_end.offset : value.length();
            selected += value.substr(start, max(0, end - start));
        }
        return join("\n", selected);
    }
    /** Delivers current selection and propagates callback errors. @return True if a handler ran */
    bool copySelection() { if (!copy_handler) { return False; } copy_handler(getSelectedText()); return True; }
    /** Sets a literal case-sensitive search query. @param query plain text; empty clears matches */
    nothing setSearch(string query) { if (query != search) { search = query; searched_revision = -1; active_match = NOTHING; markDirty(); } }
    /** Returns retained search matches. @return stable identities and grapheme-expanded ranges */
    list<hash<NcursesUi::TranscriptMatch>> getMatches() { prepareMatches(); return matches; }
    /** Navigates cyclically to the next/previous match and reveals a collapsed matching block.
        @param forward True for next @return selected match or NOTHING when no matches exist
    */
    *hash<NcursesUi::TranscriptMatch> findNext(bool forward = True) {
        prepareMatches(); if (!matches) { return NOTHING; }
        int index = forward ? -1 : 0;
        if (active_match) { for (int i = 0; i < matches.size(); ++i) { if (matches[i] == active_match) { index = i; break; } } }
        index = (index + (forward ? 1 : -1) + matches.size()) % matches.size(); active_match = matches[index];
        foreach int id in (retainedOrder()) {
            NcursesUi::TranscriptBlockState block = blocks{string(id)};
            if (block.collapsed && text.lineForId(active_match.line_id) >= text.lineForId(block.line_ids[block.first])
                    && text.lineForId(active_match.line_id) <= text.lineForId(block.line_ids[-1])) { setCollapsed(id, False); break; }
        }
        getViewportRect(); hash<Ncurses::Position> pos = text.sourceToVisual(text.lineForId(active_match.line_id), active_match.start);
        setScrollY(pos.y);
        hash<NcursesUi::Rect> view = getViewportRect();
        hash<Ncurses::Position> end = text.sourceToVisual(text.lineForId(active_match.line_id), active_match.end);
        int target = getScrollX();
        if (pos.x < target) { target = pos.x; }
        else if (end.y == pos.y && end.x > target + view.cols) { target = min(pos.x, max(0, end.x - view.cols)); }
        else if (pos.x >= target + view.cols) { target = pos.x; }
        if (target < getScrollX()) { ScrollableWidget::scrollTo(NcursesUi::ScrollDirection::Left, getScrollX() - target); }
        else if (target > getScrollX()) { ScrollableWidget::scrollTo(NcursesUi::ScrollDirection::Right, target - getScrollX()); }
        markDirty(); return active_match;
    }
    /** Installs explicit source link ranges. @param ranges stable line IDs and character ranges
        @throw TRANSCRIPT-LINK-ERROR for invalid lines/ranges or empty targets
    */
    nothing setLinks(list<hash<NcursesUi::TranscriptLink>> ranges) {
        hash<string, list<hash<NcursesUi::TranscriptLink>>> normalized = {};
        foreach hash<NcursesUi::TranscriptLink> link in (ranges) {
            int line = text.lineForId(link.line_id);
            if (line < 0 || link.start < 0 || link.end <= link.start || link.target == ""
                    || link.end > getSourceLine(line).length()) {
                throw "TRANSCRIPT-LINK-ERROR", "Invalid link source range or target";
            }
            string plain = getSourceLine(line);
            link.start = NcursesReplUi::TextPosition::snapOffset(plain, link.start);
            link.end = NcursesReplUi::TextPosition::snapOffset(plain, link.end, True);
            string key = string(link.line_id);
            if (!exists normalized{key}) { normalized{key} = (); }
            normalized{key} += link;
        }
        links = normalized;
    }
    /** Configures link activation. @param handler receives the target URI/path; no implicit opening */
    nothing setOnLink(*code<nothing(string)> handler) { link_handler = handler; }
    /** Hit tests links using wrapped source positions. @param row screen row @param col screen column @return target or NOTHING */
    *string linkAt(int row, int col) {
        hash<NcursesUi::Rect> rect = getViewportRect();
        if (!NcursesUi::Geometry::rectContains(rect, row, col)) { return NOTHING; }
        int visual_row = getScrollY() + row - rect.y; int visual_col = getScrollX() + col - rect.x;
        *hash<NcursesUi::WrappedTextRow> entry = text.getVisualRow(visual_row);
        if (!entry || visual_col >= Ncurses::Ansi::len(entry.text)) { return NOTHING; }
        hash<Ncurses::Position> source = text.visualToSource(visual_row, visual_col);
        *int id = text.getLineId(source.y);
        foreach hash<NcursesUi::TranscriptLink> link in (links{string(id)} ?? ()) {
            if (id == link.line_id && source.x >= link.start && source.x < link.end) { return link.target; }
        }
        return NOTHING;
    }
    /** Draws styled text with search and selection highlights. @param w target window */
    nothing draw(Ncurses::Window w) {
        prune(); prepareDrawViewport(w); if (follow_tail) { ScrollableWidget::scrollTo(NcursesUi::ScrollDirection::End); }
        ScrollableWidget::draw(w); prepareMatches();
        hash<NcursesUi::Rect> rect = getViewportRect(); hash<Ncurses::Position> origin = w.position();
        int first = selection_start ? text.lineForId(selection_start.line_id) : -1;
        int last = selection_end ? text.lineForId(selection_end.line_id) : -1;
        for (int row = 0; row < rect.rows; ++row) {
            *hash<NcursesUi::WrappedTextRow> entry = text.getVisualRow(getScrollY() + row); if (!entry) { continue; }
            int id = text.getLineId(entry.line_idx); int offset = entry.start; int col = 0;
            int source_length = first >= 0 ? getSourceLine(entry.line_idx).length() : 0;
            list<hash<NcursesUi::TranscriptMatch>> row_matches = match_lines{string(id)} ?? ();
            foreach string cluster in (NcursesUi::TerminalText::graphemes(NcursesUi::TerminalText::plainAnsi(entry.text))) {
                int width = char_width(cluster);
                bool selected = offset < source_length && first >= 0 && entry.line_idx >= first && entry.line_idx <= last
                    && (entry.line_idx != first || offset >= selection_start.offset)
                    && (entry.line_idx != last || offset < selection_end.offset);
                bool matched = False;
                foreach hash<NcursesUi::TranscriptMatch> match in (row_matches) {
                    if (offset >= match.start && offset < match.end) { matched = True; break; }
                }
                if ((selected || matched) && col >= getScrollX() && col + width <= getScrollX() + rect.cols) {
                    w.drawTextClipped(rect.y + row - origin.y, rect.x + col - getScrollX() - origin.x, cluster,
                        {"attrs": selected ? Ncurses::Attr::Reverse : Ncurses::Attr::Standout});
                }
                offset += cluster.length(); col += width;
            }
        }
    }
    /** Handles scrolling, match navigation (n/N), copy (Ctrl-C) and source selection/link clicks.
        @param ev input event @return handling result
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (ev.type == Ncurses::InputType::Char) {
            if (ev.ch == "n") { findNext(); return <NcursesUi::EventResult>{"handled": True}; }
            if (ev.ch == "N") { findNext(False); return <NcursesUi::EventResult>{"handled": True}; }
            if (ev.ch == "\x03") { return <NcursesUi::EventResult>{"handled": copySelection()}; }
        } else if (ev.type == Ncurses::InputType::Mouse
                && (ev.mouse.button_state & (Ncurses::BUTTON1_CLICKED | Ncurses::BUTTON1_PRESSED))) {
            hash<NcursesUi::Rect> rect = getViewportRect();
            if (NcursesUi::Geometry::rectContains(rect, ev.mouse.y, ev.mouse.x) && text.lineCount()) {
                *string link = linkAt(ev.mouse.y, ev.mouse.x);
                if (exists link && link_handler) { link_handler(link); return <NcursesUi::EventResult>{"handled": True}; }
                hash<Ncurses::Position> source = text.visualToSource(getScrollY() + ev.mouse.y - rect.y, getScrollX() + ev.mouse.x - rect.x);
                hash<NcursesUi::TextAnchor> anchor = <NcursesUi::TextAnchor>{"line_id": text.getLineId(source.y), "offset": source.x};
                if (!(ev.mouse.button_state & Ncurses::BUTTON_SHIFT) || !mouse_anchor) { mouse_anchor = anchor; }
                select(mouse_anchor, anchor);
                return <NcursesUi::EventResult>{"handled": True};
            }
        }
        hash<NcursesUi::EventResult> result = ScrollableWidget::processEvent(ev);
        if (result.handled && ev.type == Ncurses::InputType::Mouse && ev.mouse
                && (ev.mouse.button_state & (Ncurses::BUTTON1_CLICKED | Ncurses::BUTTON1_PRESSED))) {
            follow_tail = getScrollY() >= max(0, text.totalRows() - getViewportRect().rows);
            if (follow_tail) { unread = 0; }
        }
        return result;
    }
    private NcursesUi::TranscriptBlockState getBlock(int id) {
        if (!exists blocks{string(id)}) { throw "TRANSCRIPT-BLOCK-ERROR", "Block is no longer retained"; }
        return blocks{string(id)};
    }
    private nothing changed(int count) { prune(); if (!follow_tail) { unread += count; } markDirty(); }
    /** Returns deterministic retention work counters. @return number of expired source identities visited */
    hash<auto> getUpdateStats() { return {"pruned_lines": pruned_lines}; }
    private list<int> retainedOrder() {
        return block_start < block_order.size() ? block_order[block_start .. block_order.size() - 1] : ();
    }
    private nothing collapseHeader(NcursesUi::TranscriptBlockState block) {
        int line = text.lineForId(block.line_ids[block.first]);
        string key = string(block.line_ids[block.first]);
        if (block.collapsed) { original_headers{key} = block.text[block.first]; }
        else { remove original_headers{key}; }
        text.setLineVisible(line, True);
        text.setLine(line, block.text[block.first] + (block.collapsed && block.line_ids.size() - block.first > 1
            ? sprintf(" [ +%d lines ]", block.line_ids.size() - block.first - 1) : ""));
    }
    private nothing applyCollapse(NcursesUi::TranscriptBlockState block) {
        for (int i = block.first + 1; i < block.line_ids.size(); ++i) {
            text.setLineVisible(text.lineForId(block.line_ids[i]), !block.collapsed);
        }
        collapseHeader(block);
    }
    private nothing prune() {
        *int first = text.getLineId(0); if (first == retained_first) { return; } retained_first = first;
        # Retention removes a source prefix: visit only expired IDs and the new leading block.
        while (block_start < block_order.size()) {
            int id = block_order[block_start]; NcursesUi::TranscriptBlockState block = blocks{string(id)};
            while (block.first < block.line_ids.size() && text.lineForId(block.line_ids[block.first]) < 0) {
                remove links{string(block.line_ids[block.first])}; remove original_headers{string(block.line_ids[block.first])}; ++block.first; ++pruned_lines;
            }
            if (block.first == block.line_ids.size()) { remove blocks{string(id)}; ++block_start; continue; }
            if (block.first >= max(256, block.line_ids.size() / 2)) {
                block.line_ids = block.line_ids[block.first .. block.line_ids.size() - 1];
                block.text = block.text[block.first .. block.text.size() - 1]; block.first = 0;
            }
            if (block.collapsed) { collapseHeader(block); }
            break;
        }
        if (block_start >= max(256, block_order.size() / 2)) { block_order = retainedOrder(); block_start = 0; }
        if (mouse_anchor && text.lineForId(mouse_anchor.line_id) < 0) { mouse_anchor = NOTHING; }
        if (!exists first) { selection_start = NOTHING; selection_end = NOTHING; }
        else {
            if (selection_start && text.lineForId(selection_start.line_id) < 0) { selection_start = <NcursesUi::TextAnchor>{"line_id": first, "offset": 0}; }
            if (selection_end && text.lineForId(selection_end.line_id) < 0) { selection_end = <NcursesUi::TextAnchor>{"line_id": first, "offset": 0}; }
        }
    }
    private nothing prepareMatches() {
        prune(); if (searched_revision == text.getRevision()) { return; }
        list<hash<NcursesUi::TranscriptMatch>> next = (); hash<string, list<hash<NcursesUi::TranscriptMatch>>> grouped = {};
        if (search != "") {
            for (int line = 0; line < text.lineCount(); ++line) {
                string plain = getSourceLine(line); int offset = plain.find(search);
                while (offset >= 0) {
                    int id = text.getLineId(line);
                    hash<NcursesUi::TranscriptMatch> match = <NcursesUi::TranscriptMatch>{"line_id": id,
                        "start": NcursesReplUi::TextPosition::snapOffset(plain, offset),
                        "end": NcursesReplUi::TextPosition::snapOffset(plain, offset + search.length(), True)};
                    next += match; if (!exists grouped{string(id)}) { grouped{string(id)} = (); }
                    grouped{string(id)} += match; offset = plain.find(search, offset + max(1, search.length()));
                }
            }
        }
        matches = next; match_lines = grouped; searched_revision = text.getRevision();
    }
}
} # namespace NcursesUi
