#! @file TextChart.qc Accessible numeric summaries and bounded terminal sparklines
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
/** Immutable numeric snapshot. NOTHING samples denote gaps; nonfinite values are rejected.
    The string API defaults to ASCII for compatibility; the widget defaults to Unicode bars.
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
    /** Renders larger bars normalized from the snapshot minimum to maximum, without inventing samples.
        Samples use up to eight columns each; narrow views sample both endpoints.
        @param columns nonnegative width @param rows height from 1 to 64
        @param unicode use partial block cells; ASCII uses whole-row # bars
        @return top-to-bottom chart rows; a missing sample has ? at the baseline
        @throw CHART-WIDTH-ERROR for negative width @throw CHART-HEIGHT-ERROR for invalid height
    */
    list<string> bars(int columns, int rows, bool unicode = True) {
        if (columns < 0) { throw "CHART-WIDTH-ERROR", "Chart width must be nonnegative"; }
        if (rows < 1 || rows > 64) { throw "CHART-HEIGHT-ERROR", "Chart height must be between 1 and 64 rows"; }
        if (!columns || !samples) { return (); }
        int count = min(columns, samples.size()); int group = min(8, columns / count);
        int gap = group >= 3 ? 1 : 0; int width = group - gap; int resolution = unicode ? 8 : 1;
        list<string> result = ();
        for (int y = 0; y < rows; ++y) {
            string line = "";
            for (int i = 0; i < count; ++i) {
                int index = count == 1 ? samples.size() - 1 : int(number(i) * (samples.size() - 1) / (count - 1));
                *float value = samples[index]; string part;
                if (!exists value) {
                    int left = (width - 1) / 2;
                    part = y == rows - 1 ? strmul(" ", left) + "?" + strmul(" ", width - left - 1) : strmul(" ", width);
                } else {
                    int height = minimum == maximum ? max(1, rows * resolution / 2)
                        : 1 + int((number(value) - number(minimum)) * (rows * resolution - 1) / (number(maximum) - number(minimum)));
                    int fill = max(0, min(resolution, height - (rows - y - 1) * resolution));
                    string glyph = unicode ? " ▁▂▃▄▅▆▇█".substr(fill, 1) : (fill ? "#" : " ");
                    part = strmul(glyph, width);
                }
                line += part + strmul(" ", gap);
            }
            result += line;
        }
        return result;
    }
}
/** Scrollable chart with a full textual summary, Unicode bars and an explicit scale.
    setUnicode(False) selects an ASCII fallback with its complete symbol ramp in the legend.
*/
public class TextChartWidget inherits NcursesUi::ScrollableWidget {
    private { NcursesUi::TextChart chart; NcursesUi::LineListContent lines(); bool unicode = True; int chart_height = 1; int rendered_columns = -1; bool rendered_available = True; }
    /** Creates a chart surface. @param value validated chart */
    constructor(NcursesUi::TextChart value) { chart = value; lines.setWordWrap(True); setContent(lines); }
    /** Replaces a complete snapshot and returns to its summary. @param value validated chart */
    nothing setChart(NcursesUi::TextChart value) { chart = value; rendered_columns = -1; setScrollY(0); markDirty(); }
    /** Returns the current chart. @return immutable snapshot */
    NcursesUi::TextChart getChart() { return chart; }
    /** Selects the chart glyphs. @param value True for default bars, False for ASCII */
    nothing setUnicode(bool value) { unicode = value; rendered_columns = -1; markDirty(); }
    /** Returns whether Unicode glyphs are requested. @return glyph mode */
    bool getUnicode() { return unicode; }
    /** Selects one-line sparklines or expanded bars. @param rows height from 1 to 64
        @throw CHART-HEIGHT-ERROR for invalid height, without changing the current setting
    */
    nothing setChartHeight(int rows) {
        if (rows < 1 || rows > 64) { throw "CHART-HEIGHT-ERROR", "Chart height must be between 1 and 64 rows"; }
        chart_height = rows; rendered_columns = -1; markDirty();
    }
    /** Returns the requested chart height. @return rows, default 1 for a sparkline */
    int getChartHeight() { return chart_height; }
    /** Includes inherited availability in presentation invalidation. @return needs repaint */
    bool needsOwnDraw() { return rendered_available != isAvailable() || ScrollableWidget::needsOwnDraw(); }
    /** Prepares the sparkline for the effective viewport before painting. @param window target */
    nothing draw(Ncurses::Window window) {
        prepareDrawViewport(window); sync(); ScrollableWidget::draw(window);
    }
    /** Reconciles hidden content. */
    nothing onDrawClipped() { sync(); ScrollableWidget::onDrawClipped(); }
    private nothing sync() {
        int columns = max(0, getViewportRect().cols); bool available = isAvailable();
        if (columns == rendered_columns && rendered_available == available) { return; }
        list<string> rows = (chart.getSummary(),);
        if (chart.getSamples()) {
            rows += "Samples (left to right):"; rows += chartRows(columns);
            rows += chart_height > 1 ? "Height: min to max; ? = missing sample"
                : unicode ? "Scale: ▁ min to █ max; ? = missing sample" : "Scale: .:-=+*#@ (min to max); ? = missing sample";
        }
        if (!available) { rows = map "\e[2m" + NcursesUi::TerminalText::plainAnsi($1) + "\e[0m", rows; }
        lines.setLines(rows);
        int final_columns = max(0, getViewportRect().cols);
        if (chart.getSamples() && columns != final_columns) {
            list<string> bars = chartRows(final_columns);
            for (int i = 0; i < bars.size(); ++i) { lines.setLine(2 + i, bars[i]); }
        }
        rendered_columns = final_columns; rendered_available = available;
    }
    private list<string> chartRows(int columns) {
        list<string> rows = chart_height == 1 ? (chart.sparkline(columns, unicode),) : chart.bars(columns, chart_height, unicode);
        return map styledSamples($1), rows;
    }
    private string styledSamples(string value) {
        string result = "";
        if (!isAvailable()) { return "\e[2m" + value + "\e[0m"; }
        for (int i = 0; i < value.length(); ++i) {
            string glyph = value.substr(i, 1); result += (glyph == "?" ? "\e[1;33m" : "\e[1;36m") + glyph + "\e[0m";
        }
        return result;
    }
}
} # namespace NcursesUi
