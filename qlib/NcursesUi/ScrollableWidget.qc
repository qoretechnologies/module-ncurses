#! @file ScrollableWidget.qc Widget with scroll viewport and scrollbar

/*  ScrollableWidget.qc Copyright 2026 Qore Technologies, s.r.o.

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

/** Widget that wraps a @ref ScrollableContent with viewport management
    and scrollbar rendering.

    Handles keyboard scrolling (Up/Down, PgUp/PgDn, Home/End) and
    mouse wheel events. Draws a vertical scrollbar when content exceeds
    the viewport.

    @since ncurses 2.0
*/
public class NcursesUi::ScrollableWidget inherits NcursesUi::Widget {
    private {
        #! the content provider
        *NcursesUi::ScrollableContent content;
        #! vertical scroll offset (row index at top of viewport)
        int scrollY = 0;
        #! horizontal scroll offset
        int scrollX = 0;
        #! whether to show a vertical scrollbar
        bool show_scrollbar = True;
        #! number of lines to scroll per wheel event
        int wheel_lines = 3;
        #! optional cursor position (line index and column) for cursor display
        *hash<auto> cursor_pos;
    }

    /** Creates a new ScrollableWidget.
        @param c optional content provider
        @since ncurses 2.0
    */
    constructor(*NcursesUi::ScrollableContent c) {
        content = c;
        setFocusable(True);
    }

    /** Sets the content provider.
        @param c the content
        @since ncurses 2.0
    */
    nothing setContent(*NcursesUi::ScrollableContent c) {
        content = c;
        scrollY = 0;
        scrollX = 0;
        markDirty();
    }

    /** Returns the content provider.
        @since ncurses 2.0
    */
    *NcursesUi::ScrollableContent getContent() {
        return content;
    }

    /** Returns the current vertical scroll offset.
        @since ncurses 2.0
    */
    int getScrollY() {
        return scrollY;
    }

    /** Returns the current horizontal scroll offset.
        @since ncurses 2.0
    */
    int getScrollX() {
        return scrollX;
    }

    /** Sets the vertical scroll offset directly.
        @param y the new scroll offset
        @since ncurses 2.0
    */
    nothing setScrollY(int y) {
        scrollY = clampScrollY(y);
        markDirty();
    }

    /** Sets whether to show the vertical scrollbar.
        @param v True to show
        @since ncurses 2.0
    */
    nothing setShowScrollbar(bool v) {
        show_scrollbar = v;
        markDirty();
    }

    /** Sets the cursor position to display within the content.
        @param line the content line index
        @param col the column position
        @since ncurses 2.0
    */
    nothing setCursorLine(int line, int col) {
        cursor_pos = {"line": line, "col": col};
    }

    /** Clears the cursor position (no cursor displayed).
        @since ncurses 2.0
    */
    nothing clearCursorLine() {
        cursor_pos = NOTHING;
    }

    /** Returns the current cursor position, if set.
        @since ncurses 2.0
    */
    *hash<auto> getCursorPos() {
        return cursor_pos;
    }

    /** Scrolls in the given direction.
        @param dir the scroll direction
        @param amount number of lines/pages to scroll (default 1)
        @since ncurses 2.0
    */
    nothing scrollTo(int dir, int amount = 1) {
        hash<NcursesUi::Rect> cr = contentRect();
        int visible_rows = cr.rows;

        if (dir == NcursesUi::ScrollDirection::Up) {
            scrollY = clampScrollY(scrollY - amount);
        } else if (dir == NcursesUi::ScrollDirection::Down) {
            scrollY = clampScrollY(scrollY + amount);
        } else if (dir == NcursesUi::ScrollDirection::PageUp) {
            scrollY = clampScrollY(scrollY - visible_rows);
        } else if (dir == NcursesUi::ScrollDirection::PageDown) {
            scrollY = clampScrollY(scrollY + visible_rows);
        } else if (dir == NcursesUi::ScrollDirection::Home) {
            scrollY = 0;
        } else if (dir == NcursesUi::ScrollDirection::End) {
            scrollY = clampScrollY(maxScrollY());
        } else if (dir == NcursesUi::ScrollDirection::Left) {
            scrollX = max(0, scrollX - amount);
        } else if (dir == NcursesUi::ScrollDirection::Right) {
            scrollX = scrollX + amount;
        }
        markDirty();
    }

