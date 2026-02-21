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
QoreEnumDecl* init_enum_CursorVisibility(QoreNamespace& ns) {
    QoreEnumDecl* ed = new QoreEnumDecl("CursorVisibility", "::Qore::Ncurses::CursorVisibility", bigIntTypeInfo);
    ed->addMember("Hidden", 0);
    ed->addMember("Normal", 1);
    ed->addMember("VeryVisible", 2);
    ns.addSystemEnum(ed);
    return ed;
}

QoreEnumDecl* init_enum_InputType(QoreNamespace& ns) {
    QoreEnumDecl* ed = new QoreEnumDecl("InputType", "::Qore::Ncurses::InputType", bigIntTypeInfo);
    ed->addMember("None", 0);
    ed->addMember("Char", 1);
    ed->addMember("Key", 2);
    ed->addMember("Mouse", 3);
    ed->addMember("Resize", 4);
    ed->addMember("Alt", 5);
    ns.addSystemEnum(ed);
    return ed;
}

QoreEnumDecl* init_enum_Color(QoreNamespace& ns) {
    QoreEnumDecl* ed = new QoreEnumDecl("Color", "::Qore::Ncurses::Color", bigIntTypeInfo);
    ed->addMember("Default", -1);
    ed->addMember("Black", COLOR_BLACK);
    ed->addMember("Red", COLOR_RED);
    ed->addMember("Green", COLOR_GREEN);
    ed->addMember("Yellow", COLOR_YELLOW);
    ed->addMember("Blue", COLOR_BLUE);
    ed->addMember("Magenta", COLOR_MAGENTA);
    ed->addMember("Cyan", COLOR_CYAN);
    ed->addMember("White", COLOR_WHITE);
    ns.addSystemEnum(ed);
    return ed;
}

QoreEnumDecl* init_enum_Attr(QoreNamespace& ns) {
    QoreEnumDecl* ed = new QoreEnumDecl("Attr", "::Qore::Ncurses::Attr", bigIntTypeInfo);
    ed->addMember("NormalAttr", A_NORMAL);
    ed->addMember("Standout", A_STANDOUT);
    ed->addMember("Underline", A_UNDERLINE);
    ed->addMember("Reverse", A_REVERSE);
    ed->addMember("Blink", A_BLINK);
    ed->addMember("Dim", A_DIM);
    ed->addMember("Bold", A_BOLD);
    ns.addSystemEnum(ed);
    return ed;
}

QoreEnumDecl* init_enum_WrapMode(QoreNamespace& ns) {
    QoreEnumDecl* ed = new QoreEnumDecl("WrapMode", "::Qore::Ncurses::WrapMode", bigIntTypeInfo);
    ed->addMember("None", 0);
    ed->addMember("Hard", 1);
    ed->addMember("Word", 2);
    ns.addSystemEnum(ed);
    return ed;
}

TypedHashDecl* init_hashdecl_Style(QoreNamespace& ns) {
    TypedHashDecl* hd = new TypedHashDecl("Style", "::Qore::Ncurses::Style");
    hd->addMember("attrs", bigIntTypeInfo, QoreValue());
    hd->addMember("bg", bigIntTypeInfo, QoreValue());
    hd->addMember("fg", bigIntTypeInfo, QoreValue());
    ns.addSystemHashDecl(hd);
    return hd;
}

TypedHashDecl* init_hashdecl_Size(QoreNamespace& ns) {
    TypedHashDecl* hd = new TypedHashDecl("Size", "::Qore::Ncurses::Size");
    hd->addMember("cols", bigIntTypeInfo, QoreValue());
    hd->addMember("rows", bigIntTypeInfo, QoreValue());
    ns.addSystemHashDecl(hd);
    return hd;
}

TypedHashDecl* init_hashdecl_Position(QoreNamespace& ns) {
    TypedHashDecl* hd = new TypedHashDecl("Position", "::Qore::Ncurses::Position");
    hd->addMember("x", bigIntTypeInfo, QoreValue());
    hd->addMember("y", bigIntTypeInfo, QoreValue());
    ns.addSystemHashDecl(hd);
    return hd;
}

TypedHashDecl* init_hashdecl_MouseEvent(QoreNamespace& ns) {
    TypedHashDecl* hd = new TypedHashDecl("MouseEvent", "::Qore::Ncurses::MouseEvent");
    hd->addMember("button_state", bigIntTypeInfo, QoreValue());
    hd->addMember("x", bigIntTypeInfo, QoreValue());
    hd->addMember("y", bigIntTypeInfo, QoreValue());
    ns.addSystemHashDecl(hd);
    return hd;
}

TypedHashDecl* init_hashdecl_InputEvent(QoreNamespace& ns) {
    TypedHashDecl* hd = new TypedHashDecl("InputEvent", "::Qore::Ncurses::InputEvent");
    hd->addMember("ch", stringTypeInfo, QoreValue());
    hd->addMember("code", bigIntTypeInfo, QoreValue());
    hd->addMember("mouse", hashdeclMouseEvent->getTypeInfo(false), QoreValue());
    hd->addMember("name", stringTypeInfo, QoreValue());
    hd->addMember("type", bigIntTypeInfo, QoreValue());
    ns.addSystemHashDecl(hd);
    return hd;
}

