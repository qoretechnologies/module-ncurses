#! @file LineListContent.qc ScrollableContent backed by list<string>

/*  LineListContent.qc Copyright 2026 Qore Technologies, s.r.o.

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.
*/

public namespace NcursesUi {
/** A rendered row with its position in the original, ANSI-free logical line.
    @since ncurses 1.0
*/
public hashdecl WrappedTextRow {
    #! logical line index
    int line_idx;
    #! first source character in this row
    int start;
    #! one past the last source character in this row
    int end;
    #! styled row text
    string text;
}

/** ScrollableContent backed by a list of strings.

    Supports ANSI color codes in the text. Uses
    @ref NcursesUi::TerminalText::drawAnsiSlice() "drawAnsiSlice()" to preserve
    styling and clip complete graphemes to the content rectangle.

    Word-wrap can be enabled via @ref setWordWrap(). When enabled, lines
    longer than the visible width are wrapped at word boundaries. The scroll
    position and total row count account for wrapped lines transparently.

    @since ncurses 1.0
*/
public class LineListContent inherits NcursesUi::ScrollableContent {
    private {
        #! the list of logical lines
        list<string> lines = ();
        #! maximum line width (for totalCols)
        int max_width = 0;
        #! word-wrap enabled
        bool word_wrap = False;
        #! last known visible width for wrap calculations
        int last_wrap_width = 0;
        #! cached display rows and source spans
        list<hash<NcursesUi::WrappedTextRow>> display_rows = ();
        #! whether display_rows cache is valid
        bool display_cache_valid = False;
        #! Keep both full-width and scrollbar-width layouts until content changes.
        hash<string, list<hash<NcursesUi::WrappedTextRow>>> display_caches = {};
    }

    /** Returns the total number of display rows (accounts for wrapping).
        @since ncurses 1.0
    */
    int totalRows() {
        if (word_wrap && last_wrap_width > 0) {
            rebuildDisplayCache(last_wrap_width);
            return display_rows.size();
        }
        return lines.size();
    }

    /** Returns the maximum line width.
        @since ncurses 1.0
    */
    int totalCols() {
        return max_width;
    }

    /** Enables or disables word-wrap.
        @param enabled True to enable word-wrap
        @since ncurses 1.0
    */
    nothing setWordWrap(bool enabled) {
        if (word_wrap != enabled) {
            word_wrap = enabled;
            invalidateDisplayCache();
        }
    }

    /** Returns whether word-wrap is enabled.
        @since ncurses 1.0
    */
    bool getWordWrap() {
        return word_wrap;
    }

    /** Returns the display row index for a logical line index.
        With word-wrap enabled, a logical line may span multiple display rows;
        this returns the first display row for the given line.
        Without word-wrap, returns the line index unchanged.
        @param line_idx the logical line index
        @return the display row index
        @since ncurses 1.0
    */
    int displayRowForLine(int line_idx) {
        if (!word_wrap || last_wrap_width <= 0) {
            return line_idx;
        }
        rebuildDisplayCache(last_wrap_width);
        for (int i = 0; i < display_rows.size(); ++i) {
            if (display_rows[i].line_idx == line_idx) {
                return i;
            }
        }
        # Fallback: return end
        return display_rows.size();
    }

    /** Sets all lines at once.
        @param l the lines to set
        @since ncurses 1.0
    */
    nothing setLines(list<string> l) {
        lines = l;
        recalcWidth();
        invalidateDisplayCache();
    }

    /** Returns all lines.
        @since ncurses 1.0
    */
    list<string> getLines() {
        return lines;
    }

    /** Appends a line.
        @param line the line to append
        @since ncurses 1.0
    */
    nothing appendLine(string line) {
        lines += line;
        int w = Ncurses::Ansi::len(line);
        if (w > max_width) {
            max_width = w;
        }
        invalidateDisplayCache();
    }

