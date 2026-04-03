#! @file Widget.qc Base widget class for the NcursesUi toolkit

/*  Widget.qc Copyright 2026 Qore Technologies, s.r.o.

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

/** Base widget for the NcursesUi toolkit.

    Provides a tree structure (parent/children), geometry management,
    focus tracking, dirty-flag propagation, and event handling.

    Regular widgets draw into their parent's window using offset
    coordinates. @ref PanelWidget creates its own ncurses Panel for
    floating/overlapping content.

    @since ncurses 2.0
*/
public namespace NcursesUi {
public class Widget {
    private {
        #! parent widget (NOTHING for root)
        *NcursesUi::Widget parent_widget;
        #! ordered list of child widgets
        list<NcursesUi::Widget> children = ();

        #! geometry in absolute terminal coordinates
        hash<NcursesUi::Rect> frame = <NcursesUi::Rect>{};
        #! padding insets
        hash<NcursesUi::Insets> padding = <NcursesUi::Insets>{};

        #! visibility flag
        bool visible = True;
        #! whether this widget can receive focus
        bool focusable = False;
        #! whether this widget currently has focus
        bool focused = False;
        #! whether this widget needs redrawing
        bool dirty = True;

        #! horizontal size policy
        int h_size_policy = NcursesUi::SizePolicy::Expanding;
        #! vertical size policy
        int v_size_policy = NcursesUi::SizePolicy::Expanding;
        #! minimum size (rows, cols)
        hash<NcursesUi::Rect> min_size = <NcursesUi::Rect>{"rows": 0, "cols": 0};
        #! preferred size (rows, cols)
        hash<NcursesUi::Rect> pref_size = <NcursesUi::Rect>{"rows": 0, "cols": 0};
    }

    # ---- Tree management ----

    /** Returns the parent widget or NOTHING.
        @since ncurses 2.0
    */
    *NcursesUi::Widget getParent() {
        return parent_widget;
    }

    /** Returns the list of child widgets.
        @since ncurses 2.0
    */
    list<NcursesUi::Widget> getChildren() {
        return children;
    }

    /** Adds a child widget. Sets the child's parent to this widget.
        @param child the widget to add
        @since ncurses 2.0
    */
    nothing addChild(NcursesUi::Widget child) {
        child.setParent(self);
        children += child;
        markDirty();
    }

    /** Removes a child widget. Clears the child's parent reference.
        @param child the widget to remove
        @since ncurses 2.0
    */
    nothing removeChild(NcursesUi::Widget child) {
        list<NcursesUi::Widget> out = ();
        foreach NcursesUi::Widget c in (children) {
            if (c != child) {
                out += c;
            }
        }
        children = out;
        child.clearParent();
        markDirty();
    }

    /** Sets the parent reference (called by addChild).
        @param p the parent widget
        @since ncurses 2.0
    */
    nothing setParent(NcursesUi::Widget p) {
        parent_widget = p;
    }

    /** Clears the parent reference (called by removeChild).
        @since ncurses 2.0
    */
    nothing clearParent() {
        parent_widget = NOTHING;
    }

    /** Returns the number of children.
        @since ncurses 2.0
    */
    int childCount() {
        return children.size();
    }

    # ---- Geometry ----

    /** Sets the widget frame (absolute terminal coordinates).
        @param r the new frame rectangle
        @since ncurses 2.0
    */
    nothing setFrame(hash<NcursesUi::Rect> r) {
        frame = r;
        markDirty();
    }

    /** Sets the widget frame from individual values.
        @param y row position
        @param x column position
        @param rows height
        @param cols width
        @since ncurses 2.0
    */
    nothing setFrameValues(int y, int x, int rows, int cols) {
        frame = NcursesUi::Geometry::makeRect(y, x, rows, cols);
        markDirty();
    }

    /** Returns the widget frame rectangle.
        @since ncurses 2.0
    */
    hash<NcursesUi::Rect> getFrame() {
        return frame;
    }

    /** Sets the padding insets.
        @param i the new insets
        @since ncurses 2.0
    */
    nothing setPadding(hash<NcursesUi::Insets> i) {
        padding = i;
        markDirty();
    }

    /** Returns the content rectangle (frame minus padding).
        @since ncurses 2.0
    */
    hash<NcursesUi::Rect> contentRect() {
        return NcursesUi::Geometry::rectInset(frame, padding);
    }

    /** Tests if a point is inside this widget's frame.
        @param py the row coordinate
        @param px the column coordinate
        @return True if the point is inside
        @since ncurses 2.0
    */
    bool hitTest(int py, int px) {
        if (!visible) {
            return False;
        }
        return NcursesUi::Geometry::rectContains(frame, py, px);
    }

    # ---- State ----

    /** Sets visibility.
        @param v True to show, False to hide
        @since ncurses 2.0
    */
    nothing setVisible(bool v) {
        if (visible != v) {
            visible = v;
            markDirty();
        }
    }

    /** Returns visibility.
        @since ncurses 2.0
    */
    bool isVisible() {
        return visible;
    }

    /** Sets whether this widget can receive focus.
        @param v True to make focusable
        @since ncurses 2.0
    */
    nothing setFocusable(bool v) {
        focusable = v;
    }

