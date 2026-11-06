#! @file FileSelectionModel.qc Typed file selection with application-owned operations
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
#! A local or application-provided file. The widget never opens its path implicitly.
public hashdecl FileSelectionEntry {
    string id; string path; string name; *int size;
    string type = "file"; *string error; bool enabled = True;
}
#! Application-owned actions supported by a file selection surface.
public enum FileOperation : int { Open = 0, Save = 1, Export = 2 }
/** UI-thread-owned selection and one-shot open/save/export dispatch.
    Filters do not discard selections hidden by the current view. Stable IDs preserve
    selection across metadata replacement. Error/unavailable entries cannot be newly
    selected, and a refreshed error on an existing selection blocks dispatch.
    Callbacks return False for cancellation, True for success, or throw on failure.
    No network or application behavior is embedded. Local metadata/validation helpers
    are explicit opt-in filesystem operations through sandbox-checked Qore APIs.
*/
public class FileSelectionModel {
    private {
        list<hash<NcursesUi::FileSelectionEntry>> files = ();
        hash<string, int> positions = {};
        hash<string, bool> selected = {};
        list<string> visible = ();
        bool multiple;
        int revision = 0;
        int state = NcursesUi::ActionState::Pending;
        *string error;
        bool validating = False;
        *code<bool(hash<NcursesUi::FileSelectionEntry>)> filter;
        *code<*string(list<hash<NcursesUi::FileSelectionEntry>>)> validator;
        hash<string, code<bool(list<hash<NcursesUi::FileSelectionEntry>>)>> handlers = {};
    }
    /** Creates a selection model. @param entries validated file metadata @param multi allow multiple selected files */
    constructor(list<hash<NcursesUi::FileSelectionEntry>> entries = (), bool multi = False) { multiple = multi; setFiles(entries); }
    /** Atomically replaces metadata and retains selected IDs still present.
        @param entries unique IDs with nonempty paths and named entries
        @throw FILE-SELECTION-DATA for invalid metadata; filter errors propagate without replacement */
    nothing setFiles(list<hash<NcursesUi::FileSelectionEntry>> entries) {
        checkEditable(); hash<string, int> next = {}; hash<string, bool> retained = {};
        for (int i = 0; i < entries.size(); ++i) {
            hash<NcursesUi::FileSelectionEntry> file = entries[i];
            if (file.id == "" || file.path == "" || !exists file.name || (exists file.size && file.size < 0) || exists next{file.id}) { throw "FILE-SELECTION-DATA", "Invalid or duplicate file metadata"; }
            next{file.id} = i; if (selected{file.id}) { retained{file.id} = True; }
        }
        list<string> shown = filtered(entries, filter);
        files = entries; positions = next; visible = shown; selected = retained; changed();
    }
    /** Returns all immutable metadata. @return files in source order */
    list<hash<NcursesUi::FileSelectionEntry>> getFiles() { return files; }
    /** Returns one entry. @param id stable identity @return metadata @throw FILE-SELECTION-ID if absent */
    hash<NcursesUi::FileSelectionEntry> getFile(string id) { if (!exists positions{id}) { throw "FILE-SELECTION-ID", "Unknown file: " + id; } return files[positions{id}]; }
    /** Returns visible file identities. @return filtered source order */
    list<string> getVisibleIds() { return visible; }
    /** Sets filtering atomically. @param callback includes an entry when True; NOTHING shows all */
    nothing setFilter(*code<bool(hash<NcursesUi::FileSelectionEntry>)> callback) {
        checkEditable(); list<string> shown = filtered(files, callback); filter = callback; visible = shown; ++revision;
    }
    /** Selects extension suffixes case-insensitively; an empty list shows all.
        @param extensions suffixes such as .txt and .csv @throw FILE-SELECTION-FILTER for an empty or malformed suffix */
    nothing setExtensions(list<string> extensions) {
        list<string> normalized = ();
        foreach string suffix in (extensions) { if (suffix.length() < 2 || suffix.substr(0, 1) != "." || suffix.find("/") >= 0) { throw "FILE-SELECTION-FILTER", "Extensions must be dotted filename suffixes"; } normalized += suffix.lwr(); }
        setFilter(normalized ? bool sub (hash<NcursesUi::FileSelectionEntry> file) {
            string name = file.name.lwr(); foreach string suffix in (normalized) { if (name.length() >= suffix.length() && name.substr(-suffix.length()) == suffix) { return True; } } return False;
        } : NOTHING);
    }
    /** Reports whether multiple selection is enabled. @return multiple-selection mode */
    bool isMultiple() { return multiple; }
    /** Changes selection mode, retaining the first selected source entry when switching to single.
        @param value multiple-selection mode */
    nothing setMultiple(bool value) {
        checkEditable(); if (multiple == value) { return; }
        hash<string, bool> next = selected;
        if (!value) { list<hash<NcursesUi::FileSelectionEntry>> before = getSelected(); next = {}; if (before) { next{before[0].id} = True; } }
        multiple = value; selected = next; changed();
    }
    /** Returns selected entries, including selected entries hidden by filters or newly unavailable.
        @return source order */
    list<hash<NcursesUi::FileSelectionEntry>> getSelected() { list<hash<NcursesUi::FileSelectionEntry>> result = (); foreach hash<NcursesUi::FileSelectionEntry> file in (files) { if (selected{file.id}) { result += file; } } return result; }
    /** Reports selection. @param id file identity @return selected */
    bool isSelected(string id) { getFile(id); return selected{id} ?? False; }
    /** Toggles one available entry; existing invalid selections can still be cleared.
        @param id file identity @return changed; False for an unavailable entry */
    bool toggle(string id) {
        checkEditable(); hash<NcursesUi::FileSelectionEntry> file = getFile(id);
        if (selected{id}) { remove selected{id}; changed(); return True; }
        if (!file.enabled || exists file.error) { return False; }
        if (!multiple) { selected = {}; } selected{id} = True; changed(); return True;
    }
    /** Clears selections and prior failure. */
    nothing clearSelection() { checkEditable(); selected = {}; changed(); }
    /** Sets validation immediately before dispatch. @param callback returns error text or NOTHING */
    nothing setValidator(*code<*string(list<hash<NcursesUi::FileSelectionEntry>>)> callback) { checkEditable(); validator = callback; }
    /** Sets application-owned behavior. @param operation FileOperation @param callback True success, False cancellation */
    nothing setHandler(int operation, *code<bool(list<hash<NcursesUi::FileSelectionEntry>>)> callback) {
        checkEditable(); checkOperation(operation); if (callback) { handlers{string(operation)} = callback; } else { remove handlers{string(operation)}; } ++revision;
    }
    /** Reports configured behavior. @param operation FileOperation @return configured */
    bool hasHandler(int operation) { checkOperation(operation); return exists handlers{string(operation)}; }
    /** Validates and dispatches once. @param operation FileOperation @return completed
        @throw FILE-SELECTION-OPERATION for invalid operations; callback failures propagate after recording failure */
    bool dispatch(int operation) {
        checkOperation(operation);
        if (state == NcursesUi::ActionState::Running || state == NcursesUi::ActionState::Completed || validating || !exists handlers{string(operation)}) { return False; }
        list<hash<NcursesUi::FileSelectionEntry>> values = getSelected(); error = !values ? "Select at least one file" : NOTHING;
        foreach hash<NcursesUi::FileSelectionEntry> file in (values) { if (!file.enabled || exists file.error) { error = file.path + ": " + (file.error ?? "Unavailable"); break; } }
        if (exists error) { ++revision; return False; }
        validating = True;
        try { if (validator) { error = validator(values); } }
        catch (hash<ExceptionInfo> ex) { validating = False; state = NcursesUi::ActionState::Failed; error = ex.desc; ++revision; rethrow; }
        validating = False; if (exists error) { ++revision; return False; }
        state = NcursesUi::ActionState::Running; ++revision;
        try { bool accepted = handlers{string(operation)}(values); state = accepted ? NcursesUi::ActionState::Completed : NcursesUi::ActionState::Cancelled; ++revision; return accepted; }
        catch (hash<ExceptionInfo> ex) { state = NcursesUi::ActionState::Failed; error = ex.desc; ++revision; rethrow; }
    }
    /** Explicitly permits another operation while retaining selection. @throw FILE-SELECTION-BUSY during callbacks */
    nothing reset() { if (validating || state == NcursesUi::ActionState::Running) { throw "FILE-SELECTION-BUSY", "File operation is active"; } changed(); }
    /** Returns action lifecycle state. @return ActionState */
    int getState() { return state; }
    /** Returns a validation/operation error. @return error or NOTHING */
    *string getError() { return error; }
    /** Returns model revision for incremental presentation. @return monotonic revision */
    int getRevision() { return revision; }
    /** Summarizes selected and hidden entries. @return text suitable for a status line */
    string getSummary() {
        hash<string, bool> shown = {}; foreach string id in (visible) { shown{id} = True; }
        int hidden = 0; int unavailable = 0;
        foreach string id in (keys selected) { if (!shown{id}) { ++hidden; } hash<NcursesUi::FileSelectionEntry> file = getFile(id); if (!file.enabled || exists file.error) { ++unavailable; } }
        return sprintf("%d selected%s%s", selected.size(), hidden ? sprintf(" (%d hidden by filter)", hidden) : "", unavailable ? sprintf(" (%d unavailable)", unavailable) : "");
    }
    /** Inspects local regular-file metadata without opening file contents.
        @param paths filesystem paths @return entries with per-file errors; sandbox errors are represented as errors */
    static list<hash<NcursesUi::FileSelectionEntry>> inspectLocalPaths(list<string> paths) {
        list<hash<NcursesUi::FileSelectionEntry>> result = ();
        foreach string path in (paths) {
            list<string> parts = split("/", path); hash<NcursesUi::FileSelectionEntry> file = <NcursesUi::FileSelectionEntry>{"id": path, "path": path, "name": parts ? parts[-1] : path};
            try {
                hash<StatInfo> info = ReadOnlyFile::hstat(path); file.size = info.size;
                if (!is_file(path)) { file.error = "Not a regular file"; }
                else if (!is_readable(path)) { file.error = "File is not readable"; }
            } catch (hash<ExceptionInfo> ex) { if (ex.err == "THREAD-CANCELLED") { rethrow; } file.error = ex.desc; }
            result += file;
        }
        return result;
    }
    /** Rechecks local paths immediately before an application operation.
        @param entries selected files @return first error or NOTHING; applications still handle races during their actual I/O */
    static *string validateLocalSelection(list<hash<NcursesUi::FileSelectionEntry>> entries) {
        foreach hash<NcursesUi::FileSelectionEntry> file in (inspectLocalPaths(map $1.path, entries)) { if (exists file.error) { return file.path + ": " + file.error; } } return NOTHING;
    }
    private nothing changed() { error = NOTHING; state = NcursesUi::ActionState::Pending; ++revision; }
    private nothing checkEditable() { if (validating || state == NcursesUi::ActionState::Running || state == NcursesUi::ActionState::Completed) { throw "FILE-SELECTION-BUSY", "File selection is validating, running or completed"; } }
    private static nothing checkOperation(int operation) { if (operation < 0 || operation > 2) { throw "FILE-SELECTION-OPERATION", "Invalid file operation"; } }
    private list<string> filtered(list<hash<NcursesUi::FileSelectionEntry>> entries, *code<bool(hash<NcursesUi::FileSelectionEntry>)> callback) {
        validating = True; on_exit validating = False; list<string> result = ();
        foreach hash<NcursesUi::FileSelectionEntry> file in (entries) { if (!callback || callback(file)) { result += file.id; } } return result;
    }
}
} # namespace NcursesUi
