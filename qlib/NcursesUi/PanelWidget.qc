#! @file PanelWidget.qc Widget that owns an ncurses Panel

/*  PanelWidget.qc Copyright 2026 Qore Technologies, s.r.o.

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
/** Widget that owns an ncurses Panel.

    Unlike regular widgets that draw into their parent's window, a
    PanelWidget creates its own ncurses Panel for floating/overlapping
    content (popups, dialogs, menus).

    The panel is created when the widget is shown and destroyed when
    hidden or closed.

    @since ncurses 1.0
*/
public class PanelWidget inherits NcursesUi::Widget {
    private {
        *hash<NcursesUi::Rect> requested_frame;
        #! the ncurses session
        Ncurses::Session session;
        #! the panel (NOTHING when not shown)
        *Ncurses::Panel panel;
        #! the panel's window
        *Ncurses::Window win;
        #! panel title
        *string title;
        #! whether to draw a border
        bool has_border = True;
        #! whether the panel can be closed via [X]
        bool closable = False;
        #! column position of the close button
        int close_col = -1;
        #! length of the close button text
        int close_len = 0;
        #! whether to center the title in the border
        bool center_title = False;
    }

    /** Creates a new PanelWidget.
        @param s the ncurses session
        @param t optional title
        @since ncurses 1.0
    */
    constructor(Ncurses::Session s, *string t) {
        session = s;
        title = t;
        # panels have border padding by default
        if (has_border) {
            setPadding(NcursesUi::Geometry::makeInsets(1, 1, 1, 1));
        }
    }

    /** Returns the panel's window, or NOTHING if not created.
        @since ncurses 1.0
    */
    *Ncurses::Window getWindow() {
        return win;
    }

    /** Returns the ncurses session.
        @since ncurses 1.0
    */
    Ncurses::Session getSession() {
        return session;
    }

    /** Returns the content rectangle in panel-local coordinates.

        Unlike contentRect() which returns absolute screen coordinates,
        this returns coordinates relative to the panel window's origin
        (0,0 = top-left of the panel window). Use this when drawing into
        the panel's own window.

        @since ncurses 1.0
    */
    hash<NcursesUi::Rect> localContentRect() {
        hash<NcursesUi::Rect> cr = contentRect();
        hash<NcursesUi::Rect> f = getFrame();
        return NcursesUi::Geometry::makeRect(cr.y - f.y, cr.x - f.x, cr.rows, cr.cols);
    }

    /** Sets the title.
        @param t the new title
        @since ncurses 1.0
    */
    nothing setTitle(*string t) {
        title = t;
        markDirty();
    }

    /** Returns the title.
        @since ncurses 1.0
    */
    *string getTitle() {
        return title;
    }

    /** Sets whether the title is centered in the border.
        @param v True to center the title
        @since ncurses 1.0
    */
    nothing setCenterTitle(bool v) {
        center_title = v;
        markDirty();
    }

    /** Returns whether the title is centered.
        @since ncurses 1.0
    */
    bool getCenterTitle() {
        return center_title;
    }

    /** Sets whether a border is drawn.
        @param v True to draw a border
        @since ncurses 1.0
    */
    nothing setHasBorder(bool v) {
        has_border = v;
        if (v) {
            setPadding(NcursesUi::Geometry::makeInsets(1, 1, 1, 1));
        } else {
            setPadding(NcursesUi::Geometry::makeInsets(0, 0, 0, 0));
        }
        markDirty();
    }

    /** Returns whether a border is drawn.
        @since ncurses 1.0
    */
    bool getHasBorder() {
        return has_border;
    }

    /** Sets whether the panel shows a close button [X].
        @param v True to show close button
        @since ncurses 1.0
    */
    nothing setClosable(bool v) {
        closable = v;
        markDirty();
    }

    /** Returns whether the panel is closable.
        @since ncurses 1.0
    */
    bool isClosable() {
        return closable;
    }

    /** Creates the ncurses panel at the current frame position.
        @since ncurses 1.0
    */
    nothing createPanel() {
        if (!requested_frame) { requested_frame = getFrame(); }
        hash<Ncurses::Size> size = session.screen().size();
        hash<NcursesUi::Rect> f = NcursesUi::Geometry::intersect(visibleRect(),
            NcursesUi::Geometry::makeRect(0, 0, size.rows, size.cols));
        if (f.rows <= 0 || f.cols <= 0) { destroyPanel(); return; }
        # Prepare the replacement completely before releasing the current panel.
        Ncurses::Panel replacement(session, f.rows, f.cols, f.y, f.x);
        Ncurses::Window replacement_win = replacement.window();
        replacement_win.enableKeypad(True);
        replacement_win.setLeaveOk(False);
        if (isVisible()) { replacement.show(); replacement.top(); }
        else { replacement.hide(); }
        onDrawClipped();
        panel = replacement;
        win = replacement_win;
        setFrame(f);
        close_col = -1; close_len = 0;
        markDirty();
    }

