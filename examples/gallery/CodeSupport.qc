# Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
namespace NcursesGallery {
# Syntax comes from Qore's tree-sitter grammar; completion and hints use the same
# reflection-backed service as qrepl. Drafts are never evaluated and history is disabled.
class CodeSupport inherits NcursesQore::CodeSupport {
    constructor() : NcursesQore::CodeSupport(new QoreRepl::QoreRepl({"history_file": NOTHING})) {}
}
class CodePreview inherits NcursesUi::Widget {
    private {
        NcursesUi::Application app;
        NcursesUi::TextEditorWidget editor;
        NcursesUi::LabelWidget status();
        NcursesGallery::CodeSupport support();
        NcursesUi::EditorAssistance assistance;
        int revision = -1;
        int cursor = -1;
    }
    constructor(NcursesUi::Application application, NcursesUi::TextEditorWidget control) {
        app = application; editor = control;
        assistance = new NcursesUi::EditorAssistance(app, editor, hash<NcursesUi::AssistanceResponse> sub (hash<NcursesUi::AssistanceRequest> request) { return support.complete(request); });
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
    nothing request() { assistance.request(); }
    nothing close() { on_exit editor.setHighlighter(NOTHING); assistance.close(); }
}
} # namespace NcursesGallery
