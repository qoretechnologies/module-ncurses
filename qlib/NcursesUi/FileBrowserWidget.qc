#! @file FileBrowserWidget.qc Split-pane file system browser widget

/*  FileBrowserWidget.qc Copyright 2026 Qore Technologies, s.r.o.

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

/** Split-pane file system browser widget.

    Displays a directory listing on the left with a file preview pane
    on the right. Supports Tab focus switching between panes,
    directory navigation, show/hide hidden files, and file type
    identification.

    Uses a @ref ListWidget for the file list with scrollbar and a
    @ref ScrollableWidget with @ref LineListContent for the preview.
    The bottom row shows a context-sensitive status line with
    keyboard hints.

    Callbacks:
    - @ref setOnLoad() — called when the user activates a Qore source file
    - @ref setOnDismiss() — called when the user presses Escape or closes
    - @ref setOnFileSelect() — called on file selection change
    - @ref setOnFileActivate() — called on non-Qore file activation

    @since ncurses 2.0
*/
public class NcursesUi::FileBrowserWidget inherits NcursesUi::PanelWidget {
    private {
        #! current directory path
        string current_dir;
        #! the file list widget
        NcursesUi::ListWidget file_list();
        #! preview pane
        NcursesUi::ScrollableWidget preview_widget();
        #! preview content
        NcursesUi::LineListContent preview_content();
        #! whether to show hidden files
        bool show_hidden = False;
        #! which pane has focus: 0 = file list, 1 = preview
        int focused_pane = 0;
        #! status line text
        string status_text = "";
        #! whether selected file is loadable Qore source
        bool can_load = False;
        #! callback on file selection
        *code on_file_select;
        #! callback on file activation (Enter)
        *code on_file_activate;
        #! callback on load request (Qore file activation)
        *code on_load;
        #! callback on dismiss (Escape/close)
        *code on_dismiss;
        #! max preview file size (1 MB)
        int max_preview_size = 1048576;
        #! directory navigation history stack
        list<string> dir_history = ();
        #! items shown in directory preview (for click-through navigation)
        list<hash<auto>> preview_dir_items = ();
        #! path of the directory whose contents are shown in the preview
        *string preview_dir_path;
        #! Qore file extensions
        hash<string, bool> qore_extensions = {
            ".q": True, ".qm": True, ".qc": True, ".qr": True, ".qtest": True,
        };
    }

    /** Creates a new FileBrowserWidget.
        @param s the session
        @param dir the initial directory
        @since ncurses 2.0
    */
    constructor(Ncurses::Session s, string dir = getcwd())
            : PanelWidget(s, "File Browser - " + dir) {
        current_dir = dir;
        preview_widget.setContent(preview_content);
        preview_widget.setShowScrollbar(True);
        addChild(file_list);
        addChild(preview_widget);
        file_list.setOnActivate(sub (hash<auto> item) {
            handleActivation(item);
        });
        file_list.setOnSelect(sub (int idx) {
            onFileSelectionChanged();
            if (on_file_select) {
                *hash<auto> item = file_list.getSelectedItem();
                if (item) {
                    on_file_select(item);
                }
            }
        });
        file_list.setWheelMovesSelection(True);
        file_list.setRenderItem(string sub (hash<auto> item, int idx, bool selected) {
            return renderFileItem(item);
        });
        file_list.setRenderItemStyle(hash<auto> sub (hash<auto> item, int idx, bool selected) {
            return getFileItemStyle(item, selected);
        });
        setClosable(True);
        refreshListing();
        updateStatusText();
    }

    /** Returns the current directory.
        @since ncurses 2.0
    */
    string getCurrentDir() {
        return current_dir;
    }

    /** Navigates to a directory.
        @param dir the directory path
        @since ncurses 2.0
    */
    nothing navigateTo(string dir) {
        if (is_dir(dir)) {
            dir_history += current_dir;
            current_dir = realpath(dir);
            updateTitle();
            clearPreview();
            focused_pane = 0;
            refreshListing();
            updateStatusText();
        }
    }

    /** Navigates back to the previous directory in history.
        @return True if navigation occurred, False if no history
        @since ncurses 2.0
    */
    bool navigateBack() {
        if (dir_history.empty()) {
            return False;
        }
        string prev = dir_history.last();
        splice dir_history, dir_history.size() - 1, 1;
        if (is_dir(prev)) {
            current_dir = realpath(prev);
            updateTitle();
            clearPreview();
            focused_pane = 0;
            refreshListing();
            updateStatusText();
            return True;
        }
        return False;
    }

