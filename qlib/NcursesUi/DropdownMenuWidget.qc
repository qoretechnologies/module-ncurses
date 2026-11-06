#! @file DropdownMenuWidget.qc Dropdown/popup menu widget

/*  DropdownMenuWidget.qc Copyright 2026 Qore Technologies, s.r.o.

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
/** Dropdown menu popup widget.

    Displays a vertical list of menu items in a floating panel.
    Supports keyboard navigation (Up/Down, Enter, Escape) and
    mouse click selection.

    Items are hashes with keys:
    - \c label: display text
    - \c command: command string fired on selection
    - \c enabled: optional bool (default True)
    - \c separator: if True, draws a horizontal line

    @since ncurses 1.0
*/
public class DropdownMenuWidget inherits NcursesUi::PanelWidget {
    private {
        int scroll_offset = 0;
        int anchor_row = 0;
        int anchor_col = 0;
        #! list of menu item hashes
        list<hash<auto>> menu_items = ();
        #! currently highlighted index
        int highlight_index = -1;
        #! callback on item selection: code(hash<auto> item)
        *code<nothing(hash<auto>)> on_select;
        #! callback on close/escape
        *code<nothing()> on_close;
        #! callback on left/right navigation: code(string direction) where direction is "left" or "right"
        *code<nothing(string)> on_navigate;
        #! callback on Alt+key press: code(string ch) — returns True if handled
        *code<bool(string)> on_alt_key;
        #! highlight style
        hash<auto> highlight_style = {"fg": Ncurses::Color::Yellow, "bg": Ncurses::Color::Blue,
            "attrs": Ncurses::Attr::Bold};
        #! disabled style
        hash<auto> disabled_style = {"attrs": Ncurses::Attr::Dim};
    }

    /** Creates a new DropdownMenuWidget.
        @param s the session
        @param items the menu items
        @since ncurses 1.0
    */
    constructor(Ncurses::Session s, list<hash<auto>> items)
            : PanelWidget(s) {
        menu_items = items;
        setFocusable(True);
        # find first enabled non-separator item
        for (int i = 0; i < menu_items.size(); ++i) {
            if (!menu_items[i].separator && (menu_items[i].enabled ?? True)) {
                highlight_index = i;
                break;
            }
        }
    }

    /** Sets the menu items.
        @param items the items
        @since ncurses 1.0
    */
    nothing setMenuItems(list<hash<auto>> items) {
        menu_items = items;
        highlight_index = -1; scroll_offset = 0;
        moveHighlight(1); markDirty();
    }

    /** Returns the menu items.
        @since ncurses 1.0
    */
    list<hash<auto>> getMenuItems() {
        return menu_items;
    }

    /** Returns the highlighted index.
        @since ncurses 1.0
    */
    int getHighlightIndex() {
        return highlight_index;
    }

    /** Sets the selection callback.
        @param cb callback receiving the selected item hash
        @since ncurses 1.0
    */
    nothing setOnSelect(*code<nothing(hash<auto>)> cb) {
        on_select = cb;
    }

    /** Sets the close callback.
        @param cb callback
        @since ncurses 1.0
    */
    nothing setOnClose(*code<nothing()> cb) {
        on_close = cb;
    }

    /** Sets the Alt+key callback for menu switching.

        Called when the user presses Alt+key while the dropdown is open.
        The callback receives the character and should return True if handled.

        @param cb callback receiving the character string
        @since ncurses 1.0
    */
    nothing setOnAltKey(*code<bool(string)> cb) {
        on_alt_key = cb;
    }

    /** Sets the navigation callback for Left/Right key handling.

        Called when the user presses Left or Right to switch between
        menus in a menu bar. The callback receives "left" or "right".

        @param cb callback receiving the direction string
        @since ncurses 1.0
    */
    nothing setOnNavigate(*code<nothing(string)> cb) {
        on_navigate = cb;
    }

