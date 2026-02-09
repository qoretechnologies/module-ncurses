#! @file MenuBarWidget.qc Horizontal menu bar with dropdown support

/*  MenuBarWidget.qc Copyright 2026 Qore Technologies, s.r.o.

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

/** Horizontal menu bar widget with dropdown support.

    Displays a row of menu items. Click or navigate to open
    dropdown menus. Each menu item has a label and a list of
    menu entry hashes.

    Call setApplication() to enable dropdown popups. Without it,
    the bar highlights menu labels but cannot show dropdowns.

    @par Menu structure
    Menus are added via addMenu(). Each menu has:
    - \c label: display text in the bar
    - \c items: list of hashes with "label", "command", and optional "enabled"

    @since ncurses 2.0
*/
public class NcursesUi::MenuBarWidget inherits NcursesUi::Widget {
    private {
        #! list of menu definitions
        list<hash<auto>> menus = ();
        #! currently highlighted menu index (-1 for none)
        int active_menu = -1;
        #! whether a dropdown is open
        bool dropdown_open = False;
        #! callback on menu command: code(string command)
        *code on_command;
        #! menu bar style
        hash<auto> bar_style = {"fg": Ncurses::Color::White, "bg": Ncurses::Color::Blue};
        #! active item style
        hash<auto> active_style = {"fg": Ncurses::Color::Yellow, "bg": Ncurses::Color::Blue,
            "attrs": Ncurses::Attr::Bold};
        #! the application (needed for session, modal stack, screen size)
        *NcursesUi::Application app;
        #! the currently open dropdown widget
        *NcursesUi::DropdownMenuWidget active_dropdown;
    }

    /** Creates a new MenuBarWidget.
        @since ncurses 2.0
    */
    constructor() {
        setFocusable(True);
        setVSizePolicy(NcursesUi::SizePolicy::Fixed);
        setMinimumSize(1, 1);
        setPreferredSize(1, 0);
    }

    /** Sets the application reference (enables dropdown popups).
        @param application the Application
        @since ncurses 2.0
    */
    nothing setApplication(NcursesUi::Application application) {
        app = application;
    }

    /** Adds a menu to the bar.
        @param label the menu label
        @param menu_items list of menu item hashes with "label" and "command" keys
        @since ncurses 2.0
    */
    nothing addMenu(string label, list<hash<auto>> menu_items) {
        menus += {"label": label, "items": menu_items};
        markDirty();
    }

    /** Returns the menu definitions.
        @since ncurses 2.0
    */
    list<hash<auto>> getMenus() {
        return menus;
    }

    /** Returns the active menu index (-1 for none).
        @since ncurses 2.0
    */
    int getActiveMenu() {
        return active_menu;
    }

    /** Returns whether a dropdown is open.
        @since ncurses 2.0
    */
    bool isDropdownOpen() {
        return dropdown_open;
    }

    /** Sets the command callback.
        @param cb callback receiving the command string
        @since ncurses 2.0
    */
    nothing setOnCommand(*code cb) {
        on_command = cb;
    }

    /** Sets the menu bar background style.
        @param style the style hash
        @since ncurses 2.0
    */
    nothing setBarStyle(hash<auto> style) {
        bar_style = style;
        markDirty();
    }

    /** Sets the active (highlighted) menu item style.
        @param style the style hash
        @since ncurses 2.0
    */
    nothing setActiveStyle(hash<auto> style) {
        active_style = style;
        markDirty();
    }

    /** Opens the menu at the given index.

        If an Application is set, creates a DropdownMenuWidget as a
        modal popup. Otherwise just highlights the menu label.

        @param idx the menu index
        @since ncurses 2.0
    */
    nothing openMenu(int idx) {
        if (idx < 0 || idx >= menus.size()) {
            return;
        }

        # close any existing dropdown first
        if (dropdown_open) {
            closeDropdown();
        }

        active_menu = idx;
        dropdown_open = True;
        markDirty();

        # create dropdown popup if we have an app reference
        if (app) {
            showDropdown(idx);
        }
    }

