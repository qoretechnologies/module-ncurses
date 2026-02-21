//! Qore namespace
namespace Qore {
//! Ncurses namespace
namespace Ncurses {
//! Cursor visibility enum
/** Cursor visibility modes.

    @since %ncurses 2.0
*/
enum CursorVisibility {
    Hidden = 0,
    Normal = 1,
    VeryVisible = 2,
};
}
}
//! Qore namespace
namespace Qore {
//! Ncurses namespace
namespace Ncurses {
//! Input event type enum
/** Input event types produced by @ref Qore::Ncurses::Window::readEvent() "Window::readEvent()".

    @since %ncurses 2.0
*/
enum InputType {
    None = 0,
    Char = 1,
    Key = 2,
    Mouse = 3,
    Resize = 4,
    Alt = 5,
};
}
}
//! Qore namespace
namespace Qore {
//! Ncurses namespace
namespace Ncurses {
//! Color enum
/** Basic ncurses colors.

    @since %ncurses 2.0
*/
enum Color {
    Default = -1,
    Black = COLOR_BLACK,
    Red = COLOR_RED,
    Green = COLOR_GREEN,
    Yellow = COLOR_YELLOW,
    Blue = COLOR_BLUE,
    Magenta = COLOR_MAGENTA,
    Cyan = COLOR_CYAN,
    White = COLOR_WHITE,
};
}
}
//! Qore namespace
namespace Qore {
//! Ncurses namespace
namespace Ncurses {
//! Text attribute enum
/** Text attributes used with @ref Ncurses::Style.

    @since %ncurses 2.0
*/
enum Attr {
    NormalAttr = A_NORMAL,
    Standout = A_STANDOUT,
    Underline = A_UNDERLINE,
    Reverse = A_REVERSE,
    Blink = A_BLINK,
    Dim = A_DIM,
    Bold = A_BOLD,
};
}
}
//! Qore namespace
namespace Qore {
//! Ncurses namespace
namespace Ncurses {
//! Text wrapping mode enum
/** Controls how text is wrapped when rendering in panels or windows.

    @since %ncurses 2.0
*/
enum WrapMode {
//! No wrapping; text is clipped to the line width    None = 0,
//! Hard wrap at the line width    Hard = 1,
//! Word wrap when possible, otherwise hard wrap    Word = 2,
};
}
}
//! Qore namespace
namespace Qore {
//! Ncurses namespace
namespace Ncurses {
//! Style hashdecl
/** Style definition for text and backgrounds.

    @since %ncurses 2.0
*/
struct Style {
    //! Bitwise attributes (Ncurses::Attr)
    int attrs;
    //! Background color (Ncurses::Color)
    int bg;
    //! Foreground color (Ncurses::Color)
    int fg;
};
}
}
//! Qore namespace
namespace Qore {
//! Ncurses namespace
namespace Ncurses {
//! Size hashdecl
/** Size hashdecl.

    @since %ncurses 2.0
*/
struct Size {
    //! Number of columns
    int cols;
    //! Number of rows
    int rows;
};
}
}
//! Qore namespace
namespace Qore {
//! Ncurses namespace
namespace Ncurses {
//! Position hashdecl
/** Position hashdecl.

    @since %ncurses 2.0
*/
struct Position {
    //! Column (x)
    int x;
    //! Row (y)
    int y;
};
}
}
//! Qore namespace
namespace Qore {
//! Ncurses namespace
namespace Ncurses {
//! Mouse event hashdecl
/** Mouse event information.

    @since %ncurses 2.0
*/
struct MouseEvent {
    //! Button state mask
    int button_state;
    //! Column (x)
    int x;
    //! Row (y)
    int y;
};
}
}
//! Qore namespace
namespace Qore {
//! Ncurses namespace
namespace Ncurses {
//! Input event hashdecl
/** Input event information.

    @since %ncurses 2.0
*/
struct InputEvent {
    //! Character for char events
    string ch;
    //! Key code for key events
    int code;
    //! Mouse event details (if type == Ncurses::InputType::Mouse)
    hash<MouseEvent> mouse;
    //! Human-readable name for key events
    string name;
    //! Ncurses::InputType
    int type;
};
}
}
//! Qore namespace
namespace Qore {
//! Ncurses namespace
namespace Ncurses {
//! Ncurses session
/** Manages a ncurses screen session.

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
class Session {

public:
//! Emits a terminal beep
/**@since %ncurses 2.0
*/
nothing beep();

public:
//! Returns true if the terminal supports color redefinition
/**When true, @ref initColor() can be used to redefine color slots with custom RGB values.

    @return true if the terminal supports redefining colors

    @since %ncurses 2.1
*/
bool canChangeColor();

public:
//! Closes the session
/**@since %ncurses 2.0
*/
nothing close();

public:
//! Creates a new session
/**@param opts optional hash of options:
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
 constructor(__7_ hash opts);

public:
//! Flushes the virtual screen to the terminal
/**Applies the most recent cursor position set with @ref Ncurses::Window::moveCursor
    or @ref Ncurses::Window::restoreCursor before updating the terminal.

    @since %ncurses 2.0
*/
nothing doupdate();

public:
//! Flashes the terminal
/**@since %ncurses 2.0
*/
nothing flash();

public:
//! Flushes pending input
/**@since %ncurses 2.0
*/
nothing flushInput();

public:
//! Flushes any buffered C stdio data on stdout and stderr
/** This ensures that output written via C's \c printf() / \c fputs() (used
    internally by Qore's \c print() builtin) is flushed to the underlying
    file descriptor.  Call this after evaluating user code to ensure all
    output reaches the capture pipe.

    @since %ncurses 2.0
*/
nothing flushStdio();

public:
//! Redefines a color slot with custom RGB values
/**@param color the color number to redefine (0 to @ref maxColors() - 1)
    @param r red component (0-1000)
    @param g green component (0-1000)
    @param b blue component (0-1000)

    @throw NCURSES-ERROR if the terminal does not support color redefinition or the color number is out of range

    @note The terminal must support color redefinition (@ref canChangeColor() returns true)

    @since %ncurses 2.1
*/
nothing initColor(int color, int r, int g, int b);

public:
//! Injects a single input event into the ncurses input queue
/**@param ev input event hash (type + payload)
    - type (int) one of @ref InputType values
    - code (int) for Key or Char events
    - ch (string) for Char events
    - mouse (hash) for Mouse events with keys: x, y, button_state

    @since %ncurses 2.1
*/
nothing injectEvent(hash<InputEvent> ev);

public:
//! Injects a list of input events into the ncurses input queue
/**@param events list of @ref InputEvent hashes

    @since %ncurses 2.1
*/
nothing injectEvents(list<hash<InputEvent>> events);

public:
//! Injects input into the ncurses input queue
/**@param data input characters to inject

    @since %ncurses 2.0
*/
nothing injectInput(string data);

public:
//! Returns true if the session is open
/**@since %ncurses 2.0
*/
bool isOpen();

public:
//! Returns the maximum number of colors supported by the terminal
/**@return the number of colors the terminal supports (typically 8, 256, or more)

    @since %ncurses 2.1
*/
int maxColors();

public:
//! Redirects the C stderr stream to the given file
/**@param file target file

    @since %ncurses 2.0
*/
nothing redirectStderr(File file);

public:
//! Redirects the C stdout stream to the given file
/**@param file target file

    @since %ncurses 2.0
*/
nothing redirectStdout(File file);

public:
//! Returns the screen window
/**@since %ncurses 2.0
*/
Window screen();

public:
//! Sets cursor visibility
/**@param visibility one of @ref CursorVisibility values

    @since %ncurses 2.0
*/
nothing setCursor(int visibility);

public:
//! Sets the escape sequence delay
/**@param ms delay in milliseconds (values < 0 are treated as 0)
    @return previous delay value if available, otherwise 0

    @since %ncurses 2.0
*/
int setEscDelay(int ms);

public:
//! Enables or disables mouse event reporting
/**@param enabled true to enable mouse events, false to disable

    @since %ncurses 2.0
*/
nothing setMouse(bool enabled);

public:
//! Returns a snapshot of the screen contents
/**@param y start row (default 0)
    @param rows number of rows (default full screen)
    @param cols number of columns (default full screen)

    @return list of strings (one per row)

    @since %ncurses 2.1
*/
list<string> snapshot(__7_ int y, __7_ int rows, __7_ int cols);

public:
//! Returns true if colors are enabled
/**@since %ncurses 2.0
*/
bool supportsColor();

public:
//! Queues panel updates
/**@since %ncurses 2.0
*/
nothing updatePanels();

public:
//! Executes a callback with the ncurses lock held
/**@param cb callable (closure or call reference)
    @param cb_args optional list of arguments

    @return the callback result

    @since %ncurses 2.0
*/
auto withLock(code cb, __7_ list cb_args);
};
/** @defgroup ncurses_constants Ncurses Constants
    Key and mouse constants for the Ncurses module.
*/
///@{

//! Mouse button flags
    const BUTTON1_CLICKED = BUTTON1_CLICKED;
//! Mouse button flags
    const BUTTON1_DOUBLE_CLICKED = BUTTON1_DOUBLE_CLICKED;
//! Mouse button flags
    const BUTTON1_PRESSED = BUTTON1_PRESSED;
//! Mouse button flags
    const BUTTON1_RELEASED = BUTTON1_RELEASED;
//! Mouse button flags
    const BUTTON1_TRIPLE_CLICKED = BUTTON1_TRIPLE_CLICKED;
//! Mouse button flags
    const BUTTON2_CLICKED = BUTTON2_CLICKED;
//! Mouse button flags
    const BUTTON2_DOUBLE_CLICKED = BUTTON2_DOUBLE_CLICKED;
//! Mouse button flags
    const BUTTON2_PRESSED = BUTTON2_PRESSED;
//! Mouse button flags
    const BUTTON2_RELEASED = BUTTON2_RELEASED;
//! Mouse button flags
    const BUTTON2_TRIPLE_CLICKED = BUTTON2_TRIPLE_CLICKED;
//! Mouse button flags
    const BUTTON3_CLICKED = BUTTON3_CLICKED;
//! Mouse button flags
    const BUTTON3_DOUBLE_CLICKED = BUTTON3_DOUBLE_CLICKED;
//! Mouse button flags
    const BUTTON3_PRESSED = BUTTON3_PRESSED;
//! Mouse button flags
    const BUTTON3_RELEASED = BUTTON3_RELEASED;
//! Mouse button flags
    const BUTTON3_TRIPLE_CLICKED = BUTTON3_TRIPLE_CLICKED;
//! Mouse button flags
    const BUTTON4_CLICKED = BUTTON4_CLICKED;
//! Mouse button flags
    const BUTTON4_DOUBLE_CLICKED = BUTTON4_DOUBLE_CLICKED;
//! Mouse button flags
    const BUTTON4_PRESSED = BUTTON4_PRESSED;
//! Mouse button flags
    const BUTTON4_RELEASED = BUTTON4_RELEASED;
//! Mouse button flags
    const BUTTON4_TRIPLE_CLICKED = BUTTON4_TRIPLE_CLICKED;
//! Mouse button flags
    const BUTTON5_CLICKED = BUTTON5_CLICKED;
//! Mouse button flags
    const BUTTON5_DOUBLE_CLICKED = BUTTON5_DOUBLE_CLICKED;
//! Mouse button flags
    const BUTTON5_PRESSED = BUTTON5_PRESSED;
//! Mouse button flags
    const BUTTON5_RELEASED = BUTTON5_RELEASED;
//! Mouse button flags
    const BUTTON5_TRIPLE_CLICKED = BUTTON5_TRIPLE_CLICKED;
//! Mouse button flags
    const BUTTON_ALT = BUTTON_ALT;
//! Mouse button flags
    const BUTTON_CTRL = BUTTON_CTRL;
//! Mouse button flags
    const BUTTON_SHIFT = BUTTON_SHIFT;
//! Key code for Backspace
    const KEY_BACKSPACE = KEY_BACKSPACE;
//! Key code for Delete
    const KEY_DC = KEY_DC;
//! Key code for arrow down
    const KEY_DOWN = KEY_DOWN;
//! Key code for End
    const KEY_END = KEY_END;
//! Key code for Enter
    const KEY_ENTER = KEY_ENTER;
//! Key code for Home
    const KEY_HOME = KEY_HOME;
//! Key code for Insert
    const KEY_IC = KEY_IC;
//! Key code for arrow left
    const KEY_LEFT = KEY_LEFT;
//! Key code for Mouse
    const KEY_MOUSE = KEY_MOUSE;
//! Key code for Page Down
    const KEY_NPAGE = KEY_NPAGE;
//! Key code for Page Up
    const KEY_PPAGE = KEY_PPAGE;
//! Key code for Resize
    const KEY_RESIZE = KEY_RESIZE;
//! Key code for arrow right
    const KEY_RIGHT = KEY_RIGHT;
//! Key code for arrow up
    const KEY_UP = KEY_UP;
///@}
}
}
