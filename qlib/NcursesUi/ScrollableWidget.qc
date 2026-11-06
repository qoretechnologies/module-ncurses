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

public namespace NcursesUi {
/** Widget that wraps a @ref ScrollableContent with viewport management
    and scrollbar rendering.

    Handles keyboard scrolling (Up/Down, PgUp/PgDn, Home/End) and
    mouse wheel events. Draws a vertical scrollbar when content exceeds
    the viewport.

    @since ncurses 1.0
*/
public class ScrollableWidget inherits NcursesUi::Widget {
    private {
        int painted_revision = -1;
        *hash<NcursesUi::Rect> draw_bounds;
        *hash<NcursesUi::Rect> drawn_visible;
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
        #! prepared viewport width and whether it reserves a scrollbar
        int viewport_cols = 0;
        bool need_scrollbar = False;
        #! a source anchor retained across changes in wrap width
        *hash<Ncurses::Position> scroll_anchor;
        *int anchor_id;
        int anchor_revision = -1;
        #! keep a newly positioned editing cursor visible; manual scrolling releases it
        bool reveal_cursor = False;
        *Ncurses::Window cursor_window;
        int cursor_request = 0;
    }

    /** Creates a new ScrollableWidget.
        @param c optional content provider
        @since ncurses 1.0
    */
    constructor(*NcursesUi::ScrollableContent c) {
        content = c;
        setFocusable(True);
    }

    destructor() {
        releaseCursor();
    }

    /** Reports local geometry or provider content changes. @return whether repaint is needed */
    bool needsOwnDraw() { return Widget::needsOwnDraw() || (content && content.getRevision() != painted_revision); }
    /** Reports local/provider or child changes. @return whether repaint is needed */
    bool isDirty() { return needsOwnDraw() || Widget::isDirty(); }

    /** Updates allocation and discards clipping from the previous target window.
        @param rect new screen rectangle
    */
    nothing setFrame(hash<NcursesUi::Rect> rect) {
        if (rect != getFrame()) { draw_bounds = NOTHING; }
        Widget::setFrame(rect);
    }
    /** Moves the subtree and invalidates clipping from its previous drawing target.
        @param dy row displacement @param dx column displacement
    */
    nothing translate(int dy, int dx) {
        if (dy || dx) { draw_bounds = NOTHING; }
        Widget::translate(dy, dx);
    }

    /** Sets the content provider.
        @param c the content
        @since ncurses 1.0
    */
    nothing setContent(*NcursesUi::ScrollableContent c) {
        releaseCursor();
        content = c;
        scroll_anchor = NOTHING;
        anchor_id = NOTHING;
        anchor_revision = -1;
        cursor_pos = NOTHING;
        reveal_cursor = False;
        scrollY = 0;
        scrollX = 0;
        markDirty();
    }

    /** Returns the content provider.
        @since ncurses 1.0
    */
    *NcursesUi::ScrollableContent getContent() {
        return content;
    }

    /** Returns the current vertical scroll offset.
        @since ncurses 1.0
    */
    int getScrollY() {
        return scrollY;
    }

    /** Returns the current horizontal scroll offset.
        @since ncurses 1.0
    */
    int getScrollX() {
        return scrollX;
    }

    /** Sets the vertical scroll offset directly.
        @param y the new scroll offset
        @since ncurses 1.0
    */
    nothing setScrollY(int y) {
        prepareViewport();
        scrollY = clampScrollY(y);
        reveal_cursor = False;
        rememberAnchor();
        markDirty();
    }

    /** Sets whether to show the vertical scrollbar.
        @param v True to show
        @since ncurses 1.0
    */
    nothing setShowScrollbar(bool v) {
        show_scrollbar = v;
        markDirty();
    }

    /** Sets the cursor position to display within the content.
        @param line the content line index
        @param col source character offset excluding ANSI escapes (not display columns)
        @since ncurses 1.0
    */
    nothing setCursorLine(int line, int col) {
        cursor_pos = {"line": line, "col": col};
        reveal_cursor = True;
        markDirty();
    }

