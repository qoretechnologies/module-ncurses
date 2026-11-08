#! @file CodeSupport.qc Qore syntax and live-session assistance
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesQore {
/** Qore adapter with a caller-owned evaluator and an independent syntax parser. */
public class CodeSupport {
    private {
%ifndef NCURSES_QORE_NO_ASTPARSER
        astparser::AstParser parser();
%endif
        QoreRepl::QoreRepl repl;
    }
    /** Uses the live session. @param session evaluator; caller serializes evaluator and assistance calls */
    constructor(QoreRepl::QoreRepl session) { repl = session; }
    /** Reports optional parser availability. @return highlighting supported */
    bool hasSyntaxHighlighting() {
%ifdef NCURSES_QORE_NO_ASTPARSER
        return False;
%else
        return True;
%endif
    }
    /** Styles source without changing its characters. @param source draft @return ANSI-styled source */
    string highlight(string source) {
%ifdef NCURSES_QORE_NO_ASTPARSER
        return source;
%else
        *astparser::AstTree tree = parser.parseString(source);
        if (!tree) { return source; }
        string result; int offset = 0;
        foreach hash<astparser::AstHighlight> span in (tree.getHighlights()) {
            if (span.start < offset || span.end < span.start || span.end > source.length()) { throw "QORE-SYNTAX-ERROR", "Invalid parser highlight range"; }
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
%endif
    }
    /** Returns signature help at the end of a source prefix. @param source prefix through caret @return hint */
    string hint(string source) { return repl.getHints(source) ?? ""; }
    /** Returns precise completions and signatures without evaluating source.
        Existing call parentheses and namespace separators are preserved, including intervening whitespace.
        @param request immutable editor snapshot @return provider response
    */
    hash<NcursesUi::AssistanceResponse> complete(hash<NcursesUi::AssistanceRequest> request) {
        if (request.cursor < 0 || request.cursor > request.text.length()) {
            throw "QORE-ASSISTANCE-ERROR", "Completion cursor is outside the source";
        }
        string prefix = request.text.substr(0, request.cursor); int start = request.cursor;
        while (start > 0 && prefix.substr(start - 1, 1) =~ /[A-Za-z_0-9]/) { --start; }
        if (prefix.startsWith("/") && start == 1) { start = 0; }
        int end = request.cursor;
        while (end < request.text.length() && request.text.substr(end, 1) =~ /[A-Za-z_0-9]/) { ++end; }
        int suffix_start = end;
        while (suffix_start < request.text.length() && request.text.substr(suffix_start, 1) =~ /[ \t\r\n]/) { ++suffix_start; }
        list<hash<NcursesUi::CompletionItem>> items = ();
        foreach hash<QoreCodeCompletion::CompletionItem> item in (repl.getCompletionDetails(prefix)) {
            string insertion = item.label;
            if (item.isCallable && request.text.substr(suffix_start, 1) != "(") { insertion += item.noArgsOnly ? "()" : "("; }
            else if (item.kind == "namespace" && request.text.substr(suffix_start, 2) != "::") { insertion += "::"; }
            items += <NcursesUi::CompletionItem>{"id": item.label, "label": item.label, "text": insertion,
                "range": <NcursesUi::SourceRange>{"start": start, "end": end},
                "detail": item.detail ?? "", "documentation": item.documentation ?? item.detail ?? ""};
        }
        string signature = hint(prefix);
        return <NcursesUi::AssistanceResponse>{"completions": items,
            "signature": signature == "" ? NOTHING : <NcursesUi::SignatureHelp>{"label": signature}};
    }
}
}
