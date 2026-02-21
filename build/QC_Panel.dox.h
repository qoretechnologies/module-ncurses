//! Qore namespace
namespace Qore {
//! Ncurses namespace
namespace Ncurses {
//! Ncurses panel
/** Represents a panel layered above windows.

    A Panel wraps a Window with z-order stacking managed by the ncurses panel
    library. Use show(), hide(), and top() to control visibility and ordering,
    and update() to flush changes to the terminal.

   @par Restrictions:
    @ref Qore::PO_NO_TERMINAL_IO

     @par Example:
    @code{.py}
%modern
%requires ncurses

Ncurses::Session s();
Ncurses::Window root = s.screen();
root.clear();

# create a panel with a new 7x30 window at (2, 4)
Ncurses::Panel p(s, 7, 30, 2, 4);
Ncurses::Window pw = p.window();
pw.box({"fg": Ncurses::Color::Cyan});
pw.drawTextInside(0, 0, "Panel content", {"fg": Ncurses::Color::White});

p.show();
p.top();
p.update();

root.readEvent();
s.close();
    @endcode

    @since %ncurses 2.0
*/
class Panel {

public:
//! Moves the panel to the bottom
/**@since %ncurses 2.0
*/
nothing bottom();

public:
//! Creates a panel from an existing window
/**@param window the window to wrap

    @since %ncurses 2.0
*/
 constructor(Qore::Ncurses::Window window);

public:
//! Creates a panel with a new window
/**@param session the session
    @param rows height
    @param cols width
    @param y top row
    @param x left column

    @since %ncurses 2.0
*/
 constructor(Qore::Ncurses::Session session, int rows, int cols, int y, int x);

public:
//! Returns the wrap mode for the panel's window
/**@par Code Flags:
    @ref CONSTANT

@return @ref Qore::Ncurses::WrapMode "WrapMode" value

    @since %ncurses 2.0
*/
enum<WrapMode> getWrapMode();

public:
//! Hides the panel
/**@since %ncurses 2.0
*/
nothing hide();

public:
//! Moves the panel
/**@param y top row
    @param x left column

    @since %ncurses 2.0
*/
nothing move(int y, int x);

public:
//! Sets the wrap mode for the panel's window
/**@param mode wrap mode

    @since %ncurses 2.0
*/
nothing setWrapMode(enum<WrapMode> mode);

public:
//! Shows the panel
/**@since %ncurses 2.0
*/
nothing show();

public:
//! Moves the panel to the top
/**@since %ncurses 2.0
*/
nothing top();

public:
//! Updates panel stacking
/**@since %ncurses 2.0
*/
nothing update();

public:
//! Returns the panel's window
/**@since %ncurses 2.0
*/
Window window();
};
}
}
