# Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
namespace NcursesGallery {
# Syntax comes from Qore's tree-sitter grammar; completion and hints use the same
# reflection-backed service as qrepl. Drafts are never evaluated and history is disabled.
class CodeSupport {
    private { astparser::AstParser parser(); QoreRepl::QoreRepl repl({"history_file": NOTHING}); }
    string highlight(string source) {
        *astparser::AstTree tree = parser.parseString(source);
        if (!tree) { return source; }
        string result; int offset = 0;
        foreach hash<astparser::AstHighlight> span in (tree.getHighlights()) {
            if (span.start < offset || span.end > source.length()) { throw "GALLERY-SYNTAX-ERROR", "Invalid parser highlight range"; }
            result += source.substr(offset, span.start - offset);
            string kind = span.capture.split(".")[0]; string style;
            switch (kind) {
                case "keyword": style = "1;35"; break;
                case "type": style = "1;36"; break;
                case "string": style = "32"; break;
                case "number": case "boolean": case "constant": style = "33"; break;
                case "comment": style = "2;37"; break;
                case "function": style = "1;34"; break;
                default: style = "0";
            }
            result += "\e[" + style + "m" + source.substr(span.start, span.end - span.start) + "\e[0m"; offset = span.end;
        }
        return result + source.substr(offset);
    }
    string hint(string source) { return repl.getHints(source) ?? ""; }
    hash<NcursesUi::AssistanceResponse> complete(hash<NcursesUi::AssistanceRequest> request) {
        string prefix = request.text.substr(0, request.cursor); int start = request.cursor;
        while (start > 0 && prefix.substr(start - 1, 1) =~ /[A-Za-z_0-9]/) { --start; }
        list<hash<NcursesUi::CompletionItem>> items = ();
        foreach hash<QoreCodeCompletion::CompletionItem> item in (repl.getCompletionDetails(prefix)) {
            string insertion = item.label;
            if (item.isCallable) { insertion += item.noArgsOnly ? "()" : "("; }
            else if (item.kind == "namespace") { insertion += "::"; }
            items += <NcursesUi::CompletionItem>{"id": item.label, "label": item.label, "text": insertion,
                "range": <NcursesUi::SourceRange>{"start": start, "end": request.cursor},
                "detail": item.detail ?? "", "documentation": item.detail ?? ""};
        }
        string signature = hint(prefix);
        return <NcursesUi::AssistanceResponse>{"completions": items,
            "signature": signature == "" ? NOTHING : <NcursesUi::SignatureHelp>{"label": signature}};
    }
}
class CodePreview inherits NcursesUi::Widget {
    private {
        NcursesUi::Application app;
        NcursesUi::TextEditorWidget editor;
        NcursesUi::LabelWidget status();
        NcursesGallery::CodeSupport support();
        NcursesUi::AssistanceModel model;
        *NcursesUi::AssistancePopupWidget popup;
        int revision = -1;
        int cursor = -1;
    }
    constructor(NcursesUi::Application application, NcursesUi::TextEditorWidget control) {
        app = application; editor = control; model = new NcursesUi::AssistanceModel(editor.getBuffer());
        editor.setEnterSubmits(False); editor.setHighlighter(string sub (string source) { return support.highlight(source); });
        addChild(editor); addChild(status);
    }
    nothing layout() {
        hash<NcursesUi::Rect> rect = contentRect(); int footer = rect.rows >= 3 ? 2 : 0;
        editor.setFrameValues(rect.y, rect.x, max(0, rect.rows - footer), rect.cols);
        status.setFrameValues(rect.y + rect.rows - footer, rect.x, footer, rect.cols);
    }
    bool needsOwnDraw() { return revision != editor.getBuffer().getRevision() || cursor != editor.getBuffer().getCursor() || Widget::needsOwnDraw(); }
    nothing draw(Ncurses::Window window) {
        string hint = support.hint(editor.getText().substr(0, editor.getBuffer().getCursor()));
        status.setText("\e[1;36mF8 Complete | Enter Newline | Ctrl-Z Undo\e[0m\n" + (hint == "" ? "Edit code; completions use qrepl's symbol service." : "\e[33m" + hint + "\e[0m"));
        revision = editor.getBuffer().getRevision(); cursor = editor.getBuffer().getCursor();
    }
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> event) {
        if (event.type == Ncurses::InputType::Key && event.name == "KEY_F(8)") {
            request(); return <NcursesUi::EventResult>{"handled": True};
        }
        return <NcursesUi::EventResult>{};
    }
    nothing request() {
        closePopup(); hash<NcursesUi::AssistanceRequest> request = model.beginRequest();
        on_error { closePopup(); model.cancel(); }
        model.complete(request, support.complete(request));
        popup = new NcursesUi::AssistancePopupWidget(app.getSession(), editor, model);
        popup.setOnDismiss(sub () { closePopup(); });
        hash<Ncurses::Size> size = app.getSession().screen().size();
        if (popup.positionAtCaret(size.rows, size.cols)) { popup.createPanel(); app.pushPopup(popup); }
        else { closePopup(); }
    }
    private nothing closePopup() {
        *NcursesUi::AssistancePopupWidget old = popup; popup = NOTHING;
        on_exit model.cancel();
        if (!old) { return; }
        old.setOnDismiss(NOTHING);
        on_exit old.destroyPanel();
        if (app.getDispatcher().topModal() == old) { app.popModal(); }
    }
    nothing close() { on_exit editor.setHighlighter(NOTHING); closePopup(); }
}
} # namespace NcursesGallery
