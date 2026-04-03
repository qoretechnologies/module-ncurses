#! @file Geometry.qc Static geometry helper methods for Rect and Insets

/*  Geometry.qc Copyright 2026 Qore Technologies, s.r.o.

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

/** Static geometry helper methods for @ref Rect and @ref Insets types.

    @since ncurses 2.0
*/
public namespace NcursesUi {
public class Geometry {
    /** Check if a point is inside a Rect.
        @param rect the rectangle to test
        @param py the row coordinate
        @param px the column coordinate
        @return True if the point is inside the rectangle

        @since ncurses 2.0
    */
    static bool rectContains(hash<NcursesUi::Rect> rect, int py, int px) {
        return py >= rect.y && py < rect.y + rect.rows
            && px >= rect.x && px < rect.x + rect.cols;
    }

    /** Create a Rect from position and size.
        @param y row position
        @param x column position
        @param rows number of rows
        @param cols number of columns
        @return new Rect

        @since ncurses 2.0
    */
    static hash<NcursesUi::Rect> makeRect(int y, int x, int rows, int cols) {
        return <NcursesUi::Rect>{
            "y": y,
            "x": x,
            "rows": rows,
            "cols": cols,
        };
    }

    /** Create an Insets from values.
        @param top top inset
        @param bottom bottom inset
        @param left left inset
        @param right right inset
        @return new Insets

        @since ncurses 2.0
    */
    static hash<NcursesUi::Insets> makeInsets(int top, int bottom, int left, int right) {
        return <NcursesUi::Insets>{
            "top": top,
            "bottom": bottom,
            "left": left,
            "right": right,
        };
    }

    /** Shrink a Rect by Insets.
        @param rect the outer rectangle
        @param insets the insets to apply
        @return new Rect that is the inner content area

        @since ncurses 2.0
    */
    static hash<NcursesUi::Rect> rectInset(hash<NcursesUi::Rect> rect, hash<NcursesUi::Insets> insets) {
        int y = rect.y + insets.top;
        int x = rect.x + insets.left;
        int rows = max(0, rect.rows - insets.top - insets.bottom);
        int cols = max(0, rect.cols - insets.left - insets.right);
        return <NcursesUi::Rect>{
            "y": y,
            "x": x,
            "rows": rows,
            "cols": cols,
        };
    }
}

} # namespace NcursesUi