    /** Clears the cursor position (no cursor displayed).
        @since ncurses 1.0
    */
    nothing clearCursorLine() {
        releaseCursor();
        cursor_pos = NOTHING;
        reveal_cursor = False;
        markDirty();
    }

    /** Returns the current cursor position, if set.
        @since ncurses 1.0
    */
    *hash<auto> getCursorPos() {
        return cursor_pos;
    }

    /** Scrolls in the given direction.
        @param dir the scroll direction
        @param amount number of lines/pages to scroll (default 1)
        @since ncurses 1.0
    */
    nothing scrollTo(int dir, int amount = 1) {
        if (amount < 0) { throw "SCROLL-AMOUNT-ERROR", "Scroll amount must be nonnegative"; }
        prepareViewport();
        reveal_cursor = False;
        hash<NcursesUi::Rect> cr = drawableRect();
        int visible_rows = cr.rows;

        if (dir == NcursesUi::ScrollDirection::Up) {
            scrollY = clampScrollY(scrollY - amount);
        } else if (dir == NcursesUi::ScrollDirection::Down) {
            scrollY = clampScrollY(scrollY + amount);
        } else if (dir == NcursesUi::ScrollDirection::PageUp) {
            scrollY = clampScrollY(scrollY - visible_rows * amount);
        } else if (dir == NcursesUi::ScrollDirection::PageDown) {
            scrollY = clampScrollY(scrollY + visible_rows * amount);
        } else if (dir == NcursesUi::ScrollDirection::Home) {
            scrollY = 0;
        } else if (dir == NcursesUi::ScrollDirection::End) {
            scrollY = clampScrollY(maxScrollY());
        } else if (dir == NcursesUi::ScrollDirection::Left) {
            scrollX = max(0, scrollX - amount);
        } else if (dir == NcursesUi::ScrollDirection::Right) {
            int maxX = maxScrollX();
            scrollX = max(0, min(maxX, scrollX + amount));
        }
        rememberAnchor();
        markDirty();
    }

    /** Releases cursor ownership when the widget has no drawable area. */
    nothing onDrawClipped() {
        painted_revision = content ? content.getRevision() : 0;
        releaseCursor();
        Widget::onDrawClipped();
    }

    /** Draws the content and scrollbar.
        @param w the window to draw into
        @since ncurses 1.0
    */
    nothing draw(Ncurses::Window w) {
        releaseCursor();
        hash<Ncurses::Position> origin = w.position(); hash<Ncurses::Size> size = w.size();
        draw_bounds = NcursesUi::Geometry::makeRect(origin.y, origin.x, size.rows, size.cols);
        drawn_visible = visibleRect();
        on_success painted_revision = content ? content.getRevision() : 0;
        prepareViewport();
        hash<NcursesUi::Rect> cr = drawableRect(); cr.y -= origin.y; cr.x -= origin.x;
        if (cr.rows <= 0 || viewport_cols <= 0) {
            return;
        }
        *hash<Ncurses::Position> caret = cursorPosition();
        revealCaret();
        if (content) {
            content.drawContent(w, scrollY, scrollX, cr.rows, viewport_cols, cr.y, cr.x);
        }
        if (need_scrollbar && content) {
            drawScrollbar(w, cr, cr.rows);
        }
        if (caret && caret.y >= scrollY && caret.y < scrollY + cr.rows
                && caret.x >= scrollX && caret.x < scrollX + viewport_cols) {
            int y = cr.y + caret.y - scrollY;
            int x = cr.x + caret.x - scrollX;
            if (y >= 0 && x >= 0 && y < size.rows && x < size.cols) {
                cursor_window = w;
                cursor_request = w.claimCursor(y, x);
            }
        }
        rememberAnchor();
    }