/* Qore class Qore::Ncurses::Session */

qore_classid_t CID_SESSION;
QoreClass* QC_SESSION;

// nothing Session::beep(){}
static QoreValue Session_beep(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 867 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(session);
    ::beep();
    return nothing();
}

// bool Session::canChangeColor(){}
static QoreValue Session_canChangeColor(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 768 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return false;
    }
    NcursesCallGuard guard(session);
    return can_change_color();
}

// nothing Session::close(){}
static QoreValue Session_close(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 608 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->close(xsink);
    return QoreValue();
}

// Session::constructor(*hash opts) {}
static void Session_constructor_Nh(QoreObject* self, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    const QoreHashNode* opts = get_param_value(args, 0).get<const QoreHashNode>();
# 326 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
NcursesSession* s = new NcursesSession();

    bool echo_on = false;
    bool raw_on = false;
    bool cbreak_on = true;
    bool keypad_on = true;
    bool mouse_on = true;
    bool colors_on = true;
    bool default_colors_on = true;
    int cursor = 0;
    int esc_delay = -1;
    bool use_tty = false;
    bool unbuffered_stdio = false;
    bool unbuffered_stdio_set = false;
    std::string tty_path = "/dev/tty";

    ReferenceHolder<NcursesTestTerminal> tterm_holder(nullptr, xsink);
    if (opts) {
        QoreValue v;
        v = opts->getKeyValue("echo");
        if (!v.isNothing()) { echo_on = v.getAsBool(); }
        v = opts->getKeyValue("raw");
        if (!v.isNothing()) { raw_on = v.getAsBool(); }
        v = opts->getKeyValue("cbreak");
        if (!v.isNothing()) { cbreak_on = v.getAsBool(); }
        v = opts->getKeyValue("keypad");
        if (!v.isNothing()) { keypad_on = v.getAsBool(); }
        v = opts->getKeyValue("mouse");
        if (!v.isNothing()) { mouse_on = v.getAsBool(); }
        v = opts->getKeyValue("use_colors");
        if (!v.isNothing()) { colors_on = v.getAsBool(); }
        v = opts->getKeyValue("use_default_colors");
        if (!v.isNothing()) { default_colors_on = v.getAsBool(); }
        v = opts->getKeyValue("cursor");
        if (!v.isNothing()) { cursor = v.getAsBigInt(); }
        v = opts->getKeyValue("esc_delay");
        if (!v.isNothing()) { esc_delay = v.getAsBigInt(); }
        v = opts->getKeyValue("use_tty");
        if (!v.isNothing()) { use_tty = v.getAsBool(); }
        v = opts->getKeyValue("tty_path");
        if (!v.isNothing()) { tty_path = v.get<QoreStringNode>()->c_str(); }
        v = opts->getKeyValue("unbuffered_stdio");
        if (!v.isNothing()) {
            unbuffered_stdio = v.getAsBool();
            unbuffered_stdio_set = true;
        }
        v = opts->getKeyValue("test_terminal");
        if (!v.isNothing() && v.getType() == NT_OBJECT) {
            QoreObject* obj = v.get<QoreObject>();
            TryPrivateDataRefHolder<NcursesTestTerminal> t(obj, CID_TESTTERMINAL, xsink);
            if (!*xsink && t) {
                tterm_holder = t.release();
            }
        }
    }

    if (use_tty && !unbuffered_stdio_set) {
        unbuffered_stdio = true;
    } else if (!use_tty) {
        unbuffered_stdio = false;
    }

    AutoLocker al(ncurses_lock);

    if (tterm_holder) {
        tterm_holder->ensureOpen(xsink);
        if (*xsink) {
            delete s;
            return;
        }
        setenv("TERM", tterm_holder->term.c_str(), 1);
        FILE* in = fdopen(dup(tterm_holder->slave_fd), "r");
        FILE* out = fdopen(dup(tterm_holder->slave_fd), "w");
        if (!in || !out) {
            if (in) { fclose(in); }
            if (out) { fclose(out); }
            delete s;
            xsink->raiseException("NCURSES-ERROR", "failed to open test terminal streams");
            return;
        }
        s->in_file = in;
        s->out_file = out;
        s->screen = newterm(nullptr, out, in);
        if (!s->screen) {
            delete s;
            xsink->raiseException("NCURSES-ERROR", "newterm() failed");
            return;
        }
        s->is_default = false;
        set_term(s->screen);
        s->stdwin = stdscr;
    } else if (use_tty) {
        // check sandbox filesystem access before opening TTY device
        QoreSandboxManagerHelper smh;
        if (smh) {
            if (!smh->checkFilesystemAccess(tty_path.c_str(), QSEC_READ | QSEC_WRITE, xsink)) {
                delete s;
                return;
            }
        }
        FILE* in = fopen(tty_path.c_str(), "r");
        FILE* out = fopen(tty_path.c_str(), "w");
        if (!in || !out) {
            if (in) { fclose(in); }
            if (out) { fclose(out); }
            delete s;
            xsink->raiseException("NCURSES-ERROR", "failed to open tty device '%s'", tty_path.c_str());
            return;
        }
        s->in_file = in;
        s->out_file = out;
        s->screen = newterm(nullptr, out, in);
        if (!s->screen) {
            delete s;
            xsink->raiseException("NCURSES-ERROR", "newterm() failed");
            return;
        }
        s->is_default = false;
        set_term(s->screen);
        s->stdwin = stdscr;
    } else {
        s->screen = newterm(nullptr, stdout, stdin);
        if (!s->screen) {
            delete s;
            xsink->raiseException("NCURSES-ERROR", "newterm() failed");
            return;
        }
        s->is_default = true;
        set_term(s->screen);
        s->stdwin = stdscr;
    }

    if (use_tty && unbuffered_stdio) {
        setvbuf(stdout, nullptr, _IONBF, 0);
        setvbuf(stderr, nullptr, _IONBF, 0);
    }

    if (!s->stdwin) {
        delete s;
        xsink->raiseException("NCURSES-ERROR", "failed to initialize ncurses");
        return;
    }

    if (cbreak_on) { cbreak(); }
    if (raw_on) { raw(); }
    if (!echo_on) { noecho(); }
    keypad(s->stdwin, keypad_on ? TRUE : FALSE);

    if (mouse_on) {
        mousemask(ALL_MOUSE_EVENTS, nullptr);
    }

    if (colors_on && has_colors()) {
        start_color();
        s->colors_enabled = true;
        if (default_colors_on) {
            use_default_colors();
            s->use_default_colors = true;
        }
    }

    if (cursor >= 0) {
        curs_set(cursor);
    }
    if (esc_delay >= 0) {
#ifdef NCURSES_VERSION
        set_escdelay(esc_delay);
#else
#ifdef ESCDELAY
        ESCDELAY = esc_delay;
#endif
#endif
    }

    self->setPrivate(CID_SESSION, s);
}

