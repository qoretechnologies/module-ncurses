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
/* Qore class Qore::Ncurses::TestTerminal */

qore_classid_t CID_TESTTERMINAL;
QoreClass* QC_TESTTERMINAL;

// nothing TestTerminal::close(){}
static QoreValue TestTerminal_close(QoreObject* self, NcursesTestTerminal* term, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 135 "/home/david/src/qore/git/module-ncurses/src/QC_TestTerminal.qpp"
    term->close(xsink);
    return nothing();
}

// TestTerminal::constructor(*int rows, *int cols, *string term) {}
static void TestTerminal_constructor_NiNiNs(QoreObject* self, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 rows = HARD_QORE_VALUE_INT(args, 0);
    int64 cols = HARD_QORE_VALUE_INT(args, 1);
    const QoreStringNode* term = get_param_value(args, 2).get<const QoreStringNode>();
# 89 "/home/david/src/qore/git/module-ncurses/src/QC_TestTerminal.qpp"
size_t argc = args ? args->size() : 0;
    while (argc > 0 && args->retrieveEntry(argc - 1).isNothing()) {
        --argc;
    }
    int r = argc > 0 ? rows : 24;
    int c = argc > 1 ? cols : 80;
    self->setPrivate(CID_TESTTERMINAL, new NcursesTestTerminal(r, c, term));
}

// string TestTerminal::getSlavePath(){}
static QoreValue TestTerminal_getSlavePath(QoreObject* self, NcursesTestTerminal* term, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 154 "/home/david/src/qore/git/module-ncurses/src/QC_TestTerminal.qpp"
    term->ensureOpen(xsink);
    if (*xsink) {
        return "";
    }
    if (term->master_fd < 0) {
        xsink->raiseException("NCURSES-TEST-ERROR", "test terminal is closed");
        return "";
    }
    const char* path = ptsname(term->master_fd);
    if (!path) {
        xsink->raiseErrnoException("NCURSES-TEST-ERROR", errno, "ptsname() failed");
        return "";
    }
    return new QoreStringNode(path, QCS_UTF8);
}

// bool TestTerminal::isOpen(){}
static QoreValue TestTerminal_isOpen(QoreObject* self, NcursesTestTerminal* term, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 144 "/home/david/src/qore/git/module-ncurses/src/QC_TestTerminal.qpp"
    return term && term->master_fd >= 0;
}

// nothing TestTerminal::open(){}
static QoreValue TestTerminal_open(QoreObject* self, NcursesTestTerminal* term, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
# 103 "/home/david/src/qore/git/module-ncurses/src/QC_TestTerminal.qpp"
    term->ensureOpen(xsink);
    return nothing();
}

// nothing TestTerminal::resize(int rows, int cols){}
static QoreValue TestTerminal_resize_ViVi(QoreObject* self, NcursesTestTerminal* term, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    int64 rows = HARD_QORE_VALUE_INT(args, 0);
    int64 cols = HARD_QORE_VALUE_INT(args, 1);
# 115 "/home/david/src/qore/git/module-ncurses/src/QC_TestTerminal.qpp"
    term->resize(rows, cols, xsink);
    return nothing();
}

// nothing TestTerminal::writeInput(string data){}
static QoreValue TestTerminal_writeInput_Vs(QoreObject* self, NcursesTestTerminal* term, const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    const QoreStringNode* data = HARD_QORE_VALUE_STRING(args, 0);
# 126 "/home/david/src/qore/git/module-ncurses/src/QC_TestTerminal.qpp"
    term->writeInput(data, xsink);
    return nothing();
}

DLLLOCAL void preinitTestTerminalClass() {
    QC_TESTTERMINAL = new QoreBuiltinClass("TestTerminal", "::Qore::Ncurses::TestTerminal", QDOM_TERMINAL_IO);
    CID_TESTTERMINAL = QC_TESTTERMINAL->getID();
    QC_TESTTERMINAL->setSystem();
}

DLLLOCAL QoreClass* initTestTerminalClass(QoreNamespace& ns) {
    if (!QC_TESTTERMINAL)
        preinitTestTerminalClass();

    // nothing TestTerminal::close(){}
    QC_TESTTERMINAL->addMethod("close", (q_method_t)TestTerminal_close, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // TestTerminal::constructor(*int rows, *int cols, *string term) {}
    QC_TESTTERMINAL->addConstructor(TestTerminal_constructor_NiNiNs, Public, QCF_NO_FLAGS, QDOM_DEFAULT, 3, bigIntOrNothingTypeInfo, QORE_PARAM_NO_ARG, "rows", bigIntOrNothingTypeInfo, QORE_PARAM_NO_ARG, "cols", stringOrNothingTypeInfo, QORE_PARAM_NO_ARG, "term");

    // string TestTerminal::getSlavePath(){}
    QC_TESTTERMINAL->addMethod("getSlavePath", (q_method_t)TestTerminal_getSlavePath, Public, QCF_NO_FLAGS, QDOM_DEFAULT, stringTypeInfo);

    // bool TestTerminal::isOpen(){}
    QC_TESTTERMINAL->addMethod("isOpen", (q_method_t)TestTerminal_isOpen, Public, QCF_NO_FLAGS, QDOM_DEFAULT, boolTypeInfo);

    // nothing TestTerminal::open(){}
    QC_TESTTERMINAL->addMethod("open", (q_method_t)TestTerminal_open, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);

    // nothing TestTerminal::resize(int rows, int cols){}
    QC_TESTTERMINAL->addMethod("resize", (q_method_t)TestTerminal_resize_ViVi, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 2, bigIntTypeInfo, QORE_PARAM_NO_ARG, "rows", bigIntTypeInfo, QORE_PARAM_NO_ARG, "cols");

    // nothing TestTerminal::writeInput(string data){}
    QC_TESTTERMINAL->addMethod("writeInput", (q_method_t)TestTerminal_writeInput_Vs, Public, QCF_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, stringTypeInfo, QORE_PARAM_NO_ARG, "data");

    return QC_TESTTERMINAL;
}
// ---------------------------------------------
// TestTerminal implementation
// ---------------------------------------------

/**
    @param rows
    @param cols
    @param term optional TERM value

    @since %ncurses 2.0
*/
