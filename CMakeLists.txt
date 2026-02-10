cmake_minimum_required(VERSION 3.21...3.31)

project(qore-ncurses-module)

include(GNUInstallDirs)
set(CMAKE_INSTALL_BINDIR "bin")

set(VERSION_MAJOR 2)
set(VERSION_MINOR 0)
set(VERSION_PATCH 0)

set(PROJECT_VERSION "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")

# where to look first for cmake modules, before ${CMAKE_ROOT}/Modules/ is checked
set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

# ensure qdx can find the ncurses binary module and user modules when processing .qc files
set(QORE_MODULE_DIR_FOR_DOCS "${CMAKE_BINARY_DIR}:${CMAKE_SOURCE_DIR}/qlib")

find_package(Qore 2.3 REQUIRED)

# Use wide-character ncurses (ncursesw) to avoid ABI mismatch with wide panel library.
# Try pkg-config first for reliable detection of wide ncurses.
find_package(PkgConfig)
if (PKG_CONFIG_FOUND)
    pkg_check_modules(NCURSESW ncursesw)
endif()

if (NCURSESW_FOUND)
    message(STATUS "Found ncursesw via pkg-config: ${NCURSESW_LIBRARIES}")
    set(NCURSES_INCLUDE ${NCURSESW_INCLUDE_DIRS})
    set(NCURSES_CFLAGS_LIST ${NCURSESW_CFLAGS_OTHER})
else()
    # Fall back to FindCurses with wide-character preference
    set(CURSES_NEED_WIDE TRUE)
    set(CURSES_NEED_NCURSES TRUE)
    find_package(Curses REQUIRED)
    set(NCURSES_INCLUDE "")
    if (CURSES_INCLUDE_DIRS)
        set(NCURSES_INCLUDE ${CURSES_INCLUDE_DIRS})
    elseif(CURSES_INCLUDE_DIR)
        set(NCURSES_INCLUDE ${CURSES_INCLUDE_DIR})
    endif()
    set(NCURSES_CFLAGS_LIST "")
endif()

include_directories(${CMAKE_SOURCE_DIR}/src)
if (NCURSES_INCLUDE)
    include_directories(${NCURSES_INCLUDE})
endif()

# Apply ncursesw compile flags (e.g. -DNCURSES_WIDECHAR on Alpine)
foreach(_flag ${NCURSES_CFLAGS_LIST})
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${_flag}")
endforeach()

# Check for C++11
include(CheckCXXCompilerFlag)
CHECK_CXX_COMPILER_FLAG("-std=c++11" COMPILER_SUPPORTS_CXX11)
if (COMPILER_SUPPORTS_CXX11)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")
else()
    message(FATAL_ERROR "The compiler ${CMAKE_CXX_COMPILER} has no C++11 support. Please use a different C++ compiler.")
endif()

set(QPP_SRC
    src/ncurses.qpp
    src/QC_Session.qpp
    src/QC_Window.qpp
    src/QC_Panel.qpp
    src/QC_Ansi.qpp
    src/QC_TestTerminal.qpp
)

qore_wrap_qpp_value(QPP_SOURCES ${QPP_SRC})

set(module_name "ncurses")

set(CPP_SRC
    src/ncurses-internal.cpp
)

add_library(${module_name} MODULE ${CPP_SRC} ${QPP_SOURCES})

if (NCURSESW_FOUND)
    # Use pkg-config results for wide ncurses
    find_library(NCURSESW_LIBRARY ncursesw HINTS ${NCURSESW_LIBRARY_DIRS})
    find_library(PANELW_LIBRARY panelw HINTS ${NCURSESW_LIBRARY_DIRS})
    find_library(TINFO_LIBRARY tinfo HINTS ${NCURSESW_LIBRARY_DIRS})
    set(NCURSES_LIBS "")
    if (NCURSESW_LIBRARY)
        list(APPEND NCURSES_LIBS ${NCURSESW_LIBRARY})
    endif()
    if (PANELW_LIBRARY)
        list(APPEND NCURSES_LIBS ${PANELW_LIBRARY})
    endif()
    if (TINFO_LIBRARY)
        list(APPEND NCURSES_LIBS ${TINFO_LIBRARY})
    endif()
else()
    # FindCurses fallback
    set(NCURSES_LIBS ${CURSES_LIBRARIES})
    if (CURSES_PANEL_LIBRARY)
        list(APPEND NCURSES_LIBS ${CURSES_PANEL_LIBRARY})
    else()
        find_library(PANELW_LIBRARY panelw panel)
        if (PANELW_LIBRARY)
            list(APPEND NCURSES_LIBS ${PANELW_LIBRARY})
        endif()
    endif()
    if (CURSES_TINFO_LIBRARY)
        list(APPEND NCURSES_LIBS ${CURSES_TINFO_LIBRARY})
    endif()