// nothing Session::doupdate(){}
static QoreValue Session_doupdate(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 849 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(session);
    if (session->cursor_set && session->cursor_win) {
        wmove(session->cursor_win, session->cursor_y, session->cursor_x);
        wnoutrefresh(session->cursor_win);
    }
    doupdate();
    return nothing();
}

// nothing Session::flash(){}
static QoreValue Session_flash(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 881 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(session);
    ::flash();
    return nothing();
}

// nothing Session::flushInput(){}
static QoreValue Session_flushInput(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 818 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(session);
    flushinp();
    return nothing();
}

// nothing Session::flushStdio(){}
static QoreValue Session_flushStdio(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 598 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    fflush(stdout);
    fflush(stderr);
    return nothing();
}

// nothing Session::initColor(int color, int r, int g, int b){}
static QoreValue Session_initColor_ViViViVi(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 color = HARD_QORE_VALUE_INT(args, 0);
    int64 r = HARD_QORE_VALUE_INT(args, 1);
    int64 g = HARD_QORE_VALUE_INT(args, 2);
    int64 b = HARD_QORE_VALUE_INT(args, 3);
# 790 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(session);
    if (!can_change_color()) {
        xsink->raiseException("NCURSES-ERROR", "terminal does not support color redefinition");
        return nothing();
    }
    if (color < 0 || color >= COLORS) {
        xsink->raiseException("NCURSES-ERROR", "color number %d out of range (0-%d)", (int)color, COLORS - 1);
        return nothing();
    }
    if (r < 0 || r > 1000 || g < 0 || g > 1000 || b < 0 || b > 1000) {
        xsink->raiseException("NCURSES-ERROR", "RGB values must be in range 0-1000");
        return nothing();
    }
    if (init_color(color, r, g, b) != OK) {
        xsink->raiseException("NCURSES-ERROR", "init_color() failed for color %d", (int)color);
    }
    return nothing();
}