    /** Destroys the ncurses panel.
        @since ncurses 1.0
    */
    nothing destroyPanel() {
        onDrawClipped();
        if (panel) {
            panel.hide();
            panel = NOTHING;
            win = NOTHING;
        }
        close_col = -1;
        close_len = 0;
    }

    /** Shows the panel and brings it to the front.
        If the panel doesn't exist yet, creates it.
        @since ncurses 1.0
    */
    nothing show() {
        if (!panel) {
            createPanel();
        } else {
            panel.show();
            panel.top();
        }
        setVisible(True);
    }

    /** Hides the panel.
        @since ncurses 1.0
    */
    nothing hide() {
        if (panel) {
            panel.hide();
        }
        setVisible(False);
    }

    /** Brings the panel to the front of the panel stack.
        @since ncurses 1.0
    */
    nothing bringToFront() {
        if (panel) {
            panel.top();
        }
    }

    /** Resizes the panel to a new frame.
        Destroys and recreates the panel.
        @param r the new frame rectangle
        @since ncurses 1.0
    */
    nothing resize(hash<NcursesUi::Rect> r) {
        hash<NcursesUi::Rect> old = getFrame();
        *hash<NcursesUi::Rect> old_requested = requested_frame;
        requested_frame = r;
        setFrame(r);
        if (panel) {
            try { createPanel(); } catch (hash<ExceptionInfo> ex) { requested_frame = old_requested; setFrame(old); rethrow; }
        }
        hash<NcursesUi::Rect> current = getFrame();
        foreach NcursesUi::Widget child in (getChildren()) {
            child.translate(current.y - old.y, current.x - old.x);
        }
    }

    /** Moves the panel and descendants, recreating its native window when open.
        @param dy row displacement
        @param dx column displacement
    */
    nothing translate(int dy, int dx) {
        hash<NcursesUi::Rect> frame = getFrame(); frame.y += dy; frame.x += dx;
        resize(frame);
    }

    /** Fits an active panel to the terminal, retaining its requested size for regrowth.
        @param rows terminal height
        @param cols terminal width
    */
    nothing fitToScreen(int rows, int cols) {
        hash<NcursesUi::Rect> desired = requested_frame ?? getFrame();
        hash<NcursesUi::Rect> r = desired;
        r.rows = max(0, min(rows, r.rows)); r.cols = max(0, min(cols, r.cols));
        r.y = max(0, min(r.y, rows - r.rows)); r.x = max(0, min(r.x, cols - r.cols));
        resize(r);
        requested_frame = desired;
        layout();
    }

    /** Draws the panel border and title.
        @param w the window to draw into (ignored; uses own window)
        @since ncurses 1.0
    */
    nothing draw(Ncurses::Window w) {
        if (!win) {
            return;
        }
        win.erase();
        if (has_border && getFrame().rows >= 2 && getFrame().cols >= 2) {
            win.box({"fg": Ncurses::Color::Blue});
            if (title) {
                hash<NcursesUi::Rect> f = getFrame();
                string decorated = " " + title + " ";
                int title_x;
                if (center_title) {
                    title_x = max(2, (f.cols
                        - TerminalText::displayWidth(decorated)) / 2);
                } else {
                    title_x = 2;
                }
                win.drawText(0, title_x, decorated,
                    {"fg": Ncurses::Color::Yellow, "attrs": Ncurses::Attr::Bold});
            }
            close_col = -1;
            close_len = 0;
            if (closable) {
                hash<NcursesUi::Rect> f = getFrame();
                string label = "[X]";
                close_len = TerminalText::displayWidth(label);
                close_col = max(1, f.cols - close_len - 2);
                win.drawText(0, close_col, label,
                    {"fg": Ncurses::Color::Red, "attrs": Ncurses::Attr::Bold});
            }
        }
        win.noutrefresh();
    }

    /** Draws this panel widget and all visible children.
        Uses the panel's own window instead of the parent's.
        @param w the parent window (ignored)
        @since ncurses 1.0
    */
    nothing drawTree(Ncurses::Window w) {
        if (!isVisible() || !win) {
            onDrawClipped(); return;
        }
        panel.show();
        bringToFront();
        draw(win);
        foreach NcursesUi::Widget child in (getChildren()) { child.drawTree(win); }
        win.noutrefresh();
        clearDirty();
    }

    /** Hides the native panel and releases descendant cursor requests when clipped. */
    nothing onDrawClipped() {
        if (panel) { panel.hide(); }
        Widget::onDrawClipped();
    }

    /** Tests if a mouse click hit the close button.
        @param mx the column coordinate (absolute)
        @param my_row the row coordinate (absolute)
        @return True if the close button was hit
        @since ncurses 1.0
    */
    bool isCloseHit(int mx, int my_row) {
        if (!closable || close_col < 0 || close_len <= 0) {
            return False;
        }
        hash<NcursesUi::Rect> f = getFrame();
        int local_x = mx - f.x;
        int local_y = my_row - f.y;
        if (local_y != 0) {
            return False;
        }
        return local_x >= close_col && local_x < close_col + close_len;
    }
}

} # namespace NcursesUi
