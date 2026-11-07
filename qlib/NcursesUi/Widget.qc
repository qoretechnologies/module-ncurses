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

public namespace NcursesUi {
#! Internal callback depth, shared by focus managers on the current UI thread.
thread_local int _focus_callback_depth;

/** Base widget for the NcursesUi toolkit.

    Provides a tree structure (parent/children), geometry management,
    focus tracking, incremental drawing, and event handling.

    Regular widgets draw into their parent's window using offset
    coordinates. @ref PanelWidget creates its own ncurses Panel for
    floating/overlapping content.

    @since ncurses 1.0
*/
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
        #! disabled subtrees do not receive input or focus
        bool enabled = True;
        #! whether this widget can receive focus
        bool focusable = False;
        #! whether this widget currently has focus
        bool focused = False;
        #! whether this widget needs redrawing
        bool dirty = True;
        #! prior painted content, used when padding exposes old cells
        *hash<NcursesUi::Rect> painted_content;

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
        @since ncurses 1.0
    */
    *NcursesUi::Widget getParent() {
        return parent_widget;
    }

    /** Returns the list of child widgets.
        @since ncurses 1.0
    */
    list<NcursesUi::Widget> getChildren() {
        return children;
    }

    /** Adds a child widget. Sets the child's parent to this widget.
        @param child the widget to add; existing children are not duplicated
        @throw WIDGET-TREE-ERROR if the operation would create a cycle
        @since ncurses 1.0
    */
    nothing addChild(NcursesUi::Widget child) {
        if (child.containsWidget(self)) {
            throw "WIDGET-TREE-ERROR", "A widget cannot contain itself or an ancestor";
        }
        if (child.parent_widget == self) {
            return;
        }
        if (child.parent_widget) {
            child.parent_widget.removeChild(child);
        }
        # Focus-loss callbacks can change either ancestry or the child's parent.
        if (child.containsWidget(self)) {
            throw "WIDGET-TREE-ERROR", "A reparenting callback created an ancestor relationship";
        }
        if (child.parent_widget == self) {
            return;
        }
        if (child.parent_widget) {
            throw "WIDGET-TREE-ERROR", "A reparenting callback attached the child to another parent";
        }
        children += child;
        child.parent_widget = self;
        markDirty();
    }

    /** Removes a child and clears focus in the detached subtree.
        Removing a non-child has no effect. Reparenting also clears its focus.
        @param child the widget to remove
        @since ncurses 1.0
    */
    nothing removeChild(NcursesUi::Widget child) {
        if (child.parent_widget != self) {
            return;
        }
        list<NcursesUi::Widget> out = ();
        foreach NcursesUi::Widget c in (children) {
            if (c != child) {
                out += c;
            }
        }
        children = out;
        child.parent_widget = NOTHING;
        markDirty();
        child.clearFocusTree();
    }

    /** Reparents this widget, updating both sides of the tree.
        @param p the new parent
        @throw WIDGET-TREE-ERROR if the operation would create a cycle
        @since ncurses 1.0
    */
    nothing setParent(NcursesUi::Widget p) {
        p.addChild(self);
    }

    /** Detaches this widget from its parent and clears subtree focus.
        @since ncurses 1.0
    */
    nothing clearParent() {
        if (parent_widget) {
            parent_widget.removeChild(self);
        }
    }

    /** Tests whether a widget belongs to this subtree, including this widget.
        @param w widget to locate
        @return True for this widget or a descendant
        @since ncurses 1.0
    */
    bool containsWidget(NcursesUi::Widget w) {
        *NcursesUi::Widget item = w;
        while (item) {
            if (item == self) {
                return True;
            }
            item = item.getParent();
        }
        return False;
    }

    /** Returns the number of children.
        @since ncurses 1.0
    */
    int childCount() {
        return children.size();
    }

    # ---- Geometry ----

    /** Sets the widget frame (absolute terminal coordinates).
        @param r the new frame rectangle
        @since ncurses 1.0
    */
    nothing setFrame(hash<NcursesUi::Rect> r) {
        r.rows = max(0, r.rows); r.cols = max(0, r.cols);
        if (frame == r) { return; }
        if (parent_widget) { parent_widget.markDirty(); }
        frame = r; markDirty();
    }