// nothing Session::injectEvent(hash<InputEvent> ev){}
static QoreValue Session_injectEvent_C16hash_InputEvent_(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    const QoreHashNode* ev = HARD_QORE_VALUE_HASH(args, 0);
# 947 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    if (!ev) {
        return nothing();
    }
    int type = NC_INPUT_CHAR;
    bool type_set = false;
    QoreValue vtype = ev->getKeyValue("type");
    if (!vtype.isNothing()) {
        type = vtype.getAsBigInt();
        type_set = true;
    }

    QoreValue vcode = ev->getKeyValue("code");
    QoreValue vch = ev->getKeyValue("ch");
    QoreValue vmouse = ev->getKeyValue("mouse");

    if (!type_set) {
        if (!vmouse.isNothing()) {
            type = NC_INPUT_MOUSE;
        } else if (!vcode.isNothing() && vcode.getAsBigInt() >= KEY_MIN) {
            type = NC_INPUT_KEY;
        } else {
            type = NC_INPUT_CHAR;
        }
    }

    NcursesCallGuard guard(session);
    if (type == NC_INPUT_CHAR) {
        if (!vch.isNothing()) {
            QoreStringNode* s = vch.get<QoreStringNode>();
            if (!s || !s->size()) {
                return nothing();
            }
            const char* buf = s->c_str();
            size_t len = s->size();
            for (size_t i = 0; i < len; ++i) {
                ungetch((unsigned char)buf[len - 1 - i]);
            }
            return nothing();
        }
        if (vcode.isNothing()) {
            xsink->raiseException("NCURSES-ERROR", "injectEvent(): missing 'ch' or 'code' for Char event");
            return nothing();
        }
        int code = vcode.getAsBigInt();
        ungetch(code);
        return nothing();
    } else if (type == NC_INPUT_KEY) {
        if (vcode.isNothing()) {
            xsink->raiseException("NCURSES-ERROR", "injectEvent(): missing 'code' for Key event");
            return nothing();
        }
        int code = vcode.getAsBigInt();
        ungetch(code);
        return nothing();
    } else if (type == NC_INPUT_MOUSE) {
        if (vmouse.isNothing() || vmouse.getType() != NT_HASH) {
            xsink->raiseException("NCURSES-ERROR", "injectEvent(): missing 'mouse' hash for Mouse event");
            return nothing();
        }
        QoreHashNode* mh = vmouse.get<QoreHashNode>();
        int mx = 0;
        int my = 0;
        int bs = 0;
        QoreValue vx = mh->getKeyValue("x");
        QoreValue vy = mh->getKeyValue("y");
        QoreValue vbs = mh->getKeyValue("button_state");
        if (!vx.isNothing()) { mx = vx.getAsBigInt(); }
        if (!vy.isNothing()) { my = vy.getAsBigInt(); }
        if (!vbs.isNothing()) { bs = vbs.getAsBigInt(); }
        MEVENT me = {};
        me.x = mx;
        me.y = my;
        me.bstate = (mmask_t)bs;
        ungetmouse(&me);
        ungetch(KEY_MOUSE);
        return nothing();
    } else if (type == NC_INPUT_RESIZE) {
        ungetch(KEY_RESIZE);
        return nothing();
    } else if (type == NC_INPUT_ALT) {
        if (vch.isNothing()) {
            xsink->raiseException("NCURSES-ERROR", "injectEvent(): missing 'ch' for Alt event");
            return nothing();
        }
        QoreStringNode* s = vch.get<QoreStringNode>();
        if (!s || !s->size()) {
            xsink->raiseException("NCURSES-ERROR", "injectEvent(): empty 'ch' for Alt event");
            return nothing();
        }
        // ungetch is LIFO: push the char first, then ESC
        ungetch((unsigned char)s->c_str()[0]);
        ungetch(27);
        return nothing();
    }

    xsink->raiseException("NCURSES-ERROR", "injectEvent(): unsupported event type %d", type);
    return nothing();
}

// nothing Session::injectEvents(list<hash<InputEvent>> events){}
static QoreValue Session_injectEvents_C22list_hash_InputEvent__(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    const QoreListNode* events = HARD_QORE_VALUE_LIST(args, 0);
# 1057 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    if (!events) {
        return nothing();
    }
    size_t count = events->size();
    NcursesCallGuard guard(session);
    for (size_t i = 0; i < count; ++i) {
        size_t idx = count - 1 - i;
        QoreValue v = events->retrieveEntry(idx);
        if (v.isNothing() || v.getType() != NT_HASH) {
            continue;
        }
        QoreHashNode* h = v.get<QoreHashNode>();
        int type = NC_INPUT_CHAR;
        bool type_set = false;
        QoreValue vtype = h->getKeyValue("type");
        if (!vtype.isNothing()) {
            type = vtype.getAsBigInt();
            type_set = true;
        }

        QoreValue vcode = h->getKeyValue("code");
        QoreValue vch = h->getKeyValue("ch");
        QoreValue vmouse = h->getKeyValue("mouse");

        if (!type_set) {
            if (!vmouse.isNothing()) {
                type = NC_INPUT_MOUSE;
            } else if (!vcode.isNothing() && vcode.getAsBigInt() >= KEY_MIN) {
                type = NC_INPUT_KEY;
            } else {
                type = NC_INPUT_CHAR;
            }
        }

        if (type == NC_INPUT_CHAR) {
            if (!vch.isNothing()) {
                QoreStringNode* s = vch.get<QoreStringNode>();
                if (!s || !s->size()) {
                    continue;
                }
                const char* buf = s->c_str();
                size_t len = s->size();
                for (size_t i2 = 0; i2 < len; ++i2) {
                    ungetch((unsigned char)buf[len - 1 - i2]);
                }
            } else if (vcode.isNothing()) {
                xsink->raiseException("NCURSES-ERROR", "injectEvents(): missing 'ch' or 'code' for Char event");
                return nothing();
            } else {
                int code = vcode.getAsBigInt();
                ungetch(code);
            }
        } else if (type == NC_INPUT_KEY) {
            if (vcode.isNothing()) {
                xsink->raiseException("NCURSES-ERROR", "injectEvents(): missing 'code' for Key event");
                return nothing();
            }
            int code = vcode.getAsBigInt();
            ungetch(code);
        } else if (type == NC_INPUT_MOUSE) {
            if (vmouse.isNothing() || vmouse.getType() != NT_HASH) {
                xsink->raiseException("NCURSES-ERROR", "injectEvents(): missing 'mouse' hash for Mouse event");
                return nothing();
            }
            QoreHashNode* mh = vmouse.get<QoreHashNode>();
            int mx = 0;
            int my = 0;
            int bs = 0;
            QoreValue vx = mh->getKeyValue("x");
            QoreValue vy = mh->getKeyValue("y");
            QoreValue vbs = mh->getKeyValue("button_state");
            if (!vx.isNothing()) { mx = vx.getAsBigInt(); }
            if (!vy.isNothing()) { my = vy.getAsBigInt(); }
            if (!vbs.isNothing()) { bs = vbs.getAsBigInt(); }
            MEVENT me = {};
            me.x = mx;
            me.y = my;
            me.bstate = (mmask_t)bs;
            ungetmouse(&me);
            ungetch(KEY_MOUSE);
        } else if (type == NC_INPUT_RESIZE) {
            ungetch(KEY_RESIZE);
        } else if (type == NC_INPUT_ALT) {
            if (vch.isNothing()) {
                xsink->raiseException("NCURSES-ERROR", "injectEvents(): missing 'ch' for Alt event");
                return nothing();
            }
            QoreStringNode* s2 = vch.get<QoreStringNode>();
            if (!s2 || !s2->size()) {
                xsink->raiseException("NCURSES-ERROR", "injectEvents(): empty 'ch' for Alt event");
                return nothing();
            }
            // ungetch is LIFO: push the char first, then ESC
            ungetch((unsigned char)s2->c_str()[0]);
            ungetch(27);
        } else {
            xsink->raiseException("NCURSES-ERROR", "injectEvents(): unsupported event type %d", type);
            return nothing();
        }
        if (*xsink) {
            return nothing();
        }
    }
    return nothing();
}

