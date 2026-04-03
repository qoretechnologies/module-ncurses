#! @file SplitLayout.qc Two-pane split layout manager

/*  SplitLayout.qc Copyright 2026 Qore Technologies, s.r.o.

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

/** Two-pane split layout manager.

    Splits the container into two panes using either a ratio or a
    fixed size for one pane. Supports both vertical (top/bottom) and
    horizontal (left/right) orientation.

    The layout operates on the first two visible children of the
    container. Additional children are ignored.

    @par Example
    @code
    NcursesUi::SplitLayout split(NcursesUi::Orientation::Vertical);
    split.setSplitRatio(0.7);
    split.apply(container);
    @endcode

    @since ncurses 2.0
*/
public namespace NcursesUi {
public class SplitLayout {
    private {
        #! layout orientation
        int orientation;
        #! split ratio (0.0 to 1.0) for pane 0; -1 if using fixed size
        float split_ratio = 0.5;
        #! fixed size in rows/cols; -1 if using ratio
        int fixed_size = -1;
        #! which pane has fixed size (0 or 1)
        int fixed_pane = 0;
    }

    /** Creates a new SplitLayout.
        @param orient Orientation::Vertical or Orientation::Horizontal
        @since ncurses 2.0
    */
    constructor(int orient = NcursesUi::Orientation::Vertical) {
        orientation = orient;
    }

    /** Returns the orientation.
        @since ncurses 2.0
    */
    int getOrientation() {
        return orientation;
    }

    /** Sets the split ratio for pane 0.

        A ratio of 0.7 means pane 0 gets 70% of the space.
        Clears any fixed size setting.

        @param ratio value between 0.0 and 1.0
        @since ncurses 2.0
    */
    nothing setSplitRatio(float ratio) {
        if (ratio < 0.0) {
            ratio = 0.0;
        }
        if (ratio > 1.0) {
            ratio = 1.0;
        }
        split_ratio = ratio;
        fixed_size = -1;
    }

    /** Returns the split ratio.
        @since ncurses 2.0
    */
    float getSplitRatio() {
        return split_ratio;
    }

    /** Sets a fixed size for one pane.

        The other pane gets the remaining space. Clears the ratio setting.

        @param size fixed size in rows (vertical) or cols (horizontal)
        @param pane which pane has fixed size (0 or 1)
        @since ncurses 2.0
    */
    nothing setFixedSize(int size, int pane) {
        fixed_size = max(0, size);
        fixed_pane = pane == 1 ? 1 : 0;
    }

    /** Applies this layout to a container widget's first two visible children.
        @param container the widget whose children should be laid out
        @since ncurses 2.0
    */
    nothing apply(NcursesUi::Widget container) {
        list<NcursesUi::Widget> kids = container.getChildren();
        if (!kids.size()) {
            return;
        }

        # collect first two visible children
        list<NcursesUi::Widget> visible = ();
        foreach NcursesUi::Widget child in (kids) {
            if (child.isVisible()) {
                visible += child;
                if (visible.size() >= 2) {
                    break;
                }
            }
        }

        hash<NcursesUi::Rect> area = container.contentRect();

        if (visible.size() == 1) {
            # single child gets full area
            visible[0].setFrame(area);
            visible[0].layout();
            return;
        }

        if (visible.size() < 2) {
            return;
        }

        if (orientation == NcursesUi::Orientation::Vertical) {
            splitVertical(visible[0], visible[1], area);
        } else {
            splitHorizontal(visible[0], visible[1], area);
        }

        visible[0].layout();
        visible[1].layout();
    }

    private nothing splitVertical(NcursesUi::Widget pane0, NcursesUi::Widget pane1,
            hash<NcursesUi::Rect> area) {
        int total = area.rows;
        int size0;
        int size1;

        if (fixed_size >= 0) {
            if (fixed_pane == 0) {
                size0 = min(fixed_size, total);
                size1 = max(0, total - size0);
            } else {
                size1 = min(fixed_size, total);
                size0 = max(0, total - size1);
            }
        } else {
            size0 = int(total * split_ratio);
            size1 = total - size0;
        }

        # respect minimum sizes
        int min0 = pane0.getMinimumSize().rows;
        int min1 = pane1.getMinimumSize().rows;
        if (size0 < min0 && total >= min0 + min1) {
            size0 = min0;
            size1 = total - size0;
        }
        if (size1 < min1 && total >= min0 + min1) {
            size1 = min1;
            size0 = total - size1;
        }

        pane0.setFrame(NcursesUi::Geometry::makeRect(area.y, area.x, size0, area.cols));
        pane1.setFrame(NcursesUi::Geometry::makeRect(area.y + size0, area.x, size1, area.cols));
    }

    private nothing splitHorizontal(NcursesUi::Widget pane0, NcursesUi::Widget pane1,
            hash<NcursesUi::Rect> area) {
        int total = area.cols;
        int size0;
        int size1;

        if (fixed_size >= 0) {
            if (fixed_pane == 0) {
                size0 = min(fixed_size, total);
                size1 = max(0, total - size0);
            } else {
                size1 = min(fixed_size, total);
                size0 = max(0, total - size1);
            }
        } else {
            size0 = int(total * split_ratio);
            size1 = total - size0;
        }

        # respect minimum sizes
        int min0 = pane0.getMinimumSize().cols;
        int min1 = pane1.getMinimumSize().cols;
        if (size0 < min0 && total >= min0 + min1) {
            size0 = min0;
            size1 = total - size0;
        }
        if (size1 < min1 && total >= min0 + min1) {
            size1 = min1;
            size0 = total - size1;
        }

        pane0.setFrame(NcursesUi::Geometry::makeRect(area.y, area.x, area.rows, size0));
        pane1.setFrame(NcursesUi::Geometry::makeRect(area.y, area.x + size0, area.rows, size1));
    }
}

} # namespace NcursesUi
