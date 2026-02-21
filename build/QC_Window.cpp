/* -*- mode: c++; indent-tabs-mode: nil -*- */
/*
    Qore ncurses module

    Copyright (C) 2003 - 2026 Qore Technologies, s.r.o.

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

#include "ncurses-internal.h"
/* Qore class Qore::Ncurses::Window */

qore_classid_t CID_WINDOW;
QoreClass* QC_WINDOW;

// nothing Window::addChar(int y, int x, string ch, *hash style){}
static QoreValue Window_addChar_ViViVsNh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    int64 x = HARD_QORE_VALUE_INT(args, 1);
    const QoreStringNode* ch = HARD_QORE_VALUE_STRING(args, 2);
    const QoreHashNode* style = get_param_value(args, 3).get<const QoreHashNode>();
# 921 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    StyleSpec spec;
    parseStyle(style, spec, xsink);
    if (*xsink) {
        return nothing();
    }
    if (!ch || !ch->size()) {
        return nothing();
    }
    attr_t old_attr = 0;
    short old_pair = 0;
    applyStyle(win, spec, old_attr, old_pair, xsink);
    if (*xsink) {
        return nothing();
    }
    mvwaddch(win->win, y, x, ch->c_str()[0]);
    restoreStyle(win, old_attr, old_pair);
    return nothing();
}

// nothing Window::border(*string ls, *string rs, *string ts, *string bs, *string tl, *string tr, *string bl, *string br, *hash style){}
static QoreValue Window_border_NsNsNsNsNsNsNsNsNh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    const QoreStringNode* ls = get_param_value(args, 0).get<const QoreStringNode>();
    const QoreStringNode* rs = get_param_value(args, 1).get<const QoreStringNode>();
    const QoreStringNode* ts = get_param_value(args, 2).get<const QoreStringNode>();
    const QoreStringNode* bs = get_param_value(args, 3).get<const QoreStringNode>();
    const QoreStringNode* tl = get_param_value(args, 4).get<const QoreStringNode>();
    const QoreStringNode* tr = get_param_value(args, 5).get<const QoreStringNode>();
    const QoreStringNode* bl = get_param_value(args, 6).get<const QoreStringNode>();
    const QoreStringNode* br = get_param_value(args, 7).get<const QoreStringNode>();
    const QoreHashNode* style = get_param_value(args, 8).get<const QoreHashNode>();
# 816 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    StyleSpec spec;
    parseStyle(style, spec, xsink);
    if (*xsink) {
        return nothing();
    }
    chtype l = ls && ls->size() ? ls->c_str()[0] : 0;
    chtype r = rs && rs->size() ? rs->c_str()[0] : 0;
    chtype t = ts && ts->size() ? ts->c_str()[0] : 0;
    chtype b = bs && bs->size() ? bs->c_str()[0] : 0;
    chtype tlc = tl && tl->size() ? tl->c_str()[0] : 0;
    chtype trc = tr && tr->size() ? tr->c_str()[0] : 0;
    chtype blc = bl && bl->size() ? bl->c_str()[0] : 0;
    chtype brc = br && br->size() ? br->c_str()[0] : 0;
    attr_t old_attr = 0;
    short old_pair = 0;
    applyStyle(win, spec, old_attr, old_pair, xsink);
    if (*xsink) {
        return nothing();
    }
    wborder(win->win, l, r, t, b, tlc, trc, blc, brc);
    restoreStyle(win, old_attr, old_pair);
    return nothing();
}

// nothing Window::box(*hash style){}
static QoreValue Window_box_Nh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    const QoreHashNode* style = get_param_value(args, 0).get<const QoreHashNode>();
# 783 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    StyleSpec spec;
    parseStyle(style, spec, xsink);
    attr_t old_attr = 0;
    short old_pair = 0;
    applyStyle(win, spec, old_attr, old_pair, xsink);
    if (*xsink) {
        return nothing();
    }
    ::box(win->win, 0, 0);
    restoreStyle(win, old_attr, old_pair);
    return nothing();
}

// nothing Window::clear(){}
static QoreValue Window_clear(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 102 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    wclear(win->win);
    return nothing();
}

// nothing Window::clearInsideLine(int y, *hash style){}
static QoreValue Window_clearInsideLine_ViNh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    const QoreHashNode* style = get_param_value(args, 1).get<const QoreHashNode>();
# 417 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    int rows = 0;
    int cols = 0;
    getmaxyx(win->win, rows, cols);
    int inner_rows = rows - 2;
    int inner_cols = cols - 2;
    if (inner_rows <= 0 || inner_cols <= 0) {
        return nothing();
    }
    if (y < 0 || y >= inner_rows) {
        return nothing();
    }
    StyleSpec spec;
    parseStyle(style, spec, xsink);
    if (*xsink) {
        return nothing();
    }
    attr_t old_attr = 0;
    short old_pair = 0;
    applyStyle(win, spec, old_attr, old_pair, xsink);
    if (*xsink) {
        return nothing();
    }
    mvwhline(win->win, y + 1, 1, ' ', inner_cols);
    restoreStyle(win, old_attr, old_pair);
    return nothing();
}

// nothing Window::clearLine(int y, *hash style){}
static QoreValue Window_clearLine_ViNh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    const QoreHashNode* style = get_param_value(args, 1).get<const QoreHashNode>();
# 989 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    StyleSpec spec;
    attr_t old_attr = 0;
    short old_pair = 0;
    parseStyle(style, spec, xsink);
    if (*xsink) {
        return nothing();
    }
    applyStyle(win, spec, old_attr, old_pair, xsink);
    if (*xsink) {
        return nothing();
    }
    wmove(win->win, y, 0);
    wclrtoeol(win->win);
    restoreStyle(win, old_attr, old_pair);
    return nothing();
}

