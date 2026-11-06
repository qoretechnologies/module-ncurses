#! @file TextChart.qc Accessible numeric summaries and bounded terminal sparklines
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
/** Immutable numeric snapshot. NOTHING samples denote gaps; nonfinite values are rejected.
    ASCII is the default so every chart is understandable without block glyphs or color.
    Narrow charts sample evenly across the source, including both endpoints when possible;
    the summary always describes all supplied samples. A one-cell chart shows the latest sample.
*/
public class TextChart {
    private { list<*float> samples; string label; string units; *float minimum; *float maximum; *float latest; int count = 0; }
    /** Validates a complete snapshot. @param values finite samples or gaps @param title descriptive label @param unit measurement unit */
    constructor(list<*float> values = (), string title = "Chart", string unit = "") {
        foreach *float value in (values) {
            if (!exists value) { continue; }
            if (value.nanp() || value.infp()) { throw "CHART-DATA-ERROR", "Chart samples must be finite or NOTHING"; }
            minimum = exists minimum ? min(minimum, value) : value; maximum = exists maximum ? max(maximum, value) : value; latest = value; ++count;
        }
        samples = values; label = title; units = unit;
    }
    /** Returns exact source samples. @return immutable snapshot including gaps */
    list<*float> getSamples() { return samples; }
    /** Summarizes all finite data, independently of chart width. @return label, count, extrema and last available value */
    string getSummary() {
        string title = NcursesUi::TextEditorWidget::normalizePaste(label); string unit = units != "" ? " " + NcursesUi::TextEditorWidget::normalizePaste(units) : "";
        return title + (count ? sprintf(": %d samples; min %g%s; max %g%s; last %g%s", count, minimum, unit, maximum, unit, latest, unit) : ": No data") + (samples.size() > count ? sprintf("; %d gaps", samples.size() - count) : "");
    }
    /** Returns at most columns display cells. @param columns nonnegative width @param unicode use block glyphs instead of ASCII @return sparkline with ? for gaps */
    string sparkline(int columns, bool unicode = False) {
        if (columns < 0) { throw "CHART-WIDTH-ERROR", "Chart width must be nonnegative"; }
        if (!columns || !samples) { return ""; }
        string levels = unicode ? "▁▂▃▄▅▆▇█" : ".:-=+*#@"; int width = min(columns, samples.size()); string result = "";
        for (int i = 0; i < width; ++i) {
            int index = width == 1 ? samples.size() - 1 : int(number(i) * (samples.size() - 1) / (width - 1)); *float value = samples[index];
            if (!exists value) { result += "?"; continue; }
            # Arbitrary-precision arithmetic avoids overflow when finite extrema have opposite signs.
            int level = minimum == maximum ? 3 : int((number(value) - number(minimum)) * 7 / (number(maximum) - number(minimum)));
            result += levels.substr(max(0, min(7, level)), 1);
        }
        return result;
    }
}
/** Scrollable chart with a full textual summary and an optional Unicode sparkline. */
public class TextChartWidget inherits NcursesUi::ScrollableWidget {
    private { NcursesUi::TextChart chart; NcursesUi::LineListContent lines(); bool unicode = False; int rendered_columns = -1; }
    /** Creates a chart surface. @param value validated chart */
    constructor(NcursesUi::TextChart value) { chart = value; lines.setWordWrap(True); setContent(lines); }
    /** Replaces a complete snapshot and returns to its summary. @param value validated chart */
    nothing setChart(NcursesUi::TextChart value) { chart = value; rendered_columns = -1; setScrollY(0); markDirty(); }
    /** Returns the current chart. @return immutable snapshot */
    NcursesUi::TextChart getChart() { return chart; }
    /** Selects optional Unicode glyphs. @param value True for blocks, False for ASCII */
    nothing setUnicode(bool value) { unicode = value; rendered_columns = -1; markDirty(); }
    /** Returns whether Unicode glyphs are requested. @return glyph mode */
    bool getUnicode() { return unicode; }
    /** Prepares the sparkline for the effective viewport before painting. @param window target */
    nothing draw(Ncurses::Window window) {
        prepareDrawViewport(window); sync(); ScrollableWidget::draw(window);
    }
    /** Reconciles hidden content. */
    nothing onDrawClipped() { sync(); ScrollableWidget::onDrawClipped(); }
    private nothing sync() {
        int columns = max(0, getViewportRect().cols); if (columns == rendered_columns) { return; }
        lines.setLines((chart.getSummary(), chart.sparkline(columns, unicode), "Scale: low to high; ? = missing sample"));
        int final_columns = max(0, getViewportRect().cols); if (columns != final_columns) { lines.setLine(1, chart.sparkline(final_columns, unicode)); }
        rendered_columns = final_columns;
    }
}
} # namespace NcursesUi
