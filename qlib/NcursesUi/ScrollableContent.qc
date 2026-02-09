#! @file ScrollableContent.qc Abstract content provider for ScrollableWidget

/*  ScrollableContent.qc Copyright 2026 Qore Technologies, s.r.o.

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

/** Abstract content provider for @ref ScrollableWidget.

    Subclasses implement the content dimensions and drawing logic.
    The @ref ScrollableWidget handles viewport management and scrollbar
    rendering.

    @since ncurses 2.0
*/
public class NcursesUi::ScrollableContent {
    /** Returns the total number of content rows.
        @since ncurses 2.0
    */
    abstract int totalRows();

    /** Returns the total number of content columns.
        @since ncurses 2.0
    */
    abstract int totalCols();

    /** Draws the visible portion of the content.
        @param w the window to draw into
        @param scrollY vertical scroll offset (first visible row)
        @param scrollX horizontal scroll offset (first visible column)
        @param visibleRows number of visible rows
        @param visibleCols number of visible columns
        @param startY the window row to start drawing at
        @param startX the window column to start drawing at
        @since ncurses 2.0
    */
    abstract nothing drawContent(Ncurses::Window w, int scrollY, int scrollX,
        int visibleRows, int visibleCols, int startY, int startX);
}