// Window::constructor(Qore::Ncurses::Session session, int rows, int cols, int y, int x) {}
static void Window_constructor_C7SessionViViViVi(QoreObject* self, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    HARD_QORE_VALUE_OBJ_DATA(session, NcursesSession, args, 0, CID_SESSION, "Window::constructor()", "Qore::Ncurses::Session", xsink);
    if (*xsink)
        return;
    int64 rows = HARD_QORE_VALUE_INT(args, 1);
    int64 cols = HARD_QORE_VALUE_INT(args, 2);
    int64 y = HARD_QORE_VALUE_INT(args, 3);
    int64 x = HARD_QORE_VALUE_INT(args, 4);
# 80 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
ReferenceHolder<NcursesSession> sh(session, xsink);
    if (*xsink) {
        return;
    }
    sh->checkOpen(xsink);
    if (*xsink) {
        return;
    }
    NcursesCallGuard guard(*sh);
    WINDOW* w = newwin(rows, cols, y, x);
    if (!w) {
        xsink->raiseException("NCURSES-ERROR", "newwin() failed");
        return;
    }
    self->setPrivate(CID_WINDOW, new NcursesWindow(*sh, w, true));
}

// hash<Position> Window::cursor(){}
static QoreValue Window_cursor(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 181 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    int y = 0;
    int x = 0;
    getyx(win->win, y, x);
    ReferenceHolder<QoreHashNode> h(new QoreHashNode(hashdeclPosition, xsink), xsink);
    h->setKeyValue("y", y, xsink);
    h->setKeyValue("x", x, xsink);
    return h.release();
}

// nothing Window::drawAnsiText(int y, int x, string text, *hash style){}
static QoreValue Window_drawAnsiText_ViViVsNh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    int64 x = HARD_QORE_VALUE_INT(args, 1);
    const QoreStringNode* text = HARD_QORE_VALUE_STRING(args, 2);
    const QoreHashNode* style = get_param_value(args, 3).get<const QoreHashNode>();
# 512 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    if (style) {
        StyleSpec spec;
        parseStyle(style, spec, xsink);
        if (*xsink) {
            return nothing();
        }
        attr_t old_attr = 0;
        short old_pair = 0;
        applyStyle(win, spec, old_attr, old_pair, xsink);
        if (*xsink) {
            return nothing();
        }
        drawAnsiText(win, y, x, false, false, text, xsink);
        restoreStyle(win, old_attr, old_pair);
    } else {
        drawAnsiText(win, y, x, false, false, text, xsink);
    }
    return nothing();
}

// nothing Window::drawAnsiTextInside(int y, int x, string text, *hash style){}
static QoreValue Window_drawAnsiTextInside_ViViVsNh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    int64 x = HARD_QORE_VALUE_INT(args, 1);
    const QoreStringNode* text = HARD_QORE_VALUE_STRING(args, 2);
    const QoreHashNode* style = get_param_value(args, 3).get<const QoreHashNode>();
# 547 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    if (style) {
        StyleSpec spec;
        parseStyle(style, spec, xsink);
        if (*xsink) {
            return nothing();
        }
        attr_t old_attr = 0;
        short old_pair = 0;
        applyStyle(win, spec, old_attr, old_pair, xsink);
        if (*xsink) {
            return nothing();
        }
        drawAnsiText(win, y, x, true, false, text, xsink);
        restoreStyle(win, old_attr, old_pair);
    } else {
        drawAnsiText(win, y, x, true, false, text, xsink);
    }
    return nothing();
}

// nothing Window::drawAnsiTextInsideLine(int y, string text, *hash style){}
static QoreValue Window_drawAnsiTextInsideLine_ViVsNh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    const QoreStringNode* text = HARD_QORE_VALUE_STRING(args, 1);
    const QoreHashNode* style = get_param_value(args, 2).get<const QoreHashNode>();
# 581 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    if (style) {
        StyleSpec spec;
        parseStyle(style, spec, xsink);
        if (*xsink) {
            return nothing();
        }
        attr_t old_attr = 0;
        short old_pair = 0;
        applyStyle(win, spec, old_attr, old_pair, xsink);
        if (*xsink) {
            return nothing();
        }
        drawAnsiText(win, y, 0, true, true, text, xsink);
        restoreStyle(win, old_attr, old_pair);
    } else {
        drawAnsiText(win, y, 0, true, true, text, xsink);
    }
    return nothing();
}

// nothing Window::drawHLine(int y, int x, int len, *string ch, *hash style){}
static QoreValue Window_drawHLine_ViViViNsNh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    int64 x = HARD_QORE_VALUE_INT(args, 1);
    int64 len = HARD_QORE_VALUE_INT(args, 2);
    const QoreStringNode* ch = get_param_value(args, 3).get<const QoreStringNode>();
    const QoreHashNode* style = get_param_value(args, 4).get<const QoreHashNode>();
# 856 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    StyleSpec spec;
    parseStyle(style, spec, xsink);
    if (*xsink) {
        return nothing();
    }
    chtype c = ch && ch->size() ? ch->c_str()[0] : 0;
    attr_t old_attr = 0;
    short old_pair = 0;
    applyStyle(win, spec, old_attr, old_pair, xsink);
    if (*xsink) {
        return nothing();
    }
    mvwhline(win->win, y, x, c, len);
    restoreStyle(win, old_attr, old_pair);
    return nothing();
}

// nothing Window::drawText(int y, int x, string text, *hash style){}
static QoreValue Window_drawText_ViViVsNh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    int64 x = HARD_QORE_VALUE_INT(args, 1);
    const QoreStringNode* text = HARD_QORE_VALUE_STRING(args, 2);
    const QoreHashNode* style = get_param_value(args, 3).get<const QoreHashNode>();