    /** Positions the dropdown below/above an anchor point.
        @param anchor_y row of the anchor
        @param anchor_x column of the anchor
        @param screen_rows terminal rows
        @param screen_cols terminal columns
        @since ncurses 1.0
    */
    nothing positionAt(int anchor_y, int anchor_x, int screen_rows, int screen_cols) {
        anchor_row = anchor_y; anchor_col = anchor_x;
        int max_label = 0;
        int max_hotkey = 0;
        foreach hash<auto> item in (menu_items) {
            if (item.separator) {
                continue;
            }
            string label = item.label ?? "";
            int label_width = TerminalText::displayWidth(label);
            if (label_width > max_label) {
                max_label = label_width;
            }
            *string hotkey = item.hotkey;
            if (exists hotkey
                    && TerminalText::displayWidth(hotkey) > max_hotkey) {
                max_hotkey = TerminalText::displayWidth(hotkey);
            }
        }

        int width = max_label + 4;  # border + padding
        if (max_hotkey > 0) {
            width += max_hotkey + 2;  # "  " gap + hotkey text
        }
        int height = menu_items.size() + 2;  # border

        # clamp to screen
        width = max(0, min(width, screen_cols > 4 ? screen_cols - 2 : screen_cols));
        height = max(0, min(height, screen_rows > 4 ? screen_rows - 2 : screen_rows));
        setHasBorder(height >= 3 && width >= 3);

        int dy = anchor_y + 1;
        int dx = anchor_x;

        # flip above if no room below
        if (dy + height > screen_rows) {
            dy = anchor_y - height;
            if (dy < 0) {
                dy = 0;
            }
        }

        dy = max(0, min(dy, screen_rows - height));
        # clamp x
        if (dx + width > screen_cols) {
            dx = screen_cols - width;
        }
        if (dx < 0) {
            dx = 0;
        }

        resize(NcursesUi::Geometry::makeRect(dy, dx, height, width));
    }

    /** Draws the dropdown menu content.
        @param w the window
        @since ncurses 1.0
    */
    nothing draw(Ncurses::Window w) {
        PanelWidget::draw(w);

        hash<NcursesUi::Rect> cr = localContentRect();
        ensureVisible();
        for (int offset = 0; offset < cr.rows; ++offset) {
            int i = scroll_offset + offset;
            if (i >= menu_items.size()) { break; }
            int row = cr.y + offset;

            if (menu_items[i].separator) {
                # use default ACS_HLINE character (matches box border style)
                w.drawHLine(row, cr.x, cr.cols);
                continue;
            }

            string label = menu_items[i].label ?? "";
            *string hotkey = menu_items[i].hotkey;

            # find hotkey character position in label for underlining
            int hk_pos = -1;
            int hk_len = 0;
            int hk_col = -1;
            int label_pos = 0;
            int label_col = 0;
            if (exists hotkey && hotkey.size() > 0) {
                string hk_char = hotkey.substr(-1).lwr();
                foreach string grapheme in (
                        (label =~ x/(\X)/g) ?? ()) {
                    if (grapheme.lwr() == hk_char) {
                        hk_pos = label_pos;
                        hk_len = grapheme.length();
                        hk_col = label_col;
                        break;
                    }
                    label_pos += grapheme.length();
                    label_col += TerminalText::displayWidth(grapheme);
                }
            }

            if (exists hotkey && hotkey.size() > 0) {
                # build line: "label  hotkey" right-aligned within cr.cols
                int gap = cr.cols - TerminalText::displayWidth(label)
                    - TerminalText::displayWidth(hotkey);
                if (gap >= 2) {
                    label += strmul(" ", gap) + hotkey;
                } else {
                    # not enough room for hotkey, just show label
                    label = TerminalText::fitRight(label, cr.cols);
                }
            } else {
                label = TerminalText::fitRight(label, cr.cols);
            }

            bool enabled = menu_items[i].enabled ?? True;
            hash<auto> style;
            if (!enabled) {
                style = disabled_style;
            } else if (i == highlight_index) {
                style = highlight_style;
            }

            if (hk_pos >= 0 && hk_pos < label.length()
                    && hk_col + TerminalText::displayWidth(
                        label.substr(hk_pos, hk_len)) <= cr.cols) {
                # draw in 3 segments: before, underlined char, after
                hash<auto> hk_style = style + {
                    "attrs": (style.attrs ?? 0) | Ncurses::Attr::Underline,
                };
                if (hk_pos > 0) {
                    w.drawText(row, cr.x, label.substr(0, hk_pos), style);
                }
                string hk_grapheme = label.substr(hk_pos, hk_len);
                int hk_width = TerminalText::displayWidth(hk_grapheme);
                w.drawText(row, cr.x + hk_col, hk_grapheme, hk_style);
                if (hk_pos + hk_len < label.length()) {
                    w.drawText(row, cr.x + hk_col + hk_width,
                        label.substr(hk_pos + hk_len), style);
                }
            } else {
                w.drawText(row, cr.x, label, style);
            }
        }
    }

