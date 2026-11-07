# Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
# Included by the native gallery, catalog generator and headless tests.
namespace NcursesGallery {
hashdecl Step {
    string checkpoint;
    string instruction;
    *hash<Ncurses::InputEvent> event;
    *hash<Ncurses::Size> size;
    *string action;
    hash<auto> expected;
}
hashdecl Story {
    string id;
    string widget;
    string api;
    string api_url;
    string purpose;
    bool catalog = False;
    bool application = False;
    string state = "default";
    hash<auto> fixture;
    hash<Ncurses::Size> geometry;
    *hash<Ncurses::Size> review_size;
    string keyboard;
    string mouse;
    hash<string, string> states;
    list<hash<NcursesGallery::Step>> steps;
}

class Registry {
    # UI-thread tooling. Published definitions are immutable; callers get Qore COW values.
    private { static *list<hash<NcursesGallery::Story>> cached; }
    static hash<Ncurses::InputEvent> key(string name) {
        return <Ncurses::InputEvent>{"type": Ncurses::InputType::Key, "name": name};
    }
    static list<hash<NcursesGallery::Story>> stories() {
        if (exists cached) { return cached; }
        list<hash<auto>> rows = ();
        for (int i = 0; i < 24; ++i) { rows += {"id": i, "name": sprintf("Row %02d 界", i), "value": i * 3}; }
        list<hash<NcursesGallery::Story>> result = (
            <NcursesGallery::Story>{
                "id": "text-editor.boundaries", "widget": "TextEditorWidget",
                "api": "NcursesUi::TextEditorWidget", "purpose": "Edit at exact-width boundaries and retain the caret through resize.",
                "fixture": {"text": "abcdefghabcdefghabcdefghabcdefghabcdefgh", "scrollbar": False},
                "geometry": <Ncurses::Size>{"rows": 4, "cols": 8},
                "keyboard": "Arrows move by grapheme; Shift selects; Ctrl+Z undoes; paste inserts one edit.",
                "mouse": "Primary click places the caret; wheel scrolls.",
                "states": {"default": "initial", "empty": "reset with empty fixture", "focused": "initial",
                    "selected": "selection scenario", "disabled": "disabled scenario", "invalid": "limits reject edits atomically",
                    "loading": "N/A: synchronous editor", "unicode": "paste", "constrained": "shrink"},
                "steps": (
                    <NcursesGallery::Step>{"checkpoint": "initial", "instruction": "Inspect the caret after five exact-width lines.",
                        "expected": {"focus": "TextEditorWidget", "scroll_min": 1, "cursor": 1, "text": "abcdefghabcdefghabcdefghabcdefghabcdefgh"}},
                    <NcursesGallery::Step>{"checkpoint": "paste", "instruction": "Paste a wide glyph and combining character.",
                        "event": <Ncurses::InputEvent>{"type": Ncurses::InputType::Paste, "ch": "界é"},
                        "expected": {"focus": "TextEditorWidget", "text": "abcdefghabcdefghabcdefghabcdefghabcdefgh界é", "cursor": 1}},
                    <NcursesGallery::Step>{"checkpoint": "shrink", "instruction": "Shrink the viewport while editing.",
                        "size": <Ncurses::Size>{"rows": 2, "cols": 4},
                        "expected": {"focus": "TextEditorWidget", "scroll_min": 1, "cursor": 1}},
                    <NcursesGallery::Step>{"checkpoint": "undo", "instruction": "Undo the complete paste.",
                        "event": <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "\x1a"},
                        "expected": {"text": "abcdefghabcdefghabcdefghabcdefghabcdefgh", "cursor": 1}}
                )
            },
            <NcursesGallery::Story>{
                "id": "table.scrolling", "widget": "TableWidget", "api": "NcursesUi::TableWidget",
                "purpose": "Keep the last selected row visible through keyboard, mouse and resize.",
                "fixture": {"rows": rows, "columns": ({"key": "name", "header": "Name", "width": 18}, {"key": "value", "header": "Value", "width": 8})},
                "geometry": <Ncurses::Size>{"rows": 8, "cols": 32},
                "keyboard": "Arrows move cells; PageUp/PageDown scroll; Home/End select first/last; Enter activates.",
                "mouse": "Click selects; double-click activates; wheel moves one row.",
                "states": {"default": "initial", "empty": "empty scenario", "focused": "initial", "selected": "last",
                    "disabled": "disabled scenario", "invalid": "N/A: invalid data is rejected by setRows", "loading": "N/A: application owns loading",
                    "unicode": "initial", "constrained": "shrink"},
                "steps": (
                    <NcursesGallery::Step>{"checkpoint": "initial", "instruction": "Inspect the first row and column headers.",
                        "expected": {"focus": "TableWidget", "selected": 0, "scroll": 0}},
                    <NcursesGallery::Step>{"checkpoint": "last", "instruction": "Press End to reach the last row.", "event": key("KEY_END"),
                        "expected": {"selected": 23, "scroll_min": 1, "contains": "Row 23"}},
                    <NcursesGallery::Step>{"checkpoint": "shrink", "instruction": "Shrink; the selected row remains on screen.",
                        "size": <Ncurses::Size>{"rows": 3, "cols": 18}, "expected": {"selected": 23, "scroll_min": 20, "contains": "Row 23"}},
                    <NcursesGallery::Step>{"checkpoint": "first", "instruction": "Press Home to return to the first row.", "event": key("KEY_HOME"),
                        "expected": {"selected": 0, "scroll": 0, "contains": "Row 00"}}
                )
            },
            <NcursesGallery::Story>{
                "id": "completion-popup.overlap", "widget": "CompletionPopupWidget", "api": "NcursesUi::CompletionPopupWidget",
                "purpose": "Review an overlapping popup and restoration of the editor's focus, pixels and cursor.",
                "fixture": {"text": "draft 界é", "items": ({"label": "alpha", "kind": "function"}, {"label": "beta", "kind": "variable"})},
                "geometry": <Ncurses::Size>{"rows": 10, "cols": 32},
                "keyboard": "Up/Down select; Enter accepts; Escape dismisses and returns editor focus.",
                "mouse": "Click selects; an outside primary click dismisses and reaches the editor.",
                "states": {"default": "initial", "empty": "empty scenario", "focused": "initial", "selected": "next",
                    "disabled": "N/A: popup dismissal owns availability", "invalid": "N/A: no validation input",
                    "loading": "N/A: items are supplied synchronously", "unicode": "initial editor", "constrained": "constrained scenario"},
                "steps": (
                    <NcursesGallery::Step>{"checkpoint": "initial", "instruction": "Inspect the popup above the editor background.",
                        "expected": {"focus": "CompletionPopupWidget", "modal": True, "cursor": 0, "contains": "alpha"}},
                    <NcursesGallery::Step>{"checkpoint": "next", "instruction": "Move to the second completion.", "event": key("KEY_DOWN"),
                        "expected": {"selected": 1, "modal": True}},
                    <NcursesGallery::Step>{"checkpoint": "dismiss", "instruction": "Press Escape; return to the unchanged draft.",
                        "event": <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "\e"},
                        "expected": {"focus": "TextEditorWidget", "modal": False, "cursor": 1, "text": "draft 界é"}}
                )
            }
        );
        result = Variants::expand(result + Catalog::stories());
        result += Catalog::scenarios(result);
        result += Catalog::mouseScenarios(result);
        result += <NcursesGallery::Story>{"id": "text-editor.code", "widget": "TextEditorWidget",
            "api": "NcursesUi::TextEditorWidget", "state": "scenario", "purpose": "Edit syntax-highlighted Qore code with qrepl completion and signature help. Drafts are not executed.",
            "fixture": {"text": "# Complete the function name with F8\nint answer = 42;\npri"}, "geometry": <Ncurses::Size>{"rows": 12, "cols": 64},
            "keyboard": "F8 opens completions; arrows select; Enter accepts; Escape dismisses. Enter in the editor inserts a newline; Ctrl-Z undoes.",
            "mouse": "Click to place the caret; click completion entries and double-click to accept.", "states": result[0].states,
            "steps": (
                <NcursesGallery::Step>{"checkpoint": "editing", "instruction": "Inspect highlighted comments, types and numbers.", "expected": {"focus": "TextEditorWidget", "contains": "int answer = 42"}},
                <NcursesGallery::Step>{"checkpoint": "completions", "instruction": "F8 requests qrepl symbol completions for pri.", "event": key("KEY_F(8)"), "expected": {"modal": True, "contains": "printf"}},
                <NcursesGallery::Step>{"checkpoint": "select", "instruction": "Select printf.", "event": key("KEY_DOWN"), "expected": {"modal": True}},
                <NcursesGallery::Step>{"checkpoint": "accept", "instruction": "Enter inserts the completion and displays signature help.", "event": key("KEY_ENTER"), "expected": {"modal": False, "focus": "TextEditorWidget", "contains": "printf("}},
                <NcursesGallery::Step>{"checkpoint": "undo", "instruction": "Undo restores the incomplete function name as one edit.", "event": <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "\x1a"}, "expected": {"text": "# Complete the function name with F8\nint answer = 42;\npri"}}
            )};
        hash<string, string> app_states = {"default": "qrepl.default", "empty": "qrepl.default", "focused": "qrepl.default",
            "selected": "qrepl.completion", "disabled": "N/A: the application remains interactive during evaluation",
            "invalid": "qrepl.error", "loading": "N/A: deterministic worker-gate integration tests cover in-flight execution",
            "unicode": "qrepl.default", "constrained": "qrepl.constrained"};
        foreach string scenario in (("default", "completion", "error", "constrained", "files")) {
            list<hash<NcursesGallery::Step>> steps = ();
            string draft = scenario == "completion" ? "pri" : scenario == "error" ? "missing_qrepl_function()" : "6 * 7";
            if (scenario == "constrained") {
                steps = (<NcursesGallery::Step>{"checkpoint": "paused", "instruction": "Keep paused-output state visible in twelve columns.", "action": "pause-output", "expected": {"contains": "Paused", "following": False}},);
            } else if (scenario == "files") {
                steps = (
                    <NcursesGallery::Step>{"checkpoint": "menu", "instruction": "Alt-F opens File while retaining the draft.", "event": <Ncurses::InputEvent>{"type": Ncurses::InputType::Alt, "ch": "f"}, "expected": {"modal": True}},
                    <NcursesGallery::Step>{"checkpoint": "load", "instruction": "Highlight Load.", "event": key("KEY_DOWN"), "expected": {"modal": True}},
                    <NcursesGallery::Step>{"checkpoint": "save", "instruction": "Highlight Save.", "event": key("KEY_DOWN"), "expected": {"modal": True}},
                    <NcursesGallery::Step>{"checkpoint": "filename", "instruction": "Save asks for a filename with adjacent help.", "event": key("KEY_ENTER"), "expected": {"modal": True, "contains": "Filename"}},
                    <NcursesGallery::Step>{"checkpoint": "cancel", "instruction": "Escape restores the unchanged draft and focus.", "event": <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "\e"}, "expected": {"modal": False, "text": draft}}
                );
            } else if (scenario == "completion") {
                steps = (
                    <NcursesGallery::Step>{"checkpoint": "choices", "instruction": "Tab shows real Qore completions and documentation.", "event": <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "\t"}, "expected": {"modal": True, "contains": "printf"}},
                    <NcursesGallery::Step>{"checkpoint": "cancel", "instruction": "Escape restores the draft and its caret.", "event": <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "\e"}, "expected": {"modal": False, "text": draft}}
                );
            } else {
                steps = (<NcursesGallery::Step>{"checkpoint": "result", "instruction": "Evaluate the draft and capture after the worker completion barrier.", "action": "evaluate",
                    "expected": {"text": scenario == "error" ? draft : "", "contains": scenario == "error" ? "Error:" : "42", "evaluating": False}},);
            }
            result += <NcursesGallery::Story>{"id": "qrepl." + scenario, "widget": "QRepl", "api": "NcursesQore::CodeSupport", "application": True,
                "state": "scenario", "purpose": "Use the actual qrepl application: " + scenario + ". Evaluation executes Qore in this local session.",
                "fixture": {"draft": draft}, "geometry": <Ncurses::Size>{"rows": scenario == "constrained" ? 4 : 16, "cols": scenario == "constrained" ? 12 : 72},
                "keyboard": "qrepl keys are active: Enter evaluates, Tab completes, F1 helps, F6 switches panes, Ctrl-Q confirms quit. Native gallery controls use Alt-1 through Alt-6.",
                "mouse": "Click menus, editor, transcript and dialog controls.", "states": app_states, "steps": steps};
        }
        for (int i = 0; i < result.size(); ++i) {
            string file = result[i].widget == "KeyValueWidget" ? "TreeWidget" : result[i].widget == "TextChartWidget" ? "TextChart" : result[i].widget;
            result[i].api_url = "https://github.com/qoretechnologies/module-ncurses/blob/develop/" + (result[i].application ? "bin/qrepl" : "qlib/NcursesUi/" + file + ".qc");
        }
        cached = result; return result;
    }
    static hash<NcursesGallery::Story> find(string id) {
        foreach hash<NcursesGallery::Story> story in (stories()) { if (story.id == id) { return story; } }
        throw "GALLERY-STORY-ERROR", sprintf("Unknown story '%s'", id);
    }
    static list<hash<NcursesGallery::Story>> search(string query) {
        list<hash<NcursesGallery::Story>> found = ();
        foreach hash<NcursesGallery::Story> story in (stories()) {
            if ((story.id + " " + story.widget + " " + story.purpose).lwr().find(query.lwr()) >= 0) { found += story; }
        }
        return found;
    }
}
} # namespace NcursesGallery
