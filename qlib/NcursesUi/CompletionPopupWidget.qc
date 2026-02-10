#! @file CompletionPopupWidget.qc Code completion popup widget

/*  CompletionPopupWidget.qc Copyright 2026 Qore Technologies, s.r.o.

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

/** Code completion popup widget.

    Displays a scrollable list of completion items in a floating panel.
    Supports keyboard navigation (Up/Down, Enter, Escape) and displays
    a kind indicator for each item (e.g., "f" for function, "c" for class).

    Items are hashes with keys:
    - \c label: display text (the completion string)
    - \c kind: optional kind string (e.g., "function", "class", "namespace", "variable")
    - \c isCallable: optional bool indicating a callable item
    - \c detail: optional detail text

    @since %ncurses 2.0
*/
public class NcursesUi::CompletionPopupWidget inherits NcursesUi::PanelWidget {
    private {
        #! list of completion item hashes
        list<hash<auto>> completion_items = ();
        #! currently highlighted index
        int highlight_index = 0;
        #! scroll offset (for items that don't fit in visible area)
        int scroll_offset = 0;
        #! maximum number of visible items
        int max_visible;
        #! callback on item selection: code(hash<auto> item)
        *code on_select;
        #! callback on dismiss
        *code on_dismiss;
        #! highlight style
        hash<auto> highlight_style = {"fg": Ncurses::Color::Yellow, "bg": Ncurses::Color::Blue,
            "attrs": Ncurses::Attr::Bold};
        #! kind indicator style
        hash<auto> kind_style = {"fg": Ncurses::Color::Cyan, "attrs": Ncurses::Attr::Dim};
        #! detail text style (dim, shown after label)
        hash<auto> detail_style = {"fg": Ncurses::Color::White, "attrs": Ncurses::Attr::Dim};
    }

    /** Creates a new CompletionPopupWidget.
        @param s the session
        @param items the completion items
        @param max_vis maximum number of visible items (default 10)
        @since ncurses 2.0
    */
    constructor(Ncurses::Session s, list<hash<auto>> items, int max_vis = 10)
            : PanelWidget(s) {
        completion_items = items;
        max_visible = max_vis;
        setFocusable(True);
        setHasBorder(True);
    }

    /** Sets the selection callback.
        @param cb callback receiving the selected item hash
        @since ncurses 2.0
    */
    nothing setOnSelect(*code cb) {
        on_select = cb;
    }

    /** Sets the dismiss callback.
        @param cb callback called when the popup is dismissed
        @since ncurses 2.0
    */
    nothing setOnDismiss(*code cb) {
        on_dismiss = cb;
    }

    /** Returns the completion items.
        @since ncurses 2.0
    */
    list<hash<auto>> getItems() {
        return completion_items;
    }

    /** Returns the highlighted index.
        @since ncurses 2.0
    */
    int getHighlightIndex() {
        return highlight_index;
    }

    /** Returns the number of visible items. */
    int visibleCount() {
        return min(completion_items.size(), max_visible);
    }

    /** Returns a single-character kind indicator for a completion item.
        @param item the completion item
        @return a single character representing the kind
        @since ncurses 2.0
    */
    static string kindIndicator(hash<auto> item) {
        *string kind = item.kind;
        if (!exists kind) {
            if (item.isCallable) {
                return "f";
            }
            return " ";
        }
        switch (kind) {
            case "function":
            case "method":
                return "f";
            case "class":
                return "c";
            case "namespace":
                return "n";
            case "variable":
            case "local":
            case "global":
                return "v";
            case "constant":
                return "k";
            case "module":
                return "m";
            case "hashdecl":
                return "h";
            default:
                return kind.substr(0, 1);
        }
    }