    /** Returns the directory navigation history.
        @since ncurses 2.0
    */
    list<string> getDirHistory() {
        return dir_history;
    }

    /** Toggles hidden file visibility.
        @since ncurses 2.0
    */
    nothing toggleHidden() {
        show_hidden = !show_hidden;
        refreshListing();
    }

    /** Returns whether hidden files are shown.
        @since ncurses 2.0
    */
    bool isShowHidden() {
        return show_hidden;
    }

    /** Sets the file selection callback.
        @param cb callback(hash<auto> item)
        @since ncurses 2.0
    */
    nothing setOnFileSelect(*code cb) {
        on_file_select = cb;
    }

    /** Sets the file activation callback (for non-Qore files).
        @param cb callback(hash<auto> item)
        @since ncurses 2.0
    */
    nothing setOnFileActivate(*code cb) {
        on_file_activate = cb;
    }

    /** Sets the load callback (for Qore file activation).
        @param cb callback(hash<auto> item)
        @since ncurses 2.0
    */
    nothing setOnLoad(*code cb) {
        on_load = cb;
    }

    /** Sets the dismiss callback (Escape/close).
        @param cb callback()
        @since ncurses 2.0
    */
    nothing setOnDismiss(*code cb) {
        on_dismiss = cb;
    }

    /** Returns the file list widget.
        @since ncurses 2.0
    */
    NcursesUi::ListWidget getFileList() {
        return file_list;
    }

    /** Returns the preview widget.
        @since ncurses 2.0
    */
    NcursesUi::ScrollableWidget getPreviewWidget() {
        return preview_widget;
    }

    /** Returns the preview content.
        @since ncurses 2.0
    */
    NcursesUi::LineListContent getPreviewContent() {
        return preview_content;
    }

    /** Returns the selected file item.
        @since ncurses 2.0
    */
    *hash<auto> getSelectedFile() {
        return file_list.getSelectedItem();
    }

    /** Returns which pane has focus (0 = file list, 1 = preview).
        @since ncurses 2.0
    */
    int getFocusedPane() {
        return focused_pane;
    }

    /** Returns the current status line text.
        @since ncurses 2.0
    */
    string getStatusText() {
        return status_text;
    }

    /** Returns whether the selected file can be loaded.
        @since ncurses 2.0
    */
    bool getCanLoad() {
        return can_load;
    }

    /** Draws the split-pane file browser.
        @param w the window
        @since ncurses 2.0
    */
    nothing draw(Ncurses::Window w) {
        PanelWidget::draw(w);
        *Ncurses::Window pw = getWindow();
        if (!pw) {
            return;
        }
        hash<NcursesUi::Rect> cr = localContentRect();
        if (cr.rows < 2 || cr.cols < 4) {
            return;
        }

        # reserve bottom row for status line
        int content_rows = cr.rows - 1;
        int status_row = cr.y + cr.rows - 1;

        # split: 35% file list (left), 65% preview (right)
        int list_cols = max(10, cr.cols * 35 / 100);
        int preview_cols = cr.cols - list_cols - 1;  # -1 for divider

        # set frames for children (panel-local coordinates)
        hash<NcursesUi::Rect> list_frame = NcursesUi::Geometry::makeRect(
            cr.y, cr.x, content_rows, list_cols);
        hash<NcursesUi::Rect> preview_frame = NcursesUi::Geometry::makeRect(
            cr.y, cr.x + list_cols + 1, content_rows, preview_cols);

        file_list.setFrame(list_frame);
        preview_widget.setFrame(preview_frame);

        # draw both panes
        file_list.draw(pw);
        preview_widget.draw(pw);

        # draw vertical divider between panes
        int div_x = cr.x + list_cols;
        hash<auto> div_style;
        if (focused_pane == 0) {
            div_style = {"fg": Ncurses::Color::Blue};
        } else {
            div_style = {"fg": Ncurses::Color::Cyan, "attrs": Ncurses::Attr::Bold};
        }
        pw.drawVLine(cr.y, div_x, content_rows, NOTHING, div_style);

        # draw status line at bottom
        drawStatusLine(pw, status_row, cr.x, cr.cols);

        pw.noutrefresh();
    }