# 251 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    int cy = 0;
    int cx = 0;
    getyx(win->win, cy, cx);
    StyleSpec spec;
    parseStyle(style, spec, xsink);
    if (*xsink) {
        return nothing();
    }
    attr_t old_attr = 0;
    short old_pair = 0;
    applyStyle(win, spec, old_attr, old_pair, xsink);
    if (*xsink) {
        return nothing();
    }
    mvwaddnstr(win->win, y, x, text->c_str(), text->size());
    restoreStyle(win, old_attr, old_pair);
    return nothing();
}

// nothing Window::drawTextClipped(int y, int x, string text, *hash style){}
static QoreValue Window_drawTextClipped_ViViVsNh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    int64 x = HARD_QORE_VALUE_INT(args, 1);
    const QoreStringNode* text = HARD_QORE_VALUE_STRING(args, 2);
    const QoreHashNode* style = get_param_value(args, 3).get<const QoreHashNode>();
# 289 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    if (!text || !text->size()) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    int cy = 0;
    int cx = 0;
    getyx(win->win, cy, cx);
    int rows = 0;
    int cols = 0;
    getmaxyx(win->win, rows, cols);
    if (y < 0 || y >= rows || cols <= 0) {
        return nothing();
    }
    int start = 0;
    int col = x;
    if (col < 0) {
        start = -col;
        col = 0;
    }
    if (col >= cols) {
        return nothing();
    }
    int len = text->size();
    if (start >= len) {
        return nothing();
    }
    int maxlen = cols - col;
    int n = len - start;
    if (n > maxlen) {
        n = maxlen;
    }
    StyleSpec spec;
    parseStyle(style, spec, xsink);
    if (*xsink) {
        return nothing();
    }
    attr_t old_attr = 0;
    short old_pair = 0;
    applyStyle(win, spec, old_attr, old_pair, xsink);
    if (*xsink) {
        return nothing();
    }
    mvwaddnstr(win->win, y, col, text->c_str() + start, n);
    restoreStyle(win, old_attr, old_pair);
    return nothing();
}

// nothing Window::drawTextInside(int y, int x, string text, *hash style){}
static QoreValue Window_drawTextInside_ViViVsNh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    int64 x = HARD_QORE_VALUE_INT(args, 1);
    const QoreStringNode* text = HARD_QORE_VALUE_STRING(args, 2);
    const QoreHashNode* style = get_param_value(args, 3).get<const QoreHashNode>();
# 353 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    if (!text || !text->size()) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    int cy = 0;
    int cx = 0;
    getyx(win->win, cy, cx);
    int rows = 0;
    int cols = 0;
    getmaxyx(win->win, rows, cols);
    int inner_rows = rows - 2;
    int inner_cols = cols - 2;
    if (inner_rows <= 0 || inner_cols <= 0) {
        return nothing();
    }
    if (y < 0 || y >= inner_rows) {
        return nothing();
    }
    int start = 0;
    int col = x;
    if (col < 0) {
        start = -col;
        col = 0;
    }
    if (col >= inner_cols) {
        return nothing();
    }
    int len = text->size();
    if (start >= len) {
        return nothing();
    }
    int maxlen = inner_cols - col;
    int n = len - start;
    if (n > maxlen) {
        n = maxlen;
    }
    StyleSpec spec;
    parseStyle(style, spec, xsink);
    if (*xsink) {
        return nothing();
    }
    attr_t old_attr = 0;
    short old_pair = 0;
    applyStyle(win, spec, old_attr, old_pair, xsink);
    if (*xsink) {
        return nothing();
    }
    mvwaddnstr(win->win, y + 1, col + 1, text->c_str() + start, n);
    restoreStyle(win, old_attr, old_pair);
    return nothing();
}

// nothing Window::drawTextInsideLine(int y, string text, *hash style){}
static QoreValue Window_drawTextInsideLine_ViVsNh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    const QoreStringNode* text = HARD_QORE_VALUE_STRING(args, 1);
    const QoreHashNode* style = get_param_value(args, 2).get<const QoreHashNode>();
# 460 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    int cy = 0;
    int cx = 0;
    getyx(win->win, cy, cx);
    int rows = 0;
    int cols = 0;
    getmaxyx(win->win, rows, cols);
    int inner_rows = rows - 2;
    int inner_cols = cols - 2;
    if (inner_rows <= 0 || inner_cols <= 0) {
        return nothing();
    }
    if (y < 0 || y >= inner_rows) {
        return nothing();
    }
    StyleSpec spec;
    parseStyle(style, spec, xsink);
    if (*xsink) {
        return nothing();
    }
    attr_t old_attr = 0;
    short old_pair = 0;
    applyStyle(win, spec, old_attr, old_pair, xsink);
    if (*xsink) {
        return nothing();
    }
    mvwhline(win->win, y + 1, 1, ' ', inner_cols);
    if (text && text->size()) {
        int n = text->size();
        if (n > inner_cols) {
            n = inner_cols;
        }
        mvwaddnstr(win->win, y + 1, 1, text->c_str(), n);
    }
    restoreStyle(win, old_attr, old_pair);
    return nothing();
}

// nothing Window::drawVLine(int y, int x, int len, *string ch, *hash style){}
static QoreValue Window_drawVLine_ViViViNsNh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    int64 x = HARD_QORE_VALUE_INT(args, 1);
    int64 len = HARD_QORE_VALUE_INT(args, 2);
    const QoreStringNode* ch = get_param_value(args, 3).get<const QoreStringNode>();
    const QoreHashNode* style = get_param_value(args, 4).get<const QoreHashNode>();