    /** Closes any open menu and destroys the dropdown.
        @since ncurses 2.0
    */
    nothing closeMenu() {
        if (dropdown_open) {
            closeDropdown();
        }
        dropdown_open = False;
        active_menu = -1;
        markDirty();
    }

    /** Returns the x position for the menu at the given index.
        @param idx the menu index
        @return x position in the bar
        @since ncurses 2.0
    */
    int menuXPosition(int idx) {
        hash<NcursesUi::Rect> cr = contentRect();
        int x_pos = cr.x;
        for (int i = 0; i < idx && i < menus.size(); ++i) {
            x_pos += menus[i].label.length() + 2;  # " label "
        }
        return x_pos;
    }

    /** Draws the menu bar.
        @param w the window
        @since ncurses 2.0
    */
    nothing draw(Ncurses::Window w) {
        hash<NcursesUi::Rect> cr = contentRect();
        int row = cr.y;

        # fill bar background
        w.drawHLine(row, cr.x, cr.cols, " ", bar_style);

        # draw menu labels with underlined hotkey character (first char of label)
        int x_pos = cr.x;
        for (int i = 0; i < menus.size(); ++i) {
            string mlabel = menus[i].label;
            int full_len = mlabel.length() + 2;  # " label "
            if (x_pos + full_len > cr.x + cr.cols) {
                break;
            }
            hash<auto> style = (i == active_menu) ? active_style : bar_style;
            hash<auto> hk_style = style + {"attrs": (style.attrs ?? 0) | Ncurses::Attr::Underline};
            w.drawText(row, x_pos, " ", style);
            w.drawText(row, x_pos + 1, mlabel.substr(0, 1), hk_style);
            w.drawText(row, x_pos + 2, mlabel.substr(1) + " ", style);
            x_pos += full_len;
        }
    }

    /** Handles menu bar events.
        @param ev the input event
        @return EventResult
        @since ncurses 2.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (ev.type == Ncurses::InputType::Key) {
            string name = ev.name ?? "";
            if (name == "KEY_LEFT") {
                if (dropdown_open && active_menu > 0) {
                    # switch to previous menu
                    openMenu(active_menu - 1);
                } else if (active_menu > 0) {
                    active_menu -= 1;
                    markDirty();
                }
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_RIGHT") {
                if (dropdown_open && active_menu < menus.size() - 1) {
                    # switch to next menu
                    openMenu(active_menu + 1);
                } else if (active_menu < menus.size() - 1) {
                    active_menu += 1;
                    markDirty();
                }
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_F(1)") {
                if (menus.size() > 0) {
                    openMenu(0);
                    return <NcursesUi::EventResult>{"handled": True, "action": "open_menu"};
                }
            }
        } else if (ev.type == Ncurses::InputType::Char) {
            int code = ord(ev.ch ?? "");
            if (code == 0x0a) {
                if (active_menu >= 0 && active_menu < menus.size()) {
                    if (dropdown_open) {
                        closeMenu();
                    } else {
                        openMenu(active_menu);
                    }
                    return <NcursesUi::EventResult>{"handled": True, "action": "toggle_menu"};
                }
            } else if (code == 0x1b) {
                if (dropdown_open) {
                    closeMenu();
                    return <NcursesUi::EventResult>{"handled": True, "action": "close_menu"};
                }
            }
        } else if (ev.type == Ncurses::InputType::Alt) {
            string ch = ev.ch ?? "";
            if (ch != "" && processAltKey(ch)) {
                return <NcursesUi::EventResult>{"handled": True, "action": "open_menu"};
            }
        } else if (ev.type == Ncurses::InputType::Mouse) {
            int bs = ev.mouse.button_state;
            if (bs & Ncurses::BUTTON1_CLICKED || bs & Ncurses::BUTTON1_PRESSED) {
                int click_idx = hitTestMenu(ev.mouse.x);
                if (click_idx >= 0) {
                    if (dropdown_open && click_idx == active_menu) {
                        closeMenu();
                    } else {
                        openMenu(click_idx);
                    }
                    return <NcursesUi::EventResult>{"handled": True, "action": "open_menu"};
                }
            }
        }
        return <NcursesUi::EventResult>{"handled": False};
    }

    /** Processes an Alt+key shortcut to open a menu.

        Matches the first character of each menu label (case-insensitive).
        Returns True if a matching menu was found and opened.

        @param ch the character pressed with Alt
        @return True if a menu was opened
        @since ncurses 2.0
    */
    bool processAltKey(string ch) {
        string lower_ch = ch.lwr();
        for (int i = 0; i < menus.size(); ++i) {
            string label = menus[i].label ?? "";
            if (label.size() > 0 && label.substr(0, 1).lwr() == lower_ch) {
                openMenu(i);
                return True;
            }
        }
        return False;
    }