    /** Handles dropdown events.
        @param ev the input event
        @return EventResult
        @since ncurses 1.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (ev.type == Ncurses::InputType::Key) {
            string name = ev.name ?? "";
            if (name == "KEY_HOME" || name == "KEY_END") {
                highlight_index = name == "KEY_HOME" ? -1 : 0;
                moveHighlight(name == "KEY_HOME" ? 1 : -1);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_PPAGE" || name == "KEY_NPAGE") {
                pageHighlight(name == "KEY_PPAGE" ? -1 : 1);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_ENTER") {
                selectHighlighted(); return <NcursesUi::EventResult>{"handled": True, "action": "select"};
            } else if (name == "KEY_UP") {
                moveHighlight(-1);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_DOWN") {
                moveHighlight(1);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_LEFT") {
                if (on_navigate) {
                    on_navigate("left");
                }
                return <NcursesUi::EventResult>{"handled": True, "action": "navigate_left"};
            } else if (name == "KEY_RIGHT") {
                if (on_navigate) {
                    on_navigate("right");
                }
                return <NcursesUi::EventResult>{"handled": True, "action": "navigate_right"};
            } else if (name == "KEY_BTAB") {
                # Shift+Tab - navigate to previous menu
                if (on_navigate) {
                    on_navigate("left");
                }
                return <NcursesUi::EventResult>{"handled": True, "action": "navigate_left"};
            }
        } else if (ev.type == Ncurses::InputType::Char) {
            int code = ord(ev.ch ?? "");
            if (code == 0x09) {
                # Tab - navigate to next menu
                if (on_navigate) {
                    on_navigate("right");
                }
                return <NcursesUi::EventResult>{"handled": True, "action": "navigate_right"};
            } else if (code == 0x0a || code == 0x0d) {
                selectHighlighted();
                return <NcursesUi::EventResult>{"handled": True, "action": "select"};
            } else if (code == 0x1b) {
                if (on_close) {
                    on_close();
                }
                return <NcursesUi::EventResult>{"handled": True, "action": "close"};
            } else if (code >= 32) {
                # check for hotkey match
                int match_idx = findHotkeyMatch(ev.ch);
                if (match_idx >= 0) {
                    highlight_index = match_idx;
                    selectHighlighted();
                    return <NcursesUi::EventResult>{"handled": True, "action": "select"};
                }
            }
        } else if (ev.type == Ncurses::InputType::Alt) {
            # Alt+key - forward to menu bar for menu switching
            string ch = ev.ch ?? "";
            if (ch != "" && on_alt_key) {
                if (on_alt_key(ch)) {
                    return <NcursesUi::EventResult>{"handled": True, "action": "alt_switch"};
                }
            }
            return <NcursesUi::EventResult>{"handled": True};
        } else if (ev.type == Ncurses::InputType::Mouse) {
            int bs = ev.mouse.button_state;
            if ((bs & (Ncurses::BUTTON4_PRESSED | Ncurses::BUTTON5_PRESSED)) && hitTest(ev.mouse.y, ev.mouse.x)) {
                moveHighlight(bs & Ncurses::BUTTON4_PRESSED ? -1 : 1);
                return <NcursesUi::EventResult>{"handled": True};
            }
            if (bs & (Ncurses::BUTTON1_CLICKED | Ncurses::BUTTON1_PRESSED
                    | Ncurses::BUTTON1_DOUBLE_CLICKED | Ncurses::BUTTON1_TRIPLE_CLICKED)) {
                # check if click is inside the dropdown bounds
                hash<NcursesUi::Rect> f = getFrame();
                if (!NcursesUi::Geometry::rectContains(f, ev.mouse.y, ev.mouse.x)) {
                    # click outside dropdown - close it and let the event propagate
                    if (on_close) {
                        on_close();
                    }
                    return <NcursesUi::EventResult>{"handled": False, "action": "close"};
                }
                hash<NcursesUi::Rect> cr = contentRect();
                int click_row = scroll_offset + ev.mouse.y - cr.y;
                if (NcursesUi::Geometry::rectContains(cr, ev.mouse.y, ev.mouse.x)
                        && click_row < menu_items.size()) {
                    if (!menu_items[click_row].separator
                            && (menu_items[click_row].enabled ?? True)) {
                        highlight_index = click_row;
                        selectHighlighted();
                        return <NcursesUi::EventResult>{"handled": True, "action": "select"};
                    }
                }
            }
        }
        return <NcursesUi::EventResult>{"handled": False};
    }

    /** Repositions an open menu after terminal resize.
        @param rows screen height
        @param cols screen width
    */
    nothing fitToScreen(int rows, int cols) { positionAt(anchor_row, anchor_col, rows, cols); }

