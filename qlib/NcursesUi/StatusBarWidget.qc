#! @file StatusBarWidget.qc Status bar with styled segments

/*  StatusBarWidget.qc Copyright 2026 Qore Technologies, s.r.o.

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

/** Status bar widget with styled segments.

    Displays left-aligned and right-aligned text segments with
    configurable styles. Segments are truncated to fit the available
    width.

    @par Segment hash keys
    - \c text: the text to display
    - \c style: optional hash with fg, bg, attrs keys
    - \c align: "left" (default) or "right"

    @since ncurses 2.0
*/
public namespace NcursesUi {
public class StatusBarWidget inherits NcursesUi::Widget {
    private {
        #! list of segment hashes
        list<hash<auto>> segments = ();
        #! background style
        hash<auto> bg_style = {"fg": Ncurses::Color::White, "bg": Ncurses::Color::Blue};
        #! spacing between consecutive segments (in columns)
        int segment_spacing = 1;
    }

    /** Creates a new StatusBarWidget.
        @since ncurses 2.0
    */
    constructor() {
        setVSizePolicy(NcursesUi::SizePolicy::Fixed);
        setMinimumSize(1, 1);
        setPreferredSize(1, 0);
    }

    /** Sets the segments.
        @param segs list of segment hashes
        @since ncurses 2.0
    */
    nothing setSegments(list<hash<auto>> segs) {
        segments = segs;
        markDirty();
    }

    /** Returns the segments.
        @since ncurses 2.0
    */
    list<hash<auto>> getSegments() {
        return segments;
    }

    /** Sets the background style.
        @param style the style hash
        @since ncurses 2.0
    */
    nothing setBackgroundStyle(hash<auto> style) {
        bg_style = style;
        markDirty();
    }

    /** Sets the spacing between consecutive segments.
        @param spacing number of columns between segments
        @since ncurses 2.0
    */
    nothing setSegmentSpacing(int spacing) {
        segment_spacing = spacing;
        markDirty();
    }

    /** Returns the segment spacing.
        @since ncurses 2.0
    */
    int getSegmentSpacing() {
        return segment_spacing;
    }

    /** Draws the status bar.
        @param w the window
        @since ncurses 2.0
    */
    nothing draw(Ncurses::Window w) {
        hash<NcursesUi::Rect> cr = contentRect();
        int row = cr.y;
        int width = cr.cols;

        # fill background
        w.drawHLine(row, cr.x, width, " ", bg_style);

        # separate left and right segments
        list<hash<auto>> left_segs = ();
        list<hash<auto>> right_segs = ();
        foreach hash<auto> seg in (segments) {
            if (seg.align == "right") {
                right_segs += seg;
            } else {
                left_segs += seg;
            }
        }

        # draw left segments
        int left_pos = cr.x;
        for (int li = 0; li < left_segs.size(); ++li) {
            string text = left_segs[li].text ?? "";
            if (left_pos + text.length() > cr.x + width) {
                int avail = cr.x + width - left_pos;
                if (avail > 0) {
                    text = text.substr(0, avail);
                } else {
                    break;
                }
            }
            hash<auto> style = left_segs[li].style ?? bg_style;
            w.drawText(row, left_pos, text, style);
            left_pos += text.length();
            # add spacing after each segment except the last
            if (li < left_segs.size() - 1) {
                left_pos += segment_spacing;
            }
        }

        # draw right segments (from right edge)
        int right_pos = cr.x + width;
        # reverse iterate for right-to-left placement
        for (int i = right_segs.size() - 1; i >= 0; --i) {
            string text = right_segs[i].text ?? "";
            # account for spacing before this segment (except the rightmost)
            int spacing = (i < right_segs.size() - 1) ? segment_spacing : 0;
            int start = right_pos - spacing - text.length();
            if (start < left_pos) {
                # truncate from the left side of right text
                int avail = right_pos - spacing - left_pos;
                if (avail > 0) {
                    text = text.substr(text.length() - avail);
                    start = left_pos;
                } else {
                    break;
                }
            }
            hash<auto> style = right_segs[i].style ?? bg_style;
            w.drawText(row, start, text, style);
            right_pos = start;
        }
    }
}

} # namespace NcursesUi
