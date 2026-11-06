#! @file LineListContent.qc ScrollableContent backed by list<string>

/*  LineListContent.qc Copyright 2026 Qore Technologies, s.r.o.

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.
*/

public namespace NcursesUi {
/** A rendered row with its position in the original, ANSI-free logical line.
    @since ncurses 1.0
*/
public hashdecl WrappedTextRow {
    #! logical line index
    int line_idx;
    #! first source character in this row
    int start;
    #! one past the last source character in this row
    int end;
    #! styled row text
    string text;
}

# Internal segment index: logarithmic row lookup/update and constant-time maximum width.
class TextExtentIndex {
    private {
        int capacity = 1;
        int count = 0;
        list<int> sums = (0, 0);
        list<int> widths = (0, 0);
    }
    int size() { return count; }
    int total() { return sums[1]; }
    int maxWidth() { return widths[1]; }
    nothing assign(list<int> row_counts, list<int> column_widths = ()) {
        int next_capacity = 1;
        while (next_capacity < row_counts.size()) { next_capacity *= 2; }
        list<int> next_sums = (); list<int> next_widths = ();
        for (int i = 0; i < next_capacity; ++i) { next_sums += 0; next_widths += 0; }
        for (int i = 0; i < next_capacity; ++i) {
            next_sums += i < row_counts.size() ? row_counts[i] : 0;
            next_widths += i < column_widths.size() ? column_widths[i] : 0;
        }
        for (int i = next_capacity - 1; i > 0; --i) {
            next_sums[i] = next_sums[2 * i] + next_sums[2 * i + 1];
            next_widths[i] = max(next_widths[2 * i], next_widths[2 * i + 1]);
        }
        capacity = next_capacity; count = row_counts.size(); sums = next_sums; widths = next_widths;
    }
    nothing append(int rows, int width = 0) {
        if (count == capacity) {
            int next = capacity * 2;
            list<int> next_sums = (); list<int> next_widths = ();
            for (int i = 0; i < 2 * next; ++i) { next_sums += 0; next_widths += 0; }
            for (int i = 0; i < count; ++i) {
                next_sums[next + i] = sums[capacity + i];
                next_widths[next + i] = widths[capacity + i];
            }
            for (int i = next - 1; i > 0; --i) {
                next_sums[i] = next_sums[2 * i] + next_sums[2 * i + 1];
                next_widths[i] = max(next_widths[2 * i], next_widths[2 * i + 1]);
            }
            sums = next_sums; widths = next_widths; capacity = next;
        }
        ++count; set(count - 1, rows, width);
    }
    nothing set(int index, int rows, int width = 0) {
        @assert(index >= 0 && index < count);
        int node = capacity + index; sums[node] = rows; widths[node] = width;
        while (node > 1) {
            node /= 2;
            sums[node] = sums[2 * node] + sums[2 * node + 1];
            widths[node] = max(widths[2 * node], widths[2 * node + 1]);
        }
    }
    int prefix(int count) {
        int left = capacity; int right = capacity + max(0, min(count, self.count)); int total = 0;
        while (left < right) {
            if (left % 2) { total += sums[left++]; }
            if (right % 2) { total += sums[--right]; }
            left /= 2; right /= 2;
        }
        return total;
    }
    int find(int row) {
        if (row < 0 || row >= sums[1]) { return -1; }
        int node = 1;
        while (node < capacity) {
            int left = 2 * node;
            if (row < sums[left]) { node = left; }
            else { row -= sums[left]; node = left + 1; }
        }
        return node - capacity;
    }
}

class TextLineRecord {
    public {
        int id;
        string text;
        string plain;
        int width;
        bool visible = True;
    }
    constructor(int identity, string value) {
        id = identity; text = value;
        plain = NcursesUi::TerminalText::plainAnsi(value);
        width = Ncurses::Ansi::len(value);
    }
}

class TextLayoutCache {
    public {
        int width;
        NcursesUi::TextExtentIndex index();
        list<list<hash<NcursesUi::WrappedTextRow>>> rows = ();
    }
    constructor(int cols) { width = cols; }
    nothing assign(list<list<hash<NcursesUi::WrappedTextRow>>> value) {
        list<int> counts = map $1.size(), value; index.assign(counts); rows = value;
    }
    nothing append(list<hash<NcursesUi::WrappedTextRow>> value) {
        rows += (value,); index.append(value.size());
    }
    nothing replace(int line, list<hash<NcursesUi::WrappedTextRow>> value) {
        rows[line] = value; index.set(line, value.size());
    }
}

/** ScrollableContent backed by a list of strings.

    Supports ANSI color codes in the text. Uses
    @ref NcursesUi::TerminalText::drawAnsiSlice() "drawAnsiSlice()" to preserve
    styling and clip complete graphemes to the content rectangle.

    Word-wrap can be enabled via @ref setWordWrap(). When enabled, lines
    longer than the visible width are wrapped at word boundaries. The scroll
    position and total row count account for wrapped lines transparently.

    @since ncurses 1.0
*/
public class LineListContent inherits NcursesUi::ScrollableContent {
    private {
        list<*NcursesUi::TextLineRecord> lines = ();
        int first = 0;
        int next_id = 1;
        int revision = 0;
        int retention = 0;
        bool word_wrap = False;
        bool insertion_rows = False;
        int last_wrap_width = 0;
        NcursesUi::TextExtentIndex extents();
        hash<string, int> identities = {};
        hash<string, NcursesUi::TextLayoutCache> layouts = {};
        int wrap_count = 0;
    }
    /** Returns display rows at the prepared width. @return wrapped row count */
    int totalRows() { return layoutCache().index.total(); }
    /** Returns the maximum width, including after edits/removal. @return terminal cells */
    int totalCols() { return extents.maxWidth(); }
    /** Enables word wrapping. @param enabled True to wrap long lines */
    nothing setWordWrap(bool enabled) {
        if (word_wrap != enabled) { word_wrap = enabled; layouts = {}; ++revision; }
    }
    /** Reserves an empty caret row after exact-width lines for multiline editors.
        @param enabled True to include insertion rows in layout and hit testing
    */
    nothing setInsertionRows(bool enabled) {
        if (insertion_rows != enabled) { insertion_rows = enabled; layouts = {}; ++revision; }
    }
    /** Returns wrapping state. @return True when word wrapping is enabled */
    bool getWordWrap() { return word_wrap; }
    /** Returns the content generation for repaint detection. @return monotonic revision */
    int getRevision() { return revision; }
    /** Returns a logical line's first display row. @param line_idx logical index @return display row */
    int displayRowForLine(int line_idx) {
        return layoutCache().index.prefix(first + max(0, min(line_idx, lineCount())));
    }
    /** Atomically replaces all lines; replacement lines receive new identities.
        @param values logical lines
    */
    nothing setLines(list<string> values) {
        list<*NcursesUi::TextLineRecord> next = ();
        int id = next_id;
        foreach string value in (values) { next += new NcursesUi::TextLineRecord(id++, value); }
        NcursesUi::TextExtentIndex index(); hash<string, int> ids = {};
        list<int> counts = (); list<int> widths = ();
        for (int i = 0; i < next.size(); ++i) { counts += 1; widths += next[i].width; ids{string(next[i].id)} = i; }
        index.assign(counts, widths);
        lines = next; extents = index; identities = ids; first = 0; next_id = id; layouts = {};
        ++revision; trim();
    }
    /** Returns retained logical lines. @return source text including ANSI styles */
    list<string> getLines() {
        list<string> result = ();
        for (int i = first; i < lines.size(); ++i) { result += lines[i].text; }
        return result;
    }
    /** Returns one logical line. @param index logical index @return text or NOTHING */
    *string getLine(int index) { return index >= 0 && index < lineCount() ? lines[first + index].text : NOTHING; }
    /** Appends one logical line. @param line source text */
    nothing appendLine(string line) { appendLines((line,)); }
    /** Appends a batch with one content revision; validates/wraps before mutation.
        @param values logical lines
    */
    nothing appendLines(list<string> values) {
        if (!values) { return; }
        list<NcursesUi::TextLineRecord> next = (); int id = next_id;
        hash<string, list<list<hash<NcursesUi::WrappedTextRow>>>> prepared = {};
        foreach string value in (values) { next += new NcursesUi::TextLineRecord(id++, value); }
        foreach string key in (keys layouts) {
            list<list<hash<NcursesUi::WrappedTextRow>>> wrapped = ();
            foreach NcursesUi::TextLineRecord line in (next) { wrapped += (wrapLine(line, layouts{key}.width),); }
            prepared{key} = wrapped;
        }
        for (int i = 0; i < next.size(); ++i) {
            identities{string(next[i].id)} = lines.size(); lines += next[i]; extents.append(1, next[i].width);
            foreach string key in (keys layouts) { layouts{key}.append(prepared{key}[i]); }
        }
        next_id = id; ++revision; trim();
    }
    /** Removes all lines without reusing old identities. */
    nothing clear() { setLines(()); }
    /** Returns retained logical line count. @return count */
    int lineCount() { return lines.size() - first; }
    /** Replaces a valid logical line and retains its identity. @param idx logical index @param text source text */
    nothing setLine(int idx, string text) {
        if (idx < 0 || idx >= lineCount() || lines[first + idx].text == text) { return; }
        int physical = first + idx;
        NcursesUi::TextLineRecord next(lines[physical].id, text); next.visible = lines[physical].visible;
        hash<string, list<hash<NcursesUi::WrappedTextRow>>> prepared = {};
        foreach string key in (keys layouts) { prepared{key} = wrapLine(next, layouts{key}.width); }
        lines[physical] = next; extents.set(physical, next.visible ? 1 : 0, next.visible ? next.width : 0);
        foreach string key in (keys layouts) { layouts{key}.replace(physical, prepared{key}); }
        ++revision;
    }
    /** Hides or shows a logical line while retaining its identity and source text.
        @param index retained line index @param visible True to include the line in layout
    */
    nothing setLineVisible(int index, bool visible) {
        if (index < 0 || index >= lineCount()) { return; }
        int physical = first + index;
        if (lines[physical].visible == visible) { return; }
        NcursesUi::TextLineRecord next(lines[physical].id, lines[physical].text); next.visible = visible;
        hash<string, list<hash<NcursesUi::WrappedTextRow>>> prepared = {};
        foreach string key in (keys layouts) { prepared{key} = wrapLine(next, layouts{key}.width); }
        lines[physical] = next; extents.set(physical, visible ? 1 : 0, visible ? next.width : 0);
        foreach string key in (keys layouts) { layouts{key}.replace(physical, prepared{key}); }
        ++revision;
    }
    /** Removes a valid logical line. @param idx logical index */
    nothing removeLine(int idx) {
        if (idx < 0 || idx >= lineCount()) { return; }
        splice lines, first + idx, 1; reindex(); ++revision;
    }
    /** Inserts a logical line. @param idx clamped logical index @param text source text */
    nothing insertLine(int idx, string text) {
        idx = max(0, min(idx, lineCount()));
        if (idx == lineCount()) { appendLine(text); return; }
        NcursesUi::TextLineRecord next(next_id, text);
        splice lines, first + idx, 0, next; ++next_id; reindex(); ++revision; trim();
    }
    /** Limits retained lines; zero means unlimited. Existing content is trimmed immediately.
        @param maximum nonnegative limit
        @throw TEXT-RETENTION-ERROR for a negative limit
    */
    nothing setRetentionLimit(int maximum) {
        if (maximum < 0) { throw "TEXT-RETENTION-ERROR", "Retention must be nonnegative"; }
        retention = maximum; trim();
    }
    /** Returns a retained line's stable identity. @param line logical index @return ID or NOTHING */
    *int getLineId(int line) { return line >= 0 && line < lineCount() ? lines[first + line].id : NOTHING; }
    /** Locates a retained identity. @param id stable line ID @return logical index or -1 */
    int lineForId(int id) {
        *int index = identities{string(id)}; return exists index ? index - first : -1;
    }
    /** Returns deterministic layout work counters for diagnostics/benchmarks.
        @return wraps, cached widths and retained lines
    */
    hash<auto> getLayoutStats() { return {"wraps": wrap_count, "widths": layouts.size(), "lines": lineCount()}; }
    /** Prepares a display width. @param cols nonnegative terminal columns */
    nothing prepareViewport(int cols) { last_wrap_width = max(0, cols); layoutCache(); }
    /** Maps a logical source position to terminal cells, including exact-width insertion rows.
        @param line logical line @param offset ANSI-free character offset @return visual row/column, row -1 if invalid
    */
    hash<Ncurses::Position> sourceToVisual(int line, int offset) {
        if (line < 0 || line >= lineCount()) { return <Ncurses::Position>{"y": -1, "x": 0}; }
        NcursesUi::TextLayoutCache cache = layoutCache(); int physical = first + line;
        if (!lines[physical].visible) { return <Ncurses::Position>{"y": -1, "x": 0}; }
        string plain = lines[physical].plain;
        offset = NcursesReplUi::TextPosition::snapOffset(plain, offset);
        list<hash<NcursesUi::WrappedTextRow>> rows = cache.rows[physical];
        int row = 0;
        while (row + 1 < rows.size() && rows[row + 1].start <= offset) { ++row; }
        hash<NcursesUi::WrappedTextRow> entry = rows[row];
        int used = NcursesReplUi::TextPosition::columnForOffset(plain.substr(entry.start, entry.end - entry.start),
            min(offset, entry.end) - entry.start);
        int y = cache.index.prefix(physical) + row;
        if (word_wrap && cache.width > 0 && used >= cache.width && offset == plain.length()) {
            return <Ncurses::Position>{"y": y + 1, "x": 0};
        }
        return <Ncurses::Position>{"y": y, "x": used};
    }
    /** Resolves a hidden anchor to the preceding visible line, or the first following line.
        @param line logical source line @param offset character offset @return visible anchor or row -1 for empty content
    */
    hash<Ncurses::Position> sourceToVisibleAnchor(int line, int offset) {
        hash<Ncurses::Position> result = sourceToVisual(line, offset);
        if (result.y >= 0 || line < 0 || line >= lineCount()) { return result; }
        NcursesUi::TextLayoutCache cache = layoutCache();
        int preceding = cache.index.prefix(first + line);
        int physical = cache.index.find(max(0, preceding - 1));
        return physical < first ? result : sourceToVisual(physical - first, 0);
    }
    /** Maps a display cell to a logical grapheme boundary.
        @param row visual row @param col display column @return logical line/ANSI-free offset
    */
    hash<Ncurses::Position> visualToSource(int row, int col) {
        NcursesUi::TextLayoutCache cache = layoutCache();
        if (!lineCount() || !cache.index.total()) { return <Ncurses::Position>{"y": 0, "x": 0}; }
        row = max(0, min(row, cache.index.total() - 1));
        int physical = cache.index.find(row); @assert(physical >= first);
        hash<NcursesUi::WrappedTextRow> entry = cache.rows[physical][row - cache.index.prefix(physical)];
        int offset = entry.start + NcursesReplUi::TextPosition::offsetForColumn(
            lines[physical].plain.substr(entry.start, entry.end - entry.start), col);
        return <Ncurses::Position>{"y": physical - first, "x": offset};
    }
    /** Returns the source span and styled text for one display row.
        @param row visual row @return row descriptor, or NOTHING outside retained content
    */
    *hash<NcursesUi::WrappedTextRow> getVisualRow(int row) {
        NcursesUi::TextLayoutCache cache = layoutCache(); int physical = cache.index.find(row);
        if (physical < first) { return NOTHING; }
        hash<NcursesUi::WrappedTextRow> result = cache.rows[physical][row - cache.index.prefix(physical)];
        result.line_idx = physical - first; return result;
    }
    /** Draws a clipped styled viewport.
        @param w target window @param scrollY first row @param scrollX first column
        @param visibleRows height @param visibleCols width @param startY local row @param startX local column
    */
    nothing drawContent(Ncurses::Window w, int scrollY, int scrollX,
            int visibleRows, int visibleCols, int startY, int startX) {
        prepareViewport(visibleCols);
        if (visibleRows <= 0 || visibleCols <= 0) { return; }
        hash<Ncurses::Size> size = w.size(); int x = max(0, startX);
        int cols = min(startX + visibleCols, size.cols) - x;
        if (cols <= 0) { return; }
        NcursesUi::TextLayoutCache cache = layoutCache();
        int offset = (word_wrap ? 0 : max(0, scrollX)) + x - startX;
        for (int row = max(0, startY); row < min(startY + visibleRows, size.rows); ++row) {
            int visual = scrollY + row - startY;
            w.drawHLine(row, x, cols, " "); int physical = cache.index.find(visual);
            if (physical >= first) {
                hash<NcursesUi::WrappedTextRow> entry = cache.rows[physical][visual - cache.index.prefix(physical)];
                NcursesUi::TerminalText::drawAnsiSlice(w, row, x, entry.text, offset, cols);
            }
        }
    }
    private list<hash<NcursesUi::WrappedTextRow>> wrapLine(NcursesUi::TextLineRecord line, int width) {
        list<hash<NcursesUi::WrappedTextRow>> rows = ();
        if (!line.visible) { return rows; }
        list<string> wrapped = word_wrap && width > 0 && line.width > width
            ? Ncurses::Ansi::wrap(line.text, width) : (line.text,);
        int offset = 0;
        foreach string text in (wrapped) {
            string plain = NcursesUi::TerminalText::plainAnsi(text);
            int start = line.plain.find(plain, offset); @assert(start >= offset);
            offset = start + plain.length();
            rows += <NcursesUi::WrappedTextRow>{"line_idx": 0, "start": start, "end": offset, "text": text};
        }
        if (insertion_rows && word_wrap && width > 0 && rows
                && Ncurses::Ansi::len(rows[-1].text) == width) {
            rows += <NcursesUi::WrappedTextRow>{"line_idx": 0, "start": line.plain.length(),
                "end": line.plain.length(), "text": ""};
        }
        ++wrap_count; return rows;
    }
    private NcursesUi::TextLayoutCache layoutCache() {
        int width = word_wrap ? last_wrap_width : 0; string key = string(width);
        if (exists layouts{key}) { return layouts{key}; }
        NcursesUi::TextLayoutCache cache(width);
        list<list<hash<NcursesUi::WrappedTextRow>>> rows = ();
        for (int i = 0; i < lines.size(); ++i) { rows += (i < first ? () : wrapLine(lines[i], width),); }
        cache.assign(rows);
        # Keep full-width and scrollbar-width geometry without unbounded resize caches.
        if (layouts.size() >= 2) { layouts = {}; }
        layouts{key} = cache; return cache;
    }
    private nothing reindex() {
        NcursesUi::TextExtentIndex next(); hash<string, int> ids = {};
        for (int i = 0; i < lines.size(); ++i) {
            bool visible = i >= first && lines[i].visible;
            next.append(visible ? 1 : 0, visible ? lines[i].width : 0);
            if (i >= first) { ids{string(lines[i].id)} = i; }
        }
        extents = next; identities = ids; layouts = {};
    }
    private nothing trim() {
        if (!retention || lineCount() <= retention) { return; }
        while (lineCount() > retention) {
            remove identities{string(lines[first].id)};
            lines[first] = NOTHING; extents.set(first, 0);
            foreach string key in (keys layouts) { layouts{key}.replace(first, ()); }
            ++first;
        }
        ++revision;
        if (first >= max(256, lines.size() / 2)) {
            lines = lines[first .. lines.size() - 1]; first = 0; reindex();
        }
    }
}

} # namespace NcursesUi
