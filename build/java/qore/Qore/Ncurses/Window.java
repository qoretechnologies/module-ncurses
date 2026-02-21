// Java created from Qore class Qore::Ncurses::Window
package qore.Qore.Ncurses;

/** @brief Ncurses window
    Represents a drawable window.

    A Window is the primary drawing surface. Use drawText(), box(), and the
    drawAnsi* methods to render content, and readEvent() to read input.


   @par Restrictions:
    @ref Qore::PO_NO_TERMINAL_IO

     @par Example:
    @code{.py}
%modern
%requires ncurses

Ncurses::Session s();

# create a 10x40 window at position (2, 5)
Ncurses::Window w(s, 10, 40, 2, 5);
w.box({"fg": Ncurses::Color::Blue});
w.drawTextInside(0, 0, "Window title", {"fg": Ncurses::Color::Yellow, "attrs": Ncurses::Attr::Bold});
w.refresh();

w.readEvent();
s.close();
    @endcode

    @since %ncurses 2.0
*/
public class Window {
    // nothing Window::addChar(int y, int x, string ch, *hash style){}
    /** @brief Adds a single character
    @param y row
        @param x column
        @param ch character
        @param style optional style hash
    
        @since %ncurses 2.0
    */
    public void addChar(long y, long x, String ch, org.qore.jni.Hash style) throws Throwable {
    }

    // nothing Window::border(*string ls, *string rs, *string ts, *string bs, *string tl, *string tr, *string bl, *string br, *hash style){}
    /** @brief Draws a border with optional characters
    @param ls left side character
        @param rs right side character
        @param ts top side character
        @param bs bottom side character
        @param tl top-left corner character
        @param tr top-right corner character
        @param bl bottom-left corner character
        @param br bottom-right corner character
        @param style optional style hash
    
        @since %ncurses 2.0
    */
    public void border(String ls, String rs, String ts, String bs, String tl, String tr, String bl, String br, org.qore.jni.Hash style) throws Throwable {
    }

    // nothing Window::box(*hash style){}
    /** @brief Draws a box using default border characters
    @param style optional style hash
    
        @since %ncurses 2.0
    */
    public void box(org.qore.jni.Hash style) throws Throwable {
    }

    // nothing Window::clear(){}
    /** @brief Clears the window
    @since %ncurses 2.0
    */
    public void clear() throws Throwable {
    }

    // nothing Window::clearInsideLine(int y, *hash style){}
    /** @brief Clears a line inside the window border
    @param y row inside the content area (0 = first row inside the border)
        @param style optional style hash
    
        @since %ncurses 2.0
    */
    public void clearInsideLine(long y, org.qore.jni.Hash style) throws Throwable {
    }

    // nothing Window::clearLine(int y, *hash style){}
    /** @brief Clears a line
    @param y row
        @param style optional style hash
    
        @since %ncurses 2.0
    */
    public void clearLine(long y, org.qore.jni.Hash style) throws Throwable {
    }

    // Window::constructor(Qore::Ncurses::Session session, int rows, int cols, int y, int x) {}
    /** @brief Creates a new window
    @param session the session
        @param rows window height
        @param cols window width
        @param y top position
        @param x left position
    
        @since %ncurses 2.0
    */
    public Window(qore.Qore.Ncurses.Session session, long rows, long cols, long y, long x) throws Throwable {
    }

    // hash<Position> Window::cursor(){}
    /** @brief Returns the current cursor position
    @since %ncurses 2.0
    */
    public org.qore.jni.Hash cursor() throws Throwable {
    }

    // nothing Window::drawAnsiText(int y, int x, string text, *hash style){}
    /** @brief Draws ANSI-colored text at a position
    @param y row
        @param x column
        @param text text to draw (may contain ANSI SGR color codes)
        @param style optional base style hash
    
        @since %ncurses 2.0
    */
    public void drawAnsiText(long y, long x, String text, org.qore.jni.Hash style) throws Throwable {
    }

    // nothing Window::drawAnsiTextInside(int y, int x, string text, *hash style){}
    /** @brief Draws ANSI-colored text clipped to the window's inner content area
    @param y row inside the content area (0 = first row inside the border)
        @param x column inside the content area (0 = first column inside the border)
        @param text text to draw (may contain ANSI SGR color codes)
        @param style optional base style hash
    
        @since %ncurses 2.0
    */
    public void drawAnsiTextInside(long y, long x, String text, org.qore.jni.Hash style) throws Throwable {
    }