# 889 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    StyleSpec spec;
    parseStyle(style, spec, xsink);
    if (*xsink) {
        return nothing();
    }
    chtype c = ch && ch->size() ? ch->c_str()[0] : 0;
    attr_t old_attr = 0;
    short old_pair = 0;
    applyStyle(win, spec, old_attr, old_pair, xsink);
    if (*xsink) {
        return nothing();
    }
    mvwvline(win->win, y, x, c, len);
    restoreStyle(win, old_attr, old_pair);
    return nothing();
}

// nothing Window::enableKeypad(bool enabled){}
static QoreValue Window_enableKeypad_Vb(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    bool enabled = HARD_QORE_VALUE_BOOL(args, 0);
# 1050 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    keypad(win->win, enabled ? TRUE : FALSE);
    return nothing();
}

// nothing Window::enableScroll(bool enabled){}
static QoreValue Window_enableScroll_Vb(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    bool enabled = HARD_QORE_VALUE_BOOL(args, 0);
# 1034 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    scrollok(win->win, enabled ? TRUE : FALSE);
    return nothing();
}

// nothing Window::erase(){}
static QoreValue Window_erase(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 116 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    werase(win->win);
    return nothing();
}

// nothing Window::fillRect(int y, int x, int rows, int cols, *string ch, *hash style){}
static QoreValue Window_fillRect_ViViViViNsNh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    int64 x = HARD_QORE_VALUE_INT(args, 1);
    int64 rows = HARD_QORE_VALUE_INT(args, 2);
    int64 cols = HARD_QORE_VALUE_INT(args, 3);
    const QoreStringNode* ch = get_param_value(args, 4).get<const QoreStringNode>();
    const QoreHashNode* style = get_param_value(args, 5).get<const QoreHashNode>();
# 749 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    StyleSpec spec;
    parseStyle(style, spec, xsink);
    if (*xsink) {
        return nothing();
    }
    chtype c = ' ';
    if (ch && ch->size() > 0) {
        c = static_cast<chtype>(ch->c_str()[0]);
    }
    attr_t old_attr = 0;
    short old_pair = 0;
    applyStyle(win, spec, old_attr, old_pair, xsink);
    if (*xsink) {
        return nothing();
    }
    for (int r = 0; r < rows; ++r) {
        mvwhline(win->win, y + r, x, c, cols);
    }
    restoreStyle(win, old_attr, old_pair);
    return nothing();
}

// enum<WrapMode> Window::getWrapMode(){}
static QoreValue Window_getWrapMode(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 633 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    return (int64)win->wrap_mode;
}

// nothing Window::move(int y, int x){}
static QoreValue Window_move_ViVi(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    int64 x = HARD_QORE_VALUE_INT(args, 1);
# 953 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    mvwin(win->win, y, x);
    return nothing();
}

// nothing Window::moveCursor(int y, int x){}
static QoreValue Window_moveCursor_ViVi(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    int64 x = HARD_QORE_VALUE_INT(args, 1);
# 161 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    wmove(win->win, y, x);
    if (win->session && !win->leave_ok) {
        win->session->cursor_win = win->win;
        win->session->cursor_y = y;
        win->session->cursor_x = x;
        win->session->cursor_set = true;
    }
    return nothing();
}

// nothing Window::noutrefresh(){}
static QoreValue Window_noutrefresh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 144 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    wnoutrefresh(win->win);
    return nothing();
}

// hash<Position> Window::position(){}
static QoreValue Window_position(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 219 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    int y = 0;
    int x = 0;
    getbegyx(win->win, y, x);
    ReferenceHolder<QoreHashNode> h(new QoreHashNode(hashdeclPosition, xsink), xsink);
    h->setKeyValue("y", y, xsink);
    h->setKeyValue("x", x, xsink);
    return h.release();
}

// hash<InputEvent> Window::readEvent(*int timeout_ms, *int poll_ms){}
static QoreValue Window_readEvent_NiNi(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 timeout_ms = HARD_QORE_VALUE_INT(args, 0);
    int64 poll_ms = HARD_QORE_VALUE_INT(args, 1);
# 1182 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    size_t argc = args ? args->size() : 0;
    while (argc > 0 && args->retrieveEntry(argc - 1).isNothing()) {
        --argc;
    }
    int timeout = argc > 0 ? timeout_ms : -1;
    int poll = argc > 1 ? poll_ms : 25;
    if (poll <= 0) {
        xsink->raiseException("NCURSES-ERROR", "poll_ms must be > 0");
        return nothing();
    }
    int elapsed = 0;
    while (true) {
        // check for sandbox interrupt between poll cycles
        if (qore_check_cancel(xsink, "reading terminal input")) {
            return nothing();
        }
        NcursesCallGuard guard(win->session);
        wtimeout(win->win, poll);
        int rc = wgetch(win->win);
        if (rc == ERR) {
            if (timeout >= 0) {
                elapsed += poll;
                if (elapsed >= timeout) {
                    return nothing();
                }
            }
        } else {
            ReferenceHolder<QoreHashNode> h(new QoreHashNode(hashdeclInputEvent, xsink), xsink);
            h->setKeyValue("code", rc, xsink);
            if (rc == KEY_MOUSE) {
                MEVENT ev;
                if (getmouse(&ev) == OK) {
                    h->setKeyValue("type", NC_INPUT_MOUSE, xsink);
                    ReferenceHolder<QoreHashNode> mh(new QoreHashNode(hashdeclMouseEvent, xsink), xsink);
                    mh->setKeyValue("x", ev.x, xsink);
                    mh->setKeyValue("y", ev.y, xsink);
                    mh->setKeyValue("button_state", (int)ev.bstate, xsink);
                    h->setKeyValue("mouse", mh.release(), xsink);
                } else {
                    h->setKeyValue("type", NC_INPUT_MOUSE, xsink);
                }
            } else if (rc == KEY_RESIZE) {
                h->setKeyValue("type", NC_INPUT_RESIZE, xsink);
            } else if (rc >= KEY_MIN) {
                h->setKeyValue("type", NC_INPUT_KEY, xsink);
                const char* nm = keyname(rc);
                if (nm) {
                    h->setKeyValue("name", new QoreStringNode(nm, QCS_UTF8), xsink);
                }
            } else if (rc == 27) {
                // ESC received: check for Alt+key sequence
                wtimeout(win->win, 0);
                int rc2 = wgetch(win->win);
                if (rc2 != ERR && rc2 >= 32 && rc2 < 127) {
                    // Alt+key event
                    h->setKeyValue("type", NC_INPUT_ALT, xsink);
                    char buf[2] = {(char)rc2, 0};
                    h->setKeyValue("ch", new QoreStringNode(buf, QCS_UTF8), xsink);
                } else {
                    if (rc2 != ERR) {
                        ungetch(rc2);
                    }
                    // bare ESC
                    h->setKeyValue("type", NC_INPUT_CHAR, xsink);
                    char buf[2] = {(char)rc, 0};
                    h->setKeyValue("ch", new QoreStringNode(buf, QCS_UTF8), xsink);
                }
            } else {
                h->setKeyValue("type", NC_INPUT_CHAR, xsink);
                char buf[2];
                buf[0] = (char)rc;
                buf[1] = 0;
                h->setKeyValue("ch", new QoreStringNode(buf, QCS_UTF8), xsink);
            }
            return h.release();
        }
    }
    return QoreValue();
}

