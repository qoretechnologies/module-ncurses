# Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
namespace NcursesGallery {
class Variants {
    static bool includes(list<string> names, string name) { foreach string item in (names) { if (item == name) { return True; } } return False; }
    static hash<string, string> applicability(string widget) {
        hash<string, string> result = {"default": "", "unicode": "", "constrained": ""};
        result.focused = includes(("LabelWidget", "StatusBarWidget"), widget) ? "N/A: read-only display does not accept focus" : "";
        result.disabled = includes(("LabelWidget", "StatusBarWidget", "DialogWidget", "DropdownMenuWidget", "CompletionPopupWidget", "AssistancePopupWidget", "FileBrowserWidget"), widget)
            ? "N/A: read-only display or transient overlay; availability is controlled by showing/dismissing it" : "";
        result.empty = includes(("ButtonWidget", "CheckboxWidget", "ProgressWidget", "FileBrowserWidget", "AttachmentWidget"), widget)
            ? "N/A: requires a labeled action, file metadata, or an existing directory; empty content is not a distinct usable state" : "";
        result.selected = includes(("LabelWidget", "TextInputWidget", "ButtonWidget", "FormWidget", "TextChartWidget", "StatusBarWidget", "ProgressWidget", "AttachmentWidget"), widget)
            ? "N/A: no independent selection model" : "";
        result.invalid = includes(("DescribedChoiceWidget", "FormWidget", "ProgressWidget", "FileSelectionWidget", "AttachmentWidget", "AssistancePopupWidget"), widget)
            ? "" : "N/A: no user validation state; malformed API arguments are covered by negative tests";
        result.loading = includes(("FormWidget", "ProgressWidget", "AssistancePopupWidget"), widget)
            ? "" : "N/A: synchronous presentation; loading belongs to the containing application";
        return result;
    }
    static list<hash<NcursesGallery::Story>> expand(list<hash<NcursesGallery::Story>> base) {
        list<hash<NcursesGallery::Story>> result = ();
        foreach hash<NcursesGallery::Story> original in (base) {
            hash<string, string> states = applicability(original.widget);
            string prefix = original.id.split(".")[0];
            foreach string state in (keys states) {
                if (states{state} == "") { states{state} = state == "default" ? original.id : prefix + "." + state; }
            }
            original.states = states; result += original;
            foreach string state in (("empty", "focused", "selected", "disabled", "invalid", "loading", "unicode", "constrained")) {
                if (states{state}.find("N/A:") == 0) { continue; }
                hash<NcursesGallery::Story> story = original; story.id = states{state}; story.state = state;
                story.purpose = original.purpose + " State: " + state + ".";
                hash<auto> expected = {};
                switch (state) {
                    case "empty": expected.empty = True; break;
                    case "focused": expected.focus_nonempty = True; break;
                    case "selected": expected.has_selection = True; break;
                    case "disabled": expected.enabled = False; expected.focus = ""; expected.cursor = 0; break;
                    case "invalid": expected.has_error = True; break;
                    case "loading": expected.loading = True; if (story.widget == "FormWidget") { expected.cursor = 0; } break;
                    case "unicode": expected.contains = "界"; break;
                    case "constrained": story.geometry = <Ncurses::Size>{"rows": 4, "cols": 12}; expected.enabled = True; break;
                }
                story.steps = (<NcursesGallery::Step>{"checkpoint": state, "instruction": story.purpose, "expected": expected},);
                result += story;
            }
        }
        return result;
    }
}
} # namespace NcursesGallery
