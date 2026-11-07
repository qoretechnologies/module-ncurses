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

public namespace NcursesUi {
/** A table with stable row identity, typed sorting, filtering, and navigation.
    Column hashes accept key, header, width (zero means automatic), align, and
    type (auto, number, string, date). Auto sorting puts nulls first, then numeric,
    date, and textual values. Number columns also accept numeric strings; invalid
    values raise TABLE-VALUE-ERROR. Equal sort keys retain input order.

    Call setRowKey() with a unique scalar identity field to preserve selection
    across data refreshes. Without a key, equal row hashes identify the selection.
    Filtering matches a case-insensitive substring of displayed values. Left/Right
    reveal columns; Enter and double-click activate rows; mouse wheel moves rows.
    Notification callbacks run for changed row data or visible index, including
    programmatic changes. Removing a sort column restores input ordering.
    Data/comparator failures preserve the previous view. Notification callbacks
    run after a coherent view is committed and may propagate exceptions.
    @since ncurses 1.0
*/
public class TableWidget inherits NcursesUi::Widget {
    private {
        *hash<NcursesUi::Rect> draw_bounds;
        list<hash<auto>> columns = ();
        list<hash<auto>> all_rows = ();
        list<hash<auto>> rows = ();
        int selected_row = -1;
        int selected_column = 0;
        int scroll_offset = 0;
        int scroll_x = 0;
        bool show_header = True;
        bool updating = False;
        *string sort_key;
        bool sort_ascending = True;
        *string row_key;
        string filter_text = "";
        *code<int(auto, auto)> comparator;
        *code<nothing(int)> on_select;
        *code<nothing(hash<auto>)> on_activate;
        *code<nothing(string, hash<auto>)> on_action;
        hash<auto> header_style = {"attrs": Ncurses::Attr::Bold | Ncurses::Attr::Underline, "fg": Ncurses::Color::Cyan};
        hash<auto> selected_style = {"attrs": Ncurses::Attr::Reverse};
        list<int> col_widths = ();
    }
    #! Creates an empty focusable table.
    constructor() { setFocusable(True); }

