#! @file ListWidget.qc Selectable list with keyboard and mouse support

/*  ListWidget.qc Copyright 2026 Qore Technologies, s.r.o.

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
/** Selectable list widget with keyboard and mouse support.

    Displays a scrollable list of items with selection highlighting.
    Supports custom item rendering, keyboard navigation, mouse click
    selection, and scrollbar.

    Items use a "label" key unless a custom renderer is supplied. Additional keys
    can be used for custom rendering and activation data.

    @since ncurses 1.0
*/
public class ListWidget inherits NcursesUi::Widget {
    private {
        *hash<NcursesUi::Rect> draw_bounds;
        *hash<NcursesUi::Rect> drawn_visible;
        *hash<NcursesUi::Rect> painted_view;
        #! list of item hashes
        list<hash<auto>> items = ();
        #! currently selected index (-1 for none)
        int selected_index = -1;
        #! vertical scroll offset
        int scroll_offset = 0;
        #! number of lines to scroll per wheel event
        int wheel_lines = 3;
        #! whether to show scrollbar
        bool show_scrollbar = True;
        #! whether mouse wheel moves selection instead of scrolling
        bool wheel_moves_selection = False;
        #! callback on selection change
        *code<nothing(int)> on_select;
        #! callback on activation (Enter/double-click)
        *code<nothing(hash<auto>)> on_activate;
        #! custom render callback: @c "string sub(hash<auto> item, int index, bool is_selected)"
        *code<string(hash<auto>, int, bool)> render_item;
        #! custom style callback: @c "*hash<auto> sub(hash<auto> item, int index, bool is_selected)"
        *code<*hash<auto>(hash<auto>, int, bool)> render_item_style;
        #! selected item style
        hash<auto> selected_style = {"attrs": Ncurses::Attr::Reverse};
        #! normal item style
        hash<auto> normal_style = {};
    }

    /** Creates a new ListWidget.
        @since ncurses 1.0
    */
    constructor() {
        setFocusable(True);
    }

    /** Sets the items.
        @param new_items list of item hashes
        @since ncurses 1.0
    */
    nothing setItems(list<hash<auto>> new_items) {
        items = new_items;
        if (selected_index >= items.size()) {
            selected_index = items.size() > 0 ? items.size() - 1 : -1;
        }
        if (items.size() > 0 && selected_index < 0) {
            selected_index = 0;
        }
        scroll_offset = 0;
        ensureVisible();
        markDirty();
    }

    /** Returns the items.
        @since ncurses 1.0
    */
    list<hash<auto>> getItems() {
        return items;
    }

    /** Returns the selected index (-1 for none).
        @since ncurses 1.0
    */
    int getSelectedIndex() {
        return selected_index;
    }

    /** Returns the selected item or NOTHING.
        @since ncurses 1.0
    */
    *hash<auto> getSelectedItem() {
        if (selected_index >= 0 && selected_index < items.size()) {
            return items[selected_index];
        }
        return NOTHING;
    }

    /** Sets the selected index.
        @param idx the index
        @since ncurses 1.0
    */
    nothing setSelectedIndex(int idx) {
        if (items.empty()) {
            selected_index = -1;
            return;
        }
        if (idx < 0) {
            idx = 0;
        }
        if (idx >= items.size()) {
            idx = items.size() - 1;
        }
        bool changed = (idx != selected_index);
        selected_index = idx;
        ensureVisible();
        markDirty();
        if (changed && on_select) {
            on_select(selected_index);
        }
    }

    /** Sets the selection change callback.
        @param cb callback receiving the selected index
        @since ncurses 1.0
    */
    nothing setOnSelect(*code<nothing(int)> cb) {
        on_select = cb;
    }

    /** Sets the activation callback (Enter/double-click).
        @param cb callback receiving the selected item hash
        @since ncurses 1.0
    */
    nothing setOnActivate(*code<nothing(hash<auto>)> cb) {
        on_activate = cb;
    }

    /** Sets a custom item render callback.
        @param cb callback: \c string \c sub(hash\<auto\> item, int index, bool is_selected)
        @since ncurses 1.0
    */
    nothing setRenderItem(*code<string(hash<auto>, int, bool)> cb) {
        render_item = cb; markDirty();
    }

    /** Sets a custom item style callback.
        @param cb callback: \c *hash\<auto\> \c sub(hash\<auto\> item, int index, bool is_selected)
        @since ncurses 1.0
    */
    nothing setRenderItemStyle(*code<*hash<auto>(hash<auto>, int, bool)> cb) {
        render_item_style = cb;
        markDirty();
    }

    /** Sets the selected item style.
        @param style the style hash
        @since ncurses 1.0
    */
    nothing setSelectedStyle(hash<auto> style) {
        selected_style = style;
        markDirty();
    }

    /** Sets whether mouse wheel moves selection instead of scrolling.
        @param enabled True to move selection, False to scroll
        @since ncurses 1.0
    */
    nothing setWheelMovesSelection(bool enabled) {
        wheel_moves_selection = enabled;
    }