// list<string> Window::readLines(*int y, *int rows, *int cols){}
static QoreValue Window_readLines_NiNiNi(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    int64 rows = HARD_QORE_VALUE_INT(args, 1);
    int64 cols = HARD_QORE_VALUE_INT(args, 2);
# 1094 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing;
    }
    size_t argc = args ? args->size() : 0;
    while (argc > 0 && args->retrieveEntry(argc - 1).isNothing()) {
        --argc;
    }

    int start_y = argc > 0 ? y : 0;
    int max_rows = argc > 1 ? rows : -1;
    int max_cols = argc > 2 ? cols : -1;

    NcursesCallGuard guard(win->session);
    int total_rows = 0;
    int total_cols = 0;
    getmaxyx(win->win, total_rows, total_cols);
    if (max_rows < 0 || max_rows > total_rows) {
        max_rows = total_rows;
    }
    if (max_cols < 0 || max_cols > total_cols) {
        max_cols = total_cols;
    }
    if (start_y < 0) {
        start_y = 0;
    }
    if (start_y >= total_rows || max_rows <= 0 || max_cols <= 0) {
        return new QoreListNode(autoTypeInfo);
    }
    int end_row = std::min(total_rows, start_y + max_rows);
    int width = max_cols;
    ReferenceHolder<QoreListNode> out(new QoreListNode(autoTypeInfo), xsink);
    if (*xsink) {
        return nothing;
    }
    std::string buf;
    buf.resize(width + 1);
    for (int row = start_y; row < end_row; ++row) {
        mvwinnstr(win->win, row, 0, &buf[0], width);
        buf[width] = 0;
        out->push(new QoreStringNode(buf.c_str(), QCS_UTF8), xsink);
        if (*xsink) {
            return nothing;
        }
    }
    return out.release();
}

// string Window::readText(int y, int x, int len){}
static QoreValue Window_readText_ViViVi(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    int64 x = HARD_QORE_VALUE_INT(args, 1);
    int64 len = HARD_QORE_VALUE_INT(args, 2);
# 1068 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing;
    }
    NcursesCallGuard guard(win->session);
    if (len <= 0) {
        return new QoreStringNode();
    }
    std::string buf;
    buf.resize(len + 1);
    mvwinnstr(win->win, y, x, &buf[0], len);
    buf[len] = 0;
    return new QoreStringNode(buf.c_str(), QCS_UTF8);
}

// nothing Window::refresh(){}
static QoreValue Window_refresh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 130 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    wrefresh(win->win);
    return nothing();
}

// nothing Window::resize(int rows, int cols){}
static QoreValue Window_resize_ViVi(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 rows = HARD_QORE_VALUE_INT(args, 0);
    int64 cols = HARD_QORE_VALUE_INT(args, 1);
# 970 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    if (wresize(win->win, rows, cols) != OK) {
        xsink->raiseException("NCURSES-ERROR", "wresize() failed");
    }
    return nothing();
}

// nothing Window::restoreCursor(hash pos){}
static QoreValue Window_restoreCursor_Vh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    const QoreHashNode* pos = HARD_QORE_VALUE_HASH(args, 0);
# 689 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    int y = pos ? pos->getKeyValue("y").getAsBigInt() : 0;
    int x = pos ? pos->getKeyValue("x").getAsBigInt() : 0;
    wmove(win->win, y, x);
    if (win->session && !win->leave_ok) {
        win->session->cursor_win = win->win;
        win->session->cursor_y = y;
        win->session->cursor_x = x;
        win->session->cursor_set = true;
    }
    // Queue cursor position even if the window contents are unchanged.
    wnoutrefresh(win->win);
    return nothing();
}

// hash<Position> Window::saveCursor(){}
static QoreValue Window_saveCursor(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 668 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    int y = 0;
    int x = 0;
    getyx(win->win, y, x);
    ReferenceHolder<QoreHashNode> h(new QoreHashNode(hashdeclPosition, xsink), xsink);
    h->setKeyValue("y", y, xsink);
    h->setKeyValue("x", x, xsink);
    return h.release();
}

// nothing Window::scroll(int n){}
static QoreValue Window_scroll_Vi(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 n = HARD_QORE_VALUE_INT(args, 0);
# 1018 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    wscrl(win->win, n);
    return nothing();
}

