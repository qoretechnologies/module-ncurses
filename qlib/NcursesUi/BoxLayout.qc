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

/** Vertical or horizontal box layout manager.

    Distributes space among children based on their size policy:
    - @ref SizePolicy::Fixed and @ref SizePolicy::Minimum children get their
      preferred size (clamped to minimum).
    - @ref SizePolicy::Expanding children share remaining space equally.
    - Hidden children receive no space.

    @par Example
    @code
    NcursesUi::BoxLayout layout(NcursesUi::Orientation::Vertical, 0);
    layout.apply(container);
    @endcode

    @since ncurses 2.0
*/
public class NcursesUi::BoxLayout {
    private {
        #! layout orientation
        int orientation;
        #! spacing between children
        int spacing;
    }

    /** Creates a new BoxLayout.
        @param orient Orientation::Vertical or Orientation::Horizontal
        @param sp spacing in rows/columns between children (default 0)
        @since ncurses 2.0
    */
    constructor(int orient = NcursesUi::Orientation::Vertical, int sp = 0) {
        orientation = orient;
        spacing = sp;
    }

    /** Returns the orientation.
        @since ncurses 2.0
    */
    int getOrientation() {
        return orientation;
    }

    /** Returns the spacing.
        @since ncurses 2.0
    */
    int getSpacing() {
        return spacing;
    }

    /** Applies this layout to a container widget's children.

        Reads the container's content rect and distributes space along
        the layout axis. Each child's frame is set accordingly.

        @param container the widget whose children should be laid out
        @since ncurses 2.0
    */
    nothing apply(NcursesUi::Widget container) {
        list<NcursesUi::Widget> kids = container.getChildren();
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
                int pref = child.getPreferredSize().rows;
                int mn = child.getMinimumSize().rows;
                int size = max(mn, pref);
                fixed_total += size;
            } else {
                expanding_count += 1;
            }
        }

        int expanding_space = max(0, available - fixed_total);
        int per_expanding = expanding_count > 0 ? expanding_space / expanding_count : 0;
        int remainder = expanding_count > 0 ? expanding_space % expanding_count : 0;

        int cur_y = area.y;
        int idx = 0;
        foreach NcursesUi::Widget child in (visible) {
            int policy = child.getVSizePolicy();
            int child_rows;
            if (policy == NcursesUi::SizePolicy::Fixed || policy == NcursesUi::SizePolicy::Minimum) {
                int pref = child.getPreferredSize().rows;
                int mn = child.getMinimumSize().rows;
                child_rows = max(mn, pref);
            } else {
                child_rows = per_expanding;
                # distribute remainder to first expanding children
                if (remainder > 0) {
                    child_rows += 1;
                    remainder -= 1;
                }
            }

            child.setFrame(NcursesUi::Geometry::makeRect(cur_y, area.x, child_rows, area.cols));
            cur_y += child_rows;
            idx += 1;
            if (idx < visible.size()) {
                cur_y += spacing;
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
                int size = max(mn, pref);
                fixed_total += size;
            } else {
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
                child_cols = max(mn, pref);
            } else {
                child_cols = per_expanding;
                if (remainder > 0) {
                    child_cols += 1;
                    remainder -= 1;
                }
            }

            child.setFrame(NcursesUi::Geometry::makeRect(area.y, cur_x, area.rows, child_cols));
            cur_x += child_cols;
            idx += 1;
            if (idx < visible.size()) {
                cur_x += spacing;
            }
        }
    }
}