// nothing Session::injectInput(string data){}
static QoreValue Session_injectInput_Vs(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    const QoreStringNode* data = HARD_QORE_VALUE_STRING(args, 0);
# 920 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(session);
    if (!data || !data->size()) {
        return nothing();
    }
    const char* buf = data->c_str();
    size_t len = data->size();
    for (size_t i = 0; i < len; ++i) {
        ungetch((unsigned char)buf[len - 1 - i]);
    }
    return nothing();
}

// bool Session::isOpen(){}
static QoreValue Session_isOpen(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 616 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    return session && !session->closed;
}

// int Session::maxColors(){}
static QoreValue Session_maxColors(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 751 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return 0;
    }
    NcursesCallGuard guard(session);
    return COLORS;
}

// nothing Session::redirectStderr(File file){}
static QoreValue Session_redirectStderr_C4File(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    HARD_QORE_VALUE_OBJ_DATA(file, File, args, 0, CID_FILE, "Session::redirectStderr()", "File", xsink);
    if (*xsink)
        return 0;
# 562 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    ReferenceHolder<File> f(file, xsink);
    if (*xsink) {
        return nothing();
    }
    if (qore_check_cancel(xsink, "redirecting stderr")) {
        return nothing();
    }
    if (!file || !file->isOpen()) {
        xsink->raiseException("NCURSES-ERROR", "cannot redirect stderr: file is not open");
        return nothing();
    }
    int fd = file->getFD();
    if (fd < 0) {
        xsink->raiseException("NCURSES-ERROR", "cannot redirect stderr: invalid file descriptor");
        return nothing();
    }
    // flush any buffered data to the current (old) target before redirecting
    fflush(stderr);
    if (dup2(fd, STDERR_FILENO) < 0) {
        xsink->raiseErrnoException("NCURSES-ERROR", errno, "dup2() failed redirecting stderr");
        return nothing();
    }
    // set unbuffered mode; fflush above ensures this takes effect
    setvbuf(stderr, nullptr, _IONBF, 0);
    return nothing();
}

// nothing Session::redirectStdout(File file){}
static QoreValue Session_redirectStdout_C4File(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    HARD_QORE_VALUE_OBJ_DATA(file, File, args, 0, CID_FILE, "Session::redirectStdout()", "File", xsink);
    if (*xsink)
        return 0;
# 527 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    ReferenceHolder<File> f(file, xsink);
    if (*xsink) {
        return nothing();
    }
    if (qore_check_cancel(xsink, "redirecting stdout")) {
        return nothing();
    }
    if (!file || !file->isOpen()) {
        xsink->raiseException("NCURSES-ERROR", "cannot redirect stdout: file is not open");
        return nothing();
    }
    int fd = file->getFD();
    if (fd < 0) {
        xsink->raiseException("NCURSES-ERROR", "cannot redirect stdout: invalid file descriptor");
        return nothing();
    }
    // flush any buffered data to the current (old) target before redirecting
    fflush(stdout);
    if (dup2(fd, STDOUT_FILENO) < 0) {
        xsink->raiseErrnoException("NCURSES-ERROR", errno, "dup2() failed redirecting stdout");
        return nothing();
    }
    // set unbuffered mode; fflush above ensures this takes effect even if
    // prior I/O occurred on stdout (setvbuf requires empty buffer on glibc)
    setvbuf(stdout, nullptr, _IONBF, 0);
    return nothing();
}

