// Java created from Qore class Qore::Ncurses::Panel
package qore.Qore.Ncurses;

/** @brief Ncurses panel
    Represents a panel layered above windows.

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
public class Panel {
    // nothing Panel::bottom(){}
    /** @brief Moves the panel to the bottom
    @since %ncurses 2.0
    */
    public void bottom() throws Throwable {
    }

    // Panel::constructor(Qore::Ncurses::Window window) {}
    /** @brief Creates a panel from an existing window
    @param window the window to wrap
    
        @since %ncurses 2.0
    */
    public Panel(qore.Qore.Ncurses.Window window) throws Throwable {
    }

    // Panel::constructor(Qore::Ncurses::Session session, int rows, int cols, int y, int x) {}
    /** @brief Creates a panel with a new window
    @param session the session
        @param rows height
        @param cols width
        @param y top row
        @param x left column
    
        @since %ncurses 2.0
    */
    public Panel(qore.Qore.Ncurses.Session session, long rows, long cols, long y, long x) throws Throwable {
    }

    // enum<WrapMode> Panel::getWrapMode(){}
    /** @brief Returns the wrap mode for the panel's window
    @par Code Flags:
        @ref CONSTANT
    
    @return @ref Qore::Ncurses::WrapMode "WrapMode" value
    
        @since %ncurses 2.0
    */
    public qore.Qore.enum<WrapMode> getWrapMode() throws Throwable {
    }

    // nothing Panel::hide(){}
    /** @brief Hides the panel
    @since %ncurses 2.0
    */
    public void hide() throws Throwable {
    }

    // nothing Panel::move(int y, int x){}
    /** @brief Moves the panel
    @param y top row
        @param x left column
    
        @since %ncurses 2.0
    */
    public void move(long y, long x) throws Throwable {
    }

    // nothing Panel::setWrapMode(enum<WrapMode> mode){}
    /** @brief Sets the wrap mode for the panel's window
    @param mode wrap mode
    
        @since %ncurses 2.0
    */
    public void setWrapMode(qore.Qore.enum<WrapMode> mode) throws Throwable {
    }

    // nothing Panel::show(){}
    /** @brief Shows the panel
    @since %ncurses 2.0
    */
    public void show() throws Throwable {
    }

    // nothing Panel::top(){}
    /** @brief Moves the panel to the top
    @since %ncurses 2.0
    */
    public void top() throws Throwable {
    }

    // nothing Panel::update(){}
    /** @brief Updates panel stacking
    @since %ncurses 2.0
    */
    public void update() throws Throwable {
    }

    // Window Panel::window(){}
    /** @brief Returns the panel's window
    @since %ncurses 2.0
    */
    public qore.Qore.Window window() throws Throwable {
    }

}