    /** Clears all lines.
        @since ncurses 1.0
    */
    nothing clear() {
        lines = ();
        max_width = 0;
        display_rows = ();
        invalidateDisplayCache();
    }

    /** Returns the number of logical lines.
        @since ncurses 1.0
    */
    int lineCount() {
        return lines.size();
    }

    /** Replaces a line at the given index.
        @param idx the line index (0-based)
        @param text the new text for the line
        @since ncurses 1.0
    */
    nothing setLine(int idx, string text) {
        if (idx >= 0 && idx < lines.size()) {
            int old_width = Ncurses::Ansi::len(lines[idx]);
            lines[idx] = text;
            int w = Ncurses::Ansi::len(text);
            if (w > max_width) {
                max_width = w;
            } else if (old_width == max_width && w < old_width) {
                recalcWidth();
            }
            invalidateDisplayCache();
        }
    }

    /** Removes a line at the given index, shifting subsequent lines up.
        @param idx the line index (0-based)
        @since ncurses 1.0
    */
    nothing removeLine(int idx) {
        if (idx >= 0 && idx < lines.size()) {
            splice lines, idx, 1;
            recalcWidth();
            invalidateDisplayCache();
        }
    }

    /** Inserts a line at the given index, shifting subsequent lines down.
        @param idx the insertion index (0-based); clamped to valid range
        @param text the text to insert
        @since ncurses 1.0
    */
    nothing insertLine(int idx, string text) {
        if (idx < 0) {
            idx = 0;
        }
        if (idx >= lines.size()) {
            appendLine(text);
            return;
        }
        splice lines, idx, 0, text;
        int w = Ncurses::Ansi::len(text);
        if (w > max_width) {
            max_width = w;
        }
        invalidateDisplayCache();
    }

    /** Establishes the wrap width before scrolling or measuring content.
        @param cols available display columns
        @since ncurses 1.0
    */
    nothing prepareViewport(int cols) {
        cols = max(0, cols);
        if (last_wrap_width != cols) {
            last_wrap_width = cols;
            display_cache_valid = False;
        }
        rebuildDisplayCache(cols);
    }

    /** Maps an ANSI-free source character offset to a wrapped display position.
        Positions inside a grapheme snap to its start. Whitespace consumed at a
        word break maps to the end of the preceding row. The insertion position
        after an exactly full last row is the start of the following row.
        @param line logical line index
        @param offset character offset, excluding ANSI escape sequences
        @return display row and terminal column; an invalid line has row -1
        @since ncurses 1.0
    */
    hash<Ncurses::Position> sourceToVisual(int line, int offset) {
        if (line < 0 || line >= lines.size()) {
            return <Ncurses::Position>{"y": -1, "x": 0};
        }
        rebuildDisplayCache(last_wrap_width);
        string plain = NcursesUi::TerminalText::plainAnsi(lines[line]);
        offset = max(0, min(offset, plain.length()));
        int row = displayRowForLine(line);
        while (row + 1 < display_rows.size() && display_rows[row + 1].line_idx == line
                && display_rows[row + 1].start <= offset) {
            ++row;
        }
        hash<NcursesUi::WrappedTextRow> entry = display_rows[row];
        string row_text = plain.substr(entry.start, max(0, min(offset, entry.end) - entry.start));
        # Count only complete source graphemes, never a partial combining/emoji sequence.
        int used = 0;
        int chars = 0;
        foreach string cluster in ((plain.substr(entry.start, entry.end - entry.start) =~ x/(\X)/g) ?? ()) {
            if (chars + cluster.length() > row_text.length()) {
                break;
            }
            chars += cluster.length();
            used += char_width(cluster);
        }
        if (word_wrap && last_wrap_width > 0 && used >= last_wrap_width
                && offset == plain.length()) {
            return <Ncurses::Position>{"y": row + 1, "x": 0};
        }
        return <Ncurses::Position>{"y": row, "x": used};
    }