    private nothing ensureVisible() {
        int count = max(1, contentRect().rows);
        scroll_offset = max(0, min(scroll_offset, menu_items.size() - count));
        if (highlight_index < scroll_offset) { scroll_offset = max(0, highlight_index); }
        else if (highlight_index >= scroll_offset + count) { scroll_offset = highlight_index - count + 1; }
    }

    private nothing pageHighlight(int direction) {
        int target = max(0, min(menu_items.size() - 1,
            highlight_index + direction * max(1, contentRect().rows)));
        int candidate = -1;
        for (int step = 0; step < menu_items.size(); ++step) {
            int index = direction > 0 ? step : menu_items.size() - 1 - step;
            if (menu_items[index].separator || !(menu_items[index].enabled ?? True)) { continue; }
            candidate = index;
            if (direction > 0 ? index >= target : index <= target) { break; }
        }
        highlight_index = candidate; ensureVisible(); markDirty();
    }

    private nothing moveHighlight(int dir) {
        int idx = highlight_index;
        for (int count = 0; count < menu_items.size(); ++count) {
            idx = (idx + dir + menu_items.size()) % menu_items.size();
            if (!menu_items[idx].separator && (menu_items[idx].enabled ?? True)) {
                highlight_index = idx; ensureVisible(); markDirty(); return;
            }
        }
        highlight_index = -1; scroll_offset = 0;
    }

    /** Finds a menu item whose hotkey matches the pressed character.

        The hotkey field should be a string like "Alt+B". The last character
        is used for matching (case-insensitive).

        @param ch the character pressed
        @return the item index, or -1 if no match
        @since ncurses 1.0
    */
    private int findHotkeyMatch(string ch) {
        string lower_ch = ch.lwr();
        for (int i = 0; i < menu_items.size(); ++i) {
            if (menu_items[i].separator) {
                continue;
            }
            if (!(menu_items[i].enabled ?? True)) {
                continue;
            }
            *string hotkey = menu_items[i].hotkey;
            if (exists hotkey && hotkey.size() > 0) {
                string hk_char = hotkey.substr(-1).lwr();
                if (hk_char == lower_ch) {
                    return i;
                }
            }
        }
        return -1;
    }

    private nothing selectHighlighted() {
        if (highlight_index >= 0 && highlight_index < menu_items.size()) {
            hash<auto> item = menu_items[highlight_index];
            if (!item.separator && (item.enabled ?? True)) {
                if (on_select) {
                    on_select(item);
                }
            }
        }
    }
}

} # namespace NcursesUi
