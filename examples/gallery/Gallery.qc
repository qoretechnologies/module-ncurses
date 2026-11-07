# Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
namespace NcursesGallery {
class Picker inherits NcursesUi::PanelWidget {
    public {
        NcursesUi::TextInputWidget query("Search: ");
        NcursesUi::ListWidget choices();
        NcursesUi::LabelWidget help("Type to search; Tab reaches results; Enter opens; Escape closes.");
    }
    constructor(Ncurses::Session session, code<nothing(string)> choose) : PanelWidget(session, "Widget stories") {
        addChild(query); addChild(choices); addChild(help);
        query.setOnChange(sub (string text) { filter(text); });
        query.setOnSubmit(sub (string text) {
            *hash<auto> item = choices.getSelectedItem(); if (item) { choose(string(item.id)); }
        });
        choices.setOnActivate(sub (hash<auto> item) { choose(string(item.id)); }); filter("");
    }
    nothing filter(string text) {
        list<hash<auto>> items = ();
        foreach hash<NcursesGallery::Story> story in (Registry::search(text)) { items += {"id": story.id, "label": story.id + " — " + story.purpose}; }
        choices.setItems(items);
        help.setText(items ? "Tab: results   Enter: open   Escape: close" : "No matches. Edit the search or press Escape.");
    }
    nothing layout() {
        hash<NcursesUi::Rect> rect = contentRect();
        query.setFrameValues(rect.y, rect.x, min(1, rect.rows), rect.cols);
        int footer = rect.rows >= 3 ? 1 : 0;
        choices.setFrameValues(rect.y + min(1, rect.rows), rect.x, max(0, rect.rows - 1 - footer), rect.cols);
        help.setFrameValues(rect.y + max(0, rect.rows - footer), rect.x, footer, rect.cols);
    }
    nothing disconnect() { query.setOnChange(NOTHING); query.setOnSubmit(NOTHING); choices.setOnActivate(NOTHING); destroyPanel(); }
}

class Gallery {
    private {
        NcursesUi::Application app;
        *NcursesGallery::Runner runner;
        *NcursesGallery::Picker picker;
        *NcursesUi::DialogWidget info;
        hash<Ncurses::Size> available;
        *hash<Ncurses::Size> overlay_size;
        int preset = 0;
        bool closed = False;
        *int cursor_tick;
    }
    constructor(NcursesUi::Application application, string id) {
        app = application; available = app.getSession().terminalSize();
        app.setReadTimeout(-1, 25);
        try {
            select(id);
            app.setGlobalKeyHandler(hash<NcursesUi::EventResult> sub (hash<Ncurses::InputEvent> event) { return handle(event); });
            cursor_tick = app.addOwnedTickCallback(sub () { runner.syncCursor(); });
        } catch (hash<ExceptionInfo> ex) { close(); rethrow; }
    }
    NcursesGallery::Runner current() { return runner; }
    *NcursesGallery::Picker navigation() { return picker; }
    private nothing observeGeometry() {
        hash<Ncurses::Size> size = app.getSession().terminalSize();
        if (size != available) { available = size; preset = 0; }
    }
    private hash<Ncurses::Size> storySize(string id) {
        hash<Ncurses::Size> size = Registry::find(id).geometry;
        return <Ncurses::Size>{"rows": min(size.rows, available.rows), "cols": min(size.cols, available.cols)};
    }
    nothing select(string id) {
        Registry::find(id); # Validate before replacing the current story.
        observeGeometry();
        closeOverlay();
        if (runner) { runner.close(); runner = NOTHING; }
        hash<Ncurses::Size> size = storySize(id);
        app.getSession().resize(size.rows, size.cols); preset = 0;
        runner = new NcursesGallery::Runner(app, id);
    }
    nothing reset() { observeGeometry(); closeOverlay(); runner.reset(storySize(runner.story().id)); preset = 0; }
    nothing closeOverlay() {
        on_exit {
            if (overlay_size) {
                hash<Ncurses::Size> size = overlay_size; overlay_size = NOTHING;
                if (app.getSession().isOpen()) {
                    app.getSession().resize(min(size.rows, available.rows), min(size.cols, available.cols));
                    app.processEvent(<Ncurses::InputEvent>{"type": Ncurses::InputType::Resize});
                }
            }
        }
        on_exit {
            if (picker) { on_exit picker = NOTHING; picker.disconnect(); }
        }
        on_exit {
            if (info) { on_exit info = NOTHING; info.setOnButton(NOTHING); info.setOnDismiss(NOTHING); info.destroyPanel(); }
        }
        if (picker || info) { app.popModal(); }
    }
    private nothing expandOverlay() {
        observeGeometry(); overlay_size = app.getSession().screen().size();
        app.getSession().resize(available.rows, available.cols);
        app.processEvent(<Ncurses::InputEvent>{"type": Ncurses::InputType::Resize});
    }
    nothing showNavigation() {
        closeOverlay(); expandOverlay(); on_error closeOverlay();
        picker = new NcursesGallery::Picker(app.getSession(), sub (string id) { select(id); });
        hash<Ncurses::Size> size = app.getSession().screen().size();
        picker.setBorderEdges(size.rows >= 5 && size.cols >= 12 ? NcursesUi::BorderEdges::Horizontal : NcursesUi::BorderEdges::None);
        picker.setFrameValues(0, 0, size.rows, size.cols); picker.layout(); picker.createPanel(); app.pushModal(picker);
        app.getFocusManager().setFocus(picker.query); app.drawAll();
    }
    nothing showHelp(bool inspect = False, *string notice) {
        closeOverlay(); hash<auto> state = runner.capture();
        expandOverlay(); on_error closeOverlay();
        string message = runner.story().purpose + "\n\n" + runner.story().keyboard + "\n" + runner.story().mouse
            + "\n\nF1 Help | F2 Search | F3 Reset | F4 Size | F5 Next step | F6 Inspect | Ctrl+Q Quit";
        if (inspect) {
            message = sprintf("Story: %s\nFocus: %s\nModal: %y\nScroll: %y\nSelection: %y\nCursor: row %d, col %d, visibility %d\nFrame: %dx%d\nCheckpoint: %d/%d",
                runner.story().id, state.state.focus, state.state.modal, state.state.scroll, state.state.selected,
                state.frame.cursor.y, state.frame.cursor.x, state.frame.cursor.visibility, state.frame.rows, state.frame.cols,
                runner.checkpointIndex() + 1, runner.story().steps.size());
        }
        if (notice) { message = notice + "\n\n" + message; }
        info = new NcursesUi::DialogWidget(app.getSession(), inspect ? "Story inspection" : "Gallery help", message, ("Close",));
        info.setOnButton(sub (int index, string label) { closeOverlay(); });
        info.setOnDismiss(sub () { closeOverlay(); });
        hash<Ncurses::Size> size = app.getSession().screen().size();
        info.fitToScreen(size.rows, size.cols); info.createPanel(); app.pushModal(info); app.drawAll();
    }
    nothing cycleSize() {
        observeGeometry(); closeOverlay(); preset = (preset + 1) % 3;
        int rows = preset == 1 ? min(available.rows, 10) : preset == 2 ? min(available.rows, 4) : available.rows;
        int cols = preset == 1 ? min(available.cols, 40) : preset == 2 ? min(available.cols, 12) : available.cols;
        app.getSession().resize(rows, cols); app.processEvent(<Ncurses::InputEvent>{"type": Ncurses::InputType::Resize}); app.drawAll();
    }
    private hash<NcursesUi::EventResult> handle(hash<Ncurses::InputEvent> event) {
        observeGeometry();
        if (event.type == Ncurses::InputType::Char && event.ch == "\x11") { app.quit(); }
        else if (event.type == Ncurses::InputType::Char && event.ch == "\e" && (picker || info)) { closeOverlay(); }
        else if (event.type == Ncurses::InputType::Key) {
            switch (event.name) {
                case "KEY_F(1)": showHelp(); break;
                case "KEY_F(2)": showNavigation(); break;
                case "KEY_F(3)": reset(); break;
                case "KEY_F(4)": cycleSize(); break;
                case "KEY_F(5)":
                    closeOverlay(); if (runner.checkpointIndex() + 1 < runner.story().steps.size()) {
                        try { runner.step(); }
                        catch (hash<ExceptionInfo> ex) {
                            if (ex.err != "GALLERY-EXPECTATION-ERROR") { rethrow; }
                            showHelp(False, "The current state differs from the scripted scenario. Press F3 to reset, then F5 to replay.");
                        }
                    }
                    else { showHelp(True); }
                    break;
                case "KEY_F(6)": showHelp(True); break;
                default: return <NcursesUi::EventResult>{};
            }
        } else { return <NcursesUi::EventResult>{}; }
        return <NcursesUi::EventResult>{"handled": True};
    }
    nothing close() {
        if (closed) { return; } closed = True;
        on_exit app.setGlobalKeyHandler(NOTHING);
        on_exit { if (exists cursor_tick) { app.removeTickCallback(cursor_tick); cursor_tick = NOTHING; } }
        on_exit { if (runner) { runner.close(); runner = NOTHING; } }
        closeOverlay();
    }
}
} # namespace NcursesGallery
