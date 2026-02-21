// Java created from Qore class Qore::Ncurses::Ansi
package qore.Qore.Ncurses;

/** @brief ANSI text helper class
    @par Restrictions:
    @ref Qore::PO_NO_TERMINAL_IO

Helpers for parsing and wrapping ANSI SGR colored text.

    @since %ncurses 2.0
*/
public class Ansi {
    // static int Ansi::len(string text){}
    /** @brief Returns the visible character length of ANSI SGR text
     @par Code Flags:
        @ref CONSTANT
    
        @param text text with ANSI SGR color codes
        @return visible character length (ANSI codes excluded)
    
        @since %ncurses 2.0
    */
    static public long len(String text) throws Throwable {
    }

    // static list<hash> Ansi::parse(string text){}
    /** @brief Parses ANSI SGR text into segments
     @par Code Flags:
        @ref CONSTANT
    
        @param text text with ANSI SGR color codes
        @return list of segments with keys: \c text and \c style
    
        @since %ncurses 2.0
    */
    static public Object[] parse(String text) throws Throwable {
    }

    // static list<string> Ansi::wrap(string text, int width, enum<WrapMode> mode = 2){}
    /** @brief Wraps ANSI SGR text to a given width
     @par Code Flags:
        @ref CONSTANT
    
        @param text text with ANSI SGR color codes
        @param width wrap width
        @param mode wrap mode (default: @ref Qore::Ncurses::WrapMode "WrapMode::Word")
        @return list of wrapped lines with ANSI codes preserved
    
        @since %ncurses 2.0
    */
    static public Object[] wrap(String text, long width, qore.Qore.enum<WrapMode> mode) throws Throwable {
    }

}