    /** Delegates events to the focused pane.
        @param ev the input event
        @return EventResult
        @since ncurses 2.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (ev.type == Ncurses::InputType::Char) {
            int code = ord(ev.ch ?? "");
            if (code == 0x1b) {
                # Escape - dismiss
                if (on_dismiss) {
                    on_dismiss();
                }
                return <NcursesUi::EventResult>{"handled": True, "action": "close"};
            } else if (code == 0x09) {
                # Tab - navigate forward (open selected directory)
                *hash<auto> item = file_list.getSelectedItem();
                if (item && item.is_dir) {
                    navigateTo(item.path);
                    return <NcursesUi::EventResult>{"handled": True, "action": "navigate_forward"};
                }
                return <NcursesUi::EventResult>{"handled": True};
            } else if (code == ord(".")) {
                toggleHidden();
                return <NcursesUi::EventResult>{"handled": True};
            }
        } else if (ev.type == Ncurses::InputType::Key) {
            string name = ev.name ?? "";
            if (name == "KEY_BTAB") {
                # Shift+Tab - navigate back to previous directory
                navigateBack();
                return <NcursesUi::EventResult>{"handled": True, "action": "navigate_back"};
            }
        } else if (ev.type == Ncurses::InputType::Mouse) {
            # hit-test against file list vs preview frames
            int mx = ev.mouse.x;
            int my_val = ev.mouse.y;
            # convert absolute coords to panel-local
            hash<NcursesUi::Rect> f = getFrame();
            int local_x = mx - f.x;
            int local_y = my_val - f.y;

            # check close button
            if (isCloseHit(mx, my_val)) {
                if (on_dismiss) {
                    on_dismiss();
                }
                return <NcursesUi::EventResult>{"handled": True, "action": "close"};
            }

            hash<NcursesUi::Rect> list_frame = file_list.getFrame();
            hash<NcursesUi::Rect> preview_frame = preview_widget.getFrame();

            if (NcursesUi::Geometry::rectContains(list_frame, local_y, local_x)) {
                focused_pane = 0;
                # adjust mouse coords to list frame's coordinate system
                hash<Ncurses::InputEvent> adjusted = ev;
                adjusted.mouse.x = local_x;
                adjusted.mouse.y = local_y;
                markDirty();
                return file_list.processEvent(adjusted);
            } else if (NcursesUi::Geometry::rectContains(preview_frame, local_y, local_x)) {
                # check for click-through on directory preview items
                int bs = ev.mouse.button_state;
                if (preview_dir_items.size() > 0 && preview_dir_path
                        && (bs & Ncurses::BUTTON1_CLICKED
                            || bs & Ncurses::BUTTON1_PRESSED
                            || bs & Ncurses::BUTTON1_DOUBLE_CLICKED)) {
                    int click_row = local_y - preview_frame.y;
                    int line_idx = preview_widget.getScrollY() + click_row;
                    if (line_idx >= 0 && line_idx < preview_dir_items.size()) {
                        hash<auto> clicked = preview_dir_items[line_idx];
                        # navigate into the directory and select the clicked entry
                        navigateTo(preview_dir_path);
                        # find the entry in the new file list and select it
                        list<hash<auto>> items = file_list.getItems();
                        for (int i = 0; i < items.size(); ++i) {
                            if (items[i].label == clicked.name) {
                                file_list.setSelectedIndex(i);
                                break;
                            }
                        }
                        focused_pane = 0;
                        markDirty();
                        return <NcursesUi::EventResult>{"handled": True};
                    }
                }
                focused_pane = 1;
                hash<Ncurses::InputEvent> adjusted = ev;
                adjusted.mouse.x = local_x;
                adjusted.mouse.y = local_y;
                markDirty();
                return preview_widget.processEvent(adjusted);
            }

            return <NcursesUi::EventResult>{"handled": True};
        }

        # route keyboard events to focused pane
        if (focused_pane == 0) {
            return file_list.processEvent(ev);
        } else {
            return preview_widget.processEvent(ev);
        }
    }

    /** Called when the file list selection changes. */
    private nothing onFileSelectionChanged() {
        *hash<auto> item = file_list.getSelectedItem();
        if (!item) {
            clearPreview();
            can_load = False;
            updateStatusText();
            return;
        }

        if (item.is_dir) {
            loadDirectoryPreview(item.path);
            can_load = False;
        } else {
            can_load = isQoreFile(item.label);
            loadPreview(item);
        }
        updateStatusText();
        markDirty();
    }