endif()

find_library(UTIL_LIBRARY util)
if (UTIL_LIBRARY)
    list(APPEND NCURSES_LIBS ${UTIL_LIBRARY})
endif()

if (DEFINED ENV{DOXYGEN_EXECUTABLE})
    set(DOXYGEN_EXECUTABLE $ENV{DOXYGEN_EXECUTABLE})
endif()

set(QORE_DOX_TMPL_SRC
    docs/mainpage.dox.tmpl
)

set(QMOD
    qlib/NcursesReplUi.qm
)

set(SCRIPTS
    bin/qrepl
)

# disable qjar for this module (ncurses is not a Java module)
set(QORE_QJAR_COMMAND true)

qore_external_binary_module(${module_name} "${PROJECT_VERSION}")

qore_user_modules("${QMOD}")
install(PROGRAMS ${SCRIPTS} DESTINATION ${CMAKE_INSTALL_BINDIR})
qore_external_user_module("qlib/NcursesReplUi.qm" "")
qore_external_user_module("qlib/NcursesUi/NcursesUi.qm" "")

qore_dist("${PROJECT_VERSION}")

qore_config_info()

if (DOXYGEN_FOUND)
    qore_wrap_dox(QORE_DOX_SRC ${QORE_DOX_TMPL_SRC})
    add_custom_target(QORE_MOD_DOX_FILES DEPENDS ${QORE_DOX_SRC})
    add_dependencies(docs-module QORE_MOD_DOX_FILES)

    # Two-phase doc build: the initial pass (docs-module) generates ncurses.tag with empty
    # TAGFILES. User module docs (docs-NcursesUi, docs-NcursesReplUi) are then built using
    # ncurses.tag, generating their own tag files. The final pass (docs-module-final) rebuilds
    # the binary module docs with user module tag files in TAGFILES, enabling @ref
    # cross-references from the mainpage into user module symbols.

    # Suppress unresolved cross-reference warnings in the initial pass
    file(APPEND ${CMAKE_BINARY_DIR}/Doxyfile "\n# Suppress warnings for initial pass (no user module TAGFILES available)\nWARN_IF_DOC_ERROR = NO\n")

    # Add NcursesReplUi tag to NcursesUi docs so NcursesUi can cross-reference NcursesReplUi types
    file(APPEND ${CMAKE_BINARY_DIR}/doxygen/Doxyfile.NcursesUi
        "\n# Add NcursesReplUi tag for cross-module references\nTAGFILES += ${CMAKE_BINARY_DIR}/NcursesReplUi.tag=../../NcursesReplUi/html\n")

    # NcursesReplUi must build before NcursesUi so that NcursesReplUi.tag is available
    add_dependencies(docs-NcursesUi docs-NcursesReplUi)

    # Create final-pass Doxyfile from the binary module's Doxyfile with user module tag files
    # (copy + append, NOT configure_file with user module template which has wrong INPUT)
    file(COPY_FILE ${CMAKE_BINARY_DIR}/Doxyfile ${CMAKE_BINARY_DIR}/Doxyfile.final)
    file(APPEND ${CMAKE_BINARY_DIR}/Doxyfile.final
        "\n# Final pass: enable user module cross-references and re-enable doc error warnings\nTAGFILES = ${CMAKE_BINARY_DIR}/NcursesUi.tag=../NcursesUi/html ${CMAKE_BINARY_DIR}/NcursesReplUi.tag=../NcursesReplUi/html\nWARN_IF_DOC_ERROR = YES\n")

    add_custom_target(docs-module-final
        COMMAND ${DOXYGEN_EXECUTABLE} ${CMAKE_BINARY_DIR}/Doxyfile.final
        COMMAND ${QORE_DOCS_ENV} ${QORE_QDX_COMMAND} --post ${CMAKE_BINARY_DIR}/docs/${module_name}/html ${CMAKE_BINARY_DIR}/docs/${module_name}/html/search
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Generating API documentation with Doxygen (final pass with user module cross-references)"
        VERBATIM
    )
    add_dependencies(docs-module-final docs-NcursesUi docs-NcursesReplUi)
    add_dependencies(docs docs-module-final)
endif()

# link libraries
if (NCURSES_LIBS)
    target_link_libraries(${module_name} ${NCURSES_LIBS} ${QORE_LIBRARY})
else()
    target_link_libraries(${module_name} ${QORE_LIBRARY})
endif()
