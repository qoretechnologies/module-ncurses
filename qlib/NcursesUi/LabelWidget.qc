#! @file LabelWidget.qc Wrapped, styled labels and validation messages
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
/** Nonfocusable wrapped text for labels, help and validation errors. ANSI styling is supported. */
public class LabelWidget inherits NcursesUi::ScrollableWidget {
    private { NcursesUi::LineListContent lines(); string text = ""; }
    /** Creates a label. @param value text, including optional hard newlines */
    constructor(string value = "") { lines.setWordWrap(True); setContent(lines); setShowScrollbar(False); setFocusable(False); setText(value); }
    /** Replaces the text. @param value styled text */
    nothing setText(string value) { if (value == text && lines.getLines().size()) { return; } lines.setLines(split("\n", value, False, True)); text = value; markDirty(); }
    /** Returns the label text. @return styled text */
    string getText() { return text; }
    /** Measures the label at a proposed width. @param columns available cells @return wrapped rows */
    hash<NcursesUi::Rect> getPreferredSizeForWidth(int columns) {
        lines.prepareViewport(max(0, columns)); return NcursesUi::Geometry::makeRect(0, 0, max(1, lines.totalRows()), columns);
    }
    /** Labels do not consume editing/navigation events. @param event input @return unhandled */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> event) { return <NcursesUi::EventResult>{}; }
}
} # namespace NcursesUi
