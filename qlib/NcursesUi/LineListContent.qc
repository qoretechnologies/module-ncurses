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

/** ScrollableContent backed by a list of strings.

    Supports ANSI color codes in the text. Uses
    @ref Qore::Ncurses::Window::drawAnsiText() "drawAnsiText()" for rendering.

    Word-wrap can be enabled via @ref setWordWrap(). When enabled, lines
    longer than the visible width are wrapped at word boundaries. The scroll
    position and total row count account for wrapped lines transparently.

    @since ncurses 2.0
*/
public namespace NcursesUi {
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
        #! cached display rows (list of {line_idx, text} for each display row)
        list<hash<auto>> display_rows = ();
        #! whether display_rows cache is valid
        bool display_cache_valid = False;
    }

    /** Returns the total number of display rows (accounts for wrapping).
        @since ncurses 2.0
    */
    int totalRows() {
        if (word_wrap && last_wrap_width > 0) {
            rebuildDisplayCache(last_wrap_width);
            return display_rows.size();
        }
        return lines.size();
    }

    /** Returns the maximum line width.
        @since ncurses 2.0
    */
    int totalCols() {
        return max_width;
    }

    /** Enables or disables word-wrap.
        @param enabled True to enable word-wrap
        @since ncurses 2.0
    */
    nothing setWordWrap(bool enabled) {
        if (word_wrap != enabled) {
            word_wrap = enabled;
            display_cache_valid = False;
        }
    }

    /** Returns whether word-wrap is enabled.
        @since ncurses 2.0
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
        @since ncurses 2.0
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
        @since ncurses 2.0
    */
    nothing setLines(list<string> l) {
        lines = l;
        recalcWidth();
        display_cache_valid = False;
    }

    /** Returns all lines.
        @since ncurses 2.0
    */
    list<string> getLines() {
        return lines;
    }

    /** Appends a line.
        @param line the line to append
        @since ncurses 2.0
    */
    nothing appendLine(string line) {
        lines += line;
        int w = Ncurses::Ansi::len(line);
        if (w > max_width) {
            max_width = w;
        }
        display_cache_valid = False;
    }

    /** Clears all lines.
        @since ncurses 2.0
    */
    nothing clear() {
        lines = ();
        max_width = 0;
        display_rows = ();
        display_cache_valid = False;
    }

    /** Returns the number of logical lines.
        @since ncurses 2.0
    */
    int lineCount() {
        return lines.size();
    }

    /** Replaces a line at the given index.
        @param idx the line index (0-based)
        @param text the new text for the line
        @since ncurses 2.0
    */
    nothing setLine(int idx, string text) {
        if (idx >= 0 && idx < lines.size()) {
            lines[idx] = text;
            int w = Ncurses::Ansi::len(text);
            if (w > max_width) {
                max_width = w;
            }
            display_cache_valid = False;
        }
    }

    /** Removes a line at the given index, shifting subsequent lines up.
        @param idx the line index (0-based)
        @since ncurses 2.0
    */
    nothing removeLine(int idx) {
        if (idx >= 0 && idx < lines.size()) {
            splice lines, idx, 1;
            recalcWidth();
            display_cache_valid = False;
        }
    }

    /** Inserts a line at the given index, shifting subsequent lines down.
        @param idx the insertion index (0-based); clamped to valid range
        @param text the text to insert
        @since ncurses 2.0
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
        display_cache_valid = False;
    }

    /** Draws the visible portion of the lines.
        @param w the window to draw into
        @param scrollY vertical scroll offset
        @param scrollX horizontal scroll offset (unused for now)
        @param visibleRows number of visible rows
        @param visibleCols number of visible columns
        @param startY the window row to start drawing at
        @param startX the window column to start drawing at
        @since ncurses 2.0
    */
    nothing drawContent(Ncurses::Window w, int scrollY, int scrollX,
            int visibleRows, int visibleCols, int startY, int startX) {
        if (word_wrap && visibleCols > 0) {
            drawContentWrapped(w, scrollY, visibleRows, visibleCols, startY, startX);
            return;
        }
        for (int i = 0; i < visibleRows; ++i) {
            int idx = scrollY + i;
            int row = startY + i;
            if (idx >= 0 && idx < lines.size()) {
                string line = lines[idx];
                w.drawHLine(row, startX, visibleCols, " ");
                w.drawAnsiText(row, startX, line);
            } else {
                w.drawHLine(row, startX, visibleCols, " ");
            }
        }
    }

    #! Draws content with word-wrap
    private nothing drawContentWrapped(Ncurses::Window w, int scrollY,
            int visibleRows, int visibleCols, int startY, int startX) {
        # Rebuild display cache if width changed or cache is invalid
        if (last_wrap_width != visibleCols) {
            last_wrap_width = visibleCols;
            display_cache_valid = False;
        }
        rebuildDisplayCache(visibleCols);

        for (int i = 0; i < visibleRows; ++i) {
            int idx = scrollY + i;
            int row = startY + i;
            w.drawHLine(row, startX, visibleCols, " ");
            if (idx >= 0 && idx < display_rows.size()) {
                w.drawAnsiText(row, startX, display_rows[idx].text);
            }
        }
    }

    #! Rebuilds the display row cache by wrapping lines to the given width
    private nothing rebuildDisplayCache(int width) {
        if (display_cache_valid) {
            return;
        }
        display_rows = ();
        for (int i = 0; i < lines.size(); ++i) {
            string line = lines[i];
            if (Ncurses::Ansi::len(line) <= width) {
                display_rows += {"line_idx": i, "text": line};
            } else {
                list<string> wrapped = Ncurses::Ansi::wrap(line, width);
                foreach string wline in (wrapped) {
                    display_rows += {"line_idx": i, "text": wline};
                }
            }
        }
        display_cache_valid = True;
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
