#! @file AssistancePopupWidget.qc Caret-anchored completion and help presentation
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
/** Caret-anchored assistance with ranked completions, diagnostics, actions and signature help.
    Type to filter completion labels; Up/Down select, Enter activates, Tab switches
    between the result list and scrollable documentation, and Escape dismisses.
    Use the application's popup stack and setOnDismiss() to pop/destroy the panel.
    The editor's shared caret mapping supplies the anchor across wrapping/scrolling.
    If the caret is outside the visible editor, positionAtCaret() hides/cancels help.
    Models, widgets and callbacks belong to the UI thread.
*/
public class AssistancePopupWidget inherits NcursesUi::PanelWidget {
    private {
        NcursesUi::TextEditorWidget editor;
        NcursesUi::AssistanceModel model;
        NcursesUi::ListWidget results();
        NcursesUi::ScrollableWidget documentation();
        NcursesUi::LineListContent doc_lines();
        NcursesReplUi::InputBuffer filter();
        bool docs_active = False;
        int observed_revision = -1;
        int maximum_rows = 14;
        int maximum_cols = 72;
        *code<nothing()> on_dismiss;
    }
    /** Creates a popup for an editor/model pair.
        @param session terminal session @param input editor to anchor @param assistance model using the same buffer
        @throw ASSISTANCE-EDITOR-ERROR for a mismatched editor/model
    */
    constructor(Ncurses::Session session, NcursesUi::TextEditorWidget input, NcursesUi::AssistanceModel assistance)
            : PanelWidget(session, "Assistance") {
        if (input.getBuffer() != assistance.getEditor()) { throw "ASSISTANCE-EDITOR-ERROR", "Assistance model belongs to another editor"; }
        editor = input; model = assistance; setFocusable(True);
        results.setFocusable(False); documentation.setFocusable(False); doc_lines.setWordWrap(True); documentation.setContent(doc_lines);
        results.setOnSelect(sub (int index) { updateDocumentation(); });
        results.setOnActivate(sub (hash<auto> item) { activateSelected(); });
        addChild(results); addChild(documentation); refresh();
    }
    /** Sets dismissal integration. @param callback pops/destroys this popup in the owning application */
    nothing setOnDismiss(*code<nothing()> callback) { on_dismiss = callback; }
    /** Sets maximum popup dimensions. @param rows positive rows @param columns positive columns @throw ASSISTANCE-SIZE-ERROR if invalid */
    nothing setMaximumSize(int rows, int columns) {
        if (rows < 1 || columns < 1) { throw "ASSISTANCE-SIZE-ERROR", "Popup dimensions must be positive"; }
        maximum_rows = rows; maximum_cols = columns; markDirty();
    }
    /** Returns the literal completion filter. @return current filter */
    string getFilter() { return filter.getText(); }
    /** Sets completion filtering without changing source text. @param text literal query */
    nothing setFilter(string text) { filter.setText(NcursesUi::TextEditorWidget::normalizePaste(text)); refresh(); }
    /** Returns displayed result metadata. @return kind/id/label/documentation rows */
    list<hash<auto>> getResults() { refreshIfChanged(); return results.getItems(); }
    /** Returns the selected result metadata. @return kind/id/label/documentation, or NOTHING for an empty list */
    *hash<auto> getSelectedResult() { refreshIfChanged(); return results.getSelectedItem(); }
    /** Returns displayed documentation lines. @return selected help, including signature parameters */
    list<string> getDocumentation() { refreshIfChanged(); return doc_lines.getLines(); }
    /** Returns documentation scrolling. @return rows above the viewport */
    int getDocumentationScrollY() { return documentation.getScrollY(); }
    /** Positions and clamps the popup using the current editor caret.
        @param rows terminal rows @param columns terminal columns @return whether a visible anchor exists
    */
    bool positionAtCaret(int rows, int columns) {
        *hash<Ncurses::Position> anchor = editor.getCaretScreenPosition();
        if (!anchor || rows <= 0 || columns <= 0) { setVisible(False); return False; }
        setVisible(True); int height = min(maximum_rows, rows); int width = min(maximum_cols, columns);
        setHasBorder(height >= 3 && width >= 3);
        int y = anchor.y + 1; if (y + height > rows) { y = anchor.y - height; }
        hash<NcursesUi::Rect> rect = NcursesUi::Geometry::makeRect(max(0, min(y, rows - height)), max(0, min(anchor.x, columns - width)), height, width);
        if (rect != getFrame()) { resize(rect); } layout(); return True;
    }
    /** Reanchors after terminal resize. @param rows terminal rows @param columns terminal columns */
    nothing fitToScreen(int rows, int columns) { positionAtCaret(rows, columns); }
    /** Hiding invalidates pending assistance, preventing a late response reopening it. @param value visible state */
    nothing setVisible(bool value) { if (!value && isVisible()) { model.cancel(); } PanelWidget::setVisible(value); }
    /** Splits list/documentation vertically, keeping at least one list row in tiny windows. */
    nothing layout() {
        hash<NcursesUi::Rect> rect = contentRect(); int list_rows = rect.rows > 2 ? max(1, rect.rows / 2) : rect.rows;
        results.setFrameValues(rect.y, rect.x, list_rows, rect.cols);
        documentation.setFrameValues(rect.y + list_rows, rect.x, max(0, rect.rows - list_rows), rect.cols);
    }
    /** Includes model/editor revisions in invalidation. @return repaint required */
    bool needsOwnDraw() { return PanelWidget::needsOwnDraw() || observed_revision != model.getRevision(); }
    /** Includes child/model invalidation. @return repaint required */
    bool isDirty() { return needsOwnDraw() || PanelWidget::isDirty(); }
    /** Updates results before painting, preserving the selected stable identity. @param window output @param force exposed repaint */
    nothing drawTree(Ncurses::Window window, bool force = False) {
        if (!isVisible()) { PanelWidget::drawTree(window, force); return; }
        refreshIfChanged(); hash<Ncurses::Size> screen = getSession().screen().size(); positionAtCaret(screen.rows, screen.cols);
        PanelWidget::drawTree(window, force);
    }
    /** Acknowledges hidden/clipped result revisions. */
    nothing onDrawClipped() { refreshIfChanged(); PanelWidget::onDrawClipped(); observed_revision = model.getRevision(); }
    /** Activates the selected typed result; signature rows only display help. @return whether an edit/action/selection occurred */
    bool activateSelected() {
        refreshIfChanged(); *hash<auto> item = results.getSelectedItem(); if (!item || !isAvailable()) { return False; }
        bool accepted = False;
        if (item.kind == "completion") { accepted = model.applyCompletion(string(item.id)); }
        else if (item.kind == "diagnostic") { accepted = model.selectDiagnostic(string(item.id)); }
        else if (item.kind == "action") { accepted = model.activateAction(string(item.id)); }
        if (accepted) { dismiss(); } return accepted;
    }
    /** Cancels pending/results and invokes the application dismissal hook. */
    nothing dismiss() { model.cancel(); setVisible(False); if (on_dismiss) { on_dismiss(); } }
    /** Owns child mouse events so keyboard navigation follows the clicked pane. @return True */
    bool handlesChildMouseEvents() { return True; }
    /** Keeps the popup as the modal focus target. @param y row @param x column @return popup when hit */
    *NcursesUi::Widget mouseFocusTarget(int y, int x) { return hitTest(y, x) ? self : NOTHING; }
    /** Handles filtering, selection, documentation scrolling and dismissal. @param event input @return event result */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> event) {
        if (!isAvailable()) { return <NcursesUi::EventResult>{}; } refreshIfChanged();
        if (event.type == Ncurses::InputType::Char && event.ch == "\x1b") { dismiss(); return <NcursesUi::EventResult>{"handled": True, "action": "dismiss"}; }
        if (event.type == Ncurses::InputType::Char && event.ch == "\t") { docs_active = !docs_active; updateTitle(); markDirty(); return <NcursesUi::EventResult>{"handled": True}; }
        if ((event.type == Ncurses::InputType::Char && (event.ch == "\n" || event.ch == "\r")) || (event.type == Ncurses::InputType::Key && event.name == "KEY_ENTER")) {
            return <NcursesUi::EventResult>{"handled": True, "action": activateSelected() ? "accept" : NOTHING};
        }
        if (event.type == Ncurses::InputType::Mouse && event.mouse) {
            if (documentation.hitTest(event.mouse.y, event.mouse.x)) { docs_active = True; updateTitle(); markDirty(); return documentation.processEvent(event); }
            if (results.hitTest(event.mouse.y, event.mouse.x)) { docs_active = False; updateTitle(); markDirty(); return results.processEvent(event); }
            return <NcursesUi::EventResult>{};
        }
        if (docs_active && event.type == Ncurses::InputType::Key) { return documentation.processEvent(event); }
        if (event.type == Ncurses::InputType::Key && event.name != "KEY_BACKSPACE" && event.name != "KEY_DC") { return results.processEvent(event); }
        if (event.type == Ncurses::InputType::Paste) { filter.insertChar(NcursesUi::TextEditorWidget::normalizePaste(event.ch ?? "")); refresh(); return <NcursesUi::EventResult>{"handled": True}; }
        if (filter.processEvent(event)) { refresh(); return <NcursesUi::EventResult>{"handled": True}; }
        return <NcursesUi::EventResult>{};
    }
    private nothing refreshIfChanged() { if (observed_revision != model.getRevision()) { refresh(); } }
    private nothing refresh() {
        *hash<auto> before = results.getSelectedItem(); list<hash<auto>> rows = ();
        foreach hash<NcursesUi::CompletionItem> item in (model.getCompletions(filter.getText())) {
            rows += {"kind": "completion", "id": item.id, "label": item.label + (item.detail != "" ? " — " + item.detail : ""), "documentation": item.documentation};
        }
        *hash<NcursesUi::AssistanceResponse> response = model.getResponse();
        if (response) {
            foreach hash<NcursesUi::DiagnosticItem> item in (response.diagnostics) {
                rows += {"kind": "diagnostic", "id": item.id, "label": ("Error", "Warning", "Information", "Hint")[item.severity] + ": " + item.message,
                    "documentation": sprintf("Source characters %d–%d\n%s", item.range.start, item.range.end, item.documentation)};
            }
            foreach hash<NcursesUi::AssistanceAction> item in (response.actions) { rows += {"kind": "action", "id": item.id, "label": "Action: " + item.label, "documentation": item.documentation}; }
            if (response.signature) {
                hash<NcursesUi::SignatureHelp> signature = response.signature; string details = signature.label;
                if (signature.active_parameter >= 0) { details += "\nParameter: " + signature.parameters[signature.active_parameter]; }
                rows += {"kind": "signature", "id": "", "label": signature.label, "documentation": details + "\n" + signature.documentation};
            }
        }
        results.setItems(rows);
        if (before) { for (int i = 0; i < rows.size(); ++i) { if (rows[i].kind == before.kind && rows[i].id == before.id) { results.setSelectedIndex(i); break; } } }
        observed_revision = model.getRevision(); updateDocumentation(); markDirty();
    }
    private nothing updateDocumentation() {
        *hash<auto> item = results.getSelectedItem(); string text = item ? string(item.documentation) : (model.getError() ?? (model.isPending() ? "Loading assistance…" : "No assistance available"));
        doc_lines.setLines(split("\n", text, False, True)); documentation.setScrollY(0);
        updateTitle();
    }
    private nothing updateTitle() {
        setTitle((docs_active ? "Documentation" : "Assistance") + (filter.getText() != "" ? " — " + filter.getText() : "") + " [Tab: help, Esc: close]");
    }
}
} # namespace NcursesUi
