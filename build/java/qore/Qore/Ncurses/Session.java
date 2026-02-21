// Java created from Qore class Qore::Ncurses::Session
package qore.Qore.Ncurses;

/** @brief Ncurses session
    Manages a ncurses screen session.

    A Session owns the terminal state for the lifetime of the ncurses UI.
    Create a Session, obtain the screen Window, draw content, read events,
    and close when done.


   @par Restrictions:
    @ref Qore::PO_NO_TERMINAL_IO

     @par Example:
    @code{.py}
%modern
%requires ncurses

# create a session (initializes the terminal)
Ncurses::Session s();
Ncurses::Window w = s.screen();

w.clear();
w.drawText(1, 2, "Hello!", {"fg": Ncurses::Color::Cyan, "attrs": Ncurses::Attr::Bold});
w.refresh();

# wait for a keypress
w.readEvent();

# close the session (restores the terminal)
s.close();
    @endcode

    @since %ncurses 2.0
*/
public class Session {
    // nothing Session::beep(){}
    /** @brief Emits a terminal beep
    @since %ncurses 2.0
    */
    public void beep() throws Throwable {
    }

    // bool Session::canChangeColor(){}
    /** @brief Returns true if the terminal supports color redefinition
    When true, @ref initColor() can be used to redefine color slots with custom RGB values.
    
        @return true if the terminal supports redefining colors
    
        @since %ncurses 2.1
    */
    public boolean canChangeColor() throws Throwable {
    }

    // nothing Session::close(){}
    /** @brief Closes the session
    @since %ncurses 2.0
    */
    public void close() throws Throwable {
    }

    // Session::constructor(*hash opts) {}
    /** @brief Creates a new session
    @param opts optional hash of options:
        - \c echo (bool, default false)
        - \c raw (bool, default false)
        - \c cbreak (bool, default true)
        - \c keypad (bool, default true)
        - \c mouse (bool, default true)
        - \c use_colors (bool, default true)
        - \c use_default_colors (bool, default true)
        - \c cursor (int, default 0)
        - \c esc_delay (int, default no change) to set the ESC sequence delay in milliseconds
        - \c test_terminal (TestTerminal) for automated tests
        - \c use_tty (bool, default false) to use a dedicated TTY device for ncurses I/O
        - \c tty_path (string, default "/dev/tty") path to the TTY device when \c use_tty is true
        - \c unbuffered_stdio (bool, default true when \c use_tty is true) to disable stdio buffering on
          stdout/stderr when using a dedicated TTY (useful for output capture)
    
        @since %ncurses 2.0
    */
    public Session(org.qore.jni.Hash opts) throws Throwable {
    }

    // nothing Session::doupdate(){}
    /** @brief Flushes the virtual screen to the terminal
    Applies the most recent cursor position set with @ref Ncurses::Window::moveCursor
        or @ref Ncurses::Window::restoreCursor before updating the terminal.
    
        @since %ncurses 2.0
    */
    public void doupdate() throws Throwable {
    }

    // nothing Session::flash(){}
    /** @brief Flashes the terminal
    @since %ncurses 2.0
    */
    public void flash() throws Throwable {
    }

    // nothing Session::flushInput(){}
    /** @brief Flushes pending input
    @since %ncurses 2.0
    */
    public void flushInput() throws Throwable {
    }

    // nothing Session::flushStdio(){}
    /** @brief Flushes any buffered C stdio data on stdout and stderr
     This ensures that output written via C's \c printf() / \c fputs() (used
        internally by Qore's \c print() builtin) is flushed to the underlying
        file descriptor.  Call this after evaluating user code to ensure all
        output reaches the capture pipe.
    
        @since %ncurses 2.0
    */
    public void flushStdio() throws Throwable {
    }

    // nothing Session::initColor(int color, int r, int g, int b){}
    /** @brief Redefines a color slot with custom RGB values
    @param color the color number to redefine (0 to @ref maxColors() - 1)
        @param r red component (0-1000)
        @param g green component (0-1000)
        @param b blue component (0-1000)
    
        @throw NCURSES-ERROR if the terminal does not support color redefinition or the color number is out of range
    
        @note The terminal must support color redefinition (@ref canChangeColor() returns true)
    
        @since %ncurses 2.1
    */
    public void initColor(long color, long r, long g, long b) throws Throwable {
    }

