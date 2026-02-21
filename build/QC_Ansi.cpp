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
/* Qore class Qore::Ncurses::Ansi */

qore_classid_t CID_ANSI;
QoreClass* QC_ANSI;

// static int Ansi::len(string text){}
static QoreValue static_Ansi_len_Vs(const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    const QoreStringNode* text = HARD_QORE_VALUE_STRING(args, 0);
# 75 "/home/david/src/qore/git/module-ncurses/src/QC_Ansi.qpp"
std::vector<AnsiSegment> segs;
    parseAnsiSegments(text, segs);
    size_t total = 0;
    for (const auto& seg : segs) {
        total += seg.text.size();
    }
    return static_cast<int>(total);
}

// static list<hash> Ansi::parse(string text){}
static QoreValue static_Ansi_parse_Vs(const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    const QoreStringNode* text = HARD_QORE_VALUE_STRING(args, 0);
# 43 "/home/david/src/qore/git/module-ncurses/src/QC_Ansi.qpp"
std::vector<AnsiSegment> segs;
    parseAnsiSegments(text, segs);
    ReferenceHolder<QoreListNode> list(new QoreListNode(autoTypeInfo), xsink);
    for (const auto& seg : segs) {
        ReferenceHolder<QoreHashNode> h(new QoreHashNode(autoTypeInfo), xsink);
        ReferenceHolder<QoreStringNode> t(new QoreStringNode(seg.text.c_str(), text->getEncoding()), xsink);
        h->setKeyValue("text", t.release(), xsink);
        if (seg.style.has_fg || seg.style.has_bg || seg.style.attrs) {
            ReferenceHolder<QoreHashNode> sh(new QoreHashNode(hashdeclStyle, xsink), xsink);
            if (seg.style.has_fg) {
                sh->setKeyValue("fg", seg.style.fg, xsink);
            }
            if (seg.style.has_bg) {
                sh->setKeyValue("bg", seg.style.bg, xsink);
            }
            if (seg.style.attrs) {
                sh->setKeyValue("attrs", seg.style.attrs, xsink);
            }
            h->setKeyValue("style", sh.release(), xsink);
        }
        list->push(h.release(), xsink);
    }
    return list.release();
}