    /** Returns whether mouse wheel moves selection.
        @since ncurses 1.0
    */
    bool getWheelMovesSelection() {
        return wheel_moves_selection;
    }

    /** Returns the scroll offset.
        @since ncurses 1.0
    */
    int getScrollOffset() {
        return scroll_offset;
    }

    /** Draws the list.
        @param w the window
        @since ncurses 1.0
    */
    nothing draw(Ncurses::Window w) {
        hash<Ncurses::Position> origin = w.position(); hash<Ncurses::Size> size = w.size();
        draw_bounds = NcursesUi::Geometry::makeRect(origin.y, origin.x, size.rows, size.cols); drawn_visible = visibleRect();
        hash<NcursesUi::Rect> view = viewRect();
        if (painted_view != view) { ensureVisible(); }
        scroll_offset = max(0, min(scroll_offset, maxScrollOffset()));
        on_success painted_view = view;
        hash<NcursesUi::Rect> cr = view; cr.y -= origin.y; cr.x -= origin.x;
        int visible_rows = cr.rows;
        int visible_cols = cr.cols;

        # reserve space for scrollbar
        bool need_scrollbar = show_scrollbar && cr.cols > 1 && visible_rows > 0 && items.size() > visible_rows;
        if (need_scrollbar) {
            visible_cols = max(1, visible_cols - 1);
        }

        for (int i = 0; i < visible_rows; ++i) {
            int idx = scroll_offset + i;
            int row = cr.y + i;

            if (idx >= 0 && idx < items.size()) {
                bool is_selected = (idx == selected_index);
                string text;
                if (render_item) {
                    text = render_item(items[idx], idx, is_selected);
                } else {
                    text = items[idx].label ?? sprintf("Item %d", idx);
                }

                # truncate/pad to width
                text = TerminalText::fitRight(TerminalText::columnSlice(text, max(0, view.x - contentRect().x), visible_cols), visible_cols);

                hash<auto> style;
                if (render_item_style) {
                    *hash<auto> custom = render_item_style(items[idx], idx, is_selected);
                    style = custom ?? (is_selected ? selected_style : normal_style);
                } else {
                    style = is_selected ? selected_style : normal_style;
                }
                w.drawTextClipped(row, cr.x, text, style);
            } else {
                TerminalText::clearSpan(w, row, cr.x, visible_cols);
            }
        }

        # draw scrollbar
        if (need_scrollbar) {
            drawScrollbar(w, cr, visible_rows);
        }
    }

