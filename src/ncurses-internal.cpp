/* -*- mode: c++; indent-tabs-mode: nil -*- */
#include "ncurses-internal.h"

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/select.h>
#include <unistd.h>

#include <thread>

// libpanel allocates a per-SCREEN "pseudo panel" the first time new_panel() is
// called and only frees it when libpanel was built with NO_LEAKS — which is
// off in distro/macports builds. We free it ourselves before delscreen() by
// reaching into the panel hook. Layout matches ncurses' `struct panelhook`
// in include/nc_panel.h (stable since the panel layer was added).
extern "C" {
struct panelhook_compat {
    struct panel* top_panel;
    struct panel* bottom_panel;
    struct panel* stdscr_pseudo_panel;
    // optional NO_LEAKS field follows; we never read past the third pointer.
};
extern struct panelhook_compat* _nc_panelhook_sp(SCREEN*);
}

QoreRecursiveThreadLock ncurses_lock;

// Background reader for an NcursesTestTerminal's master PTY. Without it, the
// kernel's PTY output queue (small on macOS, ~1-4 KB) fills up after a few
// ncurses writes from the slave side and any further write — including the
// implicit tcsetattr(TCSADRAIN) inside endwin() — blocks forever. Linux's
// queue is typically large enough for short tests to run to completion
// without a reader, which is why CI passes on Linux but not macOS.
class NcursesTestTerminalDrain {
public:
    NcursesTestTerminalDrain(int master_fd) : master_fd(master_fd) {
        if (pipe(wake_pipe) != 0) {
            wake_pipe[0] = wake_pipe[1] = -1;
            return;
        }
        thr = std::thread(&NcursesTestTerminalDrain::run, this);
    }

    ~NcursesTestTerminalDrain() {
        stop();
    }

    void stop() {
        if (thr.joinable()) {
            if (wake_pipe[1] >= 0) {
                char b = 0;
                ssize_t r = ::write(wake_pipe[1], &b, 1);
                (void)r;
            }
            thr.join();
        }
        if (wake_pipe[0] >= 0) {
            ::close(wake_pipe[0]);
            wake_pipe[0] = -1;
        }
        if (wake_pipe[1] >= 0) {
            ::close(wake_pipe[1]);
            wake_pipe[1] = -1;
        }
    }

private:
    int master_fd = -1;
    int wake_pipe[2] = {-1, -1};
    std::thread thr;

    void run() {
        char buf[4096];
        while (true) {
            fd_set rfds;
            FD_ZERO(&rfds);
            FD_SET(master_fd, &rfds);
            FD_SET(wake_pipe[0], &rfds);
            int maxfd = master_fd > wake_pipe[0] ? master_fd : wake_pipe[0];
            int rc = select(maxfd + 1, &rfds, nullptr, nullptr, nullptr);
            if (rc < 0) {
                if (errno == EINTR) {
                    continue;
                }
                return;
            }
            if (FD_ISSET(wake_pipe[0], &rfds)) {
                return;
            }
            if (FD_ISSET(master_fd, &rfds)) {
                ssize_t n = ::read(master_fd, buf, sizeof(buf));
                if (n < 0 && errno == EINTR) {
                    continue;
                }
                if (n <= 0) {
                    return;
                }
            }
        }
    }
};

NcursesSession::NcursesSession() = default;

NcursesSession::~NcursesSession() {
    close(nullptr);
    // delscreen runs only in the dtor — by which time NcursesPanel and
    // NcursesWindow holders that ref'd this session have been deref'd and
    // destructed. Doing it here (and not in close()) lets a panel/window
    // destructed after close() still safely call del_panel/delwin against
    // a live SCREEN.
    if (screen) {
        AutoLocker al(ncurses_lock);
        // Free libpanel's per-screen pseudo panel; otherwise it leaks one
        // PANEL allocation per session that ever used a panel.
        if (panelhook_compat* ph = _nc_panelhook_sp(screen)) {
            if (ph->stdscr_pseudo_panel) {
                del_panel(ph->stdscr_pseudo_panel);
                ph->stdscr_pseudo_panel = nullptr;
                ph->top_panel = nullptr;
                ph->bottom_panel = nullptr;
            }
        }
        if (!is_default) {
            delscreen(screen);
        }
        screen = nullptr;
        stdwin = nullptr;
    }
}

void NcursesSession::close(ExceptionSink* xsink) {
    if (closed) {
        return;
    }
    AutoLocker al(ncurses_lock);
    if (screen) {
        set_term(screen);
        endwin();
        // delscreen() is deferred to ~NcursesSession; see comment there.
    }
    if (in_file) {
        fclose(in_file);
        in_file = nullptr;
    }
    if (out_file) {
        fclose(out_file);
        out_file = nullptr;
    }
    cursor_win = nullptr;
    cursor_set = false;
    closed = true;
}

