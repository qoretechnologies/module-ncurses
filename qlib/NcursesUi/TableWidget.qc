#! @file TableWidget.qc Multi-column table with headers and selection

/*  TableWidget.qc Copyright 2026 Qore Technologies, s.r.o.

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

/** Multi-column table widget with headers, sorting, and row selection.

    Displays tabular data with configurable columns, keyboard/mouse
    navigation, and optional sorting. Each column has a key, header
    label, and optional width.

    @par Column definition keys
    - \c key: hash key to read from row data
    - \c header: display header text
    - \c width: optional fixed width (0 = auto-distribute)
    - \c align: "left" (default) or "right"

    @since ncurses 2.0
*/
public namespace NcursesUi {
public class TableWidget inherits NcursesUi::Widget {
    private {
        #! column definitions
        list<hash<auto>> columns = ();
        #! row data (list of hashes)
        list<hash<auto>> rows = ();
        #! selected row index (-1 for none)
        int selected_row = -1;
        #! vertical scroll offset
        int scroll_offset = 0;
        #! whether to show the header
        bool show_header = True;
        #! sort column key
        *string sort_key;
        #! sort ascending
        bool sort_ascending = True;
        #! callback on row selection
        *code on_select;
        #! callback on row activation
        *code on_activate;
        #! header style
        hash<auto> header_style = {"attrs": Ncurses::Attr::Bold | Ncurses::Attr::Reverse};
        #! selected row style
        hash<auto> selected_style = {"attrs": Ncurses::Attr::Reverse};
        #! computed column widths
        list<int> col_widths = ();
    }

    /** Creates a new TableWidget.
        @since ncurses 2.0
    */
    constructor() {
        setFocusable(True);
    }

    /** Sets the column definitions.
        @param cols list of column definition hashes
        @since ncurses 2.0
    */
    nothing setColumns(list<hash<auto>> cols) {
        columns = cols;
        computeColumnWidths();
        markDirty();
    }

    /** Returns the column definitions.
        @since ncurses 2.0
    */
    list<hash<auto>> getColumns() {
        return columns;
    }

    /** Sets the row data.
        @param data list of row hashes
        @since ncurses 2.0
    */
    nothing setRows(list<hash<auto>> data) {
        rows = data;
        if (selected_row >= rows.size()) {
            selected_row = rows.size() > 0 ? rows.size() - 1 : -1;
        }
        if (rows.size() > 0 && selected_row < 0) {
            selected_row = 0;
        }
        scroll_offset = 0;
        computeColumnWidths();
        markDirty();
    }

    /** Returns the row data.
        @since ncurses 2.0
    */
    list<hash<auto>> getRows() {
        return rows;
    }

    /** Returns the selected row index (-1 for none).
        @since ncurses 2.0
    */
    int getSelectedRow() {
        return selected_row;
    }

    /** Returns the selected row data or NOTHING.
        @since ncurses 2.0
    */
    *hash<auto> getSelectedRowData() {
        if (selected_row >= 0 && selected_row < rows.size()) {
            return rows[selected_row];
        }
        return NOTHING;
    }

    /** Sets the row selection callback.
        @param cb callback(int index)
        @since ncurses 2.0
    */
    nothing setOnSelect(*code cb) {
        on_select = cb;
    }

    /** Sets the row activation callback.
        @param cb callback(hash<auto> row)
        @since ncurses 2.0
    */
    nothing setOnActivate(*code cb) {
        on_activate = cb;
    }

    /** Sorts by the given column key.
        @param key the column key
        @param ascending sort direction
        @since ncurses 2.0
    */
    nothing setSortColumn(string key, bool ascending = True) {
        sort_key = key;
        sort_ascending = ascending;
        applySort();
        markDirty();
    }

    /** Draws the table.
        @param w the window
        @since ncurses 2.0
    */
    nothing draw(Ncurses::Window w) {
        hash<NcursesUi::Rect> cr = contentRect();
        computeColumnWidths();

        int current_row = cr.y;
        int data_start = cr.y;

        # draw header
        if (show_header && columns.size() > 0) {
            drawHeaderRow(w, current_row, cr.x, cr.cols);
            current_row += 1;
            data_start = current_row;
        }

        # draw data rows
        int visible_rows = cr.y + cr.rows - data_start;
        for (int i = 0; i < visible_rows; ++i) {
            int idx = scroll_offset + i;
            int row = data_start + i;

            if (idx >= 0 && idx < rows.size()) {
                bool is_selected = (idx == selected_row);
                drawDataRow(w, row, cr.x, cr.cols, rows[idx], is_selected);
            } else {
                w.drawHLine(row, cr.x, cr.cols, " ");
            }
        }
    }

