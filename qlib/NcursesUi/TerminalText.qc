#! @file TerminalText.qc Unicode terminal text layout helpers

/*  TerminalText.qc Copyright 2026 Qore Technologies, s.r.o.

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

#! Unicode-safe helpers for laying out unstyled terminal text
/** All width arguments and results are terminal display columns. Clipping
    iterates Unicode extended grapheme clusters, so combining sequences and
    joined characters are never split.

    @note These helpers accept plain text. Use @ref Qore::Ncurses::Ansi for
        strings containing ANSI SGR styling.
*/
public class TerminalText {
    /** Returns the terminal display width of plain text.
        @param text text to measure
        @return terminal display columns occupied by @p text
        @par Example
        @c displayWidth("ステップの例") returns 12.
    */
    static int displayWidth(string text) {
        return char_width(text);
    }

    /** Clips plain text at the right edge without splitting graphemes.
        @param text text to clip
        @param max_width maximum terminal display columns
        @return the longest leading grapheme sequence that fits
        @par Example
        @c clipRight("日本語", 4) returns @c "日本".
        @note A grapheme wider than the entire available width is omitted.
    */
    static string clipRight(string text, int max_width) {
        if (max_width <= 0) {
            return "";
        }
        if (displayWidth(text) <= max_width) {
            return text;
        }
        string out = "";
        int used = 0;
        foreach string grapheme in (graphemes(text)) {
            int width = displayWidth(grapheme);
            if (used + width > max_width) {
                break;
            }
            out += grapheme;
            used += width;
        }
        return out;
    }

    /** Clips plain text at the left edge without splitting graphemes.
        @param text text to clip
        @param max_width maximum terminal display columns
        @return the longest trailing grapheme sequence that fits
        @par Example
        @c clipLeft("日本語", 4) returns @c "本語".
        @note A grapheme wider than the entire available width is omitted.
    */
    static string clipLeft(string text, int max_width) {
        if (max_width <= 0) {
            return "";
        }
        if (displayWidth(text) <= max_width) {
            return text;
        }
        list<string> clusters = graphemes(text);
        string out = "";
        int used = 0;
        for (int i = clusters.size() - 1; i >= 0; --i) {
            int width = displayWidth(clusters[i]);
            if (used + width > max_width) {
                break;
            }
            out = clusters[i] + out;
            used += width;
        }
        return out;
    }

    /** Clips and right-pads plain text to an exact display width.
        @param text text to fit
        @param width requested terminal display columns
        @return clipped text followed by sufficient spaces
        @par Example
        @c fitRight("界", 4) returns a four-column string.
    */
    static string fitRight(string text, int width) {
        if (width <= 0) {
            return "";
        }
        string out = clipRight(text, width);
        return out + strmul(" ", width - displayWidth(out));
    }

    /** Clips and left-pads plain text to an exact display width.
        @param text text to fit
        @param width requested terminal display columns
        @return sufficient spaces followed by clipped text
        @par Example
        @c fitLeft("界", 4) returns a four-column string.
    */
    static string fitLeft(string text, int width) {
        if (width <= 0) {
            return "";
        }
        string out = clipLeft(text, width);
        return strmul(" ", width - displayWidth(out)) + out;
    }

    /** Returns a display-column window into plain text.
        @param text text to window
        @param start_col zero-based starting display column
        @param width maximum output display columns
        @return a grapheme-safe window padded to @p width
        @par Example
        @c columnSlice("A日本B", 1, 4) returns @c "日本".
        @note If @p start_col intersects a double-width grapheme, spaces
            represent the hidden cells because half a grapheme cannot be
            rendered.
    */
    static string columnSlice(string text, int start_col, int width) {
        if (width <= 0) {
            return "";
        }
        start_col = max(0, start_col);
        string out = "";
        int source_col = 0;
        int used = 0;
        foreach string grapheme in (graphemes(text)) {
            int grapheme_width = displayWidth(grapheme);
            int end_col = source_col + grapheme_width;
            if (end_col <= start_col) {
                source_col = end_col;
                continue;
            }
            if (source_col < start_col) {
                int hidden_tail = end_col - start_col;
                int spaces = min(hidden_tail, width - used);
                out += strmul(" ", spaces);
                used += spaces;
                source_col = end_col;
                if (used >= width) {
                    break;
                }
                continue;
            }
            if (used + grapheme_width > width) {
                break;
            }
            out += grapheme;
            used += grapheme_width;
            source_col = end_col;
        }
        return out + strmul(" ", width - used);
    }

    private static list<string> graphemes(string text) {
        return (text =~ x/(\X)/g) ?? ();
    }
}

} # namespace NcursesUi