void NcursesSession::checkOpen(ExceptionSink* xsink) const {
    if (closed || !screen) {
        if (xsink) {
            xsink->raiseException("NCURSES-ERROR", "session is closed");
        }
    }
}

short NcursesSession::getColorPair(int fg, int bg, ExceptionSink* xsink) {
    if (!colors_enabled) {
        return 0;
    }
    std::pair<int, int> key(fg, bg);
    auto it = pair_cache.find(key);
    if (it != pair_cache.end()) {
        return it->second;
    }
    if (next_pair >= COLOR_PAIRS) {
        if (xsink) {
            xsink->raiseException("NCURSES-ERROR", "color pair limit exceeded (%d)", COLOR_PAIRS);
        }
        return 0;
    }
    short pair = next_pair++;
    init_pair(pair, fg, bg);
    pair_cache[key] = pair;
    return pair;
}

NcursesWindow::NcursesWindow(NcursesSession* s, WINDOW* w, bool own) : session(s), win(w), owned(own), wrap_mode(1) {
    if (session) {
        session->ref();
    }
}

NcursesWindow::~NcursesWindow() {
    if (session) {
        if (win) {
            AutoLocker al(ncurses_lock);
            // Only clear cursor tracking when an owned window is destroyed.
            // Non-owned windows (e.g. from Session::screen()) share the same
            // WINDOW* (stdscr) and must not clear cursor state on destruction.
            if (owned && session->cursor_win == win) {
                session->cursor_win = nullptr;
                session->cursor_set = false;
            }
            if (owned && session->screen) {
                set_term(session->screen);
                delwin(win);
            }
        }
        session->deref(nullptr);
    }
    win = nullptr;
    session = nullptr;
}

void NcursesWindow::checkOpen(ExceptionSink* xsink) const {
    if (!session || !win) {
        if (xsink) {
            xsink->raiseException("NCURSES-ERROR", "window is closed");
        }
    }
}

NcursesPanel::NcursesPanel(NcursesSession* s, PANEL* p, QoreObject* wobj) : session(s), panel(p), window_obj(wobj) {
    if (session) {
        session->ref();
    }
    // strong ref: the panel owns its window object; tRef() only tracks pointer
    // existence and does not keep the QoreObject alive, which leaks any
    // window object that has no other holder (e.g. created inline in the
    // Panel(session, rows, cols, ...) constructor).
    if (window_obj) {
        window_obj->ref();
    }
}

NcursesPanel::~NcursesPanel() {
    if (panel) {
        AutoLocker al(ncurses_lock);
        // del_panel only touches libpanel's internal state, not the SCREEN,
        // so it is safe to call even after Session::close() has already run
        // delscreen() — and required, otherwise the PANEL leaks.
        if (session && session->screen) {
            set_term(session->screen);
        }
        del_panel(panel);
    }
    if (window_obj) {
        window_obj->deref(nullptr);
    }
    if (session) {
        session->deref(nullptr);
    }
    panel = nullptr;
    session = nullptr;
    window_obj = nullptr;
}

void NcursesPanel::checkOpen(ExceptionSink* xsink) const {
    if (!session || !panel) {
        if (xsink) {
            xsink->raiseException("NCURSES-ERROR", "panel is closed");
        }
    }
}

NcursesTestTerminal::NcursesTestTerminal(int r, int c, const QoreString* t)
    : rows(r), cols(c), term(t ? t->c_str() : "xterm-256color") {
}

NcursesTestTerminal::~NcursesTestTerminal() {
    close(nullptr);
}

void NcursesTestTerminal::open(ExceptionSink* xsink) {
    if (master_fd >= 0) {
        return;
    }
    struct winsize ws;
    ws.ws_row = rows;
    ws.ws_col = cols;
    ws.ws_xpixel = 0;
    ws.ws_ypixel = 0;
    int mfd = -1;
    int sfd = -1;
    if (openpty(&mfd, &sfd, nullptr, nullptr, &ws) != 0) {
        xsink->raiseErrnoException("NCURSES-TEST-ERROR", errno, "openpty() failed");
        return;
    }
    master_fd = mfd;
    slave_fd = sfd;
    drain = new NcursesTestTerminalDrain(master_fd);
}

void NcursesTestTerminal::close(ExceptionSink* xsink) {
    if (drain) {
        drain->stop();
        delete drain;
        drain = nullptr;
    }
    if (master_fd >= 0) {
        ::close(master_fd);
        master_fd = -1;
    }
    if (slave_fd >= 0) {
        ::close(slave_fd);
        slave_fd = -1;
    }
}