    /** Sets column definitions. Invalid definitions leave the table unchanged.
        @param cols columns with nonempty unique keys and nonnegative widths
        @throw TABLE-COLUMN-ERROR for invalid definitions
    */
    nothing setColumns(list<hash<auto>> cols) {
        checkUpdate();
        hash<string, bool> seen = {};
        foreach hash<auto> col in (cols) {
            string key = col.key ?? "";
            string type = col.type ?? "auto";
            if (key == "" || seen{key} || (col.width ?? 0) < 0
                    || (type != "auto" && type != "number" && type != "string" && type != "date")) {
                throw "TABLE-COLUMN-ERROR", "Columns require unique keys, nonnegative widths, and valid types";
            }
            seen{key} = True;
        }
        list<hash<auto>> old = columns;
        *string old_sort = sort_key;
        if (sort_key && !seen{sort_key}) { sort_key = NOTHING; }
        columns = cols;
        bool changed;
        try { changed = rebuild(all_rows); } catch (hash<ExceptionInfo> ex) { columns = old; sort_key = old_sort; rethrow; }
        selected_column = min(selected_column, max(0, columns.size() - 1));
        computeColumnWidths(); markDirty();
        notifySelection(changed);
    }
    /** Returns column definitions. @return ordered column hashes */
    list<hash<auto>> getColumns() { return columns; }
    /** Sets or replaces rows, retaining the selected identity when present.
        @param data row hashes
        @throw TABLE-IDENTITY-ERROR for duplicate or missing configured identities
    */
    nothing setRows(list<hash<auto>> data) { notifySelection(rebuild(data)); }
    /** Returns the filtered/sorted rows. @return current visible data */
    list<hash<auto>> getRows() { return rows; }
    /** Returns the selection. @return visible row index, or -1 when empty */
    int getSelectedRow() { return selected_row; }
    /** Returns the first visible data-row index for inspection and scroll assertions.
        @return zero-based offset into getRows(); excludes the header
    */
    int getScrollOffset() { return scroll_offset; }
    /** Returns the selection data. @return selected row, or NOTHING */
    *hash<auto> getSelectedRowData() {
        return selected_row >= 0 && selected_row < rows.size() ? rows[selected_row] : NOTHING;
    }
    /** Sets a stable scalar row-identity field, or disables identity matching.
        @param key field name, or NOTHING to match entire rows
    */
    nothing setRowKey(*string key) {
        checkUpdate();
        if (exists key && key == "") { throw "TABLE-IDENTITY-ERROR", "The identity field cannot be empty"; }
        *string old = row_key; row_key = key;
        try { validateIdentities(all_rows); } catch (hash<ExceptionInfo> ex) { row_key = old; rethrow; }
    }
    /** Sets a case-insensitive substring filter over displayed column values.
        @param text filter; empty shows every row
    */
    nothing setFilter(string text) {
        checkUpdate();
        string old = filter_text; filter_text = text.lwr();
        bool changed;
        try { changed = rebuild(all_rows); } catch (hash<ExceptionInfo> ex) { filter_text = old; rethrow; }
        notifySelection(changed);
    }
    /** Returns the active filter. @return lowercase filter text */
    string getFilter() { return filter_text; }
    /** Enables or disables the header row.
        @param value True to show the header
    */
    nothing setShowHeader(bool value) {
        checkUpdate(); show_header = value; ensureVisible(); markDirty(); }
    /** Sets selection notification (called once per changed visible selection).
        @param cb callback or NOTHING
    */
    nothing setOnSelect(*code<nothing(int)> cb) { on_select = cb; }
    /** Sets activation notification.
        @param cb callback or NOTHING
    */
    nothing setOnActivate(*code<nothing(hash<auto>)> cb) { on_activate = cb; }
    /** Sets an application-owned row action callback.
        @param cb callback receiving action ID and selected row, or NOTHING
    */
    nothing setOnAction(*code<nothing(string, hash<auto>)> cb) { on_action = cb; }
    /** Invokes a row action, if a row and callback exist.
        @param id stable application action identifier
        @return True when invoked
    */
    bool activateAction(string id) {
        *hash<auto> row = getSelectedRowData();
        if (!(exists row) || !on_action) { return False; }
        on_action(id, row); return True;
    }
    /** Sets a value comparator for sorting; NOTHING restores typed comparison.
        @param cb comparator returning negative, zero, or positive
    */
    nothing setComparator(*code<int(auto, auto)> cb) {
        checkUpdate();
        *code<int(auto, auto)> old = comparator; comparator = cb;
        bool changed;
        try { changed = rebuild(all_rows); } catch (hash<ExceptionInfo> ex) { comparator = old; rethrow; }
        notifySelection(changed);
    }
    /** Sorts by a column, retaining row identity and stable equal-key order.
        @param key column key
        @param ascending direction
    */
    nothing setSortColumn(string key, bool ascending = True) {
        checkUpdate();
        bool found = False;
        foreach hash<auto> col in (columns) { if (col.key == key) { found = True; break; } }
        if (!found) { throw "TABLE-COLUMN-ERROR", "Unknown sort column: " + key; }
        *string old_key = sort_key; bool old_asc = sort_ascending;
        sort_key = key; sort_ascending = ascending;
        bool changed;
        try { changed = rebuild(all_rows); } catch (hash<ExceptionInfo> ex) {
            sort_key = old_key; sort_ascending = old_asc; rethrow;
        }
        notifySelection(changed);
    }
    /** Selects a bounded visible row and notifies on a change.
        @param idx requested visible row
    */
    nothing setSelectedRow(int idx) {
        checkUpdate();
        int next = rows ? max(0, min(idx, rows.size() - 1)) : -1;
        bool changed = next != selected_row; selected_row = next;
        ensureVisible(); markDirty();
        if (changed && on_select) { on_select(selected_row); }
    }
    /** Returns the active column. @return zero-based column index */
    int getSelectedColumn() { return selected_column; }
    /** Selects a column and scrolls it into view.
        @param index column index (clamped)
    */
    nothing setSelectedColumn(int index) {
        checkUpdate();
        selected_column = max(0, min(index, columns.size() - 1));
        computeColumnWidths(); revealColumn();
        markDirty();
    }
    /** Draws clipped cells and keeps the current selection visible after resize.
        @param w target window
    */
    nothing draw(Ncurses::Window w) {
        hash<Ncurses::Position> origin = w.position(); hash<Ncurses::Size> size = w.size();
        draw_bounds = NcursesUi::Geometry::makeRect(origin.y, origin.x, size.rows, size.cols);
        hash<NcursesUi::Rect> cr = viewRect(); cr.y -= origin.y; cr.x -= origin.x;
        computeColumnWidths(); revealColumn(); ensureVisible();
        if (cr.rows <= 0 || cr.cols <= 0) { return; }
        hash<auto> heading = header_style; hash<auto> selected = {}; selected += selected_style; hash<auto> normal = {};
        if (hasFocus() && isAvailable()) { selected.attrs |= Ncurses::Attr::Bold; selected.fg = Ncurses::Color::Cyan; }
        if (!isAvailable()) { heading.attrs |= Ncurses::Attr::Dim; selected.attrs |= Ncurses::Attr::Dim; normal.attrs = Ncurses::Attr::Dim; }
        int y = cr.y;
        if (show_header && columns) { drawRow(w, y++, cr.x, cr.cols, NOTHING, heading); }
        for (int i = 0; y < cr.y + cr.rows; ++y, ++i) {
            int index = scroll_offset + i;
            drawRow(w, y, cr.x, cr.cols, index < rows.size() ? rows[index] : NOTHING,
                index == selected_row ? selected : normal, False);
        }
    }
    /** Handles row/column navigation, primary selection, double activation, and wheel input.
        @param ev input event
        @return event result
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (!isAvailable() || !rows) { return <NcursesUi::EventResult>{"handled": False}; }
        if (ev.type == Ncurses::InputType::Key) {
            string key = ev.name ?? "";
            switch (key) {
                case "KEY_UP": setSelectedRow(selected_row - 1); break;
                case "KEY_DOWN": setSelectedRow(selected_row + 1); break;
                case "KEY_PPAGE": setSelectedRow(selected_row - max(1, visibleDataRows())); break;
                case "KEY_NPAGE": setSelectedRow(selected_row + max(1, visibleDataRows())); break;
                case "KEY_HOME": setSelectedRow(0); break;
                case "KEY_END": setSelectedRow(rows.size() - 1); break;
                case "KEY_LEFT": setSelectedColumn(selected_column - 1); break;
                case "KEY_RIGHT": setSelectedColumn(selected_column + 1); break;
                case "KEY_ENTER": return activateSelected();
                default: return <NcursesUi::EventResult>{"handled": False};
            }
        } else if (ev.type == Ncurses::InputType::Char && (ev.ch == "\n" || ev.ch == "\r")) {
            return activateSelected();
        } else if (ev.type == Ncurses::InputType::Mouse && ev.mouse) {
            hash<NcursesUi::Rect> cr = viewRect();
            if (!NcursesUi::Geometry::rectContains(cr, ev.mouse.y, ev.mouse.x)) {
                return <NcursesUi::EventResult>{"handled": False};
            }
            int bs = ev.mouse.button_state;
            if (bs & Ncurses::BUTTON4_PRESSED) { setSelectedRow(selected_row - 1); }
            else if (bs & Ncurses::BUTTON5_PRESSED) { setSelectedRow(selected_row + 1); }
            else if (bs & (Ncurses::BUTTON1_PRESSED | Ncurses::BUTTON1_CLICKED
                    | Ncurses::BUTTON1_DOUBLE_CLICKED | Ncurses::BUTTON1_TRIPLE_CLICKED)) {
                int index = scroll_offset + ev.mouse.y - cr.y - (show_header && columns ? 1 : 0);
                if (index < scroll_offset || index >= rows.size()) { return <NcursesUi::EventResult>{"handled": False}; }
                setSelectedRow(index);
                if (bs & Ncurses::BUTTON1_DOUBLE_CLICKED) { return activateSelected(); }
            } else { return <NcursesUi::EventResult>{"handled": False}; }
        } else { return <NcursesUi::EventResult>{"handled": False}; }
        return <NcursesUi::EventResult>{"handled": True};
    }
    private hash<NcursesUi::EventResult> activateSelected() {
        *hash<auto> row = getSelectedRowData();
        if (exists row && on_activate) { on_activate(row); }
        return <NcursesUi::EventResult>{"handled": True, "action": "activate"};
    }
    private hash<NcursesUi::Rect> viewRect() {
        hash<NcursesUi::Rect> rect = NcursesUi::Geometry::intersect(contentRect(), visibleRect());
        return draw_bounds ? NcursesUi::Geometry::intersect(rect, draw_bounds) : rect;
    }
    private int visibleDataRows() { return max(0, viewRect().rows - (show_header && columns ? 1 : 0)); }
    private nothing ensureVisible() {
        int visible = visibleDataRows();
        scroll_offset = max(0, min(scroll_offset, rows.size() - max(1, visible)));
        if (visible > 0 && selected_row >= 0) {
            if (selected_row < scroll_offset) { scroll_offset = selected_row; }
            else if (selected_row >= scroll_offset + visible) { scroll_offset = selected_row - visible + 1; }
        }
    }
    private nothing revealColumn() {
        int left = 0;
        for (int i = 0; i < selected_column; ++i) { left += col_widths[i]; }
        int width = viewRect().cols;
        int right = left + (col_widths ? col_widths[selected_column] : 0);
        if (left < scroll_x || right - left > width) { scroll_x = left; }
        else if (right > scroll_x + width) { scroll_x = max(left, right - width); }
    }
    private nothing computeColumnWidths() {
        col_widths = (); int fixed = 0; int automatic = 0;
        foreach hash<auto> col in (columns) {
            int width = col.width ?? 0; col_widths += width;
            if (width) { fixed += width; } else { ++automatic; }
        }
        int remaining = max(0, viewRect().cols - fixed);
        for (int i = 0; i < col_widths.size(); ++i) {
            if (!col_widths[i] && automatic) {
                col_widths[i] = remaining / automatic; remaining -= col_widths[i]; --automatic;
            }
        }
        int total = 0; foreach int width in (col_widths) { total += width; }
        scroll_x = max(0, min(scroll_x, total - viewRect().cols));
    }
    private nothing drawRow(Ncurses::Window w, int y, int x, int width, *hash<auto> row,
            hash<auto> style, bool header = True) {
        w.drawHLine(y, x, width, " ", style);
        int col = -scroll_x;
        for (int i = 0; i < columns.size(); ++i) {
            int cw = col_widths[i];
            if (cw > 0 && col < width && col + cw > 0) {
                string value = row ? sprintf("%s", row{columns[i].key} ?? "")
                    : header ? (columns[i].header ?? columns[i].key) : "";
                string text = columns[i].align == "right" && row
                    ? TerminalText::fitLeft(value, cw) : TerminalText::fitRight(value, cw);
                int begin = max(0, col); int count = min(width, col + cw) - begin;
                w.drawText(y, x + begin, TerminalText::columnSlice(text, max(0, -col), count), style);
            }
            col += cw;
        }
    }
    private string identity(hash<auto> row) {
        auto value = row{row_key};
        if (!(exists value) || (value.typeCode() != NT_STRING && value.typeCode() != NT_INT
                && value.typeCode() != NT_FLOAT && value.typeCode() != NT_NUMBER
                && value.typeCode() != NT_BOOLEAN && value.typeCode() != NT_DATE)) {
            throw "TABLE-IDENTITY-ERROR", "Configured row keys require scalar values";
        }
        return sprintf("%d:%y", value.typeCode(), value);
    }
    private nothing validateIdentities(list<hash<auto>> data) {
        if (!row_key) { return; }
        hash<string, bool> seen = {};
        foreach hash<auto> row in (data) {
            string key = identity(row);
            if (seen{key}) { throw "TABLE-IDENTITY-ERROR", "Duplicate row identity: " + key; }
            seen{key} = True;
        }
    }
    private int valueRank(auto value) {
        int t = value.typeCode();
        if (t == NT_NOTHING || t == NT_NULL) { return 0; }
        if (t == NT_INT || t == NT_FLOAT || t == NT_NUMBER) { return 1; }
        if (t == NT_DATE) { return 2; }
        return 3;
    }
    private auto sortValue(auto value, string type) {
        if (valueRank(value) == 0) { return NOTHING; }
        if (type == "number") {
            if (valueRank(value) != 1 && (value.typeCode() != NT_STRING
                    || !(value =~ /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$/))) {
                throw "TABLE-VALUE-ERROR", "A number column contains a nonnumeric value";
            }
            return number(value);
        }
        if (type == "date" && value.typeCode() != NT_DATE) {
            throw "TABLE-VALUE-ERROR", "A date column contains a non-date value";
        }
        return type == "string" ? sprintf("%s", value) : value;
    }
    private nothing checkUpdate() {
        if (updating) { throw "TABLE-UPDATE-ERROR", "A comparator cannot mutate the table"; }
    }
    private nothing notifySelection(bool changed) {
        if (changed && on_select) { on_select(selected_row); }
    }
    private bool rebuild(list<hash<auto>> data) {
        checkUpdate(); updating = True; on_exit updating = False;
        validateIdentities(data);
        *hash<auto> old_row = getSelectedRowData(); int old_index = selected_row;
        string type = "auto";
        foreach hash<auto> col in (columns) { if (col.key == sort_key) { type = col.type ?? "auto"; break; } }
        list<hash<auto>> entries = (); int index = 0;
        foreach hash<auto> row in (data) {
            string searchable = "";
            foreach hash<auto> col in (columns) { searchable += sprintf("%s\n", row{col.key} ?? ""); }
            if (filter_text == "" || searchable.lwr().find(filter_text) >= 0) {
                entries += {"row": row, "index": index, "value": sort_key ? sortValue(row{sort_key}, type) : NOTHING};
            }
            ++index;
        }
        if (sort_key) {
            entries = sort(entries, int sub (hash<auto> a, hash<auto> b) {
                int cmp;
                if (comparator) { cmp = comparator(a.value, b.value); }
                else {
                    int ra = valueRank(a.value); int rb = valueRank(b.value);
                    cmp = ra <=> rb;
                    if (!cmp && ra) { cmp = ra == 3 ? sprintf("%s", a.value) <=> sprintf("%s", b.value) : a.value <=> b.value; }
                }
                return cmp ? (sort_ascending ? cmp : -cmp) : (a.index <=> b.index);
            });
        }
        list<hash<auto>> next = map $1.row, entries;
        int selection = next ? max(0, min(selected_row, next.size() - 1)) : -1;
        if (exists old_row) {
            for (int i = 0; i < next.size(); ++i) {
                if (row_key ? identity(old_row) == identity(next[i]) : old_row == next[i]) { selection = i; break; }
            }
        }
        all_rows = data; rows = next; selected_row = selection; ensureVisible(); markDirty();
        return old_index != selection || old_row != getSelectedRowData();
    }
}
} # namespace NcursesUi