    // nothing Window::drawAnsiTextInsideLine(int y, string text, *hash style){}
    /** @brief Draws ANSI-colored text inside the window border and clears the rest of the line
    @param y row inside the content area (0 = first row inside the border)
        @param text text to draw (may contain ANSI SGR color codes)
        @param style optional base style hash
    
        @since %ncurses 2.0
    */
    public void drawAnsiTextInsideLine(long y, String text, org.qore.jni.Hash style) throws Throwable {
    }

    // nothing Window::drawHLine(int y, int x, int len, *string ch, *hash style){}
    /** @brief Draws a horizontal line
    @param y row
        @param x column
        @param len length
        @param ch optional character
        @param style optional style hash
    
        @since %ncurses 2.0
    */
    public void drawHLine(long y, long x, long len, String ch, org.qore.jni.Hash style) throws Throwable {
    }

    // nothing Window::drawText(int y, int x, string text, *hash style){}
    /** @brief Draws text at a position
    @param y row
        @param x column
        @param text text to draw
        @param style optional style hash
    
        @since %ncurses 2.0
    */
    public void drawText(long y, long x, String text, org.qore.jni.Hash style) throws Throwable {
    }

    // nothing Window::drawTextClipped(int y, int x, string text, *hash style){}
    /** @brief Draws text clipped to window bounds
    @param y row
        @param x column
        @param text text to draw
        @param style optional style hash
    
        The text is clipped to the visible window region to prevent out-of-bounds
        writes. If the text would start before column 0, the leading characters are
        skipped.
    
        @since %ncurses 2.0
    */
    public void drawTextClipped(long y, long x, String text, org.qore.jni.Hash style) throws Throwable {
    }

    // nothing Window::drawTextInside(int y, int x, string text, *hash style){}
    /** @brief Draws text clipped to the window's inner content area
    @param y row inside the content area (0 = first row inside the border)
        @param x column inside the content area (0 = first column inside the border)
        @param text text to draw
        @param style optional style hash
    
        The text is clipped to the area inside a border (excluding rows/cols 0 and
        max-1). This prevents accidental overwriting of box borders.
    
        @since %ncurses 2.0
    */
    public void drawTextInside(long y, long x, String text, org.qore.jni.Hash style) throws Throwable {
    }

    // nothing Window::drawTextInsideLine(int y, string text, *hash style){}
    /** @brief Draws text inside the window border and clears the rest of the line
    @param y row inside the content area (0 = first row inside the border)
        @param text text to draw
        @param style optional style hash
    
        The line is cleared before writing to ensure no old text remains.
    
        @since %ncurses 2.0
    */
    public void drawTextInsideLine(long y, String text, org.qore.jni.Hash style) throws Throwable {
    }

    // nothing Window::drawVLine(int y, int x, int len, *string ch, *hash style){}
    /** @brief Draws a vertical line
    @param y row
        @param x column
        @param len length
        @param ch optional character
        @param style optional style hash
    
        @since %ncurses 2.0
    */
    public void drawVLine(long y, long x, long len, String ch, org.qore.jni.Hash style) throws Throwable {
    }

    // nothing Window::enableKeypad(bool enabled){}
    /** @brief Enables or disables keypad mode
    @param enabled enable keypad decoding when true
    
        @since %ncurses 2.0
    */
    public void enableKeypad(boolean enabled) throws Throwable {
    }

    // nothing Window::enableScroll(bool enabled){}
    /** @brief Enables or disables scrolling
    @param enabled enable scrolling when true
    
        @since %ncurses 2.0
    */
    public void enableScroll(boolean enabled) throws Throwable {
    }

    // nothing Window::erase(){}
    /** @brief Erases the window contents
    @since %ncurses 2.0
    */
    public void erase() throws Throwable {
    }

    // nothing Window::fillRect(int y, int x, int rows, int cols, *string ch, *hash style){}
    /** @brief Fills a rectangle
    @param y top row
        @param x left column
        @param rows height
        @param cols width
        @param ch optional fill character
        @param style optional style hash
    
        @since %ncurses 2.0
    */
    public void fillRect(long y, long x, long rows, long cols, String ch, org.qore.jni.Hash style) throws Throwable {
    }

    // enum<WrapMode> Window::getWrapMode(){}
    /** @brief Returns the wrap mode for this window
    @par Code Flags:
        @ref CONSTANT
    
    @return @ref Qore::Ncurses::WrapMode "WrapMode" value
    
        @since %ncurses 2.0
    */
    public qore.Qore.enum<WrapMode> getWrapMode() throws Throwable {
    }