void NcursesTestTerminal::resize(int r, int c, ExceptionSink* xsink) {
    rows = r;
    cols = c;
    if (slave_fd < 0) {
        return;
    }
    struct winsize ws;
    ws.ws_row = rows;
    ws.ws_col = cols;
    ws.ws_xpixel = 0;
    ws.ws_ypixel = 0;
    if (ioctl(slave_fd, TIOCSWINSZ, &ws) != 0) {
        xsink->raiseErrnoException("NCURSES-TEST-ERROR", errno, "ioctl(TIOCSWINSZ) failed");
    }
}

void NcursesTestTerminal::writeInput(const QoreString* data, ExceptionSink* xsink) {
    ensureOpen(xsink);
    if (xsink && *xsink) {
        return;
    }
    if (master_fd < 0) {
        xsink->raiseException("NCURSES-TEST-ERROR", "test terminal is closed");
        return;
    }
    if (!data || !data->size()) {
        return;
    }
    ssize_t rc = ::write(master_fd, data->c_str(), data->size());
    if (rc < 0) {
        xsink->raiseErrnoException("NCURSES-TEST-ERROR", errno, "write() failed");
    }
}

void NcursesTestTerminal::ensureOpen(ExceptionSink* xsink) {
    if (master_fd < 0 || slave_fd < 0) {
        open(xsink);
    }
}

NcursesCallGuard::NcursesCallGuard(NcursesSession* s) : lock(ncurses_lock) {
    if (s && s->screen) {
        prev = set_term(s->screen);
    }
}

NcursesCallGuard::~NcursesCallGuard() {
    if (prev) {
        set_term(prev);
    }
}

bool parseStyle(const QoreHashNode* h, StyleSpec& out, ExceptionSink* xsink) {
    if (!h) {
        return true;
    }
    QoreValue fg = h->getKeyValue("fg");
    QoreValue bg = h->getKeyValue("bg");
    QoreValue attrs = h->getKeyValue("attrs");

    if (!fg.isNothing()) {
        out.has_fg = true;
        out.fg = fg.getAsBigInt();
    }
    if (!bg.isNothing()) {
        out.has_bg = true;
        out.bg = bg.getAsBigInt();
    }
    if (!attrs.isNothing()) {
        if (attrs.getType() == NT_LIST) {
            const QoreListNode* l = attrs.get<const QoreListNode>();
            ConstListIterator i(l);
            while (i.next()) {
                out.attrs |= i.getValue().getAsBigInt();
            }
        } else {
            out.attrs = attrs.getAsBigInt();
        }
    }
    return true;
}

void applyStyle(NcursesWindow* w, const StyleSpec& style, attr_t& old_attr, short& old_pair, ExceptionSink* xsink) {
    assert(w);
    if (!w->session || !w->session->colors_enabled) {
        wattr_get(w->win, &old_attr, &old_pair, nullptr);
        wattr_set(w->win, style.attrs, 0, nullptr);
        return;
    }
    wattr_get(w->win, &old_attr, &old_pair, nullptr);
    int fg = style.has_fg ? style.fg : -1;
    int bg = style.has_bg ? style.bg : -1;
    if (!style.has_fg && !style.has_bg) {
        wattr_set(w->win, style.attrs, old_pair, nullptr);
        return;
    }
    short pair = w->session->getColorPair(fg, bg, xsink);
    if (xsink && *xsink) {
        return;
    }
    wattr_set(w->win, style.attrs, pair, nullptr);
}

void restoreStyle(NcursesWindow* w, attr_t old_attr, short old_pair) {
    wattr_set(w->win, old_attr, old_pair, nullptr);
}

static void applySgrCode(int code, StyleSpec& style) {
    switch (code) {
        case 0:
            style.has_fg = false;
            style.has_bg = false;
            style.fg = -1;
            style.bg = -1;
            style.attrs = 0;
            break;
        case 1:
            style.attrs |= A_BOLD;
            break;
        case 2:
            style.attrs |= A_DIM;
            break;
        case 4:
            style.attrs |= A_UNDERLINE;
            break;
        case 7:
            style.attrs |= A_REVERSE;
            break;
        case 22:
            style.attrs &= ~A_BOLD;
            style.attrs &= ~A_DIM;
            break;
        case 24:
            style.attrs &= ~A_UNDERLINE;
            break;
        case 27:
            style.attrs &= ~A_REVERSE;
            break;
        case 39:
            style.has_fg = false;
            style.fg = -1;
            break;
        case 49:
            style.has_bg = false;
            style.bg = -1;
            break;
        default:
            if (code >= 30 && code <= 37) {
                style.has_fg = true;
                style.fg = code - 30;
            } else if (code >= 40 && code <= 47) {
                style.has_bg = true;
                style.bg = code - 40;
            } else if (code >= 90 && code <= 97) {
                style.has_fg = true;
                style.fg = code - 90;
                style.attrs |= A_BOLD;
            } else if (code >= 100 && code <= 107) {
                style.has_bg = true;
                style.bg = code - 100;
            }
            break;
    }
}