// nothing Window::setBackground(*hash style){}
static QoreValue Window_setBackground_Nh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    const QoreHashNode* style = get_param_value(args, 0).get<const QoreHashNode>();
# 1272 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    StyleSpec spec;
    parseStyle(style, spec, xsink);
    if (*xsink) {
        return nothing();
    }
    int fg = spec.has_fg ? spec.fg : -1;
    int bg = spec.has_bg ? spec.bg : -1;
    short pair = win->session->getColorPair(fg, bg, xsink);
    if (*xsink) {
        return nothing();
    }
    wbkgdset(win->win, COLOR_PAIR(pair) | spec.attrs);
    return nothing();
}

// nothing Window::setLeaveOk(bool on){}
static QoreValue Window_setLeaveOk_Vb(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    bool on = HARD_QORE_VALUE_BOOL(args, 0);
# 647 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    leaveok(win->win, on ? TRUE : FALSE);
    win->leave_ok = on;
    if (on && win->session && win->session->cursor_win == win->win) {
        win->session->cursor_win = nullptr;
        win->session->cursor_set = false;
    }
    return nothing();
}

// nothing Window::setWrapMode(enum<WrapMode> mode){}
static QoreValue Window_setWrapMode_C14enum_WrapMode_(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    QoreValue mode = get_param_value(args, 0);
# 613 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    int64 m = mode.getAsBigInt();
    if (m < 0 || m > 2) {
        xsink->raiseException("NCURSES-ERROR", "invalid wrap mode %d", (int)m);
        return nothing();
    }
    win->wrap_mode = (int)m;
    return nothing();
}

// hash<Size> Window::size(){}
static QoreValue Window_size(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 200 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    int rows = 0;
    int cols = 0;
    getmaxyx(win->win, rows, cols);
    ReferenceHolder<QoreHashNode> h(new QoreHashNode(hashdeclSize, xsink), xsink);
    h->setKeyValue("rows", rows, xsink);
    h->setKeyValue("cols", cols, xsink);
    return h.release();
}

// Window Window::subWindow(int rows, int cols, int y, int x){}
static QoreValue Window_subWindow_ViViViVi(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 rows = HARD_QORE_VALUE_INT(args, 0);
    int64 cols = HARD_QORE_VALUE_INT(args, 1);
    int64 y = HARD_QORE_VALUE_INT(args, 2);
    int64 x = HARD_QORE_VALUE_INT(args, 3);
# 1152 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    WINDOW* w = derwin(win->win, rows, cols, y, x);
    if (!w) {
        xsink->raiseException("NCURSES-ERROR", "derwin() failed");
        return nothing();
    }
    QoreObject* obj = new QoreObject(QC_WINDOW, getProgram(), new NcursesWindow(win->session, w, true));
    return obj;
}

// nothing Window::write(string text, *hash style){}
static QoreValue Window_write_VsNh(QoreObject* self, NcursesWindow* win, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    const QoreStringNode* text = HARD_QORE_VALUE_STRING(args, 0);
    const QoreHashNode* style = get_param_value(args, 1).get<const QoreHashNode>();
# 716 "/home/david/src/qore/git/module-ncurses/src/QC_Window.qpp"
    win->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(win->session);
    StyleSpec spec;
    parseStyle(style, spec, xsink);
    if (*xsink) {
        return nothing();
    }
    attr_t old_attr = 0;
    short old_pair = 0;
    applyStyle(win, spec, old_attr, old_pair, xsink);
    if (*xsink) {
        return nothing();
    }
    waddnstr(win->win, text->c_str(), text->size());
    restoreStyle(win, old_attr, old_pair);
    return nothing();
}

DLLLOCAL void preinitWindowClass() {
    QC_WINDOW = new QoreBuiltinClass("Window", "::Qore::Ncurses::Window", QDOM_TERMINAL_IO);
    CID_WINDOW = QC_WINDOW->getID();
    QC_WINDOW->setSystem();
}