    /** Handles scroll-related events.
        @param ev the input event
        @return EventResult
        @since ncurses 1.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        prepareViewport();
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
                hash<NcursesUi::Rect> cr = drawableRect();
                int visible_rows = cr.rows;
                if (need_scrollbar) {
                    int bar_x = cr.x + cr.cols - 1;
                    if (ev.mouse.x == bar_x && ev.mouse.y >= cr.y
                            && ev.mouse.y < cr.y + visible_rows) {
                        int click_y = ev.mouse.y - cr.y;
                        int total = totalDisplayRows();
                        int max_scroll = max(1, total - visible_rows);
                        scrollY = clampScrollY(
                            click_y * max_scroll / max(1, visible_rows - 1));
                        reveal_cursor = False;
                        rememberAnchor();
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

    /** Returns the current drawable text viewport in screen coordinates, excluding the scrollbar.
        @return clipped text rectangle used by painting, navigation and hit testing
    */
    hash<NcursesUi::Rect> getViewportRect() {
        prepareViewport(); revealCaret();
        hash<NcursesUi::Rect> rect = drawableRect(); rect.cols = viewport_cols; return rect;
    }

    private nothing revealCaret() {
        hash<NcursesUi::Rect> rect = drawableRect(); *hash<Ncurses::Position> caret = cursorPosition();
        if (reveal_cursor && caret && caret.y >= 0 && rect.rows > 0 && viewport_cols > 0) {
            scrollY = max(max(0, min(scrollY, caret.y)), caret.y - rect.rows + 1);
            scrollX = max(max(0, min(scrollX, caret.x)), caret.x - viewport_cols + 1);
            rememberAnchor();
        }
    }

    private hash<NcursesUi::Rect> drawableRect() {
        hash<NcursesUi::Rect> visible = visibleRect();
        hash<NcursesUi::Rect> rect = NcursesUi::Geometry::intersect(contentRect(), visible);
        return draw_bounds && visible == drawn_visible ? NcursesUi::Geometry::intersect(rect, draw_bounds) : rect;
    }

    #! Resolve wrapping and scrollbar width before querying or clamping extents.
    private nothing prepareViewport() {
        hash<NcursesUi::Rect> cr = drawableRect();
        int old_cols = viewport_cols;
        viewport_cols = max(0, cr.cols);
        need_scrollbar = False;
        if (content) {
            content.prepareViewport(viewport_cols);
            need_scrollbar = show_scrollbar && cr.rows > 0 && cr.cols > 1
                && totalDisplayRows() > cr.rows;
            if (need_scrollbar) {
                --viewport_cols;
                content.prepareViewport(viewport_cols);
            }
            if ((old_cols != viewport_cols || content.getRevision() != anchor_revision) && scroll_anchor) {
                int line = exists anchor_id ? content.lineForId(anchor_id) : scroll_anchor.y;
                hash<Ncurses::Position> anchor = content.sourceToVisual(max(0, line), line < 0 ? 0 : scroll_anchor.x);
                scrollY = max(0, anchor.y);
            }
        }
        scrollY = clampScrollY(scrollY);
        scrollX = max(0, min(scrollX, maxScrollX()));
    }

    private nothing releaseCursor() {
        if (cursor_window && cursor_request) {
            cursor_window.releaseCursor(cursor_request);
        }
        cursor_request = 0;
        cursor_window = NOTHING;
    }

    private nothing rememberAnchor() {
        if (content) {
            scroll_anchor = content.visualToSource(scrollY, 0);
            anchor_id = content.getLineId(scroll_anchor.y);
            anchor_revision = content.getRevision();
        }
    }

    private *hash<Ncurses::Position> cursorPosition() {
        return content && cursor_pos ? content.sourceToVisual(cursor_pos.line, cursor_pos.col) : NOTHING;
    }

    private int totalDisplayRows() {
        if (!content) {
            return 0;
        }
        *hash<Ncurses::Position> caret = cursorPosition();
        return max(content.totalRows(), caret && caret.y >= 0 ? caret.y + 1 : 0);
    }

    private int maxScrollX() {
        if (!content || viewport_cols <= 0) {
            return 0;
        }
        if (content instanceof NcursesUi::LineListContent && content.getWordWrap()) {
            return 0;
        }
        *hash<Ncurses::Position> caret = cursorPosition();
        int cols = max(content.totalCols(), caret && caret.y >= 0 ? caret.x + 1 : 0);
        return max(0, cols - viewport_cols);
    }

    private int maxScrollY() {
        return max(0, totalDisplayRows() - max(0, drawableRect().rows));
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
        int total = totalDisplayRows();
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

} # namespace NcursesUi