    /** Returns whether this widget can receive focus.
        @since ncurses 2.0
    */
    bool isFocusable() {
        return focusable && visible;
    }

    /** Sets the focused state directly.
        @param v True to set focused
        @since ncurses 2.0
    */
    nothing setFocused(bool v) {
        if (focused != v) {
            focused = v;
            markDirty();
            if (v) {
                onFocusIn();
            } else {
                onFocusOut();
            }
        }
    }

    /** Returns whether this widget has focus.
        @since ncurses 2.0
    */
    bool hasFocus() {
        return focused;
    }

    # ---- Dirty flag ----

    /** Marks this widget and all ancestors as dirty.
        @since ncurses 2.0
    */
    nothing markDirty() {
        dirty = True;
        if (parent_widget) {
            parent_widget.markDirty();
        }
    }

    /** Returns whether the widget needs redrawing.
        @since ncurses 2.0
    */
    bool isDirty() {
        return dirty;
    }

    /** Clears the dirty flag for this widget only.
        @since ncurses 2.0
    */
    nothing clearDirty() {
        dirty = False;
    }

    # ---- Size policy ----

    /** Sets the horizontal size policy.
        @param p the policy value
        @since ncurses 2.0
    */
    nothing setHSizePolicy(int p) {
        h_size_policy = p;
    }

    /** Returns the horizontal size policy.
        @since ncurses 2.0
    */
    int getHSizePolicy() {
        return h_size_policy;
    }

    /** Sets the vertical size policy.
        @param p the policy value
        @since ncurses 2.0
    */
    nothing setVSizePolicy(int p) {
        v_size_policy = p;
    }

    /** Returns the vertical size policy.
        @since ncurses 2.0
    */
    int getVSizePolicy() {
        return v_size_policy;
    }

    /** Sets the minimum size.
        @param rows minimum rows
        @param cols minimum columns
        @since ncurses 2.0
    */
    nothing setMinimumSize(int rows, int cols) {
        min_size = <NcursesUi::Rect>{"rows": rows, "cols": cols};
    }

    /** Returns the minimum size.
        @since ncurses 2.0
    */
    hash<NcursesUi::Rect> getMinimumSize() {
        return min_size;
    }

    /** Sets the preferred size.
        @param rows preferred rows
        @param cols preferred columns
        @since ncurses 2.0
    */
    nothing setPreferredSize(int rows, int cols) {
        pref_size = <NcursesUi::Rect>{"rows": rows, "cols": cols};
    }

    /** Returns the preferred size.
        @since ncurses 2.0
    */
    hash<NcursesUi::Rect> getPreferredSize() {
        return pref_size;
    }

    # ---- Layout ----

    /** Layout override point. Called when the widget's frame changes.
        Subclasses should override to position children.
        @since ncurses 2.0
    */
    nothing layout() {
        # default: no-op; subclasses override
    }

    # ---- Drawing ----

    /** Draw override point. Called when the widget needs to be redrawn.
        @param w the window to draw into
        @since ncurses 2.0
    */
    nothing draw(Ncurses::Window w) {
        # default: no-op; subclasses override
    }

    /** Draws this widget and all visible children.
        @param w the window to draw into
        @since ncurses 2.0
    */
    nothing drawTree(Ncurses::Window w) {
        if (!visible) {
            return;
        }
        draw(w);
        foreach NcursesUi::Widget child in (children) {
            if (child.isVisible()) {
                child.drawTree(w);
            }
        }
        clearDirty();
    }

    # ---- Events ----

    /** Routes an event through the widget tree.

        First tries the focused child (depth-first), then calls
        processEvent on this widget.

        @param ev the input event
        @return EventResult indicating whether the event was handled
        @since ncurses 2.0
    */
    hash<NcursesUi::EventResult> handleEvent(hash<Ncurses::InputEvent> ev) {
        # try focused child first (depth-first)
        foreach NcursesUi::Widget child in (children) {
            if (child.isVisible() && child.hasFocus()) {
                hash<NcursesUi::EventResult> result = child.handleEvent(ev);
                if (result.handled) {
                    return result;
                }
            }
        }
        # try this widget
        return processEvent(ev);
    }

    /** Event processing override point.

        Called when no focused child handled the event. Subclasses
        should override this to handle events.

        @param ev the input event
        @return EventResult indicating whether the event was handled
        @since ncurses 2.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        return <NcursesUi::EventResult>{"handled": False};
    }

    # ---- Focus ----

    /** Collects all focusable widgets in depth-first order.
        @return ordered list of focusable widgets
        @since ncurses 2.0
    */
    list<NcursesUi::Widget> collectFocusable() {
        list<NcursesUi::Widget> result = ();
        if (isFocusable()) {
            result += self;
        }
        foreach NcursesUi::Widget child in (children) {
            if (child.isVisible()) {
                result += child.collectFocusable();
            }
        }
        return result;
    }

    /** Focus-in callback. Called when this widget gains focus.
        @since ncurses 2.0
    */
    nothing onFocusIn() {
        # override point
    }

    /** Focus-out callback. Called when this widget loses focus.
        @since ncurses 2.0
    */
    nothing onFocusOut() {
        # override point
    }
}

} # namespace NcursesUi