// static list<string> Ansi::wrap(string text, int width, enum<WrapMode> mode = 2){}
static QoreValue static_Ansi_wrap_VsViC14enum_WrapMode_(const QoreListNode* args, RuntimeConfig& runtime_cfg, ExceptionSink* xsink) {
    const QoreStringNode* text = HARD_QORE_VALUE_STRING(args, 0);
    int64 width = HARD_QORE_VALUE_INT(args, 1);
    QoreValue mode = get_param_value(args, 2);
# 93 "/home/david/src/qore/git/module-ncurses/src/QC_Ansi.qpp"
ReferenceHolder<QoreListNode> list(new QoreListNode(stringTypeInfo), xsink);
    if (width <= 0) {
        return list.release();
    }
    std::vector<AnsiSegment> segs;
    parseAnsiSegments(text, segs);
    struct StyledChar {
        char c;
        StyleSpec style;
    };
    std::vector<StyledChar> chars;
    for (const auto& seg : segs) {
        for (size_t i = 0; i < seg.text.size(); ++i) {
            chars.push_back({seg.text[i], seg.style});
        }
    }
    auto style_eq = [](const StyleSpec& a, const StyleSpec& b) {
        return a.has_fg == b.has_fg && a.has_bg == b.has_bg && a.fg == b.fg && a.bg == b.bg && a.attrs == b.attrs;
    };
    auto style_empty = [](const StyleSpec& s) {
        return !s.has_fg && !s.has_bg && !s.attrs;
    };
    auto style_sgr = [](const StyleSpec& s) {
        std::string out;
        std::vector<int> codes;
        if (s.attrs & A_BOLD) {
            codes.push_back(1);
        }
        if (s.attrs & A_DIM) {
            codes.push_back(2);
        }
        if (s.attrs & A_UNDERLINE) {
            codes.push_back(4);
        }
        if (s.attrs & A_REVERSE) {
            codes.push_back(7);
        }
        if (s.has_fg) {
            codes.push_back(30 + s.fg);
        }
        if (s.has_bg) {
            codes.push_back(40 + s.bg);
        }
        if (codes.empty()) {
            return out;
        }
        out = "\x1b[";
        for (size_t i = 0; i < codes.size(); ++i) {
            if (i) {
                out += ";";
            }
            out += std::to_string(codes[i]);
        }
        out += "m";
        return out;
    };
    auto emit_line = [&](size_t start, size_t end) {
        std::string line;
        StyleSpec cur;
        bool cur_set = false;
        for (size_t i = start; i < end; ++i) {
            const StyleSpec& st = chars[i].style;
            if (!cur_set || !style_eq(cur, st)) {
                line += "\x1b[0m";
                std::string sgr = style_sgr(st);
                line += sgr;
                cur = st;
                cur_set = true;
            }
            line.push_back(chars[i].c);
        }
        if (cur_set && !style_empty(cur)) {
            line += "\x1b[0m";
        }
        return line;
    };
    if (mode.getAsBigInt() == 0 || chars.empty()) {
        if (!chars.empty()) {
            std::string line = emit_line(0, chars.size());
            list->push(new QoreStringNode(line.c_str(), text->getEncoding()), xsink);
        }
        return list.release();
    }
    size_t i = 0;
    int wrap_mode = static_cast<int>(mode.getAsBigInt());
    while (i < chars.size()) {
        size_t remaining = chars.size() - i;
        if (remaining <= static_cast<size_t>(width)) {
            std::string line = emit_line(i, chars.size());
            list->push(new QoreStringNode(line.c_str(), text->getEncoding()), xsink);
            break;
        }
        size_t end = i + width;
        if (wrap_mode == 2) {
            ssize_t last_space = -1;
            for (size_t j = i; j < end; ++j) {
                if (chars[j].c == ' ' || chars[j].c == '\t') {
                    last_space = static_cast<ssize_t>(j);
                }
            }
            if (last_space > static_cast<ssize_t>(i)) {
                std::string line = emit_line(i, static_cast<size_t>(last_space));
                list->push(new QoreStringNode(line.c_str(), text->getEncoding()), xsink);
                i = static_cast<size_t>(last_space + 1);
                while (i < chars.size() && (chars[i].c == ' ' || chars[i].c == '\t')) {
                    ++i;
                }
                continue;
            }
        }
        std::string line = emit_line(i, end);
        list->push(new QoreStringNode(line.c_str(), text->getEncoding()), xsink);
        i = end;
    }
    return list.release();
}

DLLLOCAL void preinitAnsiClass() {
    QC_ANSI = new QoreBuiltinClass("Ansi", "::Qore::Ncurses::Ansi", QDOM_TERMINAL_IO);
    CID_ANSI = QC_ANSI->getID();
    QC_ANSI->setSystem();
}

DLLLOCAL QoreClass* initAnsiClass(QoreNamespace& ns) {
    if (!QC_ANSI)
        preinitAnsiClass();

    // static int Ansi::len(string text){}
    QC_ANSI->addStaticMethod("len", (q_func_t)static_Ansi_len_Vs, Public, QCF_CONSTANT, QDOM_DEFAULT, bigIntTypeInfo, 1, stringTypeInfo, QORE_PARAM_NO_ARG, "text");

    // static list<hash> Ansi::parse(string text){}
    QC_ANSI->addStaticMethod("parse", (q_func_t)static_Ansi_parse_Vs, Public, QCF_CONSTANT, QDOM_DEFAULT, qore_get_complex_list_type(hashTypeInfo), 1, stringTypeInfo, QORE_PARAM_NO_ARG, "text");

    // static list<string> Ansi::wrap(string text, int width, enum<WrapMode> mode = 2){}
    QC_ANSI->addStaticMethod("wrap", (q_func_t)static_Ansi_wrap_VsViC14enum_WrapMode_, Public, QCF_CONSTANT, QDOM_DEFAULT, qore_get_complex_list_type(stringTypeInfo), 3, stringTypeInfo, QORE_PARAM_NO_ARG, "text", bigIntTypeInfo, QORE_PARAM_NO_ARG, "width", enumWrapMode->getTypeInfo(false), QoreSimpleValue((int64)2), "mode");

    return QC_ANSI;
}