    /** Positions the popup at the given screen location.
        @param anchor_y the row to position below
        @param anchor_x the column to start at
        @param screen_rows terminal rows
        @param screen_cols terminal columns
        @since ncurses 2.0
    */
    nothing positionAt(int anchor_y, int anchor_x, int screen_rows, int screen_cols) {
        int vis = visibleCount();
        int height = vis + 2;  # border top + bottom

        # calculate width from longest label + detail + kind indicator + padding
        int max_label = 0;
        foreach hash<auto> item in (completion_items) {
            string label = item.label ?? "";
            int item_width = label.length();
            # account for detail text (shown as " detail" after label)
            *string detail = item.detail;
            if (exists detail && detail != "") {
                item_width += 1 + detail.length();
            }
            if (item_width > max_label) {
                max_label = item_width;
            }
        }
        int width = max_label + 6;  # kind char + space + label + border*2 + padding

        # clamp to screen
        width = min(width, screen_cols - 2);
        height = min(height, screen_rows - 2);

        int dy = anchor_y + 1;
        int dx = anchor_x;

        # flip above if no room below
        if (dy + height > screen_rows) {
            dy = anchor_y - height;
        }

        # always clamp y to screen bounds
        if (dy < 0) {
            dy = 0;
        } else if (dy + height > screen_rows) {
            dy = screen_rows - height;
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

    /** Draws the completion popup content.
        @param w the window
        @since ncurses 2.0
    */
    nothing draw(Ncurses::Window w) {
        PanelWidget::draw(w);

        hash<NcursesUi::Rect> cr = localContentRect();
        # actual drawable rows may be smaller than visibleCount() if the widget was clamped
        int drawable = min(visibleCount(), cr.rows);

        for (int i = 0; i < drawable; ++i) {
            int item_idx = scroll_offset + i;
            if (item_idx >= completion_items.size()) {
                break;
            }
            int row = cr.y + i;
            hash<auto> item = completion_items[item_idx];

            string kind_ch = kindIndicator(item);
            string label = item.label ?? "";
            *string detail = item.detail;

            # build label portion: "k label"
            string label_part = kind_ch + " " + label;
            # build detail portion (if available)
            string detail_part = "";
            if (exists detail && detail != "") {
                detail_part = " " + detail;
            }
            int label_len = label_part.length();
            int total_len = label_len + detail_part.length();

            # pad to content width
            string pad = "";
            if (total_len < cr.cols) {
                pad = strmul(" ", cr.cols - total_len);
            }

            if (item_idx == highlight_index) {
                # highlighted: draw entire line in highlight style
                string line = label_part + detail_part + pad;
                if (line.length() > cr.cols) {
                    line = line.substr(0, cr.cols);
                }
                w.drawText(row, cr.x, line, highlight_style);
            } else {
                # kind character in kind_style
                w.drawText(row, cr.x, kind_ch, kind_style);
                # label in default style
                string label_rest = label_part.substr(1);
                w.drawText(row, cr.x + 1, label_rest);
                # detail in dim style
                if (detail_part != "") {
                    int detail_col = cr.x + label_len;
                    # truncate if needed
                    if (detail_col < cr.x + cr.cols) {
                        int avail = cr.cols - label_len;
                        string shown = detail_part.length() > avail
                            ? detail_part.substr(0, avail) : detail_part;
                        w.drawText(row, detail_col, shown, detail_style);
                    }
                }
                # pad remaining space
                int drawn = label_len + detail_part.length();
                if (drawn < cr.cols) {
                    w.drawText(row, cr.x + drawn, pad);
                }
            }
        }

        # draw scroll indicators if there are more items than drawable
        if (completion_items.size() > drawable) {
            if (scroll_offset > 0) {
                w.drawText(cr.y, cr.x + cr.cols - 1, "^", kind_style);
            }
            if (scroll_offset + drawable < completion_items.size()) {
                w.drawText(cr.y + drawable - 1, cr.x + cr.cols - 1, "v", kind_style);
            }
        }
    }

    /** Handles completion popup events.
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
            } else if (name == "KEY_PPAGE") {
                moveHighlight(-max_visible);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_NPAGE") {
                moveHighlight(max_visible);
                return <NcursesUi::EventResult>{"handled": True};
            }
        } else if (ev.type == Ncurses::InputType::Char) {
            int code = ord(ev.ch ?? "");
            if (code == 0x0a) {
                # Enter - select highlighted item
                selectHighlighted();
                return <NcursesUi::EventResult>{"handled": True, "action": "select"};
            } else if (code == 0x1b) {
                # Escape - dismiss
                dismiss();
                return <NcursesUi::EventResult>{"handled": True, "action": "dismiss"};
            } else if (code == 0x09) {
                # Tab - select highlighted item
                selectHighlighted();
                return <NcursesUi::EventResult>{"handled": True, "action": "select"};
            } else {
                # any other key - dismiss and let the key propagate
                dismiss();
                return <NcursesUi::EventResult>{"handled": False, "action": "dismiss"};
            }
        }
        return <NcursesUi::EventResult>{"handled": False};
    }

    private nothing moveHighlight(int dir) {
        if (completion_items.empty()) {
            return;
        }
        highlight_index += dir;
        if (highlight_index < 0) {
            highlight_index = 0;
        } else if (highlight_index >= completion_items.size()) {
            highlight_index = completion_items.size() - 1;
        }
        # adjust scroll to keep highlighted item visible
        int vis = visibleCount();
        if (highlight_index < scroll_offset) {
            scroll_offset = highlight_index;
        } else if (highlight_index >= scroll_offset + vis) {
            scroll_offset = highlight_index - vis + 1;
        }
        markDirty();
    }

    private nothing selectHighlighted() {
        if (highlight_index >= 0 && highlight_index < completion_items.size()) {
            hash<auto> item = completion_items[highlight_index];
            if (on_select) {
                on_select(item);
            }
        }
    }

    private nothing dismiss() {
        if (on_dismiss) {
            on_dismiss();
        }
    }
}