    /** Sets the widget frame from individual values.
        @param y row position
        @param x column position
        @param rows height
        @param cols width
        @since ncurses 1.0
    */
    nothing setFrameValues(int y, int x, int rows, int cols) {
        setFrame(NcursesUi::Geometry::makeRect(y, x, max(0, rows), max(0, cols)));
    }

    /** Returns the widget frame rectangle.
        @since ncurses 1.0
    */
    hash<NcursesUi::Rect> getFrame() {
        return frame;
    }

    /** Moves a subtree in screen coordinates without changing its layout sizes.
        @param dy row displacement
        @param dx column displacement
    */
    nothing translate(int dy, int dx) {
        if (!dy && !dx) { return; }
        if (parent_widget) { parent_widget.markDirty(); }
        frame.y += dy; frame.x += dx;
        foreach NcursesUi::Widget child in (children) { child.translate(dy, dx); }
        markDirty();
    }

    /** Sets the padding insets.
        @param i the new insets
        @since ncurses 1.0
    */
    nothing setPadding(hash<NcursesUi::Insets> i) {
        padding = i;
        markDirty();
    }

    /** Returns the content rectangle (frame minus padding).
        @since ncurses 1.0
    */
    hash<NcursesUi::Rect> contentRect() {
        return NcursesUi::Geometry::rectInset(frame, padding);
    }

    /** Converts the logical content rectangle to target-window coordinates.
        Layout and input always use screen coordinates; drawing uses this method.
        @param w target window
        @return window-local content rectangle (possibly clipped by the window)
    */
    hash<NcursesUi::Rect> drawContentRect(Ncurses::Window w) {
        hash<NcursesUi::Rect> rect = contentRect();
        hash<Ncurses::Position> origin = w.position();
        rect.y -= origin.y; rect.x -= origin.x;
        return rect;
    }

    /** Returns the frame intersected with every ancestor's content rectangle.
        @return visible screen rectangle; zero dimensions mean fully clipped
    */
    hash<NcursesUi::Rect> visibleRect() {
        hash<NcursesUi::Rect> rect = frame;
        *NcursesUi::Widget ancestor = getParent();
        while (ancestor) {
            rect = NcursesUi::Geometry::intersect(rect, ancestor.contentRect());
            ancestor = ancestor.getParent();
        }
        return rect;
    }

    # Match drawTextClipped after logical-width clipping. Partial wide glyphs
    # become spaces at the target edges and must not remain action targets.
    private bool textActionHit(string text, *hash<NcursesUi::Rect> draw_bounds, int py, int px) {
        hash<NcursesUi::Rect> content = contentRect(); content.rows = min(1, content.rows);
        hash<NcursesUi::Rect> clip = NcursesUi::Geometry::intersect(content, visibleRect());
        if (draw_bounds) { clip = NcursesUi::Geometry::intersect(clip, draw_bounds); }
        if (!NcursesUi::Geometry::rectContains(clip, py, px)) { return False; }
        int col = content.x;
        foreach string cluster in (NcursesUi::TerminalText::graphemes(NcursesUi::TerminalText::clipRight(text, content.cols))) {
            int end = col + NcursesUi::TerminalText::displayWidth(cluster);
            if (px >= col && px < end) { return col >= clip.x && end <= clip.x + clip.cols; }
            col = end;
            if (col > px) { break; }
        }
        return False;
    }

    /** Releases rendering resources when this subtree has no drawable area.
        Subclasses owning cursor requests override this and call the base method.
    */
    nothing onDrawClipped() {
        foreach NcursesUi::Widget child in (children) { child.onDrawClipped(); child.clearDirty(); }
    }

    /** Tests if a point is inside this widget's frame.
        @param py the row coordinate
        @param px the column coordinate
        @return True if the point is inside
        @since ncurses 1.0
    */
    bool hitTest(int py, int px) {
        if (!visible) {
            return False;
        }
        return NcursesUi::Geometry::rectContains(visibleRect(), py, px);
    }

    # ---- State ----

    /** Sets visibility.
        @param v True to show, False to hide
        @since ncurses 1.0
    */
    nothing setVisible(bool v) {
        if (visible != v && parent_widget) { parent_widget.markDirty(); }
        if (visible != v) {
            visible = v;
            markDirty();
            if (!v) {
                clearFocusTree();
            }
        }
    }

