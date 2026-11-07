#! @file EditorBuffer.qc Multiline editing, selection, undo and draft history
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
#! Complete text selection state; offsets count Qore characters at grapheme boundaries.
public hashdecl EditorSnapshot {
    string text;
    int cursor;
    *int anchor;
}

/** Grapheme-safe multiline editing model shared by terminal editors.
    Mutations are prepared before committing, undo is bounded, and clipboard
    callbacks run before destructive changes. All access belongs to the UI thread.
*/
public class EditorBuffer {
    private {
        NcursesReplUi::InputBuffer buffer();
        *int anchor;
        int revision = 0;
        int max_chars = 1048576;
        int undo_limit = 100;
        list<hash<NcursesUi::EditorSnapshot>> undo_stack = ();
        list<hash<NcursesUi::EditorSnapshot>> redo_stack = ();
        list<string> history = ();
        *list<string> pending_history;
        int history_index = -1;
        *hash<NcursesUi::EditorSnapshot> draft;
        bool locked = False;
    }
    /** Returns source text. @return text with hard newlines */
    string getText() { return buffer.getText(); }
    /** Returns the insertion offset. @return Qore character offset */
    int getCursor() { return buffer.getCursor(); }
    /** Returns the edit/selection generation. @return monotonic generation */
    int getRevision() { return revision; }
    /** Returns a complete selection snapshot. @return text, caret and optional anchor */
    hash<NcursesUi::EditorSnapshot> snapshot() {
        return <NcursesUi::EditorSnapshot>{"text": getText(), "cursor": getCursor(), "anchor": anchor};
    }
    /** Sets the character and undo limits. Existing oversized text is rejected, never truncated.
        @param characters positive source-character limit @param undo_steps nonnegative history limit
        @throw EDITOR-LIMIT-ERROR for invalid limits or oversized existing text
    */
    nothing setLimits(int characters, int undo_steps = 100) {
        checkUnlocked();
        if (characters < 1 || undo_steps < 0 || getText().length() > characters) {
            throw "EDITOR-LIMIT-ERROR", "Invalid editor limits or existing text exceeds the requested limit";
        }
        max_chars = characters; undo_limit = undo_steps;
        trimUndo(); redo_stack = ();
    }
    /** Replaces a document and clears undo, selection and history browsing.
        @param text new source text @throw EDITOR-LIMIT-ERROR if too large
    */
    nothing setText(string text) {
        checkUnlocked(); validate(text); buffer.setText(text); anchor = NOTHING;
        undo_stack = (); redo_stack = (); finishHistory(); ++revision;
    }
    /** Moves to a grapheme boundary, optionally extending a selection.
        @param offset character offset @param selecting True to retain the selection anchor
    */
    nothing setCursor(int offset, bool selecting = False) {
        checkUnlocked(); int before = getCursor(); buffer.setCursor(offset);
        if (selecting) { if (!exists anchor) { anchor = before; } } else { anchor = NOTHING; }
        ++revision;
    }
    /** Selects a source range, expanding partial graphemes.
        @param start inclusive anchor @param end exclusive caret (reversed ranges supported)
    */
    nothing select(int start, int end) {
        checkUnlocked(); string text = getText();
        int first = NcursesReplUi::TextPosition::snapOffset(text, min(start, end));
        int last = NcursesReplUi::TextPosition::snapOffset(text, max(start, end), start != end);
        anchor = start <= end ? first : last; buffer.setCursor(start <= end ? last : first); ++revision;
    }
    /** Returns the ordered selected range. @return start/end character offsets */
    hash<Ncurses::Position> selection() {
        int first = anchor ?? getCursor();
        return <Ncurses::Position>{"y": min(first, getCursor()), "x": max(first, getCursor())};
    }
    /** Returns selected text. @return empty string without a selection */
    string selectedText() { hash<Ncurses::Position> r = selection(); return getText().substr(r.y, r.x - r.y); }
    /** Replaces selection as one undo operation. Newlines and tabs are literal text.
        @param text insertion text @throw EDITOR-LIMIT-ERROR if result exceeds the bound
    */
    nothing insert(string text) {
        checkUnlocked(); hash<Ncurses::Position> r = selection(); replace(r.y, r.x, text);
    }
    /** Replaces a character range as one undo operation.
        @param start inclusive start @param end exclusive end @param text insertion text
        @throw EDITOR-LIMIT-ERROR if the result is too large
    */
    nothing replace(int start, int end, string text) {
        checkUnlocked(); NcursesReplUi::InputBuffer next(); next.setText(getText());
        next.replaceRange(start, end, text); validate(next.getText());
        if (next.getText() == getText() && !exists anchor && next.getCursor() == getCursor()) { return; }
        hash<NcursesUi::EditorSnapshot> before = snapshot();
        undo_stack += before; trimUndo(); redo_stack = ();
        buffer = next; anchor = NOTHING; finishHistory(); ++revision;
    }
    /** Deletes selection or the adjacent grapheme. @param forward True for Delete, False for Backspace */
    nothing erase(bool forward = False) {
        hash<Ncurses::Position> r = selection();
        if (r.x != r.y) { replace(r.y, r.x, ""); }
        else if (forward && getCursor() < getText().length()) { replace(getCursor(), getCursor() + 1, ""); }
        else if (!forward && getCursor() > 0) { replace(getCursor() - 1, getCursor(), ""); }
    }
    /** Moves one grapheme horizontally. @param forward True for right @param selecting extend selection */
    nothing moveHorizontal(bool forward, bool selecting = False) {
        checkUnlocked(); int before = getCursor(); hash<Ncurses::Position> range = selection();
        if (!selecting && range.x != range.y) { setCursor(forward ? range.x : range.y); return; }
        if (forward) { buffer.moveRight(); } else { buffer.moveLeft(); }
        if (selecting) { if (!exists anchor) { anchor = before; } } else { anchor = NOTHING; }
        ++revision;
    }
    /** Moves by words using the shared input boundary rules.
        @param forward True for the next word @param selecting extend the selection
    */
    nothing moveWord(bool forward, bool selecting = False) {
        checkUnlocked(); NcursesReplUi::InputBuffer next(); next.setText(getText()); next.setCursor(getCursor());
        if (forward) { next.moveWordRight(); } else { next.moveWordLeft(); }
        setCursor(next.getCursor(), selecting);
    }
    /** Deletes selection or the adjacent word as one undo step. @param forward direction */
    nothing eraseWord(bool forward = False) {
        checkUnlocked(); hash<Ncurses::Position> range = selection();
        if (range.x != range.y) { insert(""); return; }
        NcursesReplUi::InputBuffer next(); next.setText(getText()); next.setCursor(getCursor());
        if (forward) { next.moveWordRight(); } else { next.moveWordLeft(); }
        replace(min(getCursor(), next.getCursor()), max(getCursor(), next.getCursor()), "");
    }
    /** Deletes to a hard line boundary, or its newline when already at the boundary.
        @param forward True to delete toward the end of the line
    */
    nothing killToBoundary(bool forward = True) {
        checkUnlocked(); string text = getText(); int cursor = getCursor(); int boundary = cursor;
        if (forward) {
            while (boundary < text.length() && text.substr(boundary, 1) != "\n") { ++boundary; }
            if (boundary == cursor && boundary < text.length()) { ++boundary; }
        } else {
            while (boundary > 0 && text.substr(boundary - 1, 1) != "\n") { --boundary; }
            if (boundary == cursor && boundary > 0) { --boundary; }
        }
        replace(min(cursor, boundary), max(cursor, boundary), "");
    }
    /** Undoes the last mutation. @return True when restored */
    bool undo() {
        checkUnlocked(); if (!undo_stack) { return False; }
        hash<NcursesUi::EditorSnapshot> state = undo_stack[-1]; validate(state.text);
        redo_stack += snapshot(); pop undo_stack; restore(state); return True;
    }
    /** Redoes the last undone mutation. @return True when restored */
    bool redo() {
        checkUnlocked(); if (!redo_stack) { return False; }
        hash<NcursesUi::EditorSnapshot> state = redo_stack[-1]; validate(state.text);
        undo_stack += snapshot(); pop redo_stack; restore(state); return True;
    }
    /** Copies selection with a caller-provided clipboard hook. @param writer clipboard writer */
    nothing copySelection(code<nothing(string)> writer) {
        checkUnlocked(); locked = True; on_exit locked = False; writer(selectedText());
    }
    /** Cuts selection after successful clipboard delivery. @param writer clipboard writer */
    nothing cutSelection(code<nothing(string)> writer) { copySelection(writer); if (selectedText() != "") { insert(""); } }
    /** Pastes clipboard text as one undo operation. @param reader clipboard reader */
    nothing pasteClipboard(code<string()> reader) {
        checkUnlocked(); string text;
        { locked = True; on_exit locked = False; text = reader(); }
        insert(text);
    }
    /** Calls a submission handler with an immutable draft; failure preserves text/selection/undo.
        @param submit handler; the caller decides whether to clear after success
    */
    nothing submit(code<nothing(string)> submit) {
        checkUnlocked(); locked = True; on_exit locked = False; submit(getText());
    }
    /** Sets searchable history in oldest-first order.
        @param entries previous submitted texts
        @param preserve_navigation retain an active browsing snapshot and its unfinished
        draft; the latest update becomes searchable when browsing ends by returning to
        the draft or editing/replacing the current text. False resets browsing immediately.
        @par Example
        @code{.py}
NcursesUi::EditorBuffer editor();
editor.setHistory(("previous command",));
editor.setText("unfinished draft");
editor.historyMove();
editor.setHistory(("previous command", "completed background command"), True);
editor.historyMove(True); # restores the unfinished draft; refreshed history is now available
        @endcode
    */
    nothing setHistory(list<string> entries, bool preserve_navigation = False) {
        checkUnlocked();
        if (preserve_navigation && exists draft) { pending_history = entries; return; }
        history = entries; pending_history = NOTHING; history_index = -1; draft = NOTHING;
    }
    /** Searches backward/forward through history, preserving the unfinished draft and selection.
        @param forward True to move toward the draft @param query literal substring filter
        @return True when a history entry or the draft is restored
        @note An unsuccessful initial search does not enter browsing mode or defer history updates.
    */
    bool historyMove(bool forward = False, string query = "") {
        checkUnlocked();
        bool starting = history_index < 0;
        if (starting && forward) { return False; }
        int next = (starting ? history.size() : history_index) + (forward ? 1 : -1);
        while (next >= 0 && next < history.size()) {
            if (history[next].find(query) >= 0) {
                validate(history[next]);
                if (starting) { draft = snapshot(); }
                buffer.setText(history[next]); anchor = NOTHING; history_index = next; ++revision;
                return True;
            }
            next += forward ? 1 : -1;
        }
        if (forward && draft) { hash<NcursesUi::EditorSnapshot> saved = draft; restore(saved); return True; }
        return False;
    }
    private nothing restore(hash<NcursesUi::EditorSnapshot> state) {
        validate(state.text); buffer.setText(state.text); buffer.setCursor(state.cursor); anchor = state.anchor;
        finishHistory(); ++revision;
    }
    private nothing finishHistory() {
        if (exists pending_history) { history = pending_history; pending_history = NOTHING; }
        draft = NOTHING; history_index = -1;
    }
    private nothing checkUnlocked() { if (locked) { throw "EDITOR-BUSY-ERROR", "An editor callback cannot mutate its draft"; } }
    private nothing validate(string text) {
        if (text.length() > max_chars) { throw "EDITOR-LIMIT-ERROR", "Text exceeds the editor character limit"; }
    }
    private nothing trimUndo() {
        if (!undo_limit) { undo_stack = (); }
        else if (undo_stack.size() > undo_limit) { undo_stack = undo_stack[undo_stack.size() - undo_limit .. undo_stack.size() - 1]; }
    }
}
} # namespace NcursesUi
