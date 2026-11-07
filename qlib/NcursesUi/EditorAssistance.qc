#! @file EditorAssistance.qc Owned editor assistance workflow
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
/** Connects a provider to an editor, owning popup placement, dismissal and focus restoration.
    Call request() from an application shortcut. Provider exceptions preserve the draft
    and close the popup. Call close() before disposing the application/editor.
    The provider runs on the UI thread; asynchronous providers can use getModel(),
    beginRequest()/complete() and show() instead.
*/
public class EditorAssistance {
    private {
        NcursesUi::Application app;
        NcursesUi::TextEditorWidget editor;
        NcursesUi::AssistanceModel model;
        *NcursesUi::AssistancePopupWidget popup;
    }
    /** Binds an editor. @param application owner @param input editor @param provider optional synchronous provider */
    constructor(NcursesUi::Application application, NcursesUi::TextEditorWidget input,
            *code<hash<NcursesUi::AssistanceResponse>(hash<NcursesUi::AssistanceRequest>)> provider) {
        app = application; editor = input; model = new NcursesUi::AssistanceModel(input.getBuffer()); model.setProvider(provider);
    }
    /** Returns the versioned assistance model. @return model */
    NcursesUi::AssistanceModel getModel() { return model; }
    /** Returns the current popup for inspection. @return popup or NOTHING */
    *NcursesUi::AssistancePopupWidget getPopup() { return popup; }
    /** Requests help, optionally applying a sole completion atomically.
        @param apply_single apply the only completion without opening a popup @return whether assistance was available */
    bool request(bool apply_single = False) {
        close(); on_error close();
        if (!model.request()) { return False; }
        list<hash<NcursesUi::CompletionItem>> items = model.getCompletions();
        if (apply_single && items.size() == 1) { return model.applyCompletion(items[0].id); }
        return show();
    }
    /** Shows accepted results at the caret, including explicit empty-result feedback. @return popup opened */
    bool show() {
        dismissPopup(); on_error close();
        *hash<NcursesUi::AssistanceResponse> response = model.getResponse();
        if (!response) { return False; }
        popup = new NcursesUi::AssistancePopupWidget(app.getSession(), editor, model);
        popup.setOnDismiss(sub () { close(); });
        hash<Ncurses::Size> size = app.getSession().screen().size();
        NcursesUi::AssistancePopupWidget candidate = popup;
        if (!candidate.positionAtCaret(size.rows, size.cols)) { close(); return False; }
        candidate.createPanel(); app.pushPopup(candidate); return True;
    }
    /** Cancels requests and releases the popup; reusable and idempotent. */
    nothing close() { on_exit model.cancel(); dismissPopup(); }
    private nothing dismissPopup() {
        *NcursesUi::AssistancePopupWidget old = popup; popup = NOTHING;
        if (!old) { return; }
        old.setOnDismiss(NOTHING); on_exit old.destroyPanel(); app.removeModal(old);
    }
}
}