    /** Draws the content and scrollbar.
        @param w the window to draw into
        @since ncurses 2.0
    */
    nothing draw(Ncurses::Window w) {
        hash<NcursesUi::Rect> cr = contentRect();
        int visible_rows = cr.rows;
        int visible_cols = cr.cols;

        # reserve space for scrollbar
        bool need_scrollbar = show_scrollbar && content
            && content.totalRows() > visible_rows;
        if (need_scrollbar) {
            visible_cols = max(1, visible_cols - 1);
        }

        # draw content
        if (content) {
            scrollY = clampScrollY(scrollY);
            content.drawContent(w, scrollY, scrollX, visible_rows, visible_cols,
                cr.y, cr.x);
        }

        # draw scrollbar
        if (need_scrollbar && content) {
            drawScrollbar(w, cr, visible_rows);
        }

        # position cursor if set
        if (cursor_pos) {
            int row = cr.y + (cursor_pos.line - scrollY);
            if (row >= cr.y && row < cr.y + visible_rows) {
                w.moveCursor(row, cr.x + cursor_pos.col);
            }
        }
    }

    /** Handles scroll-related events.
        @param ev the input event
        @return EventResult
        @since ncurses 2.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (ev.type == Ncurses::InputType::Key) {
            string name = ev.name ?? "";
            if (name == "KEY_UP") {
                scrollTo(NcursesUi::ScrollDirection::Up);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_DOWN") {
                scrollTo(NcursesUi::ScrollDirection::Down);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_PPAGE") {
                scrollTo(NcursesUi::ScrollDirection::PageUp);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_NPAGE") {
                scrollTo(NcursesUi::ScrollDirection::PageDown);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_HOME") {
                scrollTo(NcursesUi::ScrollDirection::Home);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_END") {
                scrollTo(NcursesUi::ScrollDirection::End);
                return <NcursesUi::EventResult>{"handled": True};
            }
        } else if (ev.type == Ncurses::InputType::Mouse) {
            int bs = ev.mouse.button_state;
            # scrollbar click/drag
            if (bs & Ncurses::BUTTON1_CLICKED || bs & Ncurses::BUTTON1_PRESSED) {
                hash<NcursesUi::Rect> cr = contentRect();
                int visible_rows = cr.rows;
                bool need_scrollbar = show_scrollbar && content
                    && content.totalRows() > visible_rows;
                if (need_scrollbar) {
                    int bar_x = cr.x + cr.cols - 1;
                    if (ev.mouse.x == bar_x && ev.mouse.y >= cr.y
                            && ev.mouse.y < cr.y + visible_rows) {
                        int click_y = ev.mouse.y - cr.y;
                        int total = content.totalRows();
                        int max_scroll = max(1, total - visible_rows);
                        scrollY = clampScrollY(
                            click_y * max_scroll / max(1, visible_rows - 1));
                        markDirty();
                        return <NcursesUi::EventResult>{"handled": True};
                    }
                }
            }
            if (bs & Ncurses::BUTTON4_PRESSED || bs & Ncurses::BUTTON4_CLICKED) {
                scrollTo(NcursesUi::ScrollDirection::Up, wheel_lines);
                return <NcursesUi::EventResult>{"handled": True};
            }
            if (bs & Ncurses::BUTTON5_PRESSED || bs & Ncurses::BUTTON5_CLICKED) {
                scrollTo(NcursesUi::ScrollDirection::Down, wheel_lines);
                return <NcursesUi::EventResult>{"handled": True};
            }
        }
        return <NcursesUi::EventResult>{"handled": False};
    }

    private int maxScrollY() {
        if (!content) {
            return 0;
        }
        hash<NcursesUi::Rect> cr = contentRect();
        return max(0, content.totalRows() - cr.rows);
    }

    private int clampScrollY(int y) {
        if (y < 0) {
            return 0;
        }
        int mx = maxScrollY();
        if (y > mx) {
            return mx;
        }
        return y;
    }

    private nothing drawScrollbar(Ncurses::Window w, hash<NcursesUi::Rect> cr, int visible_rows) {
        int total = content.totalRows();
        if (total <= 0 || visible_rows <= 0) {
            return;
        }

        int bar_x = cr.x + cr.cols - 1;
        int bar_y = cr.y;
        int bar_height = visible_rows;

        # draw track (ACS_VLINE - connected vertical line)
        hash<auto> track_style = {"fg": Ncurses::Color::Blue, "attrs": Ncurses::Attr::Dim};
        w.drawVLine(bar_y, bar_x, bar_height, NOTHING, track_style);

        # calculate thumb
        int thumb_size = max(1, bar_height * visible_rows / total);
        int max_scroll = max(1, total - visible_rows);
        int thumb_pos = 0;
        if (max_scroll > 0) {
            thumb_pos = scrollY * (bar_height - thumb_size) / max_scroll;
        }
        thumb_pos = max(0, min(thumb_pos, bar_height - thumb_size));

        # draw thumb (space with reverse video for a solid block)
        hash<auto> thumb_style = {"fg": Ncurses::Color::Cyan,
            "attrs": Ncurses::Attr::Reverse};
        for (int i = 0; i < thumb_size; ++i) {
            w.drawText(bar_y + thumb_pos + i, bar_x, " ", thumb_style);
        }
    }
}
