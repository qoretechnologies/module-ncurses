//! Qore namespace
namespace Qore {
//! Ncurses namespace
namespace Ncurses {
//! ANSI text helper class
/** @par Restrictions:
    @ref Qore::PO_NO_TERMINAL_IO

Helpers for parsing and wrapping ANSI SGR colored text.

    @since %ncurses 2.0
*/
class Ansi {

public:
//! Returns the visible character length of ANSI SGR text
/** @par Code Flags:
    @ref CONSTANT

    @param text text with ANSI SGR color codes
    @return visible character length (ANSI codes excluded)

    @since %ncurses 2.0
*/
static int len(string text);

public:
//! Parses ANSI SGR text into segments
/** @par Code Flags:
    @ref CONSTANT

    @param text text with ANSI SGR color codes
    @return list of segments with keys: \c text and \c style

    @since %ncurses 2.0
*/
static list<hash> parse(string text);

public:
//! Wraps ANSI SGR text to a given width
/** @par Code Flags:
    @ref CONSTANT

    @param text text with ANSI SGR color codes
    @param width wrap width
    @param mode wrap mode (default: @ref Qore::Ncurses::WrapMode "WrapMode::Word")
    @return list of wrapped lines with ANSI codes preserved

    @since %ncurses 2.0
*/
static list<string> wrap(string text, int width, enum<WrapMode> mode = 2);
};
}
}