DLLLOCAL QoreClass* initWindowClass(QoreNamespace& ns) {
    if (!QC_WINDOW)
        preinitWindowClass();

    // nothing Window::addChar(int y, int x, string ch, *hash style){}
    QC_WINDOW->addMethod("addChar", (q_method_t)Window_addChar_ViViVsNh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 4, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntTypeInfo, QORE_PARAM_NO_ARG, "x", stringTypeInfo, QORE_PARAM_NO_ARG, "ch", hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    // nothing Window::border(*string ls, *string rs, *string ts, *string bs, *string tl, *string tr, *string bl, *string br, *hash style){}
    QC_WINDOW->addMethod("border", (q_method_t)Window_border_NsNsNsNsNsNsNsNsNh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 9, stringOrNothingTypeInfo, QORE_PARAM_NO_ARG, "ls", stringOrNothingTypeInfo, QORE_PARAM_NO_ARG, "rs", stringOrNothingTypeInfo, QORE_PARAM_NO_ARG, "ts", stringOrNothingTypeInfo, QORE_PARAM_NO_ARG, "bs", stringOrNothingTypeInfo, QORE_PARAM_NO_ARG, "tl", stringOrNothingTypeInfo, QORE_PARAM_NO_ARG, "tr", stringOrNothingTypeInfo, QORE_PARAM_NO_ARG, "bl", stringOrNothingTypeInfo, QORE_PARAM_NO_ARG, "br", hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    // nothing Window::box(*hash style){}
    QC_WINDOW->addMethod("box", (q_method_t)Window_box_Nh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    // nothing Window::clear(){}
    QC_WINDOW->addMethod("clear", (q_method_t)Window_clear, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // nothing Window::clearInsideLine(int y, *hash style){}
    QC_WINDOW->addMethod("clearInsideLine", (q_method_t)Window_clearInsideLine_ViNh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 2, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    // nothing Window::clearLine(int y, *hash style){}
    QC_WINDOW->addMethod("clearLine", (q_method_t)Window_clearLine_ViNh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 2, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    // Window::constructor(Qore::Ncurses::Session session, int rows, int cols, int y, int x) {}
    QC_WINDOW->addConstructor(Window_constructor_C7SessionViViViVi, Public, QCF_NO_FLAGS, QDOM_DEFAULT, 5, QC_SESSION->getTypeInfo(), QORE_PARAM_NO_ARG, "session", bigIntTypeInfo, QORE_PARAM_NO_ARG, "rows", bigIntTypeInfo, QORE_PARAM_NO_ARG, "cols", bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntTypeInfo, QORE_PARAM_NO_ARG, "x");

    // hash<Position> Window::cursor(){}
    QC_WINDOW->addMethod("cursor", (q_method_t)Window_cursor, Public, QCF_NO_FLAGS, QDOM_DEFAULT, hashdeclPosition->getTypeInfo(false));

    // nothing Window::drawAnsiText(int y, int x, string text, *hash style){}
    QC_WINDOW->addMethod("drawAnsiText", (q_method_t)Window_drawAnsiText_ViViVsNh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 4, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntTypeInfo, QORE_PARAM_NO_ARG, "x", stringTypeInfo, QORE_PARAM_NO_ARG, "text", hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    // nothing Window::drawAnsiTextInside(int y, int x, string text, *hash style){}
    QC_WINDOW->addMethod("drawAnsiTextInside", (q_method_t)Window_drawAnsiTextInside_ViViVsNh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 4, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntTypeInfo, QORE_PARAM_NO_ARG, "x", stringTypeInfo, QORE_PARAM_NO_ARG, "text", hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    // nothing Window::drawAnsiTextInsideLine(int y, string text, *hash style){}
    QC_WINDOW->addMethod("drawAnsiTextInsideLine", (q_method_t)Window_drawAnsiTextInsideLine_ViVsNh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 3, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", stringTypeInfo, QORE_PARAM_NO_ARG, "text", hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    // nothing Window::drawHLine(int y, int x, int len, *string ch, *hash style){}
    QC_WINDOW->addMethod("drawHLine", (q_method_t)Window_drawHLine_ViViViNsNh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 5, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntTypeInfo, QORE_PARAM_NO_ARG, "x", bigIntTypeInfo, QORE_PARAM_NO_ARG, "len", stringOrNothingTypeInfo, QORE_PARAM_NO_ARG, "ch", hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    // nothing Window::drawText(int y, int x, string text, *hash style){}
    QC_WINDOW->addMethod("drawText", (q_method_t)Window_drawText_ViViVsNh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 4, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntTypeInfo, QORE_PARAM_NO_ARG, "x", stringTypeInfo, QORE_PARAM_NO_ARG, "text", hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    // nothing Window::drawTextClipped(int y, int x, string text, *hash style){}
    QC_WINDOW->addMethod("drawTextClipped", (q_method_t)Window_drawTextClipped_ViViVsNh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 4, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntTypeInfo, QORE_PARAM_NO_ARG, "x", stringTypeInfo, QORE_PARAM_NO_ARG, "text", hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    // nothing Window::drawTextInside(int y, int x, string text, *hash style){}
    QC_WINDOW->addMethod("drawTextInside", (q_method_t)Window_drawTextInside_ViViVsNh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 4, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntTypeInfo, QORE_PARAM_NO_ARG, "x", stringTypeInfo, QORE_PARAM_NO_ARG, "text", hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    // nothing Window::drawTextInsideLine(int y, string text, *hash style){}
    QC_WINDOW->addMethod("drawTextInsideLine", (q_method_t)Window_drawTextInsideLine_ViVsNh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 3, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", stringTypeInfo, QORE_PARAM_NO_ARG, "text", hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    // nothing Window::drawVLine(int y, int x, int len, *string ch, *hash style){}
    QC_WINDOW->addMethod("drawVLine", (q_method_t)Window_drawVLine_ViViViNsNh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 5, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntTypeInfo, QORE_PARAM_NO_ARG, "x", bigIntTypeInfo, QORE_PARAM_NO_ARG, "len", stringOrNothingTypeInfo, QORE_PARAM_NO_ARG, "ch", hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    // nothing Window::enableKeypad(bool enabled){}
    QC_WINDOW->addMethod("enableKeypad", (q_method_t)Window_enableKeypad_Vb, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, boolTypeInfo, QORE_PARAM_NO_ARG, "enabled");

    // nothing Window::enableScroll(bool enabled){}
    QC_WINDOW->addMethod("enableScroll", (q_method_t)Window_enableScroll_Vb, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, boolTypeInfo, QORE_PARAM_NO_ARG, "enabled");

    // nothing Window::erase(){}
    QC_WINDOW->addMethod("erase", (q_method_t)Window_erase, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // nothing Window::fillRect(int y, int x, int rows, int cols, *string ch, *hash style){}
    QC_WINDOW->addMethod("fillRect", (q_method_t)Window_fillRect_ViViViViNsNh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 6, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntTypeInfo, QORE_PARAM_NO_ARG, "x", bigIntTypeInfo, QORE_PARAM_NO_ARG, "rows", bigIntTypeInfo, QORE_PARAM_NO_ARG, "cols", stringOrNothingTypeInfo, QORE_PARAM_NO_ARG, "ch", hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    // enum<WrapMode> Window::getWrapMode(){}
    QC_WINDOW->addMethod("getWrapMode", (q_method_t)Window_getWrapMode, Public, QCF_CONSTANT, QDOM_DEFAULT, enumWrapMode->getTypeInfo(false));

    // nothing Window::move(int y, int x){}
    QC_WINDOW->addMethod("move", (q_method_t)Window_move_ViVi, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 2, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntTypeInfo, QORE_PARAM_NO_ARG, "x");

    // nothing Window::moveCursor(int y, int x){}
    QC_WINDOW->addMethod("moveCursor", (q_method_t)Window_moveCursor_ViVi, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 2, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntTypeInfo, QORE_PARAM_NO_ARG, "x");

    // nothing Window::noutrefresh(){}
    QC_WINDOW->addMethod("noutrefresh", (q_method_t)Window_noutrefresh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // hash<Position> Window::position(){}
    QC_WINDOW->addMethod("position", (q_method_t)Window_position, Public, QCF_NO_FLAGS, QDOM_DEFAULT, hashdeclPosition->getTypeInfo(false));

    // hash<InputEvent> Window::readEvent(*int timeout_ms, *int poll_ms){}
    QC_WINDOW->addMethod("readEvent", (q_method_t)Window_readEvent_NiNi, Public, QCF_NO_FLAGS, QDOM_DEFAULT, hashdeclInputEvent->getTypeInfo(false), 2, bigIntOrNothingTypeInfo, QORE_PARAM_NO_ARG, "timeout_ms", bigIntOrNothingTypeInfo, QORE_PARAM_NO_ARG, "poll_ms");

    // list<string> Window::readLines(*int y, *int rows, *int cols){}
    QC_WINDOW->addMethod("readLines", (q_method_t)Window_readLines_NiNiNi, Public, QCF_NO_FLAGS, QDOM_DEFAULT, qore_get_complex_list_type(stringTypeInfo), 3, bigIntOrNothingTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntOrNothingTypeInfo, QORE_PARAM_NO_ARG, "rows", bigIntOrNothingTypeInfo, QORE_PARAM_NO_ARG, "cols");

    // string Window::readText(int y, int x, int len){}
    QC_WINDOW->addMethod("readText", (q_method_t)Window_readText_ViViVi, Public, QCF_NO_FLAGS, QDOM_DEFAULT, stringTypeInfo, 3, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntTypeInfo, QORE_PARAM_NO_ARG, "x", bigIntTypeInfo, QORE_PARAM_NO_ARG, "len");

    // nothing Window::refresh(){}
    QC_WINDOW->addMethod("refresh", (q_method_t)Window_refresh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // nothing Window::resize(int rows, int cols){}
    QC_WINDOW->addMethod("resize", (q_method_t)Window_resize_ViVi, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 2, bigIntTypeInfo, QORE_PARAM_NO_ARG, "rows", bigIntTypeInfo, QORE_PARAM_NO_ARG, "cols");

    // nothing Window::restoreCursor(hash pos){}
    QC_WINDOW->addMethod("restoreCursor", (q_method_t)Window_restoreCursor_Vh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, hashTypeInfo, QORE_PARAM_NO_ARG, "pos");

    // hash<Position> Window::saveCursor(){}
    QC_WINDOW->addMethod("saveCursor", (q_method_t)Window_saveCursor, Public, QCF_NO_FLAGS, QDOM_DEFAULT, hashdeclPosition->getTypeInfo(false));

    // nothing Window::scroll(int n){}
    QC_WINDOW->addMethod("scroll", (q_method_t)Window_scroll_Vi, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, bigIntTypeInfo, QORE_PARAM_NO_ARG, "n");

    // nothing Window::setBackground(*hash style){}
    QC_WINDOW->addMethod("setBackground", (q_method_t)Window_setBackground_Nh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    // nothing Window::setLeaveOk(bool on){}
    QC_WINDOW->addMethod("setLeaveOk", (q_method_t)Window_setLeaveOk_Vb, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, boolTypeInfo, QORE_PARAM_NO_ARG, "on");

    // nothing Window::setWrapMode(enum<WrapMode> mode){}
    QC_WINDOW->addMethod("setWrapMode", (q_method_t)Window_setWrapMode_C14enum_WrapMode_, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, enumWrapMode->getTypeInfo(false), QORE_PARAM_NO_ARG, "mode");

    // hash<Size> Window::size(){}
    QC_WINDOW->addMethod("size", (q_method_t)Window_size, Public, QCF_NO_FLAGS, QDOM_DEFAULT, hashdeclSize->getTypeInfo(false));

    // Window Window::subWindow(int rows, int cols, int y, int x){}
    QC_WINDOW->addMethod("subWindow", (q_method_t)Window_subWindow_ViViViVi, Public, QCF_NO_FLAGS, QDOM_DEFAULT, QC_WINDOW->getTypeInfo(), 4, bigIntTypeInfo, QORE_PARAM_NO_ARG, "rows", bigIntTypeInfo, QORE_PARAM_NO_ARG, "cols", bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntTypeInfo, QORE_PARAM_NO_ARG, "x");

    // nothing Window::write(string text, *hash style){}
    QC_WINDOW->addMethod("write", (q_method_t)Window_write_VsNh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 2, stringTypeInfo, QORE_PARAM_NO_ARG, "text", hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "style");

    return QC_WINDOW;
}
// ---------------------------------------------
// Window implementation
// ---------------------------------------------

/**
    @param session the session
    @param rows window height
    @param cols window width
    @param y top position
    @param x left position

    @since %ncurses 2.0
*/

/**
    @param y row
    @param x column
    @param text text to draw
    @param style optional style hash

    @since %ncurses 2.0
*/

/**
    @param timeout_ms total timeout in milliseconds (-1 for infinite)
    @param poll_ms poll interval in milliseconds

    @return hash<@ref InputEvent> or @ref nothing on timeout

    @since %ncurses 2.0
*/
