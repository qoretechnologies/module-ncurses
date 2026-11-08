#! @file BoxLayout.qc Vertical/horizontal layout manager

/*  BoxLayout.qc Copyright 2026 Qore Technologies, s.r.o.

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
/** Vertical or horizontal box layout manager.

    Distributes space among children based on their size policy:
    - @ref SizePolicy::Fixed and @ref SizePolicy::Minimum children get their
      preferred size (clamped to minimum).
    - @ref SizePolicy::Expanding children receive their minimum size and share remaining space equally.
    - If requests exceed available space, children are truncated in order; later
      children can receive zero space. Spacing is clamped to remaining space.
    - Hidden children receive no space.

    @par Example
    @code{.py}
    NcursesUi::BoxLayout layout(NcursesUi::Orientation::Vertical, 0);
    layout.apply(container);
    @endcode

    @since ncurses 1.0
*/
public class BoxLayout {
    private {
        #! layout orientation
        int orientation;
        #! spacing between children
        int spacing;
        *NcursesUi::Widget flow_content;
        *NcursesUi::Widget flow_follower;
    }

    /** Creates a new BoxLayout.
        @param orient Orientation::Vertical or Orientation::Horizontal
        @param sp spacing in rows/columns between children (default 0)
        @since ncurses 1.0
    */
    constructor(int orient = NcursesUi::Orientation::Vertical, int sp = 0) {
        orientation = orient;
        spacing = max(0, sp);
    }

    /** Returns the orientation.
        @since ncurses 1.0
    */
    int getOrientation() {
        return orientation;
    }

    /** Returns the spacing.
        @since ncurses 1.0
    */
    int getSpacing() {
        return spacing;
    }

    /** Places a follower immediately after short content in a vertical layout.
        The expanding content receives at most its normal allocation, shrinking to
        its width-dependent preferred height (respecting its minimum). Unused rows
        move after the follower, so later children such as status bars stay in place.
        Overflow keeps the normal allocation. Hidden pairs use ordinary layout.
        @param content expanding content widget, or NOTHING to disable
        @param follower the immediately following child, or NOTHING to disable
        @throw LAYOUT-FLOW-ERROR for an incomplete pair, identical widgets, a horizontal
        layout, or non-expanding content; apply() also validates direct-child adjacency
        before changing frames
        @par Example
        @code{.py}
        NcursesUi::BoxLayout layout();
        layout.setContentFlow(transcript, editor);
        layout.apply(root);
        @endcode
    */
    nothing setContentFlow(*NcursesUi::Widget content, *NcursesUi::Widget follower) {
        if (!!content != !!follower || (content && (content == follower
                || orientation != NcursesUi::Orientation::Vertical
                || content.getVSizePolicy() != NcursesUi::SizePolicy::Expanding))) {
            throw "LAYOUT-FLOW-ERROR", "Content flow requires distinct content and follower widgets in a vertical layout with expanding content";
        }
        flow_content = content; flow_follower = follower;
    }

    /** Applies this layout to a container widget's children.

        Reads the container's content rect and distributes space along
        the layout axis. Each child's frame is set accordingly.

        @param container the widget whose children should be laid out
        @since ncurses 1.0
    */
    nothing apply(NcursesUi::Widget container) {
        list<NcursesUi::Widget> kids = container.getChildren();
        if (flow_content) {
            bool adjacent = False;
            for (int i = 0; i + 1 < kids.size(); ++i) {
                if (kids[i] == flow_content && kids[i + 1] == flow_follower) { adjacent = True; break; }
            }
            if (!adjacent || flow_content.getVSizePolicy() != NcursesUi::SizePolicy::Expanding) {
                throw "LAYOUT-FLOW-ERROR", "Content flow requires adjacent direct children and expanding content";
            }
        }
        if (!kids.size()) {
            return;
        }

        hash<NcursesUi::Rect> area = container.contentRect();

        # collect visible children
        list<NcursesUi::Widget> visible = ();
        foreach NcursesUi::Widget child in (kids) {
            if (child.isVisible()) {
                visible += child;
            }
        }

        if (!visible.size()) {
            return;
        }

        if (orientation == NcursesUi::Orientation::Vertical) {
            layoutVertical(visible, area);
        } else {
            layoutHorizontal(visible, area);
        }

        # recursively layout children
        foreach NcursesUi::Widget child in (visible) {
            child.layout();
        }
    }