    /** Returns visibility.
        @since ncurses 1.0
    */
    bool isVisible() {
        return visible;
    }

    /** Sets whether this widget can receive focus.
        @param v True to make focusable
        @since ncurses 1.0
    */
    nothing setFocusable(bool v) {
        focusable = v;
        if (!v) {
            setFocused(False);
        }
    }

    /** Returns whether this widget can receive focus.
        @since ncurses 1.0
    */
    bool isFocusable() {
        return focusable && isAvailable();
    }

    /** Sets the focused state directly.
        @param v True to set focused
        @throw FOCUS-CHANGE-ERROR if a focus callback tries to acquire focus
        @since ncurses 1.0
    */
    nothing setFocused(bool v) {
        v = v && isFocusable();
        if (focused != v) {
            if (v && _focus_callback_depth > 0) {
                throw "FOCUS-CHANGE-ERROR", "A focus callback cannot acquire focus";
            }
            focused = v;
            markDirty();
            ++_focus_callback_depth;
            on_exit --_focus_callback_depth;
            if (v) {
                try {
                    onFocusIn();
                } catch (hash<ExceptionInfo> ex) {
                    focused = False;
                    try {
                        onFocusOut();
                    } catch (hash<ExceptionInfo> cleanup_error) {
                        # Preserve the focus-in failure after attempting cleanup.
                    }
                    rethrow;
                }
            } else {
                onFocusOut();
            }
        }
    }

    /** Returns whether this widget has focus.
        @since ncurses 1.0
    */
    bool hasFocus() {
        return focused;
    }

    /** Enables or disables this widget and input to its descendants.
        @param v True to enable input; disabling clears subtree focus
        @since ncurses 1.0
    */
    nothing setEnabled(bool v) {
        enabled = v;
        markDirty();
        if (!v) {
            clearFocusTree();
        }
    }

    /** Returns this widget's enabled flag.
        @return True if locally enabled
        @since ncurses 1.0
    */
    bool isEnabled() {
        return enabled;
    }

    /** Returns whether this widget and all ancestors allow input.
        @return True if the entire path is visible and enabled
        @since ncurses 1.0
    */
    bool isAvailable() {
        return visible && enabled && (!parent_widget || parent_widget.isAvailable());
    }

    /** Reports whether a focused widget uses a visible terminal caret.
        Text editors override this; selection controls use a highlight instead.
        @return False by default
        @since ncurses 1.0
    */
    bool wantsCursor() {
        return False;
    }

    /** Reports whether this composite delegates mouse events to its own children.
        The dispatcher stops descending here and delivers screen coordinates to
        processEvent(). Override this when children use a local coordinate space
        or the composite implements interactions before child dispatch.
        @return False by default
        @since ncurses 1.0
    */
    bool handlesChildMouseEvents() {
        return False;
    }

    /** Returns the focus target for a primary mouse activation.
        Composites that handle child mouse events may return a child; the
        dispatcher validates its scope and availability before changing focus.
        @param py screen row
        @param px screen column
        @return this widget by default; NOTHING to preserve current focus
        @since ncurses 1.0
    */
    *NcursesUi::Widget mouseFocusTarget(int py, int px) {
        return self;
    }

    private nothing clearFocusTree() {
        *hash<ExceptionInfo> failure;
        try {
            setFocused(False);
        } catch (hash<ExceptionInfo> ex) {
            failure = ex;
        }
        foreach NcursesUi::Widget child in (children) {
            try {
                child.clearFocusTree();
            } catch (hash<ExceptionInfo> ex) {
                if (!failure) {
                    failure = ex;
                }
            }
        }
        if (failure) {
            throw failure.err, failure.desc, failure.arg;
        }
    }

    # ---- Dirty flag ----

    /** Marks this widget for painting; ancestor isDirty() includes descendant changes.
        @since ncurses 1.0
    */
    nothing markDirty() {
        dirty = True;
    }

    /** Returns whether the widget needs redrawing.
        @since ncurses 1.0
    */
    bool isDirty() {
        if (dirty) { return True; }
        if (visible) {
            foreach NcursesUi::Widget child in (children) { if (child.isDirty()) { return True; } }
        }
        return False;
    }

