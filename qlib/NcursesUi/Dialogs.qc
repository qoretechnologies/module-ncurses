#! @file Dialogs.qc Owned confirmation, prompt and file-selection workflows
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
/** @internal Scrollable help document owned by Dialogs. */
class TextPanel inherits NcursesUi::PanelWidget {
    private { NcursesUi::TranscriptWidget viewer(); *code<nothing()> on_dismiss; }
    constructor(NcursesUi::Application app, string title, string text) : PanelWidget(app.getSession(), title) {
        viewer.appendBlock(NcursesUi::TerminalText::styledLines(text), "help");
        viewer.setFollowTail(False); viewer.setScrollY(0); viewer.setWordWrap(True); addChild(viewer);
    }
    nothing setOnDismiss(*code<nothing()> callback) { on_dismiss = callback; }
    nothing layout() { viewer.setFrame(contentRect()); viewer.layout(); }
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> event) {
        if (event.type == Ncurses::InputType::Char && event.ch == "\x1b") {
            if (on_dismiss) { on_dismiss(); } return <NcursesUi::EventResult>{"handled": True};
        }
        return viewer.processEvent(event);
    }
}
/** @internal Form composition used by Dialogs; field focus/validation are provided by FormWidget. */
class PromptPanel inherits NcursesUi::PanelWidget {
    private { NcursesUi::FormWidget form; }
    constructor(NcursesUi::Application app, string title, hash<NcursesUi::FormField> field)
            : PanelWidget(app.getSession(), title) {
        form = new NcursesUi::FormWidget(new NcursesUi::FormModel((field,)));
        form.setFocusManager(app.getFocusManager()); addChild(form);
    }
    NcursesUi::FormWidget getForm() { return form; }
    nothing layout() { form.setFrame(contentRect()); form.layout(); }
    nothing fitToScreen(int rows, int cols) {
        setHasBorder(rows >= 6 && cols >= 20); PanelWidget::fitToScreen(rows, cols);
    }
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> event) {
        if (event.type == Ncurses::InputType::Char && event.ch == "\x1b") { form.cancel(); return <NcursesUi::EventResult>{"handled": True}; }
        return <NcursesUi::EventResult>{};
    }
}
/** Reusable modal workflows owning panel cleanup and restoration of previous focus.
    Application callbacks define acceptance semantics; cancel never calls them.
    Call close() when the application is disposed. Individual panels can be dismissed
    explicitly. Prompt validation is field-local and leaves the entered value intact.
*/
public class Dialogs {
    private { NcursesUi::Application app; list<NcursesUi::PanelWidget> panels = (); }
    /** Binds an application. @param application UI owner */
    constructor(NcursesUi::Application application) { app = application; }
    /** Opens a scrollable document at the beginning. Escape closes; navigation keys scroll.
        @param title heading @param text document @return owned panel */
    NcursesUi::PanelWidget text(string title, string text) {
        NcursesUi::TextPanel panel(app, title + " — Esc: close", text);
        panel.setOnDismiss(sub () { dismiss(panel); }); panel.setCenteredSize(24, 88); show(panel); return panel;
    }
    /** Offers several actions, allowing an asynchronous workflow to retain its dialog.
        @param title heading @param message explanation @param actions button labels
        @param choose returns true to dismiss after handling an action
        @param cancel runs on Escape @return owned dialog, also dismissible on an external event
        @throw DIALOG-ACTIONS-ERROR if no actions are supplied
    */
    NcursesUi::DialogWidget choose(string title, string message, list<string> actions,
            code<bool(int)> choose, code<nothing()> cancel) {
        if (!actions) { throw "DIALOG-ACTIONS-ERROR", "At least one action is required"; }
        NcursesUi::DialogWidget panel(app.getSession(), title, message, actions);
        panel.setOnButton(sub (int index, string label) { if (choose(index)) { dismiss(panel); } });
        panel.setOnDismiss(sub () { dismiss(panel); cancel(); });
        hash<Ncurses::Size> screen = app.getSession().screen().size(); panel.centerOn(screen.rows, screen.cols);
        show(panel); return panel;
    }
    /** Shows information with a single Close action. @param title heading @param message body @return dialog */
    NcursesUi::DialogWidget message(string title, string message) {
        NcursesUi::DialogWidget panel(app.getSession(), title, message, ("Close",));
        panel.setOnButton(sub (int index, string label) { dismiss(panel); });
        panel.setOnDismiss(sub () { dismiss(panel); });
        hash<Ncurses::Size> screen = app.getSession().screen().size(); panel.centerOn(screen.rows, screen.cols);
        show(panel); return panel;
    }
    /** Asks for an explicit action with a Cancel alternative.
        @param title heading @param message explanation @param accept action callback
        @param action affirmative button label @return dialog */
    NcursesUi::DialogWidget confirm(string title, string message, code<nothing()> accept, string action = "Continue") {
        NcursesUi::DialogWidget panel(app.getSession(), title, message, (action, "Cancel"));
        panel.setOnButton(sub (int index, string label) { dismiss(panel); if (!index) { accept(); } });
        panel.setOnDismiss(sub () { dismiss(panel); });
        hash<Ncurses::Size> screen = app.getSession().screen().size(); panel.centerOn(screen.rows, screen.cols);
        show(panel); return panel;
    }
    /** Prompts for a typed field using the shared form's labels, help and validation.
        @param title heading @param field field schema including default/validation
        @param accept receives the typed field value @param action affirmative label @return panel
        @note Acceptance closes the prompt before calling application code; exceptions propagate. */
    NcursesUi::PanelWidget prompt(string title, hash<NcursesUi::FormField> field, code<nothing(auto)> accept,
            string action = "Continue") {
        NcursesUi::PromptPanel panel(app, title, field);
        panel.getForm().setActionLabels(action, "Cancel");
        panel.getForm().setOnSubmit(auto sub (hash<auto> values) { dismiss(panel); accept(values{field.name}); return NOTHING; });
        panel.getForm().setOnCancel(sub () { dismiss(panel); });
        panel.setCenteredSize(10, 64); show(panel); return panel;
    }
    /** Browses existing files; application decides what opening means.
        @param directory initial location @param accept receives selected path @return browser */
    NcursesUi::FileBrowserWidget openFile(string directory, code<nothing(string)> accept) {
        NcursesUi::FileBrowserWidget panel(app.getSession(), directory);
        code<nothing(hash<auto>)> selected = sub (hash<auto> item) { dismiss(panel); accept(string(item.path)); };
        panel.setOnLoad(selected); panel.setOnFileActivate(selected);
        panel.setOnDismiss(sub () { dismiss(panel); }); panel.setClosable(True);
        panel.setCenteredSize(24, 96); show(panel); return panel;
    }
    /** Removes a panel owned by this controller; safe after earlier dismissal.
        @param panel workflow panel */
    nothing dismiss(NcursesUi::PanelWidget panel) {
        int position = -1;
        for (int i = 0; i < panels.size(); ++i) { if (panels[i] == panel) { position = i; break; } }
        if (position < 0) { return; }
        splice panels, position, 1; detachCallbacks(panel);
        on_exit panel.destroyPanel(); app.removeModal(panel);
    }
    /** Disposes all owned workflows, including nested confirmations. */
    nothing close() {
        *hash<ExceptionInfo> failure;
        while (panels) {
            try { dismiss(panels[-1]); } catch (hash<ExceptionInfo> ex) { if (!failure) { failure = ex; } }
        }
        if (failure) { throw failure.err, failure.desc, failure.arg; }
    }
    private nothing show(NcursesUi::PanelWidget panel) {
        panels += panel; on_error dismiss(panel); panel.createPanel(); app.pushModal(panel);
    }
    private static nothing detachCallbacks(NcursesUi::PanelWidget panel) {
        if (panel instanceof NcursesUi::DialogWidget) {
            NcursesUi::DialogWidget dialog = cast<NcursesUi::DialogWidget>(panel); dialog.setOnButton(NOTHING); dialog.setOnDismiss(NOTHING);
        } else if (panel instanceof NcursesUi::FileBrowserWidget) {
            NcursesUi::FileBrowserWidget browser = cast<NcursesUi::FileBrowserWidget>(panel);
            browser.setOnLoad(NOTHING); browser.setOnFileActivate(NOTHING); browser.setOnDismiss(NOTHING);
        } else if (panel instanceof NcursesUi::PromptPanel) {
            NcursesUi::FormWidget form = cast<NcursesUi::PromptPanel>(panel).getForm(); form.setOnSubmit(NOTHING); form.setOnCancel(NOTHING);
        } else if (panel instanceof NcursesUi::TextPanel) {
            cast<NcursesUi::TextPanel>(panel).setOnDismiss(NOTHING);
        }
    }
}
}
