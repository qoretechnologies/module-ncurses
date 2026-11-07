#! @file CodeViewWidget.qc Read-only searchable code with application-provided syntax styling
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
/** Read-only code/text viewer with search, selection, wrapping and copy/export hooks.
    Display text normalizes CR/LF and tabs and discards other C0/DEL controls using
    TextEditorWidget::normalizePaste(); getText(), copyAll() and exportText() retain
    the exact original source. Selection copies visible normalized text. An optional
    highlighter returns ANSI-styled display text and must preserve every plain
    character. A failed or reentrant highlighter leaves the previous document intact.
*/
public class CodeViewWidget inherits NcursesUi::TranscriptWidget {
    private {
        string source = "";
        string displayed = "";
        string language = "text";
        *code<string(string, string)> highlighter;
        *code<nothing(string)> copy_all;
        *code<nothing(string, string)> exporter;
        bool formatting = False;
    }
    /** Creates a viewer. @param text original source @param syntax application-defined language identifier */
    constructor(string text = "", string syntax = "text") { setWordWrap(False); setText(text, syntax); }
    /** Replaces a document after validating its highlighted form.
        @param text original source @param syntax language identifier
        @throw CODEVIEW-HIGHLIGHT-ERROR if styling changes source text @throw CODEVIEW-BUSY-ERROR for reentrant mutation
    */
    nothing setText(string text, string syntax = "text") {
        checkEditable(); formatting = True; on_exit formatting = False;
        string plain = NcursesUi::TextEditorWidget::normalizePaste(text);
        string styled = format(plain, syntax, highlighter); commitText(text, plain, styled, syntax);
    }
    /** Clears the document through the same guarded replacement API. */
    nothing clear() { setText("", language); }
    /** Rejects transcript mutation; replace the read-only document with setText().
        @param lines ignored @param kind ignored @param title ignored @return never returns
        @throw CODEVIEW-DOCUMENT-ERROR for direct transcript mutation
    */
    int appendBlock(list<string> lines, string kind = "output", string title = "") { throw "CODEVIEW-DOCUMENT-ERROR", "Use setText() to replace a code document"; }
    /** Rejects direct transcript append. @param lines ignored @throw CODEVIEW-DOCUMENT-ERROR always */
    nothing appendLines(list<string> lines) { throw "CODEVIEW-DOCUMENT-ERROR", "Use setText() to replace a code document"; }
    /** Rejects direct transcript append. @param line ignored @throw CODEVIEW-DOCUMENT-ERROR always */
    nothing appendLine(string line) { throw "CODEVIEW-DOCUMENT-ERROR", "Use setText() to replace a code document"; }
    /** Rejects direct block append. @param id ignored @param lines ignored @throw CODEVIEW-DOCUMENT-ERROR always */
    nothing appendBlockLines(int id, list<string> lines) { throw "CODEVIEW-DOCUMENT-ERROR", "Use setText() to replace a code document"; }
    /** Code documents retain their full source. @param maximum must be zero (unlimited)
        @throw CODEVIEW-DOCUMENT-ERROR for a positive retention bound
    */
    nothing setRetentionLimit(int maximum) { if (maximum) { throw "CODEVIEW-DOCUMENT-ERROR", "Code documents cannot be trimmed"; } TranscriptWidget::setRetentionLimit(0); }
    /** Returns original source including original line endings, tabs and control characters. @return source text */
    string getText() { return source; }
    /** Returns the normalized source used for display/search/selection. @return display text without ANSI styling */
    string getDisplayText() { return displayed; }
    /** Returns the application-provided language identifier. @return syntax name */
    string getLanguage() { return language; }
    /** Sets syntax styling and restyles the current document atomically.
        @param callback receives normalized source and language, returns source-preserving ANSI text
        @throw CODEVIEW-HIGHLIGHT-ERROR for changed source @throw CODEVIEW-BUSY-ERROR for reentrant mutation
    */
    nothing setHighlighter(*code<string(string, string)> callback) {
        checkEditable(); formatting = True; on_exit formatting = False;
        string styled = format(displayed, language, callback);
        commitText(source, displayed, styled, language); highlighter = callback;
    }
    /** Sets copy integration for visible selections and exact full-source copies.
        @param callback receives copied text
    */
    nothing setOnCopy(*code<nothing(string)> callback) { TranscriptWidget::setOnCopy(callback); copy_all = callback; }
    /** Copies exact original source. @return True if a callback ran; errors propagate without modifying the document */
    bool copyAll() { if (!copy_all) { return False; } copy_all(source); return True; }
    /** Sets export integration. @param callback receives original source and language; no files are written by the widget */
    nothing setOnExport(*code<nothing(string, string)> callback) { exporter = callback; }
    /** Exports exact original source. @return True if a callback ran; errors propagate without modifying the document */
    bool exportText() { if (!exporter) { return False; } exporter(source, language); return True; }
    private nothing checkEditable() { if (formatting) { throw "CODEVIEW-BUSY-ERROR", "A highlighter cannot modify the document"; } }
    private static string format(string text, string syntax, *code<string(string, string)> callback) {
        string result = callback ? callback(text, syntax) : text;
        if (NcursesUi::TerminalText::plainAnsi(result) != text) { throw "CODEVIEW-HIGHLIGHT-ERROR", "Syntax styling changed the source text"; }
        return result;
    }
    private nothing commitText(string original, string plain, string styled, string syntax) {
        list<string> lines = NcursesUi::TerminalText::styledLines(styled);
        TranscriptWidget::clear(); TranscriptWidget::appendBlock(lines, "code", syntax); setFollowTail(False); setScrollY(0);
        source = original; displayed = plain; language = syntax;
    }
}
} # namespace NcursesUi