    /** Returns whether this widget's own pixels need repainting. @return local dirty state */
    bool needsOwnDraw() { return dirty; }

    /** Indicates that draw() itself paints children (for composite compatibility).
        @return False unless a composite owns child painting
    */
    bool drawsChildren() { return False; }

    /** Clears the dirty flag for this widget only.
        @since ncurses 1.0
    */
    nothing clearDirty() {
        dirty = False;
    }

    # ---- Size policy ----

    /** Sets the horizontal size policy.
        @param p the policy value
        @since ncurses 1.0
    */
    nothing setHSizePolicy(int p) {
        h_size_policy = p;
    }

    /** Returns the horizontal size policy.
        @since ncurses 1.0
    */
    int getHSizePolicy() {
        return h_size_policy;
    }

    /** Sets the vertical size policy.
        @param p the policy value
        @since ncurses 1.0
    */
    nothing setVSizePolicy(int p) {
        v_size_policy = p;
    }

    /** Returns the vertical size policy.
        @since ncurses 1.0
    */
    int getVSizePolicy() {
        return v_size_policy;
    }

    /** Sets the minimum size.
        @param rows minimum rows
        @param cols minimum columns
        @since ncurses 1.0
    */
    nothing setMinimumSize(int rows, int cols) {
        min_size = <NcursesUi::Rect>{"rows": rows, "cols": cols};
    }

    /** Returns the minimum size.
        @since ncurses 1.0
    */
    hash<NcursesUi::Rect> getMinimumSize() {
        return min_size;
    }

    /** Sets the preferred size.
        @param rows preferred rows
        @param cols preferred columns
        @since ncurses 1.0
    */
    nothing setPreferredSize(int rows, int cols) {
        pref_size = <NcursesUi::Rect>{"rows": rows, "cols": cols};
    }

    /** Returns the preferred size.
        @since ncurses 1.0
    */
    hash<NcursesUi::Rect> getPreferredSize() {
        return pref_size;
    }

    /** Measures the preferred size at an offered content width.
        Wrapping widgets can override this without changing their allocated frame.
        @param columns available terminal columns @return preferred size
    */
    hash<NcursesUi::Rect> getPreferredSizeForWidth(int columns) { return getPreferredSize(); }

    # ---- Layout ----

    /** Layout override point. Called when the widget's frame changes.
        Subclasses should override to position children.
        @since ncurses 1.0
    */
    nothing layout() {
        # default: no-op; subclasses override
    }

    /** Relayout hook for an active modal after terminal resize.
        @param rows terminal height
        @param cols terminal width
    */
    nothing fitToScreen(int rows, int cols) { layout(); }

    # ---- Drawing ----

    /** Draw override point. Called when the widget needs to be redrawn.
        @param w the window to draw into
        @since ncurses 1.0
    */
    nothing draw(Ncurses::Window w) {
        # default: no-op; subclasses override
    }

    /** Draws this widget and all visible children.
        @param w the window to draw into
        @param force repaint even when clean (for exposed regions)
        @since ncurses 1.0
    */
    nothing drawTree(Ncurses::Window w, bool force = False) {
        on_error markDirty();
        if (!force && !isDirty()) { return; }
        if (!visible) { onDrawClipped(); clearDirty(); return; }
        hash<Ncurses::Position> origin = w.position(); hash<Ncurses::Size> size = w.size();
        hash<NcursesUi::Rect> bounds = NcursesUi::Geometry::makeRect(origin.y, origin.x, size.rows, size.cols);
        hash<NcursesUi::Rect> clip = NcursesUi::Geometry::intersect(visibleRect(), bounds);
        if (clip.rows <= 0 || clip.cols <= 0) { onDrawClipped(); clearDirty(); return; }
        Ncurses::Window target = w;
        if (clip != frame) {
            target = w.subWindow(clip.rows, clip.cols, clip.y - origin.y, clip.x - origin.x);
            target.setLeaveOk(False);
        }
        bool redraw = force || needsOwnDraw() || drawsChildren();
        if (redraw) {
            hash<Ncurses::Position> offset = target.position();
            hash<NcursesUi::Rect> current = NcursesUi::Geometry::intersect(contentRect(), clip);
            list<hash<NcursesUi::Rect>> areas = (current,);
            if (painted_content) { areas += NcursesUi::Geometry::intersect(painted_content, clip); }
            foreach hash<NcursesUi::Rect> area in (areas) {
                if (area.cols <= 0) { continue; }
                for (int row = area.y; row < area.y + area.rows; ++row) {
                    target.drawHLine(row - offset.y, area.x - offset.x, area.cols, " ");
                }
            }
            draw(target);
            painted_content = current;
        }
        if (!drawsChildren()) {
            drawChildren(target, redraw);
        }
        if (target != w) { target.noutrefresh(); }
        clearDirty();
    }