// Window Session::screen(){}
static QoreValue Session_screen(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 624 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    QoreObject* obj = new QoreObject(QC_WINDOW, getProgram(), new NcursesWindow(session, session->stdwin, false));
    return obj;
}

// nothing Session::setCursor(int visibility){}
static QoreValue Session_setCursor_Vi(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 visibility = HARD_QORE_VALUE_INT(args, 0);
# 706 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(session);
    curs_set(visibility);
    return nothing();
}

// int Session::setEscDelay(int ms){}
static QoreValue Session_setEscDelay_Vi(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 ms = HARD_QORE_VALUE_INT(args, 0);
# 723 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return 0;
    }
    if (ms < 0) {
        ms = 0;
    }
    NcursesCallGuard guard(session);
#ifdef NCURSES_VERSION
    return set_escdelay(ms);
#else
#ifdef ESCDELAY
    int old = ESCDELAY;
    ESCDELAY = ms;
    return old;
#else
    return 0;
#endif
#endif
    return QoreValue();
}

// nothing Session::setMouse(bool enabled){}
static QoreValue Session_setMouse_Vb(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    bool enabled = HARD_QORE_VALUE_BOOL(args, 0);
# 511 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(session);
    mousemask(enabled ? ALL_MOUSE_EVENTS : 0, nullptr);
    return nothing();
}

// list<string> Session::snapshot(*int y, *int rows, *int cols){}
static QoreValue Session_snapshot_NiNiNi(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 y = HARD_QORE_VALUE_INT(args, 0);
    int64 rows = HARD_QORE_VALUE_INT(args, 1);
    int64 cols = HARD_QORE_VALUE_INT(args, 2);
# 643 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    size_t argc = args ? args->size() : 0;
    while (argc > 0 && args->retrieveEntry(argc - 1).isNothing()) {
        --argc;
    }

    int start_y = argc > 0 ? y : 0;
    int max_rows = argc > 1 ? rows : -1;
    int max_cols = argc > 2 ? cols : -1;

    NcursesCallGuard guard(session);
    int total_rows = 0;
    int total_cols = 0;
    getmaxyx(session->stdwin, total_rows, total_cols);
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
        return nothing();
    }
    std::string buf;
    buf.resize(width + 1);
    for (int row = start_y; row < end_row; ++row) {
        mvwinnstr(session->stdwin, row, 0, &buf[0], width);
        buf[width] = 0;
        out->push(new QoreStringNode(buf.c_str(), QCS_UTF8), xsink);
        if (*xsink) {
            return nothing();
        }
    }
    return out.release();
}

// bool Session::supportsColor(){}
static QoreValue Session_supportsColor(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 696 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    return session && session->colors_enabled;
}

// nothing Session::updatePanels(){}
static QoreValue Session_updatePanels(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 832 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(session);
    update_panels();
    return nothing();
}

// auto Session::withLock(code cb, *list cb_args){}
static QoreValue Session_withLock_VcNl(QoreObject* self, NcursesSession* session, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    const ResolvedCallReferenceNode* cb = get_param_value(args, 0).get<const ResolvedCallReferenceNode>();
    const QoreListNode* cb_args = get_param_value(args, 1).get<const QoreListNode>();
# 900 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    session->checkOpen(xsink);
    if (*xsink) {
        return nothing();
    }
    NcursesCallGuard guard(session);
    ReferenceHolder<ResolvedCallReferenceNode> holder(cb->refRefSelf(), xsink);
    if (*xsink) {
        return nothing();
    }
    QoreListNode* arg_list = cb_args ? const_cast<QoreListNode*>(cb_args) : nullptr;
    return holder->execValue(arg_list, xsink);
}

DLLLOCAL void preinitSessionClass() {
    QC_SESSION = new QoreBuiltinClass("Session", "::Qore::Ncurses::Session", QDOM_TERMINAL_IO);
    CID_SESSION = QC_SESSION->getID();
    QC_SESSION->setSystem();
}