    /** Handles keyboard and mouse events.
        @param ev the input event
        @return EventResult
        @since ncurses 2.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (rows.empty()) {
            return <NcursesUi::EventResult>{"handled": False};
        }

        if (ev.type == Ncurses::InputType::Key) {
            string name = ev.name ?? "";
            if (name == "KEY_UP") {
                moveSelection(-1);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_DOWN") {
                moveSelection(1);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_PPAGE") {
                int visible = visibleDataRows();
                moveSelection(-visible);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_NPAGE") {
                int visible = visibleDataRows();
                moveSelection(visible);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_HOME") {
                setSelectedRow(0);
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_END") {
                setSelectedRow(rows.size() - 1);
                return <NcursesUi::EventResult>{"handled": True};
            }
        } else if (ev.type == Ncurses::InputType::Char) {
            if (ord(ev.ch ?? "") == 0x0a) {
                activateSelected();
                return <NcursesUi::EventResult>{"handled": True, "action": "activate"};
            }
        }
        return <NcursesUi::EventResult>{"handled": False};
    }

    private nothing setSelectedRow(int idx) {
        if (idx < 0) {
            idx = 0;
        }
        if (idx >= rows.size()) {
            idx = rows.size() - 1;
        }
        selected_row = idx;
        ensureVisible();
        markDirty();
    }

    private nothing moveSelection(int delta) {
        int new_idx = selected_row + delta;
        if (new_idx < 0) {
            new_idx = 0;
        }
        if (new_idx >= rows.size()) {
            new_idx = rows.size() - 1;
        }
        if (new_idx != selected_row) {
            selected_row = new_idx;
            ensureVisible();
            markDirty();
            if (on_select) {
                on_select(selected_row);
            }
        }
    }

    private nothing activateSelected() {
        if (on_activate && selected_row >= 0 && selected_row < rows.size()) {
            on_activate(rows[selected_row]);
        }
    }

    private nothing ensureVisible() {
        int visible = visibleDataRows();
        if (visible <= 0) {
            return;
        }
        if (selected_row < scroll_offset) {
            scroll_offset = selected_row;
        } else if (selected_row >= scroll_offset + visible) {
            scroll_offset = selected_row - visible + 1;
        }
    }

    private int visibleDataRows() {
        hash<NcursesUi::Rect> cr = contentRect();
        int header_rows = show_header && columns.size() > 0 ? 1 : 0;
        return cr.rows - header_rows;
    }

    private nothing computeColumnWidths() {
        hash<NcursesUi::Rect> cr = contentRect();
        int total_width = cr.cols;

        col_widths = ();
        int fixed_total = 0;
        int auto_count = 0;

        for (int i = 0; i < columns.size(); ++i) {
            int w = columns[i].width ?? 0;
            if (w > 0) {
                col_widths += w;
                fixed_total += w;
            } else {
                col_widths += 0;
                auto_count += 1;
            }
        }

        # distribute remaining space to auto columns
        if (auto_count > 0) {
            int remaining = total_width - fixed_total;
            int per_col = remaining > 0 ? remaining / auto_count : 0;
            int extra = remaining > 0 ? remaining % auto_count : 0;

            for (int i = 0; i < col_widths.size(); ++i) {
                if (col_widths[i] == 0) {
                    col_widths[i] = per_col;
                    if (extra > 0) {
                        col_widths[i] += 1;
                        extra -= 1;
                    }
                }
            }
        }
    }

    private nothing drawHeaderRow(Ncurses::Window w, int row, int start_x, int total_width) {
        w.drawHLine(row, start_x, total_width, " ", header_style);
        int x = start_x;
        for (int i = 0; i < columns.size() && i < col_widths.size(); ++i) {
            string header = columns[i].header ?? columns[i].key ?? "";
            int cw = col_widths[i];
            if (cw <= 0) {
                continue;
            }
            if (header.length() > cw) {
                header = header.substr(0, cw);
            }
            w.drawText(row, x, header, header_style);
            x += cw;
        }
    }

    private nothing drawDataRow(Ncurses::Window w, int row, int start_x, int total_width,
            hash<auto> row_data, bool is_selected) {
        hash<auto> style = is_selected ? selected_style : {};
        w.drawHLine(row, start_x, total_width, " ", style);
        int x = start_x;
        for (int i = 0; i < columns.size() && i < col_widths.size(); ++i) {
            int cw = col_widths[i];
            if (cw <= 0) {
                continue;
            }
            string key = columns[i].key ?? "";
            string cell_text = sprintf("%s", row_data{key} ?? "");
            string align = columns[i].align ?? "left";

            if (cell_text.length() > cw) {
                cell_text = cell_text.substr(0, cw);
            } else if (align == "right" && cell_text.length() < cw) {
                cell_text = strmul(" ", cw - cell_text.length()) + cell_text;
            }

            w.drawText(row, x, cell_text, style);
            x += cw;
        }
    }

    private nothing applySort() {
        if (!sort_key) {
            return;
        }
        string sk = sort_key;
        bool asc = sort_ascending;
        rows = sort(rows, int sub (hash<auto> a, hash<auto> b) {
            auto va = a{sk} ?? "";
            auto vb = b{sk} ?? "";
            int cmp;
            if (va.typeCode() == NT_INT && vb.typeCode() == NT_INT) {
                cmp = va <=> vb;
            } else {
                cmp = sprintf("%s", va) <=> sprintf("%s", vb);
            }
            return asc ? cmp : -cmp;
        });
    }
}

} # namespace NcursesUi
