//! Qore namespace
namespace Qore {
//! Ncurses namespace
namespace Ncurses {
//! Ncurses window
/** Represents a drawable window.

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
class Window {

public:
//! Adds a single character
/**@param y row
    @param x column
    @param ch character
    @param style optional style hash

    @since %ncurses 2.0
*/
nothing addChar(int y, int x, string ch, __7_ hash style);

public:
//! Draws a border with optional characters
/**@param ls left side character
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
nothing border(__7_ string ls, __7_ string rs, __7_ string ts, __7_ string bs, __7_ string tl, __7_ string tr, __7_ string bl, __7_ string br, __7_ hash style);

public:
//! Draws a box using default border characters
/**@param style optional style hash

    @since %ncurses 2.0
*/
nothing box(__7_ hash style);

public:
//! Clears the window
/**@since %ncurses 2.0
*/
nothing clear();

public:
//! Clears a line inside the window border
/**@param y row inside the content area (0 = first row inside the border)
    @param style optional style hash

    @since %ncurses 2.0
*/
nothing clearInsideLine(int y, __7_ hash style);

public:
//! Clears a line
/**@param y row
    @param style optional style hash

    @since %ncurses 2.0
*/
nothing clearLine(int y, __7_ hash style);

public:
//! Creates a new window
/**@param session the session
    @param rows window height
    @param cols window width
    @param y top position
    @param x left position

    @since %ncurses 2.0
*/
 constructor(Qore::Ncurses::Session session, int rows, int cols, int y, int x);

public:
//! Returns the current cursor position
/**@since %ncurses 2.0
*/
hash<Position> cursor();

public:
//! Draws ANSI-colored text at a position
/**@param y row
    @param x column
    @param text text to draw (may contain ANSI SGR color codes)
    @param style optional base style hash

    @since %ncurses 2.0
*/
nothing drawAnsiText(int y, int x, string text, __7_ hash style);

public:
//! Draws ANSI-colored text clipped to the window's inner content area
/**@param y row inside the content area (0 = first row inside the border)
    @param x column inside the content area (0 = first column inside the border)
    @param text text to draw (may contain ANSI SGR color codes)
    @param style optional base style hash

    @since %ncurses 2.0
*/
nothing drawAnsiTextInside(int y, int x, string text, __7_ hash style);

public:
//! Draws ANSI-colored text inside the window border and clears the rest of the line
/**@param y row inside the content area (0 = first row inside the border)
    @param text text to draw (may contain ANSI SGR color codes)
    @param style optional base style hash

    @since %ncurses 2.0
*/
nothing drawAnsiTextInsideLine(int y, string text, __7_ hash style);

public:
//! Draws a horizontal line
/**@param y row
    @param x column
    @param len length
    @param ch optional character
    @param style optional style hash

    @since %ncurses 2.0
*/
nothing drawHLine(int y, int x, int len, __7_ string ch, __7_ hash style);

public:
//! Draws text at a position
/**@param y row
    @param x column
    @param text text to draw
    @param style optional style hash

    @since %ncurses 2.0
*/
nothing drawText(int y, int x, string text, __7_ hash style);

public:
//! Draws text clipped to window bounds
/**@param y row
    @param x column
    @param text text to draw
    @param style optional style hash

    The text is clipped to the visible window region to prevent out-of-bounds
    writes. If the text would start before column 0, the leading characters are
    skipped.

    @since %ncurses 2.0
*/
nothing drawTextClipped(int y, int x, string text, __7_ hash style);

public:
//! Draws text clipped to the window's inner content area
/**@param y row inside the content area (0 = first row inside the border)
    @param x column inside the content area (0 = first column inside the border)
    @param text text to draw
    @param style optional style hash

    The text is clipped to the area inside a border (excluding rows/cols 0 and
    max-1). This prevents accidental overwriting of box borders.

    @since %ncurses 2.0
*/
nothing drawTextInside(int y, int x, string text, __7_ hash style);

public:
//! Draws text inside the window border and clears the rest of the line
/**@param y row inside the content area (0 = first row inside the border)
    @param text text to draw
    @param style optional style hash

    The line is cleared before writing to ensure no old text remains.

    @since %ncurses 2.0
*/
nothing drawTextInsideLine(int y, string text, __7_ hash style);

public:
//! Draws a vertical line
/**@param y row
    @param x column
    @param len length
    @param ch optional character
    @param style optional style hash

    @since %ncurses 2.0
*/
nothing drawVLine(int y, int x, int len, __7_ string ch, __7_ hash style);

public:
//! Enables or disables keypad mode
/**@param enabled enable keypad decoding when true

    @since %ncurses 2.0
*/
nothing enableKeypad(bool enabled);

public:
//! Enables or disables scrolling
/**@param enabled enable scrolling when true

    @since %ncurses 2.0
*/
nothing enableScroll(bool enabled);

public:
//! Erases the window contents
/**@since %ncurses 2.0
*/
nothing erase();

public:
//! Fills a rectangle
/**@param y top row
    @param x left column
    @param rows height
    @param cols width
    @param ch optional fill character
    @param style optional style hash

    @since %ncurses 2.0
*/
nothing fillRect(int y, int x, int rows, int cols, __7_ string ch, __7_ hash style);

public:
//! Returns the wrap mode for this window
/**@par Code Flags:
    @ref CONSTANT

@return @ref Qore::Ncurses::WrapMode "WrapMode" value

    @since %ncurses 2.0
*/
enum<WrapMode> getWrapMode();

public:
//! Moves the window
/**@param y new top row
    @param x new left column

    @since %ncurses 2.0
*/
nothing move(int y, int x);

public:
//! Moves the cursor
/**@param y row
    @param x column

    @since %ncurses 2.0
*/
nothing moveCursor(int y, int x);

public:
//! Queues the window for refresh
/**@since %ncurses 2.0
*/
nothing noutrefresh();

public:
//! Returns the window position
/**@since %ncurses 2.0
*/
hash<Position> position();

public:
//! Reads an input event
/**@param timeout_ms optional overall timeout in milliseconds
    @param poll_ms optional poll interval in milliseconds

    @since %ncurses 2.0
*/
hash<InputEvent> readEvent(__7_ int timeout_ms, __7_ int poll_ms);

public:
//! Reads multiple lines of text from the window
/**@param y start row (default 0)
    @param rows number of rows (default full window)
    @param cols number of columns (default full window)

    @return list of strings (one per row)

    @since %ncurses 2.1
*/
list<string> readLines(__7_ int y, __7_ int rows, __7_ int cols);

public:
//! Reads text from the window
/**@param y row
    @param x column
    @param len length

    @since %ncurses 2.0
*/
string readText(int y, int x, int len);

public:
//! Refreshes the window
/**@since %ncurses 2.0
*/
nothing refresh();

public:
//! Resizes the window
/**@param rows new height
    @param cols new width

    @since %ncurses 2.0
*/
nothing resize(int rows, int cols);

public:
//! Restores a previously saved cursor position
/**@param pos hash with keys \c y and \c x

    @since %ncurses 2.0
*/
nothing restoreCursor(hash pos);

public:
//! Saves the current cursor position
/**@return hash<@ref Position>

    @since %ncurses 2.0
*/
hash<Position> saveCursor();

public:
//! Scrolls the window
/**@param n number of lines to scroll

    @since %ncurses 2.0
*/
nothing scroll(int n);

public:
//! Sets the background style
/**@param style optional style hash

    @since %ncurses 2.0
*/
nothing setBackground(__7_ hash style);

public:
//! Sets whether the cursor should be left in this window after refresh
/**@param on True to disable cursor positioning for this window

    @since %ncurses 2.0
*/
nothing setLeaveOk(bool on);

public:
//! Sets the wrap mode for this window
/**@param mode wrap mode

    @since %ncurses 2.0
*/
nothing setWrapMode(enum<WrapMode> mode);

public:
//! Returns the window size
/**@since %ncurses 2.0
*/
hash<Size> size();

public:
//! Creates a sub-window
/**@param rows height
    @param cols width
    @param y top row
    @param x left column

    @since %ncurses 2.0
*/
Window subWindow(int rows, int cols, int y, int x);

public:
//! Writes text at the current cursor position
/**@param text text to write
    @param style optional style hash

    @since %ncurses 2.0
*/
nothing write(string text, __7_ hash style);
};
}
}