DLLLOCAL QoreClass* initSessionClass(QoreNamespace& ns) {
    if (!QC_SESSION)
        preinitSessionClass();

    // nothing Session::beep(){}
    QC_SESSION->addMethod("beep", (q_method_t)Session_beep, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // bool Session::canChangeColor(){}
    QC_SESSION->addMethod("canChangeColor", (q_method_t)Session_canChangeColor, Public, QCF_NO_FLAGS, QDOM_DEFAULT, boolTypeInfo);

    // nothing Session::close(){}
    QC_SESSION->addMethod("close", (q_method_t)Session_close, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // Session::constructor(*hash opts) {}
    QC_SESSION->addConstructor(Session_constructor_Nh, Public, QCF_NO_FLAGS, QDOM_DEFAULT, 1, hashOrNothingTypeInfo, QORE_PARAM_NO_ARG, "opts");

    // nothing Session::doupdate(){}
    QC_SESSION->addMethod("doupdate", (q_method_t)Session_doupdate, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // nothing Session::flash(){}
    QC_SESSION->addMethod("flash", (q_method_t)Session_flash, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // nothing Session::flushInput(){}
    QC_SESSION->addMethod("flushInput", (q_method_t)Session_flushInput, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // nothing Session::flushStdio(){}
    QC_SESSION->addMethod("flushStdio", (q_method_t)Session_flushStdio, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // nothing Session::initColor(int color, int r, int g, int b){}
    QC_SESSION->addMethod("initColor", (q_method_t)Session_initColor_ViViViVi, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 4, bigIntTypeInfo, QORE_PARAM_NO_ARG, "color", bigIntTypeInfo, QORE_PARAM_NO_ARG, "r", bigIntTypeInfo, QORE_PARAM_NO_ARG, "g", bigIntTypeInfo, QORE_PARAM_NO_ARG, "b");

    // nothing Session::injectEvent(hash<InputEvent> ev){}
    QC_SESSION->addMethod("injectEvent", (q_method_t)Session_injectEvent_C16hash_InputEvent_, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, hashdeclInputEvent->getTypeInfo(false), QORE_PARAM_NO_ARG, "ev");

    // nothing Session::injectEvents(list<hash<InputEvent>> events){}
    QC_SESSION->addMethod("injectEvents", (q_method_t)Session_injectEvents_C22list_hash_InputEvent__, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, qore_get_complex_list_type(hashdeclInputEvent->getTypeInfo(false)), QORE_PARAM_NO_ARG, "events");

    // nothing Session::injectInput(string data){}
    QC_SESSION->addMethod("injectInput", (q_method_t)Session_injectInput_Vs, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, stringTypeInfo, QORE_PARAM_NO_ARG, "data");

    // bool Session::isOpen(){}
    QC_SESSION->addMethod("isOpen", (q_method_t)Session_isOpen, Public, QCF_NO_FLAGS, QDOM_DEFAULT, boolTypeInfo);

    // int Session::maxColors(){}
    QC_SESSION->addMethod("maxColors", (q_method_t)Session_maxColors, Public, QCF_NO_FLAGS, QDOM_DEFAULT, bigIntTypeInfo);

    // nothing Session::redirectStderr(File file){}
    QC_SESSION->addMethod("redirectStderr", (q_method_t)Session_redirectStderr_C4File, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, QC_FILE->getTypeInfo(), QORE_PARAM_NO_ARG, "file");

    // nothing Session::redirectStdout(File file){}
    QC_SESSION->addMethod("redirectStdout", (q_method_t)Session_redirectStdout_C4File, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, QC_FILE->getTypeInfo(), QORE_PARAM_NO_ARG, "file");

    // Window Session::screen(){}
    QC_SESSION->addMethod("screen", (q_method_t)Session_screen, Public, QCF_NO_FLAGS, QDOM_DEFAULT, QC_WINDOW->getTypeInfo());

    // nothing Session::setCursor(int visibility){}
    QC_SESSION->addMethod("setCursor", (q_method_t)Session_setCursor_Vi, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, bigIntTypeInfo, QORE_PARAM_NO_ARG, "visibility");

    // int Session::setEscDelay(int ms){}
    QC_SESSION->addMethod("setEscDelay", (q_method_t)Session_setEscDelay_Vi, Public, QCF_NO_FLAGS, QDOM_DEFAULT, bigIntTypeInfo, 1, bigIntTypeInfo, QORE_PARAM_NO_ARG, "ms");

    // nothing Session::setMouse(bool enabled){}
    QC_SESSION->addMethod("setMouse", (q_method_t)Session_setMouse_Vb, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, boolTypeInfo, QORE_PARAM_NO_ARG, "enabled");

    // list<string> Session::snapshot(*int y, *int rows, *int cols){}
    QC_SESSION->addMethod("snapshot", (q_method_t)Session_snapshot_NiNiNi, Public, QCF_NO_FLAGS, QDOM_DEFAULT, qore_get_complex_list_type(stringTypeInfo), 3, bigIntOrNothingTypeInfo, QORE_PARAM_NO_ARG, "y", bigIntOrNothingTypeInfo, QORE_PARAM_NO_ARG, "rows", bigIntOrNothingTypeInfo, QORE_PARAM_NO_ARG, "cols");

    // bool Session::supportsColor(){}
    QC_SESSION->addMethod("supportsColor", (q_method_t)Session_supportsColor, Public, QCF_NO_FLAGS, QDOM_DEFAULT, boolTypeInfo);

    // nothing Session::updatePanels(){}
    QC_SESSION->addMethod("updatePanels", (q_method_t)Session_updatePanels, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // auto Session::withLock(code cb, *list cb_args){}
    QC_SESSION->addMethod("withLock", (q_method_t)Session_withLock_VcNl, Public, QCF_NO_FLAGS, QDOM_DEFAULT, autoTypeInfo, 2, codeTypeInfo, QORE_PARAM_NO_ARG, "cb", listOrNothingTypeInfo, QORE_PARAM_NO_ARG, "cb_args");
# 170 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
#ifndef BUTTON5_PRESSED
#define BUTTON5_PRESSED 0
#define BUTTON5_RELEASED 0
#define BUTTON5_CLICKED 0
#define BUTTON5_DOUBLE_CLICKED 0
#define BUTTON5_TRIPLE_CLICKED 0
#endif
# 184 "/home/david/src/qore/git/module-ncurses/src/QC_Session.qpp"
    ns.addConstant("BUTTON1_CLICKED", ((int64)BUTTON1_CLICKED));
    ns.addConstant("BUTTON1_DOUBLE_CLICKED", ((int64)BUTTON1_DOUBLE_CLICKED));
    ns.addConstant("BUTTON1_PRESSED", ((int64)BUTTON1_PRESSED));
    ns.addConstant("BUTTON1_RELEASED", ((int64)BUTTON1_RELEASED));
    ns.addConstant("BUTTON1_TRIPLE_CLICKED", ((int64)BUTTON1_TRIPLE_CLICKED));
    ns.addConstant("BUTTON2_CLICKED", ((int64)BUTTON2_CLICKED));
    ns.addConstant("BUTTON2_DOUBLE_CLICKED", ((int64)BUTTON2_DOUBLE_CLICKED));
    ns.addConstant("BUTTON2_PRESSED", ((int64)BUTTON2_PRESSED));
    ns.addConstant("BUTTON2_RELEASED", ((int64)BUTTON2_RELEASED));
    ns.addConstant("BUTTON2_TRIPLE_CLICKED", ((int64)BUTTON2_TRIPLE_CLICKED));
    ns.addConstant("BUTTON3_CLICKED", ((int64)BUTTON3_CLICKED));
    ns.addConstant("BUTTON3_DOUBLE_CLICKED", ((int64)BUTTON3_DOUBLE_CLICKED));
    ns.addConstant("BUTTON3_PRESSED", ((int64)BUTTON3_PRESSED));
    ns.addConstant("BUTTON3_RELEASED", ((int64)BUTTON3_RELEASED));
    ns.addConstant("BUTTON3_TRIPLE_CLICKED", ((int64)BUTTON3_TRIPLE_CLICKED));
    ns.addConstant("BUTTON4_CLICKED", ((int64)BUTTON4_CLICKED));
    ns.addConstant("BUTTON4_DOUBLE_CLICKED", ((int64)BUTTON4_DOUBLE_CLICKED));
    ns.addConstant("BUTTON4_PRESSED", ((int64)BUTTON4_PRESSED));
    ns.addConstant("BUTTON4_RELEASED", ((int64)BUTTON4_RELEASED));
    ns.addConstant("BUTTON4_TRIPLE_CLICKED", ((int64)BUTTON4_TRIPLE_CLICKED));
    ns.addConstant("BUTTON5_CLICKED", ((int64)BUTTON5_CLICKED));
    ns.addConstant("BUTTON5_DOUBLE_CLICKED", ((int64)BUTTON5_DOUBLE_CLICKED));
    ns.addConstant("BUTTON5_PRESSED", ((int64)BUTTON5_PRESSED));
    ns.addConstant("BUTTON5_RELEASED", ((int64)BUTTON5_RELEASED));
    ns.addConstant("BUTTON5_TRIPLE_CLICKED", ((int64)BUTTON5_TRIPLE_CLICKED));
    ns.addConstant("BUTTON_ALT", ((int64)BUTTON_ALT));
    ns.addConstant("BUTTON_CTRL", ((int64)BUTTON_CTRL));
    ns.addConstant("BUTTON_SHIFT", ((int64)BUTTON_SHIFT));
    ns.addConstant("KEY_BACKSPACE", ((int64)KEY_BACKSPACE));
    ns.addConstant("KEY_DC", ((int64)KEY_DC));
    ns.addConstant("KEY_DOWN", ((int64)KEY_DOWN));
    ns.addConstant("KEY_END", ((int64)KEY_END));
    ns.addConstant("KEY_ENTER", ((int64)KEY_ENTER));
    ns.addConstant("KEY_HOME", ((int64)KEY_HOME));
    ns.addConstant("KEY_IC", ((int64)KEY_IC));
    ns.addConstant("KEY_LEFT", ((int64)KEY_LEFT));
    ns.addConstant("KEY_MOUSE", ((int64)KEY_MOUSE));
    ns.addConstant("KEY_NPAGE", ((int64)KEY_NPAGE));
    ns.addConstant("KEY_PPAGE", ((int64)KEY_PPAGE));
    ns.addConstant("KEY_RESIZE", ((int64)KEY_RESIZE));
    ns.addConstant("KEY_RIGHT", ((int64)KEY_RIGHT));
    ns.addConstant("KEY_UP", ((int64)KEY_UP));

    return QC_SESSION;
}
// ---------------------------------------------
// Session implementation
// ---------------------------------------------