    private nothing layoutVertical(list<NcursesUi::Widget> visible, hash<NcursesUi::Rect> area) {
        int total_spacing = spacing * (visible.size() - 1);
        int available = max(0, area.rows - total_spacing);

        # calculate fixed space
        int fixed_total = 0;
        int expanding_count = 0;
        foreach NcursesUi::Widget child in (visible) {
            int policy = child.getVSizePolicy();
            if (policy == NcursesUi::SizePolicy::Fixed || policy == NcursesUi::SizePolicy::Minimum) {
                int pref = child.getPreferredSizeForWidth(area.cols).rows;
                int mn = child.getMinimumSize().rows;
                int size = max(0, max(mn, pref));
                fixed_total += size;
            } else {
                fixed_total += max(0, child.getMinimumSize().rows);
                expanding_count += 1;
            }
        }

        int expanding_space = max(0, available - fixed_total);
        int per_expanding = expanding_count > 0 ? expanding_space / expanding_count : 0;
        int remainder = expanding_count > 0 ? expanding_space % expanding_count : 0;

        int cur_y = area.y;
        int idx = 0;
        int flow_gap = 0;
        bool flowing = flow_content && flow_content.isVisible() && flow_follower.isVisible();
        foreach NcursesUi::Widget child in (visible) {
            int policy = child.getVSizePolicy();
            int child_rows;
            if (policy == NcursesUi::SizePolicy::Fixed || policy == NcursesUi::SizePolicy::Minimum) {
                int pref = child.getPreferredSizeForWidth(area.cols).rows;
                int mn = child.getMinimumSize().rows;
                child_rows = max(0, max(mn, pref));
            } else {
                child_rows = max(0, child.getMinimumSize().rows) + per_expanding;
                # distribute remainder to first expanding children
                if (remainder > 0) {
                    child_rows += 1;
                    remainder -= 1;
                }
            }

            child_rows = min(child_rows, max(0, area.y + area.rows - cur_y));
            if (flowing && child == flow_content) {
                int preferred = max(0, max(child.getMinimumSize().rows, child.getPreferredSizeForWidth(area.cols).rows));
                flow_gap = max(0, child_rows - preferred);
                child_rows -= flow_gap;
            }
            child.setFrame(NcursesUi::Geometry::makeRect(cur_y, area.x, child_rows, area.cols));
            cur_y += child_rows;
            if (flowing && child == flow_follower) { cur_y += flow_gap; }
            idx += 1;
            if (idx < visible.size()) {
                cur_y = min(area.y + area.rows, cur_y + spacing);
            }
        }
    }

    private nothing layoutHorizontal(list<NcursesUi::Widget> visible, hash<NcursesUi::Rect> area) {
        int total_spacing = spacing * (visible.size() - 1);
        int available = max(0, area.cols - total_spacing);

        # calculate fixed space
        int fixed_total = 0;
        int expanding_count = 0;
        foreach NcursesUi::Widget child in (visible) {
            int policy = child.getHSizePolicy();
            if (policy == NcursesUi::SizePolicy::Fixed || policy == NcursesUi::SizePolicy::Minimum) {
                int pref = child.getPreferredSize().cols;
                int mn = child.getMinimumSize().cols;
                int size = max(0, max(mn, pref));
                fixed_total += size;
            } else {
                fixed_total += max(0, child.getMinimumSize().cols);
                expanding_count += 1;
            }
        }

        int expanding_space = max(0, available - fixed_total);
        int per_expanding = expanding_count > 0 ? expanding_space / expanding_count : 0;
        int remainder = expanding_count > 0 ? expanding_space % expanding_count : 0;

        int cur_x = area.x;
        int idx = 0;
        foreach NcursesUi::Widget child in (visible) {
            int policy = child.getHSizePolicy();
            int child_cols;
            if (policy == NcursesUi::SizePolicy::Fixed || policy == NcursesUi::SizePolicy::Minimum) {
                int pref = child.getPreferredSize().cols;
                int mn = child.getMinimumSize().cols;
                child_cols = max(0, max(mn, pref));
            } else {
                child_cols = max(0, child.getMinimumSize().cols) + per_expanding;
                if (remainder > 0) {
                    child_cols += 1;
                    remainder -= 1;
                }
            }

            child_cols = min(child_cols, max(0, area.x + area.cols - cur_x));
            child.setFrame(NcursesUi::Geometry::makeRect(area.y, cur_x, area.rows, child_cols));
            cur_x += child_cols;
            idx += 1;
            if (idx < visible.size()) {
                cur_x = min(area.x + area.cols, cur_x + spacing);
            }
        }
    }
}

} # namespace NcursesUi
