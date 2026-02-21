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
/* Qore class Qore::Ncurses::Panel */

qore_classid_t CID_PANEL;
QoreClass* QC_PANEL;

// nothing Panel::bottom(){}
static QoreValue Panel_bottom(QoreObject* self, NcursesPanel* panel, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 174 "/home/david/src/qore/git/module-ncurses/src/QC_Panel.qpp"
    panel->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(panel->session);
    bottom_panel(panel->panel);
    return nothing();
}

// Panel::constructor(Qore::Ncurses::Window window) {}
static void Panel_constructor_C6Window(QoreObject* self, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    HARD_QORE_VALUE_OBJ_DATA(window, NcursesWindow, args, 0, CID_WINDOW, "Panel::constructor()", "Qore::Ncurses::Window", xsink);
    if (*xsink)
        return;
# 74 "/home/david/src/qore/git/module-ncurses/src/QC_Panel.qpp"
ReferenceHolder<NcursesWindow> wh(window, xsink);
    if (*xsink) {
        return;
    }
    wh->checkOpen(xsink);
    if (*xsink) {
        return;
    }
    NcursesCallGuard guard(wh->session);
    PANEL* p = new_panel(wh->win);
    if (!p) {
        xsink->raiseException("NCURSES-ERROR", "new_panel() failed");
        return;
    }
    QoreObject* wobj = const_cast<QoreObject*>(obj_window);
    self->setPrivate(CID_PANEL, new NcursesPanel(wh->session, p, wobj));
}

// Panel::constructor(Qore::Ncurses::Session session, int rows, int cols, int y, int x) {}
static void Panel_constructor_C7SessionViViViVi(QoreObject* self, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    HARD_QORE_VALUE_OBJ_DATA(session, NcursesSession, args, 0, CID_SESSION, "Panel::constructor()", "Qore::Ncurses::Session", xsink);
    if (*xsink)
        return;
    int64 rows = HARD_QORE_VALUE_INT(args, 1);
    int64 cols = HARD_QORE_VALUE_INT(args, 2);
    int64 y = HARD_QORE_VALUE_INT(args, 3);
    int64 x = HARD_QORE_VALUE_INT(args, 4);
# 103 "/home/david/src/qore/git/module-ncurses/src/QC_Panel.qpp"
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
    PANEL* p = new_panel(w);
    if (!p) {
        delwin(w);
        xsink->raiseException("NCURSES-ERROR", "new_panel() failed");
        return;
    }
    QoreObject* wobj = new QoreObject(QC_WINDOW, getProgram(), new NcursesWindow(*sh, w, true));
    self->setPrivate(CID_PANEL, new NcursesPanel(*sh, p, wobj));
}

// enum<WrapMode> Panel::getWrapMode(){}
static QoreValue Panel_getWrapMode(QoreObject* self, NcursesPanel* panel, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 264 "/home/david/src/qore/git/module-ncurses/src/QC_Panel.qpp"
    panel->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    if (!panel->window_obj) {
        return 1;
    }
    PrivateDataRefHolder<NcursesWindow> wh(panel->window_obj, CID_WINDOW, xsink);
    if (*xsink || !wh) {
        return 1;
    }
    return (int64)wh->wrap_mode;
}

// nothing Panel::hide(){}
static QoreValue Panel_hide(QoreObject* self, NcursesPanel* panel, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 146 "/home/david/src/qore/git/module-ncurses/src/QC_Panel.qpp"
    panel->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(panel->session);
    hide_panel(panel->panel);
    return nothing();
}

// nothing Panel::move(int y, int x){}
static QoreValue Panel_move_ViVi(QoreObject* self, NcursesPanel* panel, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    int64 x = HARD_QORE_VALUE_INT(args, 1);
# 191 "/home/david/src/qore/git/module-ncurses/src/QC_Panel.qpp"
    panel->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(panel->session);
    move_panel(panel->panel, y, x);
    return nothing();
}

// nothing Panel::setWrapMode(enum<WrapMode> mode){}
static QoreValue Panel_setWrapMode_C14enum_WrapMode_(QoreObject* self, NcursesPanel* panel, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    QoreValue mode = get_param_value(args, 0);
# 237 "/home/david/src/qore/git/module-ncurses/src/QC_Panel.qpp"
    panel->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    if (!panel->window_obj) {
        return nothing();
    }
    PrivateDataRefHolder<NcursesWindow> wh(panel->window_obj, CID_WINDOW, xsink);
    if (*xsink || !wh) {
        return nothing();
    }
    int64 m = mode.getAsBigInt();
    if (m < 0 || m > 2) {
        xsink->raiseException("NCURSES-ERROR", "invalid wrap mode %d", (int)m);
        return nothing();
    }
    wh->wrap_mode = (int)m;
    return nothing();
}

