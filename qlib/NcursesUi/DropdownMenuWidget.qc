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

/** Dropdown menu popup widget.

    Displays a vertical list of menu items in a floating panel.
    Supports keyboard navigation (Up/Down, Enter, Escape) and
    mouse click selection.

    Items are hashes with keys:
    - \c label: display text
    - \c command: command string fired on selection
    - \c enabled: optional bool (default True)
    - \c separator: if True, draws a horizontal line

    @since ncurses 2.0
*/
public namespace NcursesUi {
public class DropdownMenuWidget inherits NcursesUi::PanelWidget {
    private {
        #! list of menu item hashes
        list<hash<auto>> menu_items = ();
        #! currently highlighted index
        int highlight_index = 0;
        #! callback on item selection: code(hash<auto> item)
        *code on_select;
        #! callback on close/escape
        *code on_close;
        #! callback on left/right navigation: code(string direction) where direction is "left" or "right"
        *code on_navigate;
        #! callback on Alt+key press: code(string ch) — returns True if handled
        *code on_alt_key;
        #! highlight style
        hash<auto> highlight_style = {"fg": Ncurses::Color::Yellow, "bg": Ncurses::Color::Blue,
            "attrs": Ncurses::Attr::Bold};
        #! disabled style
        hash<auto> disabled_style = {"attrs": Ncurses::Attr::Dim};
    }

    /** Creates a new DropdownMenuWidget.
        @param s the session
        @param items the menu items
        @since ncurses 2.0
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
        @since ncurses 2.0
    */
    nothing setMenuItems(list<hash<auto>> items) {
        menu_items = items;
        highlight_index = 0;
        markDirty();
    }

    /** Returns the menu items.
        @since ncurses 2.0
    */
    list<hash<auto>> getMenuItems() {
        return menu_items;
    }

    /** Returns the highlighted index.
        @since ncurses 2.0
    */
    int getHighlightIndex() {
        return highlight_index;
    }

    /** Sets the selection callback.
        @param cb callback receiving the selected item hash
        @since ncurses 2.0
    */
    nothing setOnSelect(*code cb) {
        on_select = cb;
    }

    /** Sets the close callback.
        @param cb callback
        @since ncurses 2.0
    */
    nothing setOnClose(*code cb) {
        on_close = cb;
    }

    /** Sets the Alt+key callback for menu switching.

        Called when the user presses Alt+key while the dropdown is open.
        The callback receives the character and should return True if handled.

        @param cb callback receiving the character string
        @since ncurses 2.0
    */
    nothing setOnAltKey(*code cb) {
        on_alt_key = cb;
    }

    /** Sets the navigation callback for Left/Right key handling.

        Called when the user presses Left or Right to switch between
        menus in a menu bar. The callback receives "left" or "right".

        @param cb callback receiving the direction string
        @since ncurses 2.0
    */
    nothing setOnNavigate(*code cb) {
        on_navigate = cb;
    }

