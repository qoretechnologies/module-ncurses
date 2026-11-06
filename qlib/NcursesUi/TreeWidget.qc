#! @file TreeWidget.qc Typed structured data inspection with stable source paths
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
#! A source entry; path uses JSON Pointer escaping, with the root identified by an empty string.
public hashdecl TreeEntry {
    string path; *string parent; string label; string type; int depth; bool branch; auto value;
}
/** @internal Flat index entry: traversal never recurses through user data. */
hashdecl TreeNode { hash<NcursesUi::TreeEntry> entry; list<string> children = (); string preview; string display_label; string searchable; }
/** Read-only inspector for nested hashes/lists and typed scalar values.
    Stable paths preserve selection/expansion across replacement. Filtering includes
    matching nodes and their ancestors without changing saved expansion state.
    Left/Right collapse/expand or visit parent/first child; Enter/Space toggle a
    branch, and Enter on a scalar invokes the optional activation callback. Copy
    returns a scalar string verbatim; export delivers the original typed value.
*/
public class TreeWidget inherits NcursesUi::ScrollableWidget {
    private {
        hash<string, hash<NcursesUi::TreeNode>> nodes = {};
        list<string> order = ();
        list<string> visible_paths = ();
        hash<string, int> visible_indexes = {};
        int rendered_rows = 0;
        hash<string, bool> expanded = {};
        *string selected;
        string filter = "";
        NcursesUi::LineListContent lines();
        int rendered_width = -1;
        *hash<NcursesUi::Rect> last_viewport;
        bool reveal_selection = True;
        int maximum_nodes = 100000;
        int maximum_depth = 2048;
        *code<nothing(*hash<NcursesUi::TreeEntry>)> on_select;
        *code<nothing(hash<NcursesUi::TreeEntry>)> on_activate;
        *code<nothing(string)> on_copy;
        *code<nothing(string, auto)> on_export;
    }
    /** Creates an inspector. @param value arbitrary typed data, including NOTHING @param label root label */
    constructor(auto value = NOTHING, string label = "Root") { setContent(lines); setData(value, label); }
    /** Sets traversal limits for subsequent replacements. @param count positive node bound @param depth nonnegative depth bound
        @throw TREE-LIMIT-ERROR for invalid limits
    */
    nothing setLimits(int count, int depth) {
        if (count < 1 || depth < 0) { throw "TREE-LIMIT-ERROR", "Invalid tree traversal limits"; }
        maximum_nodes = count; maximum_depth = depth;
    }
    /** Replaces data atomically after indexing and validating traversal limits.
        @param value typed source @param label root label @throw TREE-LIMIT-ERROR for excessive depth/nodes
    */
    nothing setData(auto value, string label = "Root") {
        *hash<NcursesUi::TreeEntry> before = getSelectedEntry();
        hash<string, hash<NcursesUi::TreeNode>> next = {}; list<string> next_order = ();
        list<hash<NcursesUi::TreeEntry>> pending = (<NcursesUi::TreeEntry>{"path": "", "label": label, "depth": 0, "value": value, "type": "", "branch": False},);
        while (pending) {
            hash<NcursesUi::TreeEntry> entry = pop pending;
            if (entry.depth > maximum_depth || next_order.size() >= maximum_nodes) { throw "TREE-LIMIT-ERROR", "Tree exceeds configured depth or node limit"; }
            auto item = entry.value; int type = item.typeCode(); entry.type = item.type();
            entry.branch = type == NT_HASH || type == NT_LIST;
            if (entry.branch && (item.size() + pending.size() + next_order.size() + 1 > maximum_nodes
                    || (item.size() && entry.depth >= maximum_depth))) { throw "TREE-LIMIT-ERROR", "Tree exceeds configured depth or node limit"; }
            hash<NcursesUi::TreeNode> node = <NcursesUi::TreeNode>{"entry": entry, "preview": preview(item), "display_label": literal(entry.label), "searchable": entry.label + " " + (type == NT_STRING ? string(item) : preview(item))};
            list<hash<NcursesUi::TreeEntry>> children = ();
            if (type == NT_HASH) {
                hash<auto> values = item;
                foreach hash<string, auto> pair in (values.pairIterator()) {
                    string path = entry.path + "/" + replace(replace(string(pair.key), "~", "~0"), "/", "~1");
                    node.children += path;
                    children += <NcursesUi::TreeEntry>{"path": path, "parent": entry.path, "label": string(pair.key), "depth": entry.depth + 1,
                        "value": pair.value, "type": "", "branch": False};
                }
            } else if (type == NT_LIST) {
                for (int i = 0; i < item.size(); ++i) {
                    string path = entry.path + "/" + i; node.children += path;
                    children += <NcursesUi::TreeEntry>{"path": path, "parent": entry.path, "label": "[" + i + "]", "depth": entry.depth + 1,
                        "value": item[i], "type": "", "branch": False};
                }
            }
            next{entry.path} = node; next_order += entry.path;
            for (int i = children.size() - 1; i >= 0; --i) { pending += children[i]; }
            if (pending.size() + next_order.size() > maximum_nodes) { throw "TREE-LIMIT-ERROR", "Tree exceeds configured node limit"; }
        }
        hash<string, bool> retained = {};
        foreach string path in (next_order) { if (expanded{path} && next{path}.entry.branch) { retained{path} = True; } }
        if (!nodes) { retained{""} = True; }
        while (exists selected && !exists next{selected}) { selected = nodes{selected}.entry.parent; }
        nodes = next; order = next_order; expanded = retained; rebuild(); revealSelection();
        if (before !== getSelectedEntry()) { notifySelection(); }
    }
    /** Returns an indexed source entry. @param path stable source path @return typed entry @throw TREE-PATH-ERROR if absent */
    hash<NcursesUi::TreeEntry> getEntry(string path) { return node(path).entry; }
    /** Returns visible source identities in order. @return paths, not display-row numbers */
    list<string> getVisiblePaths() { return visible_paths; }
    /** Returns the selected source identity. @return path or NOTHING when a filter hides every entry */
    *string getSelectedPath() { return selected; }
    /** Returns selected typed data. @return entry or NOTHING */
    *hash<NcursesUi::TreeEntry> getSelectedEntry() { return exists selected ? nodes{selected}.entry : NOTHING; }
    /** Selects a source path and expands its ancestors. Filtering must permit the requested path.
        @param path source identity @throw TREE-PATH-ERROR if absent or excluded by the filter
    */
    nothing selectPath(string path) {
        node(path); if (filter != "" && !exists visible_indexes{path}) { throw "TREE-PATH-ERROR", "Path is excluded by the filter"; }
        *string parent = nodes{path}.entry.parent; bool changed = False;
        while (exists parent) { if (!expanded{parent}) { changed = True; expanded{parent} = True; } parent = nodes{parent}.entry.parent; }
        *string before = selected; selected = path;
        if (changed) { rebuild(); } else { renderSelection(before); }
        revealSelection(); notifySelection();
    }
    /** Expands or collapses a branch. @param path source identity @param value expanded state */
    nothing setExpanded(string path, bool value) {
        hash<NcursesUi::TreeNode> entry = node(path); if (!entry.entry.branch) { return; }
        *string before = selected; expanded{path} = value; rebuild(); revealSelection();
        if (before !== selected) { notifySelection(); }
    }
    /** Returns saved expansion state, independent of filtering. @param path source identity @return expanded */
    bool isExpanded(string path) { node(path); return expanded{path} ?? False; }
    /** Sets literal case-insensitive filtering. @param text label/value query; empty restores saved expansion */
    nothing setFilter(string text) { *string before = selected; filter = text.lwr(); rebuild(); revealSelection(); if (before !== selected) { notifySelection(); } }
    /** Sets selection notification. @param callback receives the newly selected source entry */
    nothing setOnSelect(*code<nothing(*hash<NcursesUi::TreeEntry>)> callback) { on_select = callback; }
    /** Sets scalar activation. @param callback receives original typed data */
    nothing setOnActivate(*code<nothing(hash<NcursesUi::TreeEntry>)> callback) { on_activate = callback; }
    /** Sets copy integration. @param callback receives plain selected value */
    nothing setOnCopy(*code<nothing(string)> callback) { on_copy = callback; }
    /** Sets export integration. @param callback receives path and original typed value; no files are written by the widget */
    nothing setOnExport(*code<nothing(string, auto)> callback) { on_export = callback; }
    /** Copies selected data through the configured callback. @return whether a callback ran */
    bool copySelection() { if (!exists selected || !on_copy) { return False; } auto value = nodes{selected}.entry.value; on_copy(value.typeCode() == NT_STRING ? string(value) : sprintf("%Y", value)); return True; }
    /** Exports selected typed data through the configured callback. @return whether a callback ran */
    bool exportSelection() { if (!exists selected || !on_export) { return False; } on_export(selected, nodes{selected}.entry.value); return True; }
    /** Reflows indentation for narrow terminals before drawing. @param window target */
    nothing draw(Ncurses::Window window) {
        prepareDrawViewport(window);
        bool reflow = rendered_width != getViewportRect().cols;
        if (reflow) { render(); }
        if (reflow || reveal_selection || last_viewport != getViewportRect()) { revealSelection(); }
        reveal_selection = False; last_viewport = getViewportRect();
        ScrollableWidget::draw(window);
    }
    /** Reveals the selected source entry on focus entry. */
    nothing onFocusIn() { reveal_selection = True; }
    /** Handles keyboard and mouse navigation. @param event input @return handling result */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> event) {
        if (!isAvailable()) { return <NcursesUi::EventResult>{}; }
        int index = selectedIndex(); int next = index; string key = event.name ?? "";
        if (event.type == Ncurses::InputType::Key) {
            if (key == "KEY_UP") { next = max(0, index - 1); }
            else if (key == "KEY_DOWN") { next = min(visible_paths.size() - 1, index + 1); }
            else if (key == "KEY_HOME") { next = 0; }
            else if (key == "KEY_END") { next = visible_paths.size() - 1; }
            else if (key == "KEY_PPAGE") { next = max(0, index - max(1, getViewportRect().rows)); }
            else if (key == "KEY_NPAGE") { next = min(visible_paths.size() - 1, index + max(1, getViewportRect().rows)); }
            else if (key == "KEY_LEFT" && exists selected) {
                if (nodes{selected}.entry.branch && expanded{selected}) { setExpanded(selected, False); }
                else if (exists nodes{selected}.entry.parent) { selectPath(nodes{selected}.entry.parent); }
                return <NcursesUi::EventResult>{"handled": True};
            } else if (key == "KEY_RIGHT" && exists selected) {
                if (!expanded{selected}) { setExpanded(selected, True); }
                else {
                    foreach string child in (nodes{selected}.children) { if (exists visible_indexes{child}) { selectPath(child); break; } }
                }
                return <NcursesUi::EventResult>{"handled": True};
            } else if (key != "KEY_ENTER") { return ScrollableWidget::processEvent(event); }
        } else if (event.type == Ncurses::InputType::Mouse && event.mouse
                && (event.mouse.button_state & (Ncurses::BUTTON1_CLICKED | Ncurses::BUTTON1_PRESSED | Ncurses::BUTTON1_DOUBLE_CLICKED))) {
            hash<NcursesUi::Rect> view = getViewportRect();
            if (!NcursesUi::Geometry::rectContains(view, event.mouse.y, event.mouse.x)) { return ScrollableWidget::processEvent(event); }
            next = event.mouse.y - view.y + getScrollY();
            if (next >= 0 && next < visible_paths.size()) {
                string path = visible_paths[next]; hash<NcursesUi::TreeNode> item = nodes{path};
                int column = event.mouse.x - view.x + getScrollX(); int indent = indentation(item.entry.depth, getViewportRect().cols);
                if (item.entry.branch && ((column >= indent && column < indent + min(2, view.cols))
                        || (event.mouse.button_state & Ncurses::BUTTON1_DOUBLE_CLICKED))) {
                    selected = path; setExpanded(path, !expanded{path}); notifySelection();
                    return <NcursesUi::EventResult>{"handled": True, "action": "toggle"};
                }
            }
        } else if (event.type == Ncurses::InputType::Char && event.ch == "\x03") { return <NcursesUi::EventResult>{"handled": copySelection()}; }
        else if (event.type != Ncurses::InputType::Char || (event.ch != " " && event.ch != "\n" && event.ch != "\r")) { return ScrollableWidget::processEvent(event); }
        bool activate = key == "KEY_ENTER" || (event.type == Ncurses::InputType::Char && (event.ch == " " || event.ch == "\n" || event.ch == "\r"));
        if (activate && exists selected) {
            if (nodes{selected}.entry.branch) { setExpanded(selected, !expanded{selected}); }
            else if (on_activate) { on_activate(nodes{selected}.entry); }
            return <NcursesUi::EventResult>{"handled": True, "action": "activate"};
        }
        if (next >= 0 && next < visible_paths.size() && next != index) { *string before = selected; selected = visible_paths[next]; renderSelection(before); revealSelection(); notifySelection(); }
        return <NcursesUi::EventResult>{"handled": True};
    }
    private hash<NcursesUi::TreeNode> node(string path) { if (!exists nodes{path}) { throw "TREE-PATH-ERROR", "Unknown tree path"; } return nodes{path}; }
    private nothing notifySelection() { if (on_select) { on_select(getSelectedEntry()); } }
    /** Returns deterministic rendering work counts. @return source rows formatted since construction */
    hash<auto> getUpdateStats() { return {"rendered_rows": rendered_rows}; }
    private int selectedIndex() { return exists selected ? visible_indexes{selected} ?? -1 : -1; }
    private nothing revealSelection() {
        int index = selectedIndex(); hash<NcursesUi::Rect> view = getViewportRect();
        if (index < 0) { return; } if (index < getScrollY()) { setScrollY(index); }
        else if (index >= getScrollY() + view.rows) { setScrollY(index - max(1, view.rows) + 1); }
    }
    private nothing rebuild() {
        hash<string, bool> included = {};
        if (filter != "") {
            # Bottom-up propagation includes ancestors in linear time, even for very deep data.
            for (int i = order.size() - 1; i >= 0; --i) {
                string path = order[i]; hash<NcursesUi::TreeNode> item = nodes{path};
                if (item.searchable.lwr().find(filter) >= 0) { included{path} = True; }
                if (included{path} && exists item.entry.parent) { included{item.entry.parent} = True; }
            }
        }
        list<string> next = (); hash<string, bool> shown = {};
        foreach string path in (order) {
            *string parent = nodes{path}.entry.parent;
            bool display = filter != "" ? included{path} ?? False : (!exists parent || (shown{parent} && expanded{parent}));
            if (display) { next += path; shown{path} = True; }
        }
        visible_paths = next; visible_indexes = {};
        for (int i = 0; i < next.size(); ++i) { visible_indexes{next[i]} = i; }
        while (exists selected && !shown{selected}) { selected = exists nodes{selected} ? nodes{selected}.entry.parent : NOTHING; }
        if (!exists selected && next) { selected = next[0]; }
        render();
    }
    private static int indentation(int depth, int columns) { return min(depth * 2, max(0, min(columns / 3, columns - 3))); }
    private string renderLine(string path) {
        hash<NcursesUi::TreeNode> item = nodes{path}; ++rendered_rows;
        int columns = getViewportRect().cols;
        string marker = columns < 3 ? "" : (item.entry.branch ? ((expanded{path} || filter != "") ? "▾ " : "▸ ") : "  ");
        string row = strmul(" ", indentation(item.entry.depth, columns)) + marker
            + item.display_label + ": " + item.preview;
        return path == selected ? "\e[7m" + row + "\e[0m" : row;
    }
    private nothing renderSelection(*string before) {
        if (exists before && exists visible_indexes{before}) { lines.setLine(visible_indexes{before}, renderLine(before)); }
        if (exists selected && selected !== before) { lines.setLine(visible_indexes{selected}, renderLine(selected)); }
        markDirty();
    }
    private nothing render() {
        list<string> rows = (); foreach string path in (visible_paths) { rows += renderLine(path); }
        lines.setLines(rows); rendered_width = getViewportRect().cols; markDirty();
    }
    private static string literal(string value) {
        value = value.substr(0, 256); value = replace(value, "\\", "\\\\");
        value = replace(replace(replace(value, "\n", "\\n"), "\r", "\\r"), "\t", "\\t");
        for (int i = 0; i < 32; ++i) { if (i != 9 && i != 10 && i != 13) { value = replace(value, chr(i), sprintf("\\x%02x", i)); } }
        return replace(value, "\x7f", "\\x7f");
    }
    private static string preview(auto value) {
        int type = value.typeCode();
        if (type == NT_HASH) { return sprintf("{ %d keys }", value.size()); }
        if (type == NT_LIST) { return sprintf("[ %d items ]", value.size()); }
        if (type == NT_NOTHING) { return "nothing"; }
        if (type == NT_STRING) { return "\"" + literal(string(value)) + (value.length() > 256 ? "…" : "") + "\""; }
        if (type == NT_BINARY) { return "binary " + cast<binary>(value).substr(0, 64).toHex() + (value.size() > 64 ? "…" : ""); }
        return literal(sprintf("%Y", value));
    }
}
/** A hash-oriented inspector sharing the tree's typed expansion, filtering, copy and export behavior. */
public class KeyValueWidget inherits NcursesUi::TreeWidget {
    /** Creates a key/value inspector. @param values named typed values */
    constructor(hash<auto> values = {}) : TreeWidget(values, "Values") {}
}
} # namespace NcursesUi
