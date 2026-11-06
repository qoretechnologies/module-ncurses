#! @file TextEditorWidget.qc Multiline terminal editor with shared viewport geometry
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
/** Multiline editor with soft wrapping, selection and bounded scrolling.
    Enter submits by default and Alt-Enter inserts a newline; setEnterSubmits(False)
    reverses these bindings. Ctrl-Z/Ctrl-Y undo/redo, Shift-arrows extend selection,
    Ctrl-A selects all, and configured clipboard hooks handle Ctrl-C/X/V. Explicit
    paste operations normalize CR/LF and tabs and discard other C0 controls.
*/
public class TextEditorWidget inherits NcursesUi::ScrollableWidget {
    private {
        NcursesUi::EditorBuffer model();
        NcursesUi::LineListContent lines();
        list<string> logical_lines = ("",);
        list<int> line_offsets = (0,);
        string displayed_text = "";
        string prompt = "";
        int prompt_length = 0;
        int displayed_revision = -1;
        int caret_revision = -1;
        bool caret_focus = False;
        *int preferred_column;
        int vertical_revision = -1;
        int min_height = 1;
        int max_height = 6;
        bool enter_submits = True;
        *code<nothing(string)> on_submit;
        *code<nothing(string)> clipboard_writer;
        *code<string()> clipboard_reader;
    }
    constructor() {
        lines.setWordWrap(True); lines.setInsertionRows(True); lines.setLines(("",));
        setContent(lines); setFocusable(True);
    }
    /** Returns the editing model. @return UI-thread-owned model */
    NcursesUi::EditorBuffer getBuffer() { return model; }
    /** Sets a document and resets undo/history browsing. @param text plain text */
    nothing setText(string text) { model.setText(normalizePaste(text)); preferred_column = NOTHING; sync(); }
    /** Returns the complete document. @return text including hard newlines */
    string getText() { return model.getText(); }
    /** Sets a styled, noneditable first-line prefix. It participates in wrapping and caret geometry.
        @param value single-line ANSI-styled prompt @throw EDITOR-PROMPT-ERROR for hard newlines
    */
    nothing setPrompt(string value) {
        if (value.find("\n") >= 0 || value.find("\r") >= 0) { throw "EDITOR-PROMPT-ERROR", "Prompt must be one logical line"; }
        if (value == prompt) { return; }
        sync(); lines.setLine(0, value + logical_lines[0]);
        prompt = value; prompt_length = NcursesUi::TerminalText::plainAnsi(value).length();
        caret_revision = -1; markDirty();
    }
    /** Sets the submit handler; successful submission leaves clearing to the caller.
        @param callback handler or NOTHING to disable submission
    */
    nothing setOnSubmit(*code<nothing(string)> callback) { on_submit = callback; }
    /** Configures Enter versus Alt-Enter. @param value True for Enter to submit */
    nothing setEnterSubmits(bool value) { enter_submits = value; }
    /** Configures clipboard integration without requiring a particular desktop clipboard.
        @param writer receives selected text @param reader returns text to paste
    */
    nothing setClipboard(*code<nothing(string)> writer, *code<string()> reader) {
        clipboard_writer = writer; clipboard_reader = reader;
    }
    /** Sets automatic preferred-height bounds. Actual allocation remains the parent's responsibility.
        @param minimum positive minimum rows @param maximum maximum rows
        @throw EDITOR-SIZE-ERROR for invalid bounds
    */
    nothing setAutoHeight(int minimum, int maximum) {
        if (minimum < 1 || maximum < minimum) { throw "EDITOR-SIZE-ERROR", "Invalid editor height bounds"; }
        min_height = minimum; max_height = maximum; markDirty();
    }
    /** Returns a bounded preferred size using current wrapping geometry. @return preferred rows/columns */
    hash<NcursesUi::Rect> getPreferredSize() {
        return getPreferredSizeForWidth(getFrame().cols);
    }
    /** Measures wrapping before a parent allocates rows. @param columns available columns @return preferred size */
    hash<NcursesUi::Rect> getPreferredSizeForWidth(int columns) {
        sync(); lines.prepareViewport(max(0, columns));
        return NcursesUi::Geometry::makeRect(0, 0, max(min_height, min(max_height, lines.totalRows())), columns);
    }
    /** Returns the visible insertion point for completion popups and assistance.
        @return screen row/column, or NOTHING when the caret is outside the drawable viewport
    */
    *hash<Ncurses::Position> getCaretScreenPosition() {
        sync(); hash<NcursesUi::Rect> rect = getViewportRect(); hash<Ncurses::Position> source = cursorSource();
        hash<Ncurses::Position> pos = lines.sourceToVisual(source.y, source.x);
        pos.y += rect.y - getScrollY(); pos.x += rect.x - getScrollX();
        return NcursesUi::Geometry::rectContains(rect, pos.y, pos.x) ? pos : NOTHING;
    }
    /** Reports a visible caret when focused. @return True */
    bool wantsCursor() { return True; }
    /** Reports model or viewport changes. @return whether painting is needed */
    bool needsOwnDraw() { return model.getRevision() != displayed_revision || ScrollableWidget::needsOwnDraw(); }
    /** Releases the caret on focus loss. */
    nothing onFocusOut() { clearCursorLine(); caret_focus = False; }
    /** Releases cursor ownership for a clipped editor. */
    nothing onDrawClipped() { ScrollableWidget::onDrawClipped(); displayed_revision = model.getRevision(); }
    /** Normalizes pasted terminal control characters into safe editable text.
        CR/LF becomes LF, tabs become four spaces, and other C0/DEL characters are omitted.
        @param text incoming text @return normalized plain text
    */
    static string normalizePaste(string text) {
        text =~ s/\r\n?/\n/g;
        text =~ s/\t/    /g;
        text =~ s/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]//g;
        return text;
    }
    /** Inserts a complete paste as a single undo operation, without dispatching embedded keys.
        @param text pasted text @throw EDITOR-LIMIT-ERROR if the resulting document is too large
    */
    nothing insertPaste(string text) { model.insert(normalizePaste(text)); preferred_column = NOTHING; sync(); }
    /** Submits the immutable draft through the configured handler. @return True if a handler ran */
    bool submit() { if (!on_submit) { return False; } model.submit(on_submit); return True; }
    /** Moves by visual rows while retaining a preferred terminal column.
        @param rows signed visual row displacement @param selecting extend selection
    */
    nothing moveVertical(int rows, bool selecting = False) {
        if (model.getRevision() != vertical_revision) { preferred_column = NOTHING; }
        sync(); getViewportRect(); hash<Ncurses::Position> source = cursorSource();
        hash<Ncurses::Position> visual = lines.sourceToVisual(source.y, source.x);
        if (!exists preferred_column) { preferred_column = visual.x; }
        hash<Ncurses::Position> next = lines.visualToSource(visual.y + rows, preferred_column);
        model.setCursor(sourceOffset(next), selecting); vertical_revision = model.getRevision(); sync();
    }
    /** Places the caret using the same wrapped geometry as painting.
        @param row screen row @param col screen column @param selecting extend selection
    */
    nothing setCursorAt(int row, int col, bool selecting = False) {
        sync(); hash<NcursesUi::Rect> rect = getViewportRect();
        hash<Ncurses::Position> source = lines.visualToSource(getScrollY() + row - rect.y, getScrollX() + col - rect.x);
        model.setCursor(sourceOffset(source), selecting); preferred_column = NOTHING; sync();
    }
    /** Draws text, selection and the focused caret. @param w clipped target window */
    nothing draw(Ncurses::Window w) {
        sync(); ScrollableWidget::draw(w);
        hash<Ncurses::Position> selection = model.selection();
        if (selection.x != selection.y) {
            hash<NcursesUi::Rect> rect = getViewportRect(); hash<Ncurses::Position> origin = w.position();
            for (int row = 0; row < rect.rows; ++row) {
                *hash<NcursesUi::WrappedTextRow> entry = lines.getVisualRow(getScrollY() + row);
                if (!entry) { continue; }
                int offset = line_offsets[entry.line_idx] + entry.start - (entry.line_idx == 0 ? prompt_length : 0); int col = 0;
                foreach string cluster in (NcursesUi::TerminalText::graphemes(NcursesUi::TerminalText::plainAnsi(entry.text))) {
                    int width = char_width(cluster);
                    if (offset >= selection.y && offset < selection.x && col >= getScrollX()
                            && col + width <= getScrollX() + rect.cols) {
                        w.drawTextClipped(rect.y + row - origin.y, rect.x + col - getScrollX() - origin.x,
                            cluster, {"attrs": Ncurses::Attr::Reverse});
                    }
                    offset += cluster.length(); col += width;
                }
            }
        }
        displayed_revision = model.getRevision();
    }
    /** Handles editing/navigation keys and primary mouse selection. @param ev input @return handling result */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        bool handled = True; string name = ev.name ?? ""; string ch = ev.ch ?? "";
        if (ev.type == Ncurses::InputType::Paste) {
            insertPaste(ch);
        } else if (ev.type == Ncurses::InputType::Mouse) {
            hash<NcursesUi::Rect> rect = getViewportRect();
            if (NcursesUi::Geometry::rectContains(rect, ev.mouse.y, ev.mouse.x)
                    && (ev.mouse.button_state & (Ncurses::BUTTON1_CLICKED | Ncurses::BUTTON1_PRESSED))) {
                setCursorAt(ev.mouse.y, ev.mouse.x, (ev.mouse.button_state & Ncurses::BUTTON_SHIFT) != 0);
            } else { return ScrollableWidget::processEvent(ev); }
        } else if ((ev.type == Ncurses::InputType::Char && (ch == "\n" || ch == "\r"))
                || (ev.type == Ncurses::InputType::Key && name == "KEY_ENTER")
                || (ev.type == Ncurses::InputType::Alt && (ch == "\n" || ch == "\r"))) {
            bool alternate = ev.type == Ncurses::InputType::Alt;
            if (enter_submits != alternate) { submit(); } else { insertPaste("\n"); }
        } else if (ev.type == Ncurses::InputType::Key) {
            bool selecting = name == "KEY_SLEFT" || name == "KEY_SRIGHT" || name == "KEY_SR" || name == "KEY_SF";
            if (name == "KEY_LEFT" || name == "KEY_SLEFT") { model.moveHorizontal(False, selecting); preferred_column = NOTHING; }
            else if (name == "KEY_RIGHT" || name == "KEY_SRIGHT") { model.moveHorizontal(True, selecting); preferred_column = NOTHING; }
            else if (name == "KEY_UP" || name == "KEY_SR") { moveVertical(-1, selecting); }
            else if (name == "KEY_DOWN" || name == "KEY_SF") { moveVertical(1, selecting); }
            else if (name == "KEY_PPAGE") { moveVertical(-max(1, getViewportRect().rows)); }
            else if (name == "KEY_NPAGE") { moveVertical(max(1, getViewportRect().rows)); }
            else if (name == "KEY_HOME" || name == "KEY_END") {
                sync(); hash<Ncurses::Position> pos = cursorSource();
                model.setCursor(line_offsets[pos.y] + (name == "KEY_END" ? logical_lines[pos.y].length() : 0));
                preferred_column = NOTHING;
            } else if (name == "KEY_BACKSPACE") { model.erase(); preferred_column = NOTHING; }
            else if (name == "KEY_DC") { model.erase(True); preferred_column = NOTHING; }
            else { handled = False; }
        } else if (ev.type == Ncurses::InputType::Char) {
            if (ch == "\x1a") { model.undo(); preferred_column = NOTHING; }
            else if (ch == "\x19") { model.redo(); preferred_column = NOTHING; }
            else if (ch == "\x01") { model.select(0, getText().length()); }
            else if (ch == "\x03" && clipboard_writer) { model.copySelection(clipboard_writer); }
            else if (ch == "\x18" && clipboard_writer) { model.cutSelection(clipboard_writer); }
            else if (ch == "\x16" && clipboard_reader) {
                model.pasteClipboard(string sub () { return normalizePaste(clipboard_reader()); }); preferred_column = NOTHING;
            } else if (ch == "\x7f" || ch == "\x08") { model.erase(); preferred_column = NOTHING; }
            else if (ch != "" && ord(ch) >= 32) { insertPaste(ch); }
            else { handled = False; }
        } else { handled = False; }
        if (handled) { sync(); markDirty(); }
        return <NcursesUi::EventResult>{"handled": handled};
    }
    private hash<Ncurses::Position> cursorSource() {
        int line = 0;
        while (line + 1 < line_offsets.size() && line_offsets[line + 1] <= model.getCursor()) { ++line; }
        return <Ncurses::Position>{"y": line, "x": model.getCursor() - line_offsets[line] + (line == 0 ? prompt_length : 0)};
    }
    private int sourceOffset(hash<Ncurses::Position> source) {
        return line_offsets[source.y] + max(0, source.x - (source.y == 0 ? prompt_length : 0));
    }
    private nothing sync() {
        string text = model.getText();
        if (text != displayed_text) {
            list<string> next = split("\n", text, False, True); if (!next) { next = ("",); }
            if (next.size() == logical_lines.size()) {
                for (int i = 0; i < next.size(); ++i) {
                    if (next[i] != logical_lines[i]) { lines.setLine(i, (i == 0 ? prompt : "") + next[i]); }
                }
            } else { list<string> rendered = next; rendered[0] = prompt + rendered[0]; lines.setLines(rendered); }
            list<int> offsets = (); int offset = 0;
            foreach string line in (next) { offsets += offset; offset += line.length() + 1; }
            logical_lines = next; line_offsets = offsets; displayed_text = text;
        }
        if (model.getRevision() != caret_revision || hasFocus() != caret_focus) {
            if (hasFocus()) {
                hash<Ncurses::Position> source = cursorSource(); setCursorLine(source.y, source.x);
            } else { clearCursorLine(); }
            caret_revision = model.getRevision(); caret_focus = hasFocus();
        }
    }
}
} # namespace NcursesUi