    // nothing Window::move(int y, int x){}
    /** @brief Moves the window
    @param y new top row
        @param x new left column
    
        @since %ncurses 2.0
    */
    public void move(long y, long x) throws Throwable {
    }

    // nothing Window::moveCursor(int y, int x){}
    /** @brief Moves the cursor
    @param y row
        @param x column
    
        @since %ncurses 2.0
    */
    public void moveCursor(long y, long x) throws Throwable {
    }

    // nothing Window::noutrefresh(){}
    /** @brief Queues the window for refresh
    @since %ncurses 2.0
    */
    public void noutrefresh() throws Throwable {
    }

    // hash<Position> Window::position(){}
    /** @brief Returns the window position
    @since %ncurses 2.0
    */
    public org.qore.jni.Hash position() throws Throwable {
    }

    // hash<InputEvent> Window::readEvent(*int timeout_ms, *int poll_ms){}
    /** @brief Reads an input event
    @param timeout_ms optional overall timeout in milliseconds
        @param poll_ms optional poll interval in milliseconds
    
        @since %ncurses 2.0
    */
    public org.qore.jni.Hash readEvent(Long timeout_ms, Long poll_ms) throws Throwable {
    }

    // list<string> Window::readLines(*int y, *int rows, *int cols){}
    /** @brief Reads multiple lines of text from the window
    @param y start row (default 0)
        @param rows number of rows (default full window)
        @param cols number of columns (default full window)
    
        @return list of strings (one per row)
    
        @since %ncurses 2.1
    */
    public Object[] readLines(Long y, Long rows, Long cols) throws Throwable {
    }

    // string Window::readText(int y, int x, int len){}
    /** @brief Reads text from the window
    @param y row
        @param x column
        @param len length
    
        @since %ncurses 2.0
    */
    public String readText(long y, long x, long len) throws Throwable {
    }

    // nothing Window::refresh(){}
    /** @brief Refreshes the window
    @since %ncurses 2.0
    */
    public void refresh() throws Throwable {
    }

    // nothing Window::resize(int rows, int cols){}
    /** @brief Resizes the window
    @param rows new height
        @param cols new width
    
        @since %ncurses 2.0
    */
    public void resize(long rows, long cols) throws Throwable {
    }

    // nothing Window::restoreCursor(hash pos){}
    /** @brief Restores a previously saved cursor position
    @param pos hash with keys \c y and \c x
    
        @since %ncurses 2.0
    */
    public void restoreCursor(org.qore.jni.Hash pos) throws Throwable {
    }

    // hash<Position> Window::saveCursor(){}
    /** @brief Saves the current cursor position
    @return hash<@ref Position>
    
        @since %ncurses 2.0
    */
    public org.qore.jni.Hash saveCursor() throws Throwable {
    }

    // nothing Window::scroll(int n){}
    /** @brief Scrolls the window
    @param n number of lines to scroll
    
        @since %ncurses 2.0
    */
    public void scroll(long n) throws Throwable {
    }

    // nothing Window::setBackground(*hash style){}
    /** @brief Sets the background style
    @param style optional style hash
    
        @since %ncurses 2.0
    */
    public void setBackground(org.qore.jni.Hash style) throws Throwable {
    }

    // nothing Window::setLeaveOk(bool on){}
    /** @brief Sets whether the cursor should be left in this window after refresh
    @param on True to disable cursor positioning for this window
    
        @since %ncurses 2.0
    */
    public void setLeaveOk(boolean on) throws Throwable {
    }

    // nothing Window::setWrapMode(enum<WrapMode> mode){}
    /** @brief Sets the wrap mode for this window
    @param mode wrap mode
    
        @since %ncurses 2.0
    */
    public void setWrapMode(qore.Qore.enum<WrapMode> mode) throws Throwable {
    }

    // hash<Size> Window::size(){}
    /** @brief Returns the window size
    @since %ncurses 2.0
    */
    public org.qore.jni.Hash size() throws Throwable {
    }

    // Window Window::subWindow(int rows, int cols, int y, int x){}
    /** @brief Creates a sub-window
    @param rows height
        @param cols width
        @param y top row
        @param x left column
    
        @since %ncurses 2.0
    */
    public qore.Qore.Window subWindow(long rows, long cols, long y, long x) throws Throwable {
    }

    // nothing Window::write(string text, *hash style){}
    /** @brief Writes text at the current cursor position
    @param text text to write
        @param style optional style hash
    
        @since %ncurses 2.0
    */
    public void write(String text, org.qore.jni.Hash style) throws Throwable {
    }

}