static void parseSgrCodes(const char* s, size_t len, StyleSpec& style) {
    int val = 0;
    bool have = false;
    for (size_t i = 0; i <= len; ++i) {
        char c = (i < len) ? s[i] : ';';
        if (c >= '0' && c <= '9') {
            val = val * 10 + (c - '0');
            have = true;
        } else if (c == ';' || i == len) {
            if (have) {
                applySgrCode(val, style);
            } else if (i == len && !have) {
                applySgrCode(0, style);
            }
            val = 0;
            have = false;
        }
    }
}

void parseAnsiSegments(const QoreString* text, std::vector<AnsiSegment>& segs) {
    segs.clear();
    if (!text || !text->size()) {
        return;
    }
    const char* s = text->c_str();
    size_t len = text->size();
    StyleSpec style;
    std::string buf;
    for (size_t i = 0; i < len; ) {
        unsigned char ch = static_cast<unsigned char>(s[i]);
        if (ch == 0x1b && i + 1 < len && s[i + 1] == '[') {
            if (!buf.empty()) {
                segs.push_back({buf, style});
                buf.clear();
            }
            i += 2;
            size_t start = i;
            while (i < len && s[i] != 'm') {
                ++i;
            }
            if (i < len && s[i] == 'm') {
                parseSgrCodes(s + start, i - start, style);
                ++i;
                continue;
            }
            break;
        }
        buf.push_back(static_cast<char>(ch));
        ++i;
    }
    if (!buf.empty()) {
        segs.push_back({buf, style});
    }
}

void drawAnsiText(NcursesWindow* w, int y, int x, bool inside, bool clear_line, const QoreString* text,
    ExceptionSink* xsink) {
    if (!w || !w->win) {
        return;
    }
    int rows = 0;
    int cols = 0;
    getmaxyx(w->win, rows, cols);
    int inner_rows = inside ? rows - 2 : rows;
    int inner_cols = inside ? cols - 2 : cols;
    if (inner_rows <= 0 || inner_cols <= 0) {
        return;
    }
    if (y < 0 || y >= inner_rows) {
        return;
    }
    int start_col = inside ? x + 1 : x;
    int start_row = inside ? y + 1 : y;
    int max_cols = inner_cols - x;
    if (max_cols <= 0) {
        return;
    }
    if (clear_line) {
        int clear_start = inside ? 1 : 0;
        mvwhline(w->win, start_row, clear_start, ' ', inner_cols);
    }
    std::vector<AnsiSegment> segs;
    parseAnsiSegments(text, segs);
    int col = start_col;
    int remaining = max_cols;
    for (size_t i = 0; i < segs.size() && remaining > 0; ++i) {
        const std::string& t = segs[i].text;
        if (t.empty()) {
            continue;
        }
        // Calculate how many bytes of this segment fit within 'remaining'
        // display columns. Walk UTF-8 codepoints and sum display widths.
        int fit_bytes = 0;
        int fit_cols = 0;
        const char* p = t.c_str();
        const char* end = p + t.size();
        size_t decoded = 0;
        while (p < end) {
            unsigned char c = static_cast<unsigned char>(*p);
            int char_bytes;
            if (c < 0x80) {
                char_bytes = 1;
            } else if ((c & 0xE0) == 0xC0) {
                char_bytes = 2;
            } else if ((c & 0xF0) == 0xE0) {
                char_bytes = 3;
            } else if ((c & 0xF8) == 0xF0) {
                char_bytes = 4;
            } else {
                char_bytes = 1;
            }
            if (p + char_bytes > end) {
                break;
            }
            // Use QoreString to measure this character's display width
            QoreString ch_str(p, char_bytes, QCS_UTF8);
            int ch_width = static_cast<int>(ch_str.getCharWidth(xsink));
            if (xsink && *xsink) {
                return;
            }
            if (fit_cols + ch_width > remaining) {
                break;
            }
            fit_cols += ch_width;
            fit_bytes += char_bytes;
            p += char_bytes;
            if (++decoded % 100 == 0
                    && qore_check_cancel(xsink,
                        "drawing ANSI terminal text")) {
                return;
            }
        }

        if (fit_bytes <= 0) {
            continue;
        }

        StyleSpec spec = segs[i].style;
        attr_t old_attr = 0;
        short old_pair = 0;
        applyStyle(w, spec, old_attr, old_pair, xsink);
        if (xsink && *xsink) {
            return;
        }
        mvwaddnstr(w->win, start_row, col, t.c_str(), fit_bytes);
        restoreStyle(w, old_attr, old_pair);
        remaining -= fit_cols;
        col += fit_cols;
    }
}