// nothing Panel::show(){}
static QoreValue Panel_show(QoreObject* self, NcursesPanel* panel, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 132 "/home/david/src/qore/git/module-ncurses/src/QC_Panel.qpp"
    panel->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(panel->session);
    show_panel(panel->panel);
    return nothing();
}

// nothing Panel::top(){}
static QoreValue Panel_top(QoreObject* self, NcursesPanel* panel, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 160 "/home/david/src/qore/git/module-ncurses/src/QC_Panel.qpp"
    panel->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(panel->session);
    top_panel(panel->panel);
    return nothing();
}

// nothing Panel::update(){}
static QoreValue Panel_update(QoreObject* self, NcursesPanel* panel, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 205 "/home/david/src/qore/git/module-ncurses/src/QC_Panel.qpp"
    panel->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(panel->session);
    update_panels();
    doupdate();
    return nothing();
}

// Window Panel::window(){}
static QoreValue Panel_window(QoreObject* self, NcursesPanel* panel, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 220 "/home/david/src/qore/git/module-ncurses/src/QC_Panel.qpp"
    panel->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    if (!panel->window_obj) {
        return nothing();
    }
    return panel->window_obj->refSelf();
}

DLLLOCAL void preinitPanelClass() {
    QC_PANEL = new QoreBuiltinClass("Panel", "::Qore::Ncurses::Panel", QDOM_TERMINAL_IO);
    CID_PANEL = QC_PANEL->getID();
    QC_PANEL->setSystem();
}

DLLLOCAL QoreClass* initPanelClass(QoreNamespace& ns) {
    if (!QC_PANEL)
        preinitPanelClass();

    // nothing Panel::bottom(){}
    QC_PANEL->addMethod("bottom", (q_method_t)Panel_bottom, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // Panel::constructor(Qore::Ncurses::Window window) {}
    QC_PANEL->addConstructor(Panel_constructor_C6Window, Public, QCF_NO_FLAGS, QDOM_DEFAULT, 1, QC_WINDOW->getTypeInfo(), QORE_PARAM_NO_ARG, "window");

    // Panel::constructor(Qore::Ncurses::Session session, int rows, int cols, int y, int x) {}
    QC_PANEL->addConstructor(Panel_constructor_C7SessionViViViVi, Public, QCF_NO_FLAGS, QDOM_DEFAULT, 5, QC_SESSION->getTypeInfo(), QORE_PARAM_NO_ARG, "session", bigIntTypeInfo, QORE_PARAM_NO_ARG, "rows", bigIntTypeInfo, QORE_PARAM_NO_ARG, "cols", bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntTypeInfo, QORE_PARAM_NO_ARG, "x");

    // enum<WrapMode> Panel::getWrapMode(){}
    QC_PANEL->addMethod("getWrapMode", (q_method_t)Panel_getWrapMode, Public, QCF_CONSTANT, QDOM_DEFAULT, enumWrapMode->getTypeInfo(false));

    // nothing Panel::hide(){}
    QC_PANEL->addMethod("hide", (q_method_t)Panel_hide, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // nothing Panel::move(int y, int x){}
    QC_PANEL->addMethod("move", (q_method_t)Panel_move_ViVi, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 2, bigIntTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntTypeInfo, QORE_PARAM_NO_ARG, "x");

    // nothing Panel::setWrapMode(enum<WrapMode> mode){}
    QC_PANEL->addMethod("setWrapMode", (q_method_t)Panel_setWrapMode_C14enum_WrapMode_, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, enumWrapMode->getTypeInfo(false), QORE_PARAM_NO_ARG, "mode");

    // nothing Panel::show(){}
    QC_PANEL->addMethod("show", (q_method_t)Panel_show, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // nothing Panel::top(){}
    QC_PANEL->addMethod("top", (q_method_t)Panel_top, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // nothing Panel::update(){}
    QC_PANEL->addMethod("update", (q_method_t)Panel_update, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // Window Panel::window(){}
    QC_PANEL->addMethod("window", (q_method_t)Panel_window, Public, QCF_NO_FLAGS, QDOM_DEFAULT, QC_WINDOW->getTypeInfo());

    return QC_PANEL;
}
// ---------------------------------------------
// Panel implementation
// ---------------------------------------------
