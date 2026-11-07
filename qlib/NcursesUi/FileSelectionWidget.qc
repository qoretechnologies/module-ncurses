#! @file FileSelectionWidget.qc Keyboard-accessible single and multiple file selection
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
/** File selector with a stable highlighted identity, selection markers and status.
    Space toggles selection; Enter opens the selection, S saves and E exports through
    configured application callbacks. Escape cancels/dismisses through its callback.
    Single mode selects the highlighted file on Enter when the selection is empty.
    Multi mode requires explicit selection. Arrow/page/home/end and mouse navigation
    remain available after completion, with repeat operation dispatch guarded by the model.
*/
public class FileSelectionWidget inherits NcursesUi::Widget {
    private {
        NcursesUi::FileSelectionModel model;
        NcursesUi::ListWidget list_widget();
        NcursesUi::LabelWidget status();
        int observed_revision = -1;
        list<hash<auto>> displayed = ();
        *hash<NcursesUi::Rect> layout_view;
        *hash<NcursesUi::Rect> target_bounds;
        *code<nothing()> on_dismiss;
    }
    /** Binds a UI-thread-owned selection model. @param value model */
    constructor(NcursesUi::FileSelectionModel value) {
        model = value; setFocusable(True); list_widget.setFocusable(False); addChild(list_widget); addChild(status);
        list_widget.setRenderItem(string sub (hash<auto> item, int index, bool highlighted) {
            string name = item.name == "" ? item.path : item.name;
            string text = (model.isSelected(string(item.id)) ? "[x] " : "[ ] ") + name + " — " + item.path;
            if (exists item.size) { text += sprintf(" (%d bytes)", item.size); }
            if (exists item.error) { text += " [Unavailable: " + item.error + "]"; }
            return replace(NcursesUi::TextEditorWidget::normalizePaste(text), "\n", " ");
        });
        list_widget.setOnSelect(sub (int index) { updateStatus(); });
        list_widget.setOnActivate(sub (hash<auto> item) { activate(NcursesUi::FileOperation::Open); });
        sync();
    }
    /** Returns the bound model. @return shared selection model */
    NcursesUi::FileSelectionModel getModel() { return model; }
    /** Returns the highlighted entry, distinct from checked selections. @return entry or NOTHING */
    *hash<NcursesUi::FileSelectionEntry> getHighlighted() { sync(); *hash<auto> item = list_widget.getSelectedItem(); return item ? model.getFile(string(item.id)) : NOTHING; }
    /** Highlights a visible entry. @param id stable identity @throw FILE-SELECTION-ID if filtered/absent */
    nothing highlight(string id) {
        sync(); list<string> ids = model.getVisibleIds(); for (int i = 0; i < ids.size(); ++i) { if (ids[i] == id) { list_widget.setSelectedIndex(i); updateStatus(); return; } }
        throw "FILE-SELECTION-ID", "File is not visible: " + id;
    }
    /** Returns current status text. @return selection count, operation state and errors */
    string getStatusText() { sync(); return status.getText(); }
    /** Sets explicit popup/dialog dismissal. @param callback application-owned cancellation */
    nothing setOnDismiss(*code<nothing()> callback) { on_dismiss = callback; }
    /** Dispatches a configured operation. @param operation FileOperation @return completed */
    bool activate(int operation) {
        if (!isAvailable() || !model.hasHandler(operation)) { return False; } sync();
        if (model.getState() == NcursesUi::ActionState::Running || model.getState() == NcursesUi::ActionState::Completed) { return False; }
        if (!model.isMultiple() && !model.getSelected()) { *hash<NcursesUi::FileSelectionEntry> file = getHighlighted(); if (file) { model.toggle(file.id); } }
        on_exit { sync(); markDirty(); } return model.dispatch(operation);
    }
    /** Includes model updates in invalidation. @return dirty */
    bool needsOwnDraw() { return observed_revision != model.getRevision() || Widget::needsOwnDraw(); }
    /** Includes child invalidation. @return dirty */
    bool isDirty() { return needsOwnDraw() || Widget::isDirty(); }
    /** Arranges against ancestor and actual target-window bounds before painting.
        @param window target @param force repaint exposed pixels */
    nothing drawTree(Ncurses::Window window, bool force = False) {
        hash<Ncurses::Position> origin = window.position(); hash<Ncurses::Size> size = window.size();
        target_bounds = NcursesUi::Geometry::makeRect(origin.y, origin.x, size.rows, size.cols); sync(); layout(); Widget::drawTree(window, force);
    }
    /** Reconciles model changes while hidden/clipped. */
    nothing onDrawClipped() { sync(); Widget::onDrawClipped(); }
    /** Invalidates previous target bounds when moved/resized. @param rect screen allocation */
    nothing setFrame(hash<NcursesUi::Rect> rect) { if (rect != getFrame()) { target_bounds = NOTHING; } Widget::setFrame(rect); layout(); }
    /** Moves and invalidates previous target bounds. @param dy row change @param dx column change */
    nothing translate(int dy, int dx) { target_bounds = NOTHING; Widget::translate(dy, dx); layout(); }
    /** Allocates a list and wrapped summary; the summary remains visible on a one-row terminal. */
    nothing layout() {
        hash<NcursesUi::Rect> view = NcursesUi::Geometry::intersect(contentRect(), visibleRect());
        if (target_bounds) { view = NcursesUi::Geometry::intersect(view, target_bounds); }
        if (layout_view == view) { return; } layout_view = view;
        int summary_rows = min(view.rows, max(1, min(3, view.rows / 3))); int list_rows = max(0, view.rows - summary_rows);
        list_widget.setFrameValues(view.y, view.x, list_rows, view.cols); status.setFrameValues(view.y + list_rows, view.x, summary_rows, view.cols); markDirty();
    }
    /** Owns pointer dispatch to preserve selection semantics. @return True */
    bool handlesChildMouseEvents() { return True; }
    /** Keeps composite focus on this widget. @param y screen row @param x screen column @return focus target */
    *NcursesUi::Widget mouseFocusTarget(int y, int x) { return hitTest(y, x) ? self : NOTHING; }
    /** Handles selection, application actions and read-only list navigation. @param event input @return result */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> event) {
        if (!isAvailable()) { return <NcursesUi::EventResult>{}; } sync();
        if (event.type == Ncurses::InputType::Char && event.ch == "\x1b") { if (on_dismiss) { on_dismiss(); } return <NcursesUi::EventResult>{"handled": True, "action": "cancel"}; }
        bool editable = model.getState() != NcursesUi::ActionState::Running && model.getState() != NcursesUi::ActionState::Completed;
        if (event.type == Ncurses::InputType::Char && event.ch == " ") {
            *hash<NcursesUi::FileSelectionEntry> file = getHighlighted(); if (editable && file) { model.toggle(file.id); sync(); } return <NcursesUi::EventResult>{"handled": True};
        }
        if ((event.type == Ncurses::InputType::Key && event.name == "KEY_ENTER") || (event.type == Ncurses::InputType::Char && (event.ch == "\n" || event.ch == "\r"))) {
            return <NcursesUi::EventResult>{"handled": True, "action": activate(NcursesUi::FileOperation::Open) ? "open" : NOTHING};
        }
        if (event.type == Ncurses::InputType::Char && (event.ch == "s" || event.ch == "S" || event.ch == "e" || event.ch == "E")) {
            bool save = event.ch == "s" || event.ch == "S"; return <NcursesUi::EventResult>{"handled": True, "action": activate(save ? NcursesUi::FileOperation::Save : NcursesUi::FileOperation::Export) ? (save ? "save" : "export") : NOTHING};
        }
        hash<NcursesUi::EventResult> result = list_widget.processEvent(event);
        if (editable && model.getState() != NcursesUi::ActionState::Running && model.getState() != NcursesUi::ActionState::Completed && event.type == Ncurses::InputType::Mouse && event.mouse && (event.mouse.button_state & (Ncurses::BUTTON1_CLICKED | Ncurses::BUTTON1_PRESSED))
                && list_widget.hitTest(event.mouse.y, event.mouse.x) && event.mouse.x < list_widget.getFrame().x + 3) {
            *hash<NcursesUi::FileSelectionEntry> file = getHighlighted(); if (file) { model.toggle(file.id); sync(); }
        }
        updateStatus(); return result;
    }
    private nothing sync() {
        if (observed_revision == model.getRevision()) { return; }
        *hash<auto> before = list_widget.getSelectedItem(); list<hash<auto>> rows = ();
        foreach string id in (model.getVisibleIds()) { hash<auto> row = model.getFile(id); rows += row; }
        if (rows != displayed) {
            list_widget.setItems(rows); displayed = rows;
            if (before) { for (int i = 0; i < rows.size(); ++i) { if (rows[i].id == before.id) { list_widget.setSelectedIndex(i); break; } } }
        } else { list_widget.markDirty(); }
        observed_revision = model.getRevision(); updateStatus(); markDirty();
    }
    private nothing updateStatus() {
        *hash<auto> item = list_widget.getSelectedItem();
        string text = (item ? string(item.name) + " — " : "No files — ") + model.getSummary();
        if (item && exists item.error) { text += "\nUnavailable: " + item.error; }
        if (exists model.getError()) { text += "\nError: " + model.getError(); }
        else if (model.getState() == NcursesUi::ActionState::Completed) { text += "\nCompleted"; }
        else if (model.getState() == NcursesUi::ActionState::Cancelled) { text += "\nCancelled; selection retained"; }
        else { text += "\nSpace: select" + (model.hasHandler(NcursesUi::FileOperation::Open) ? "  Enter: open" : "") + (model.hasHandler(NcursesUi::FileOperation::Save) ? "  S: save" : "") + (model.hasHandler(NcursesUi::FileOperation::Export) ? "  E: export" : ""); }
        status.setText(NcursesUi::TextEditorWidget::normalizePaste(text));
    }
}
} # namespace NcursesUi
