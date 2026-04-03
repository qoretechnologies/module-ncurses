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
    @ref Qore::Ncurses::Window::drawAnsiTextInsideLine() "drawAnsiTextInsideLine()" for rendering when
    the widget has a border, or @ref Qore::Ncurses::Window::drawAnsiText() "drawAnsiText()"
    for direct rendering.

    @since ncurses 2.0
*/
public namespace NcursesUi {
public class LineListContent inherits NcursesUi::ScrollableContent {
    private {
        #! the list of lines
        list<string> lines = ();
        #! maximum line width (for totalCols)
        int max_width = 0;
    }

    /** Returns the total number of lines.
        @since ncurses 2.0
    */
    int totalRows() {
        return lines.size();
    }

    /** Returns the maximum line width.
        @since ncurses 2.0
    */
    int totalCols() {
        return max_width;
    }

    /** Sets all lines at once.
        @param l the lines to set
        @since ncurses 2.0
    */
    nothing setLines(list<string> l) {
        lines = l;
        recalcWidth();
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
    }

    /** Clears all lines.
        @since ncurses 2.0
    */
    nothing clear() {
        lines = ();
        max_width = 0;
    }

    /** Returns the number of lines.
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
        for (int i = 0; i < visibleRows; ++i) {
            int idx = scrollY + i;
            int row = startY + i;
            if (idx >= 0 && idx < lines.size()) {
                string line = lines[idx];
                # clear the line first, then draw ANSI text
                w.drawHLine(row, startX, visibleCols, " ");
                w.drawAnsiText(row, startX, line);
            } else {
                # blank line
                w.drawHLine(row, startX, visibleCols, " ");
            }
        }
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