    /** Positions the dropdown below/above an anchor point.
        @param anchor_y row of the anchor
        @param anchor_x column of the anchor
        @param screen_rows terminal rows
        @param screen_cols terminal columns
        @since ncurses 2.0
    */
    nothing positionAt(int anchor_y, int anchor_x, int screen_rows, int screen_cols) {
        int max_label = 0;
        int max_hotkey = 0;
        foreach hash<auto> item in (menu_items) {
            if (item.separator) {
                continue;
            }
            string label = item.label ?? "";
            if (label.length() > max_label) {
                max_label = label.length();
            }
            *string hotkey = item.hotkey;
            if (exists hotkey && hotkey.length() > max_hotkey) {
                max_hotkey = hotkey.length();
            }
        }

        int width = max_label + 4;  # border + padding
        if (max_hotkey > 0) {
            width += max_hotkey + 2;  # "  " gap + hotkey text
        }
        int height = menu_items.size() + 2;  # border

        # clamp to screen
        width = min(width, screen_cols - 2);
        height = min(height, screen_rows - 2);

        int dy = anchor_y + 1;
        int dx = anchor_x;

        # flip above if no room below
        if (dy + height > screen_rows) {
            dy = anchor_y - height;
            if (dy < 0) {
                dy = 0;
            }
        }

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
        @since ncurses 2.0
    */
    nothing draw(Ncurses::Window w) {
        PanelWidget::draw(w);

        hash<NcursesUi::Rect> cr = localContentRect();

        for (int i = 0; i < menu_items.size() && i < cr.rows; ++i) {
            int row = cr.y + i;

            if (menu_items[i].separator) {
                # use default ACS_HLINE character (matches box border style)
                w.drawHLine(row, cr.x, cr.cols);
                continue;
            }

            string label = menu_items[i].label ?? "";
            *string hotkey = menu_items[i].hotkey;

            # find hotkey character position in label for underlining
            int hk_pos = -1;
            if (exists hotkey && hotkey.size() > 0) {
                string hk_char = hotkey.substr(-1).lwr();
                for (int ci = 0; ci < label.size(); ++ci) {
                    if (label.substr(ci, 1).lwr() == hk_char) {
                        hk_pos = ci;
                        break;
                    }
                }
            }

            if (exists hotkey && hotkey.size() > 0) {
                # build line: "label  hotkey" right-aligned within cr.cols
                int gap = cr.cols - label.length() - hotkey.length();
                if (gap >= 2) {
                    label += strmul(" ", gap - 0) + hotkey;
                } else {
                    # not enough room for hotkey, just show label
                    if (label.length() > cr.cols) {
                        label = label.substr(0, cr.cols);
                    }
                    if (label.length() < cr.cols) {
                        label += strmul(" ", cr.cols - label.length());
                    }
                }
            } else {
                if (label.length() > cr.cols) {
                    label = label.substr(0, cr.cols);
                }
                if (label.length() < cr.cols) {
                    label += strmul(" ", cr.cols - label.length());
                }
            }

            bool enabled = menu_items[i].enabled ?? True;
            hash<auto> style;
            if (!enabled) {
                style = disabled_style;
            } else if (i == highlight_index) {
                style = highlight_style;
            }

            if (hk_pos >= 0 && hk_pos < label.size()) {
                # draw in 3 segments: before, underlined char, after
                hash<auto> hk_style = style + {
                    "attrs": (style.attrs ?? 0) | Ncurses::Attr::Underline,
                };
                if (hk_pos > 0) {
                    w.drawText(row, cr.x, label.substr(0, hk_pos), style);
                }
                w.drawText(row, cr.x + hk_pos, label.substr(hk_pos, 1), hk_style);
                if (hk_pos + 1 < label.size()) {
                    w.drawText(row, cr.x + hk_pos + 1, label.substr(hk_pos + 1), style);
                }
            } else {
                w.drawText(row, cr.x, label, style);
            }
        }
    }

    /** Handles dropdown events.
        @param ev the input event
        @return EventResult
        @since ncurses 2.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (ev.type == Ncurses::InputType::Key) {
            string name = ev.name ?? "";
            if (name == "KEY_UP") {
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
            } else if (code == 0x0a) {
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
            if (bs & Ncurses::BUTTON1_CLICKED || bs & Ncurses::BUTTON1_PRESSED) {
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
                int click_row = ev.mouse.y - cr.y;
                if (click_row >= 0 && click_row < menu_items.size()) {
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

    private nothing moveHighlight(int dir) {
        if (menu_items.empty()) {
            return;
        }
        int start = highlight_index;
        int idx = highlight_index;
        do {
            idx += dir;
            if (idx < 0) {
                idx = menu_items.size() - 1;
            } else if (idx >= menu_items.size()) {
                idx = 0;
            }
            if (!menu_items[idx].separator && (menu_items[idx].enabled ?? True)) {
                highlight_index = idx;
                markDirty();
                return;
            }
        } while (idx != start);
    }

    /** Finds a menu item whose hotkey matches the pressed character.

        The hotkey field should be a string like "Alt+B". The last character
        is used for matching (case-insensitive).

        @param ch the character pressed
        @return the item index, or -1 if no match
        @since ncurses 2.0
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