    /** Loads a file preview into the preview pane.
        @param item the file item hash with path, type, size, etc.
        @since ncurses 2.0
    */
    private nothing loadPreview(hash<auto> item) {
        preview_content.clear();
        preview_widget.setScrollY(0);
        preview_dir_items = ();
        preview_dir_path = NOTHING;

        string path = item.path;
        try {
            hash<auto> st = hstat(path);
            if (st.size > max_preview_size) {
                preview_content.appendLine("(File too large to preview)");
                preview_content.appendLine(sprintf("Size: %s", formatSize(st.size)));
                preview_widget.markDirty();
                return;
            }

            # check for binary files by extension or content
            string ftype = item.type ?? "file";
            if (ftype == "binary" || isBinaryContent(path)) {
                preview_content.appendLine("(Binary file)");
                preview_content.appendLine(sprintf("Size: %s", formatSize(st.size)));
                preview_widget.markDirty();
                return;
            }

            string data = ReadOnlyFile::readTextFile(path);
            list<string> lines = data.split("\n");
            foreach string line in (lines) {
                preview_content.appendLine(line);
            }
        } catch (hash<ExceptionInfo> ex) {
            preview_content.appendLine("(Cannot preview file)");
            preview_content.appendLine(ex.err + ": " + ex.desc);
        }
        preview_widget.markDirty();
    }

    /** Loads a directory preview into the preview pane.
        Shows subdirectories first, then files with sizes.
        @param path the directory path
        @since ncurses 2.0
    */
    private nothing loadDirectoryPreview(string path) {
        preview_content.clear();
        preview_widget.setScrollY(0);
        preview_dir_items = ();
        preview_dir_path = path;

        try {
            Dir d();
            d.chdir(path);
            list<string> dirs = sort(d.listDirs());
            list<string> files = sort(d.listFiles());

            # show dirs first, then files
            foreach string name in (dirs) {
                if (!show_hidden && name.substr(0, 1) == ".") {
                    continue;
                }
                preview_content.appendLine("[DIR] " + name);
                preview_dir_items += {"name": name, "is_dir": True,
                    "path": path + "/" + name};
            }
            foreach string name in (files) {
                if (!show_hidden && name.substr(0, 1) == ".") {
                    continue;
                }
                # show file with size
                string full = path + "/" + name;
                string size_str = "";
                try {
                    hash<auto> st = hstat(full);
                    size_str = formatSize(st.size);
                } catch (hash<ExceptionInfo> ex) {
                    # ignore stat errors
                }
                preview_content.appendLine("      " + name + "  " + size_str);
                preview_dir_items += {"name": name, "is_dir": False, "path": full};
            }

            if (preview_content.lineCount() == 0) {
                preview_content.appendLine("(Empty directory)");
            }
        } catch (hash<ExceptionInfo> ex) {
            preview_content.appendLine("(Cannot read directory)");
            preview_content.appendLine(ex.err + ": " + ex.desc);
        }
        preview_widget.markDirty();
    }

    /** Clears the preview pane. */
    private nothing clearPreview() {
        preview_content.clear();
        preview_widget.setScrollY(0);
        preview_dir_items = ();
        preview_dir_path = NOTHING;
        preview_widget.markDirty();
    }

    /** Updates the panel title. */
    private nothing updateTitle() {
        setTitle("File Browser - " + current_dir);
    }

    /** Updates the status line text based on current state. */
    private nothing updateStatusText() {
        list<string> hints = ();
        *hash<auto> item = file_list.getSelectedItem();
        if (item) {
            if (item.is_dir) {
                hints += "Enter/Tab:Open";
            } else if (can_load) {
                hints += "Enter:Load";
            }
        }
        if (!dir_history.empty()) {
            hints += "S-Tab:Back";
        }
        hints += ".:Hidden";
        hints += "Esc:Close";
        status_text = hints.join(" | ");
    }

    /** Draws the status line at the bottom of the content area. */
    private nothing drawStatusLine(Ncurses::Window w, int row, int x, int width) {
        hash<auto> bg_style = {"fg": Ncurses::Color::Cyan, "bg": Ncurses::Color::Blue};
        # clear the row
        w.drawHLine(row, x, width, " ", bg_style);
        # draw status text with bright foreground for readability
        hash<auto> text_style = {"fg": Ncurses::Color::White, "bg": Ncurses::Color::Blue,
            "attrs": Ncurses::Attr::Bold};
        string text = " " + status_text;
        if (text.length() > width) {
            text = text.substr(0, width);
        }
        w.drawText(row, x, text, text_style);
    }

    /** Tests if a filename is a Qore source file. */
    bool isQoreFile(string name) {
        foreach string ext in (keys qore_extensions) {
            if (name.size() > ext.size() && name.substr(-ext.size()) == ext) {
                return True;
            }
        }
        return False;
    }

