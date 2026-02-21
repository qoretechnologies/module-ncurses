// Java created from Qore class Qore::Ncurses::TestTerminal
package qore.Qore.Ncurses;

/** @brief Test terminal helper
    Provides a pseudo-terminal for automated tests.

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
public class TestTerminal {
    // nothing TestTerminal::close(){}
    /** @brief Closes the test terminal
    @since %ncurses 2.0
    */
    public void close() throws Throwable {
    }

    // TestTerminal::constructor(*int rows, *int cols, *string term) {}
    /** @brief Creates a test terminal
    @param rows optional rows
        @param cols optional cols
        @param term optional TERM value
    
        @since %ncurses 2.0
    */
    public TestTerminal(Long rows, Long cols, String term) throws Throwable {
    }

    // string TestTerminal::getSlavePath(){}
    /** @brief Returns the path to the slave device for this test terminal
    @return slave device path (for use with Session::constructor \c tty_path)
    
        @since %ncurses 2.0
    */
    public String getSlavePath() throws Throwable {
    }

    // bool TestTerminal::isOpen(){}
    /** @brief Returns true if the test terminal is open
    @since %ncurses 2.0
    */
    public boolean isOpen() throws Throwable {
    }

    // nothing TestTerminal::open(){}
    /** @brief Opens the pseudo-terminal
    @since %ncurses 2.0
    */
    public void open() throws Throwable {
    }

    // nothing TestTerminal::resize(int rows, int cols){}
    /** @brief Resizes the test terminal
    @param rows new rows
        @param cols new cols
    
        @since %ncurses 2.0
    */
    public void resize(long rows, long cols) throws Throwable {
    }

    // nothing TestTerminal::writeInput(string data){}
    /** @brief Writes input data to the test terminal
    @param data input data
    
        @since %ncurses 2.0
    */
    public void writeInput(String data) throws Throwable {
    }

}
