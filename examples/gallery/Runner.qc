# Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
namespace NcursesGallery {
# One runner owns all state for one story. Reset uses the same fixture factory.
class Runner {
    private {
        NcursesUi::Application app;
        hash<NcursesGallery::Story> definition;
        *NcursesUi::Widget widget;
        *NcursesUi::TextEditorWidget editor;
        *NcursesUi::TableWidget table;
        *NcursesUi::CompletionPopupWidget popup;
        *NcursesGallery::Fixture fixture;
        *NcursesGallery::CodePreview code_preview;
        bool closed = False;
        int checkpoint_index = -1;
        hash<Ncurses::Size> initial_size;
    }
    constructor(NcursesUi::Application application, string id) {
        app = application; definition = Registry::find(id);
        initial_size = app.getSession().screen().size();
        try { reset(); } catch (hash<ExceptionInfo> ex) { close(); rethrow; }
    }
    hash<NcursesGallery::Story> story() { return definition; }
    NcursesUi::Application application() { return app; }
    *NcursesUi::Widget control() { return widget; }
    int checkpointIndex() { return checkpoint_index; }
    private nothing checkOpen() { if (closed) { throw "GALLERY-CLOSED-ERROR", "The story has been closed"; } }
    private nothing release() {
        on_exit { popup = NOTHING; fixture = NOTHING; code_preview = NOTHING; table = NOTHING; editor = NOTHING; widget = NOTHING; }
        on_exit {
            if (app.getSession().isOpen()) {
                app.setRoot(new NcursesUi::Widget());
                app.getSession().screen().erase(); app.getSession().flushInput();
            }
        }
        on_exit {
            on_exit { if (popup) { popup.setOnSelect(NOTHING); popup.setOnDismiss(NOTHING); popup.destroyPanel(); } }
            if (fixture) { fixture.close(); }
            if (code_preview) { code_preview.close(); }
        }
        while (app.getDispatcher().hasModal()) { app.popModal(); }
    }
    nothing close() { if (closed) { return; } closed = True; release(); }
    nothing reset(*hash<Ncurses::Size> reset_size) {
        checkOpen(); on_error close(); release(); checkpoint_index = -1;
        if (reset_size) { initial_size = reset_size; }
        app.getSession().resize(initial_size.rows, initial_size.cols);
        app.getSession().setCursor(1);
        if (definition.catalog) {
            fixture = new NcursesGallery::Fixture(app, definition); widget = fixture.control(); syncCursor(); return;
        }
        switch (definition.widget) {
            case "TextEditorWidget":
            case "CompletionPopupWidget":
                editor = new NcursesUi::TextEditorWidget(); editor.setShowScrollbar(False);
                editor.setText(string(definition.fixture.text)); widget = editor;
                break;
            case "TableWidget":
                table = new NcursesUi::TableWidget(); table.setColumns(definition.fixture.columns);
                table.setRowKey("id"); table.setRows(definition.fixture.rows); widget = table;
                app.getSession().setCursor(0);
                break;
            default: throw "GALLERY-STORY-ERROR", "No fixture factory for " + definition.widget;
        }
        if (definition.id == "text-editor.code") {
            code_preview = new NcursesGallery::CodePreview(app, editor); app.setRoot(code_preview);
        } else { app.setRoot(widget); }
        app.getFocusManager().setFocus(widget);
        if (definition.widget == "CompletionPopupWidget") {
            popup = new NcursesUi::CompletionPopupWidget(app.getSession(), definition.state == "empty" ? () : definition.fixture.items);
            popup.setOnDismiss(sub () { dismiss(); });
            popup.setOnSelect(sub (hash<auto> item) { editor.getBuffer().insert(string(item.label)); dismiss(); });
            hash<Ncurses::Size> size = app.getSession().screen().size();
            popup.positionAt(1, 2, size.rows, size.cols); popup.createPanel(); app.pushPopup(popup);
        }
        if (definition.state == "empty") {
            if (editor) { editor.setText(""); }
            if (table) { table.setRows(()); }
        } else if (definition.state == "selected") {
            if (editor) { editor.getBuffer().select(0, 3); }
            if (table) { table.setSelectedRow(1); }
            if (popup) { app.processEvent(Registry::key("KEY_DOWN")); }
        } else if (definition.state == "disabled") { widget.setEnabled(False); }
        else if (definition.state == "unicode") {
            if (editor) { editor.setText("Unicode 界é " + strmul("long content ", 10)); editor.getBuffer().setCursor(0); }
        }
        app.drawAll();
        syncCursor();
    }
    # Nonmodal cursor policy belongs to the application. Reconcile it after
    # focus/state transitions; modal cursor saving/restoration remains Application's.
    nothing syncCursor() {
        checkOpen();
        if (!app.getDispatcher().hasModal()) {
            *NcursesUi::Widget focus = app.getFocusManager().getCurrentFocus();
            app.getSession().setCursor(focus && focus.wantsCursor() ? 1 : 0);
        }
    }
    private nothing dismiss() { app.popModal(); if (popup) { popup.destroyPanel(); } }
    hash<auto> inspect() {
        checkOpen();
        *NcursesUi::Widget focus = app.getFocusManager().getCurrentFocus();
        hash<auto> state = {"focus": focus ? focus.className() : "", "modal": app.getDispatcher().hasModal(), "enabled": widget.isEnabled()};
        if (fixture) { state += fixture.inspect(); }
        if (editor) { state.text = editor.getText(); state.scroll = editor.getScrollY(); state.empty = editor.getText() == ""; state.has_selection = editor.getBuffer().selectedText() != ""; }
        if (table) { state.selected = table.getSelectedRow(); state.scroll = table.getScrollOffset(); state.empty = !table.getRows(); state.has_selection = table.getSelectedRow() == 1; }
        if (popup && app.getDispatcher().hasModal()) { state.selected = popup.getHighlightIndex(); state.empty = !popup.getItems(); state.has_selection = popup.getHighlightIndex() == 1; }
        return state;
    }
    hash<auto> capture(string checkpoint = "interactive") {
        checkOpen(); app.drawAll(); syncCursor();
        return {"story": definition.id, "checkpoint": checkpoint, "state": inspect(), "frame": app.getSession().capture()};
    }
    hash<auto> step() {
        checkOpen();
        if (checkpoint_index + 1 >= definition.steps.size()) { throw "GALLERY-STEP-ERROR", "All story steps are complete"; }
        hash<NcursesGallery::Step> step = definition.steps[checkpoint_index + 1];
        if (step.size) {
            app.getSession().resize(step.size.rows, step.size.cols);
            app.processEvent(<Ncurses::InputEvent>{"type": Ncurses::InputType::Resize});
        }
        if (step.event) { app.processEvent(step.event); }
        if (step.action) {
            if (!fixture) { throw "GALLERY-ACTION-ERROR", "This story has no model action"; }
            fixture.perform(step.action);
        }
        hash<auto> artifact = capture(step.checkpoint);
        verify(artifact, step.expected); ++checkpoint_index; return artifact;
    }
    static nothing verify(hash<auto> artifact, hash<auto> expected) {
        foreach string key in (keys expected) {
            bool valid;
            if (key == "cursor") { valid = artifact.frame.cursor.visibility == expected{key}; }
            else if (key == "cursor_x") { valid = artifact.frame.cursor.x == expected{key}; }
            else if (key == "focus_nonempty") { valid = artifact.state.focus != ""; }
            else if (key == "scroll_min") { valid = artifact.state.scroll >= expected{key}; }
            else if (key == "visible_content") {
                string text; foreach hash<Ncurses::ScreenCell> cell in (artifact.frame.cells) { text += cell.text; }
                valid = trim(text) != "" || artifact.frame.cursor.visibility > 0;
            } else if (key == "contains") {
                string text; foreach hash<Ncurses::ScreenCell> cell in (artifact.frame.cells) { text += cell.text; }
                valid = text.find(expected{key}) >= 0;
            } else { valid = artifact.state{key} == expected{key}; }
            if (!valid) { throw "GALLERY-EXPECTATION-ERROR", sprintf("%s/%s: %s expected %y, state %y", artifact.story, artifact.checkpoint, key, expected{key}, artifact.state); }
        }
        if (artifact.frame.cursor.visibility > 0) {
            if (artifact.frame.cursor.y < 0 || artifact.frame.cursor.y >= artifact.frame.rows
                    || artifact.frame.cursor.x < 0 || artifact.frame.cursor.x >= artifact.frame.cols) {
                throw "GALLERY-EXPECTATION-ERROR", "Visible cursor is outside the captured frame";
            }
        }
    }
}
} # namespace NcursesGallery