    private nothing refreshListing() {
        list<hash<auto>> entries = ();

        # parent directory entry
        if (current_dir != "/") {
            entries += {"label": "..", "path": current_dir + "/..", "is_dir": True, "type": "dir"};
        }

        # read directory
        list<string> names;
        try {
            Dir d();
            d.chdir(current_dir);
            names = sort(d.listFiles() + d.listDirs());
        } catch (hash<ExceptionInfo> ex) {
            names = ();
        }

        foreach string name in (names) {
            if (!show_hidden && name.substr(0, 1) == ".") {
                continue;
            }

            string full_path = current_dir + "/" + name;
            bool is_directory = is_dir(full_path);
            string ftype = is_directory ? "dir" : identifyFileType(name);

            hash<auto> entry = {
                "label": name,
                "path": full_path,
                "is_dir": is_directory,
                "type": ftype,
            };

            if (!is_directory) {
                try {
                    hash<auto> st = hstat(full_path);
                    entry.size = st.size;
                    entry.mtime = st.mtime;
                } catch (hash<ExceptionInfo> ex) {
                    # ignore stat errors
                }
            }

            entries += entry;
        }

        file_list.setItems(entries);
        markDirty();
    }

    private nothing handleActivation(hash<auto> item) {
        if (item.is_dir) {
            navigateTo(item.path);
        } else if (isQoreFile(item.label) && on_load) {
            on_load(item);
        } else {
            if (on_file_activate) {
                on_file_activate(item);
            }
        }
    }

    private string identifyFileType(string name) {
        # check binary extensions first
        if (name =~ /\.(o|so|a|dylib|exe|bin|class|pyc|pyo|gz|bz2|xz|zip|tar|tgz|rar|7z|png|jpg|jpeg|gif|bmp|ico|tiff|webp|pdf|doc|docx|xls|xlsx|ppt|pptx|mp3|mp4|avi|mov|mkv|flac|wav|ogg|woff|woff2|ttf|eot)$/i) {
            return "binary";
        }
        # check Qore extensions
        foreach string ext in (keys qore_extensions) {
            if (name.size() > ext.size() && name.substr(-ext.size()) == ext) {
                return "qore";
            }
        }
        # check common extensions
        if (name =~ /\.(cpp|cc|cxx|c|h|hpp)$/) {
            return "c++";
        }
        if (name =~ /\.(py)$/) {
            return "python";
        }
        if (name =~ /\.(js|ts)$/) {
            return "javascript";
        }
        if (name =~ /\.(md|txt|rst)$/) {
            return "text";
        }
        if (name =~ /\.(json|yaml|yml|xml|ini|conf|cfg)$/) {
            return "config";
        }
        return "file";
    }

    /** Returns the display style for a file item based on type.
        @param item the file item hash
        @param selected whether the item is selected
        @return the style hash
        @since ncurses 2.0
    */
    private hash<auto> getFileItemStyle(hash<auto> item, bool selected) {
        hash<auto> style;
        if (item.is_dir) {
            style = {"fg": Ncurses::Color::Cyan, "attrs": Ncurses::Attr::Bold};
        } else {
            string ftype = item.type ?? "file";
            switch (ftype) {
                case "qore":
                    style = {"fg": Ncurses::Color::Green, "attrs": Ncurses::Attr::Bold};
                    break;
                case "binary":
                    style = {"attrs": Ncurses::Attr::Dim};
                    break;
                default:
                    style = {};
                    break;
            }
        }
        if (selected) {
            style.attrs = (style.attrs ?? 0) | Ncurses::Attr::Reverse;
        }
        return style;
    }

    /** Checks if file content appears to be binary (contains null bytes).
        @param path the file path
        @return True if the file appears to be binary
        @since ncurses 2.0
    */
    private bool isBinaryContent(string path) {
        try {
            ReadOnlyFile f(path);
            *binary chunk = f.readBinary(8192);
            if (!chunk || !chunk.size()) {
                return False;
            }
            for (int i = 0; i < chunk.size(); ++i) {
                if (chunk[i] == 0) {
                    return True;
                }
            }
            return False;
        } catch (hash<ExceptionInfo> ex) {
            return False;
        }
    }

    private string renderFileItem(hash<auto> item) {
        if (item.is_dir) {
            return "[DIR] " + item.label;
        }

        string size_str = "";
        if (exists item.size) {
            size_str = formatSize(item.size);
        }

        return sprintf("      %s  %s", item.label, size_str);
    }

    /** Formats a file size for display. */
    private static string formatSize(int sz) {
        if (sz >= 1048576) {
            return sprintf("%.1fM", sz / 1048576.0);
        } else if (sz >= 1024) {
            return sprintf("%.1fK", sz / 1024.0);
        }
        return sprintf("%d", sz);
    }
}