    /** Maps a display cell to the start of its source grapheme.
        @param row display row, clamped to existing rows
        @param col display column, clamped to the row's text
        @return logical line in @c y and ANSI-free character offset in @c x
        @since ncurses 1.0
    */
    hash<Ncurses::Position> visualToSource(int row, int col) {
        rebuildDisplayCache(last_wrap_width);
        if (!display_rows) {
            return <Ncurses::Position>{"y": 0, "x": 0};
        }
        hash<NcursesUi::WrappedTextRow> entry = display_rows[max(0, min(row, display_rows.size() - 1))];
        string text = NcursesUi::TerminalText::plainAnsi(entry.text);
        int offset = entry.start;
        int used = 0;
        foreach string cluster in ((text =~ x/(\X)/g) ?? ()) {
            int width = char_width(cluster);
            if (used + width > max(0, col)) {
                break;
            }
            used += width;
            offset += cluster.length();
        }
        return <Ncurses::Position>{"y": entry.line_idx, "x": offset};
    }

    /** Draws a horizontal and vertical slice, clipped to the requested rectangle.
        @param w target window
        @param scrollY first display row
        @param scrollX first display column (zero for wrapped content)
        @param visibleRows viewport height
        @param visibleCols viewport width
        @param startY window row of the viewport
        @param startX window column of the viewport
        @since ncurses 1.0
    */
    nothing drawContent(Ncurses::Window w, int scrollY, int scrollX,
            int visibleRows, int visibleCols, int startY, int startX) {
        prepareViewport(visibleCols);
        if (visibleRows <= 0 || visibleCols <= 0) {
            return;
        }
        hash<Ncurses::Size> size = w.size();
        int x = max(0, startX);
        int cols = min(startX + visibleCols, size.cols) - x;
        if (cols <= 0) {
            return;
        }
        int offset = (word_wrap ? 0 : max(0, scrollX)) + x - startX;
        for (int row = max(0, startY); row < min(startY + visibleRows, size.rows); ++row) {
            int idx = scrollY + row - startY;
            w.drawHLine(row, x, cols, " ");
            if (idx >= 0 && idx < display_rows.size()) {
                NcursesUi::TerminalText::drawAnsiSlice(w, row, x, display_rows[idx].text, offset, cols);
            }
        }
    }

    #! Wrapping retains exact source spans, including the gaps consumed at word breaks.
    private nothing rebuildDisplayCache(int width) {
        if (display_cache_valid) {
            return;
        }
        string key = sprintf("%d", width);
        if (exists display_caches{key}) {
            display_rows = display_caches{key};
            display_cache_valid = True;
            return;
        }
        list<hash<NcursesUi::WrappedTextRow>> rows = ();
        for (int i = 0; i < lines.size(); ++i) {
            string source = NcursesUi::TerminalText::plainAnsi(lines[i]);
            list<string> wrapped = word_wrap && width > 0 && Ncurses::Ansi::len(lines[i]) > width
                ? Ncurses::Ansi::wrap(lines[i], width) : (lines[i],);
            int offset = 0;
            foreach string text in (wrapped) {
                string plain = NcursesUi::TerminalText::plainAnsi(text);
                int start = source.find(plain, offset);
                @assert(start >= offset);
                offset = start + plain.length();
                rows += <NcursesUi::WrappedTextRow>{"line_idx": i, "start": start, "end": offset, "text": text};
            }
        }
        # Bound the cache to the two widths used to resolve scrollbar geometry.
        if (display_caches.size() >= 2) {
            display_caches = {};
        }
        display_caches{key} = rows;
        display_rows = rows;
        display_cache_valid = True;
    }

    private nothing invalidateDisplayCache() {
        display_cache_valid = False;
        display_caches = {};
    }

    private nothing recalcWidth() {
        max_width = 0;
        foreach string line in (lines) {
            int w = Ncurses::Ansi::len(line);
            if (w > max_width) {
                max_width = w;
            }
        }
    }
}

} # namespace NcursesUi
