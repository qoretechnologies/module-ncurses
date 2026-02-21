//! Qore namespace
namespace Qore {
//! Ncurses namespace
namespace Ncurses {
//! Test terminal helper
/** Provides a pseudo-terminal for automated tests.

    TestTerminal creates a PTY (pseudo-terminal) pair that can be passed to
    the Session constructor for headless, deterministic testing. Use
    Session::injectEvent() to simulate input and Session::snapshot() to
    read back screen contents.

   @par Restrictions:
    @ref Qore::PO_NO_TERMINAL_IO

     @par Example:
    @code{.py}
%modern
%requires ncurses

# create a 24x80 test terminal
Ncurses::TestTerminal tt(24, 80);

# create a session backed by the test terminal
Ncurses::Session s({"test_terminal": tt});
Ncurses::Window w = s.screen();

w.clear();
w.drawText(0, 0, "Test output");
w.refresh();

# read back screen contents for verification
list<string> rows = s.snapshot();
# rows[0] starts with "Test output"

# inject a keypress
s.injectEvent({"type": Ncurses::InputType::Char, "ch": "q"});
auto ev = w.readEvent(100, 25);
# ev.ch == "q"

s.close();
    @endcode

    @since %ncurses 2.0
*/
class TestTerminal {

public:
//! Closes the test terminal
/**@since %ncurses 2.0
*/
nothing close();

public:
//! Creates a test terminal
/**@param rows optional rows
    @param cols optional cols
    @param term optional TERM value

    @since %ncurses 2.0
*/
 constructor(__7_ int rows, __7_ int cols, __7_ string term);

public:
//! Returns the path to the slave device for this test terminal
/**@return slave device path (for use with Session::constructor \c tty_path)

    @since %ncurses 2.0
*/
string getSlavePath();

public:
//! Returns true if the test terminal is open
/**@since %ncurses 2.0
*/
bool isOpen();

public:
//! Opens the pseudo-terminal
/**@since %ncurses 2.0
*/
nothing open();

public:
//! Resizes the test terminal
/**@param rows new rows
    @param cols new cols

    @since %ncurses 2.0
*/
nothing resize(int rows, int cols);

public:
//! Writes input data to the test terminal
/**@param data input data

    @since %ncurses 2.0
*/
nothing writeInput(string data);
};
}
}