    /** Handles keyboard and mouse events.
        @param ev the input event
        @return EventResult
        @since ncurses 1.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (!isAvailable() || items.empty()) {
            return <NcursesUi::EventResult>{"handled": False};
        }

        if (ev.type == Ncurses::InputType::Key) {
            string name = ev.name ?? "";
            if (name == "KEY_ENTER") { activate(); return <NcursesUi::EventResult>{"handled": True, "action": "activate"}; }
            if (name == "KEY_UP") {
                moveSelection(-1);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_DOWN") {
                moveSelection(1);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_PPAGE") {
                hash<NcursesUi::Rect> cr = viewRect();
                moveSelection(-max(1, cr.rows));
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_NPAGE") {
                hash<NcursesUi::Rect> cr = viewRect();
                moveSelection(max(1, cr.rows));
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_HOME") {
                setSelectedIndex(0);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_END") {
                setSelectedIndex(items.size() - 1);
                return <NcursesUi::EventResult>{"handled": True};
            }
        } else if (ev.type == Ncurses::InputType::Char) {
            if (ev.ch == "\n" || ev.ch == "\r") {
                activate();
                return <NcursesUi::EventResult>{"handled": True, "action": "activate"};
            }
        } else if (ev.type == Ncurses::InputType::Mouse && ev.mouse) {
            if (!NcursesUi::Geometry::rectContains(viewRect(), ev.mouse.y, ev.mouse.x)) { return <NcursesUi::EventResult>{}; }
            int bs = ev.mouse.button_state;
            # check for scrollbar click first
            if (bs & Ncurses::BUTTON1_CLICKED || bs & Ncurses::BUTTON1_PRESSED
                    || bs & Ncurses::BUTTON1_DOUBLE_CLICKED) {
                hash<NcursesUi::Rect> cr = viewRect();
                int visible_rows = cr.rows;
                bool need_scrollbar = show_scrollbar && cr.cols > 1 && visible_rows > 0 && items.size() > visible_rows;
                if (need_scrollbar) {
                    int bar_x = cr.x + cr.cols - 1;
                    if (ev.mouse.x == bar_x && ev.mouse.y >= cr.y
                            && ev.mouse.y < cr.y + visible_rows) {
                        int click_y = ev.mouse.y - cr.y;
                        int total = items.size();
                        int max_scroll = max(1, total - visible_rows);
                        scroll_offset = max(0, min(max_scroll,
                            click_y * max_scroll / max(1, visible_rows - 1)));
                        markDirty();
                        return <NcursesUi::EventResult>{"handled": True};
                    }
                }
            }
            if (!(bs & Ncurses::BUTTON1_DOUBLE_CLICKED) && (bs & Ncurses::BUTTON1_CLICKED || bs & Ncurses::BUTTON1_PRESSED)) {
                hash<NcursesUi::Rect> cr = viewRect();
                int click_row = ev.mouse.y - cr.y;
                int idx = scroll_offset + click_row;
                if (idx >= 0 && idx < items.size()) {
                    setSelectedIndex(idx);
                    return <NcursesUi::EventResult>{"handled": True};
                }
            } else if (bs & Ncurses::BUTTON1_DOUBLE_CLICKED) {
                hash<NcursesUi::Rect> cr = viewRect();
                int click_row = ev.mouse.y - cr.y;
                int idx = scroll_offset + click_row;
                if (idx >= 0 && idx < items.size()) {
                    setSelectedIndex(idx);
                    activate();
                    return <NcursesUi::EventResult>{"handled": True, "action": "activate"};
                }
            } else if (bs & Ncurses::BUTTON4_PRESSED || bs & Ncurses::BUTTON4_CLICKED) {
                if (wheel_moves_selection) {
                    moveSelection(-1);
                } else {
                    scroll_offset = max(0, scroll_offset - wheel_lines);
                    markDirty();
                }
                return <NcursesUi::EventResult>{"handled": True};
            } else if (bs & Ncurses::BUTTON5_PRESSED || bs & Ncurses::BUTTON5_CLICKED) {
                if (wheel_moves_selection) {
                    moveSelection(1);
                } else {
                    int max_scroll = maxScrollOffset();
                    scroll_offset = min(max_scroll, scroll_offset + wheel_lines);
                    markDirty();
                }
                return <NcursesUi::EventResult>{"handled": True};
            }
        }
        return <NcursesUi::EventResult>{"handled": False};
    }

    /** Discards obsolete target clipping after allocation changes. @param rect screen allocation */
    nothing setFrame(hash<NcursesUi::Rect> rect) { if (rect != getFrame()) { draw_bounds = NOTHING; } Widget::setFrame(rect); }
    /** Discards obsolete target clipping when moving. @param dy row displacement @param dx column displacement */
    nothing translate(int dy, int dx) { draw_bounds = NOTHING; Widget::translate(dy, dx); }
    /** Observes ancestor clipping changes even when local allocation is unchanged. @return needs paint */
    bool needsOwnDraw() { return painted_view != viewRect() || Widget::needsOwnDraw(); }
    /** Acknowledges empty/hidden viewports. */
    nothing onDrawClipped() { painted_view = viewRect(); Widget::onDrawClipped(); }
    private hash<NcursesUi::Rect> viewRect() {
        hash<NcursesUi::Rect> visible = visibleRect(); hash<NcursesUi::Rect> rect = NcursesUi::Geometry::intersect(contentRect(), visible);
        return draw_bounds && visible == drawn_visible ? NcursesUi::Geometry::intersect(rect, draw_bounds) : rect;
    }

    private nothing moveSelection(int delta) {
        int new_idx = selected_index + delta;
        if (new_idx < 0) {
            new_idx = 0;
        }
        if (new_idx >= items.size()) {
            new_idx = items.size() - 1;
        }
        if (new_idx != selected_index) {
            selected_index = new_idx;
            ensureVisible();
            markDirty();
            if (on_select) {
                on_select(selected_index);
            }
        }
    }

    private nothing activate() {
        if (on_activate && selected_index >= 0 && selected_index < items.size()) {
            on_activate(items[selected_index]);
        }
    }

    private nothing ensureVisible() {
        hash<NcursesUi::Rect> cr = viewRect();
        int visible_rows = cr.rows;
        if (visible_rows <= 0) {
            return;
        }
        if (selected_index < scroll_offset) {
            scroll_offset = selected_index;
        } else if (selected_index >= scroll_offset + visible_rows) {
            scroll_offset = selected_index - visible_rows + 1;
        }
    }

    private int maxScrollOffset() {
        hash<NcursesUi::Rect> cr = viewRect();
        return max(0, items.size() - cr.rows);
    }

    private nothing drawScrollbar(Ncurses::Window w, hash<NcursesUi::Rect> cr, int visible_rows) {
        int total = items.size();
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
            thumb_pos = scroll_offset * (bar_height - thumb_size) / max_scroll;
        }
        thumb_pos = max(0, min(thumb_pos, bar_height - thumb_size));

        # draw thumb (space with reverse video for a solid block)
        hash<auto> thumb_style = {"fg": Ncurses::Color::Cyan,
            "attrs": Ncurses::Attr::Reverse};
        for (int i = 0; i < thumb_size; ++i) {
            w.drawTextClipped(bar_y + thumb_pos + i, bar_x, " ", thumb_style);
        }
    }
}

} # namespace NcursesUi