    /** Checks all menu items for a matching hotkey and fires the command.

        Looks at the last character of each item's hotkey field
        (case-insensitive). If a match is found, fires the command
        and returns True.

        @param ch the character pressed with Alt
        @return True if a matching item was found and its command was fired
        @since ncurses 2.0
    */
    bool processItemHotkey(string ch) {
        string lower_ch = ch.lwr();
        for (int i = 0; i < menus.size(); ++i) {
            foreach hash<auto> item in (menus[i].items) {
                if (item.separator) {
                    continue;
                }
                *string hotkey = item.hotkey;
                if (exists hotkey && hotkey.size() > 0) {
                    string hk_char = hotkey.substr(-1).lwr();
                    if (hk_char == lower_ch) {
                        string cmd = item.command ?? "";
                        if (cmd != "") {
                            fireCommand(cmd);
                            return True;
                        }
                    }
                }
            }
        }
        return False;
    }

    /** Fires a command from a dropdown selection.
        @param command the command string
        @since ncurses 2.0
    */
    nothing fireCommand(string command) {
        closeMenu();
        if (on_command) {
            on_command(command);
        }
    }

    private nothing showDropdown(int idx) {
        Ncurses::Session sess = app.getSession();
        list<hash<auto>> items = menus[idx].items;

        active_dropdown = new NcursesUi::DropdownMenuWidget(sess, items);

        # position below the menu label
        hash<Ncurses::Size> sz = sess.screen().size();
        int anchor_x = menuXPosition(idx);
        hash<NcursesUi::Rect> cr = contentRect();
        int anchor_y = cr.y;
        active_dropdown.positionAt(anchor_y, anchor_x, sz.rows, sz.cols);
        active_dropdown.createPanel();

        # set callbacks
        active_dropdown.setOnSelect(sub (hash<auto> item) {
            string cmd = item.command ?? "";
            if (cmd != "") {
                fireCommand(cmd);
            }
        });
        active_dropdown.setOnClose(sub () {
            closeMenu();
        });
        active_dropdown.setOnNavigate(sub (string direction) {
            if (direction == "left") {
                openMenu(active_menu > 0 ? active_menu - 1 : menus.size() - 1);
            } else if (direction == "right") {
                openMenu(active_menu < menus.size() - 1 ? active_menu + 1 : 0);
            }
        });
        active_dropdown.setOnAltKey(bool sub (string ch) {
            # try item-level hotkeys first (e.g., Alt+B → browse)
            if (processItemHotkey(ch)) {
                return True;
            }
            # fall back to switching menus by label
            return processAltKey(ch);
        });

        # push as modal so the dropdown gets all events
        app.pushModal(active_dropdown);
    }

    private nothing closeDropdown() {
        if (active_dropdown) {
            # pop from modal stack
            if (app) {
                app.popModal();
            }
            active_dropdown.destroyPanel();
            active_dropdown = NOTHING;
        }
    }

    private int hitTestMenu(int mx) {
        hash<NcursesUi::Rect> cr = contentRect();
        int x_pos = cr.x;
        for (int i = 0; i < menus.size(); ++i) {
            int label_len = menus[i].label.length() + 2;
            if (mx >= x_pos && mx < x_pos + label_len) {
                return i;
            }
            x_pos += label_len;
        }
        return -1;
    }
}