    /** Paints dirty children in stacking order, restoring overlapping later siblings.
        @param w drawing surface
        @param force repaint all descendants after this widget's own surface changed
    */
    private nothing drawChildren(Ncurses::Window w, bool force) {
        list<hash<NcursesUi::Rect>> damage = ();
        foreach NcursesUi::Widget child in (children) {
            bool repaint = force;
            hash<NcursesUi::Rect> rect = child.visibleRect();
            if (!repaint && child.isVisible()) {
                foreach hash<NcursesUi::Rect> area in (damage) {
                    hash<NcursesUi::Rect> overlap = NcursesUi::Geometry::intersect(rect, area);
                    if (overlap.rows > 0 && overlap.cols > 0) { repaint = True; break; }
                }
            }
            bool changed = repaint || child.isDirty();
            child.drawTree(w, repaint);
            if (changed && child.isVisible()) { damage += rect; }
        }
    }

    # ---- Events ----

    /** Routes an event to the focused descendant, then bubbles to ancestors.
        Non-focusable containers remain part of the path. An unhandled event
        reaches this widget once; unrelated siblings are never called.
        @param ev input event
        @return handling result
        @since ncurses 1.0
    */
    hash<NcursesUi::EventResult> handleEvent(hash<Ncurses::InputEvent> ev) {
        *NcursesUi::Widget target = findFocused();
        return dispatchTo(target ?? self, ev);
    }

    /** Finds a focused, available descendant (or this widget).
        @return focused widget or NOTHING
        @since ncurses 1.0
    */
    *NcursesUi::Widget findFocused() {
        if (!isAvailable()) {
            return NOTHING;
        }
        foreach NcursesUi::Widget child in (children) {
            *NcursesUi::Widget target = child.findFocused();
            if (target) {
                return target;
            }
        }
        return focused && isFocusable() ? self : NOTHING;
    }

    /** Dispatches to a target and bubbles through its original ancestor path.
        Routing stops if a callback detaches/disables the target or reparents
        it away from that path. Each widget is called at most once.
        @param target widget in this scope
        @param ev input event
        @return handling result; False for unavailable or foreign targets
        @since ncurses 1.0
    */
    hash<NcursesUi::EventResult> dispatchTo(NcursesUi::Widget target, hash<Ncurses::InputEvent> ev) {
        list<NcursesUi::Widget> path = ();
        *NcursesUi::Widget item = target;
        while (item && containsWidget(item)) {
            path += item;
            if (item == self) {
                break;
            }
            item = item.getParent();
        }
        foreach NcursesUi::Widget widget in (path) {
            if (!containsWidget(target) || !target.isAvailable() || !widget.containsWidget(target)) {
                break;
            }
            hash<NcursesUi::EventResult> result = widget.processEvent(ev);
            if (result.handled) {
                return result;
            }
        }
        return <NcursesUi::EventResult>{"handled": False};
    }

    /** Event processing override point.

        Called when no focused child handled the event. Subclasses
        should override this to handle events.

        @param ev the input event
        @return EventResult indicating whether the event was handled
        @since ncurses 1.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        return <NcursesUi::EventResult>{"handled": False};
    }

    # ---- Focus ----

    /** Collects all focusable widgets in depth-first order.
        @return ordered list of focusable widgets
        @since ncurses 1.0
    */
    list<NcursesUi::Widget> collectFocusable() {
        list<NcursesUi::Widget> result = ();
        if (!isAvailable()) {
            return result;
        }
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
        @since ncurses 1.0
    */
    nothing onFocusIn() {
        # override point
    }

    /** Focus-out callback. Called when this widget loses focus.
        @since ncurses 1.0
    */
    nothing onFocusOut() {
        # override point
    }
}

} # namespace NcursesUi