    // nothing Session::injectEvent(hash<InputEvent> ev){}
    /** @brief Injects a single input event into the ncurses input queue
    @param ev input event hash (type + payload)
        - type (int) one of @ref InputType values
        - code (int) for Key or Char events
        - ch (string) for Char events
        - mouse (hash) for Mouse events with keys: x, y, button_state
    
        @since %ncurses 2.1
    */
    public void injectEvent(org.qore.jni.Hash ev) throws Throwable {
    }

    // nothing Session::injectEvents(list<hash<InputEvent>> events){}
    /** @brief Injects a list of input events into the ncurses input queue
    @param events list of @ref InputEvent hashes
    
        @since %ncurses 2.1
    */
    public void injectEvents(Object[] events) throws Throwable {
    }

    // nothing Session::injectInput(string data){}
    /** @brief Injects input into the ncurses input queue
    @param data input characters to inject
    
        @since %ncurses 2.0
    */
    public void injectInput(String data) throws Throwable {
    }

    // bool Session::isOpen(){}
    /** @brief Returns true if the session is open
    @since %ncurses 2.0
    */
    public boolean isOpen() throws Throwable {
    }

    // int Session::maxColors(){}
    /** @brief Returns the maximum number of colors supported by the terminal
    @return the number of colors the terminal supports (typically 8, 256, or more)
    
        @since %ncurses 2.1
    */
    public long maxColors() throws Throwable {
    }

    // nothing Session::redirectStderr(File file){}
    /** @brief Redirects the C stderr stream to the given file
    @param file target file
    
        @since %ncurses 2.0
    */
    public void redirectStderr(qore.Qore.File file) throws Throwable {
    }

    // nothing Session::redirectStdout(File file){}
    /** @brief Redirects the C stdout stream to the given file
    @param file target file
    
        @since %ncurses 2.0
    */
    public void redirectStdout(qore.Qore.File file) throws Throwable {
    }

    // Window Session::screen(){}
    /** @brief Returns the screen window
    @since %ncurses 2.0
    */
    public qore.Qore.Window screen() throws Throwable {
    }

    // nothing Session::setCursor(int visibility){}
    /** @brief Sets cursor visibility
    @param visibility one of @ref CursorVisibility values
    
        @since %ncurses 2.0
    */
    public void setCursor(long visibility) throws Throwable {
    }

    // int Session::setEscDelay(int ms){}
    /** @brief Sets the escape sequence delay
    @param ms delay in milliseconds (values < 0 are treated as 0)
        @return previous delay value if available, otherwise 0
    
        @since %ncurses 2.0
    */
    public long setEscDelay(long ms) throws Throwable {
    }

    // nothing Session::setMouse(bool enabled){}
    /** @brief Enables or disables mouse event reporting
    @param enabled true to enable mouse events, false to disable
    
        @since %ncurses 2.0
    */
    public void setMouse(boolean enabled) throws Throwable {
    }

    // list<string> Session::snapshot(*int y, *int rows, *int cols){}
    /** @brief Returns a snapshot of the screen contents
    @param y start row (default 0)
        @param rows number of rows (default full screen)
        @param cols number of columns (default full screen)
    
        @return list of strings (one per row)
    
        @since %ncurses 2.1
    */
    public Object[] snapshot(Long y, Long rows, Long cols) throws Throwable {
    }

    // bool Session::supportsColor(){}
    /** @brief Returns true if colors are enabled
    @since %ncurses 2.0
    */
    public boolean supportsColor() throws Throwable {
    }

    // nothing Session::updatePanels(){}
    /** @brief Queues panel updates
    @since %ncurses 2.0
    */
    public void updatePanels() throws Throwable {
    }

    // auto Session::withLock(code cb, *list cb_args){}
    /** @brief Executes a callback with the ncurses lock held
    @param cb callable (closure or call reference)
        @param cb_args optional list of arguments
    
        @return the callback result
    
        @since %ncurses 2.0
    */
    public Object withLock(org.qore.jni.QoreClosure cb, Object[] cb_args) throws Throwable {
    }

}
