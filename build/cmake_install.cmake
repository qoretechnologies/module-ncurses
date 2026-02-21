# Install script for directory: /home/david/src/qore/git/module-ncurses

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/usr/local")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Install shared libraries without execute permission?
if(NOT DEFINED CMAKE_INSTALL_SO_NO_EXE)
  set(CMAKE_INSTALL_SO_NO_EXE "1")
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

# Set path to fallback-tool for dependency-resolution.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/usr/bin/objdump")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}/usr/local/lib/x86_64-linux-gnu/qore-modules/ncurses-api-2.0.qmod" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}/usr/local/lib/x86_64-linux-gnu/qore-modules/ncurses-api-2.0.qmod")
    file(RPATH_CHECK
         FILE "$ENV{DESTDIR}/usr/local/lib/x86_64-linux-gnu/qore-modules/ncurses-api-2.0.qmod"
         RPATH "/usr/local/lib/x86_64-linux-gnu")
  endif()
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "/usr/local/lib/x86_64-linux-gnu/qore-modules/ncurses-api-2.0.qmod")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "/usr/local/lib/x86_64-linux-gnu/qore-modules" TYPE MODULE FILES "/home/david/src/qore/git/module-ncurses/build/ncurses-api-2.0.qmod")
  if(EXISTS "$ENV{DESTDIR}/usr/local/lib/x86_64-linux-gnu/qore-modules/ncurses-api-2.0.qmod" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}/usr/local/lib/x86_64-linux-gnu/qore-modules/ncurses-api-2.0.qmod")
    file(RPATH_CHANGE
         FILE "$ENV{DESTDIR}/usr/local/lib/x86_64-linux-gnu/qore-modules/ncurses-api-2.0.qmod"
         OLD_RPATH "/usr/local/lib/x86_64-linux-gnu:"
         NEW_RPATH "/usr/local/lib/x86_64-linux-gnu")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/usr/bin/strip" "$ENV{DESTDIR}/usr/local/lib/x86_64-linux-gnu/qore-modules/ncurses-api-2.0.qmod")
    endif()
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  include("/home/david/src/qore/git/module-ncurses/build/CMakeFiles/ncurses.dir/install-cxx-module-bmi-release.cmake" OPTIONAL)
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "/usr/local/share/qore-modules/NcursesReplUi.qm")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "/usr/local/share/qore-modules" TYPE FILE FILES "/home/david/src/qore/git/module-ncurses/qlib/NcursesReplUi.qm")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE PROGRAM FILES "/home/david/src/qore/git/module-ncurses/bin/qrepl")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "/usr/local/share/qore-modules/NcursesReplUi.qm")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "/usr/local/share/qore-modules" TYPE FILE FILES "/home/david/src/qore/git/module-ncurses/qlib/NcursesReplUi.qm")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "/usr/local/share/qore-modules/NcursesUi/Application.qc;/usr/local/share/qore-modules/NcursesUi/BoxLayout.qc;/usr/local/share/qore-modules/NcursesUi/CheckboxWidget.qc;/usr/local/share/qore-modules/NcursesUi/ComboBoxWidget.qc;/usr/local/share/qore-modules/NcursesUi/CompletionPopupWidget.qc;/usr/local/share/qore-modules/NcursesUi/DialogWidget.qc;/usr/local/share/qore-modules/NcursesUi/DropdownMenuWidget.qc;/usr/local/share/qore-modules/NcursesUi/EventDispatcher.qc;/usr/local/share/qore-modules/NcursesUi/FileBrowserWidget.qc;/usr/local/share/qore-modules/NcursesUi/FocusManager.qc;/usr/local/share/qore-modules/NcursesUi/Geometry.qc;/usr/local/share/qore-modules/NcursesUi/LineListContent.qc;/usr/local/share/qore-modules/NcursesUi/ListWidget.qc;/usr/local/share/qore-modules/NcursesUi/MenuBarWidget.qc;/usr/local/share/qore-modules/NcursesUi/NcursesUi.qm;/usr/local/share/qore-modules/NcursesUi/PanelWidget.qc;/usr/local/share/qore-modules/NcursesUi/RadioGroupWidget.qc;/usr/local/share/qore-modules/NcursesUi/ScrollableContent.qc;/usr/local/share/qore-modules/NcursesUi/ScrollableWidget.qc;/usr/local/share/qore-modules/NcursesUi/SplitLayout.qc;/usr/local/share/qore-modules/NcursesUi/StatusBarWidget.qc;/usr/local/share/qore-modules/NcursesUi/TableWidget.qc;/usr/local/share/qore-modules/NcursesUi/TextInputWidget.qc;/usr/local/share/qore-modules/NcursesUi/Widget.qc")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "/usr/local/share/qore-modules/NcursesUi" TYPE FILE FILES
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/Application.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/BoxLayout.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/CheckboxWidget.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/ComboBoxWidget.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/CompletionPopupWidget.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/DialogWidget.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/DropdownMenuWidget.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/EventDispatcher.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/FileBrowserWidget.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/FocusManager.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/Geometry.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/LineListContent.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/ListWidget.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/MenuBarWidget.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/NcursesUi.qm"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/PanelWidget.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/RadioGroupWidget.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/ScrollableContent.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/ScrollableWidget.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/SplitLayout.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/StatusBarWidget.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/TableWidget.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/TextInputWidget.qc"
    "/home/david/src/qore/git/module-ncurses/qlib/NcursesUi/Widget.qc"
    )
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "/usr/local/share/qore/metadata/ncurses/ncurses.meta.json;/usr/local/share/qore/metadata/ncurses/QC_Session.meta.json;/usr/local/share/qore/metadata/ncurses/QC_Window.meta.json;/usr/local/share/qore/metadata/ncurses/QC_Panel.meta.json;/usr/local/share/qore/metadata/ncurses/QC_Ansi.meta.json;/usr/local/share/qore/metadata/ncurses/QC_TestTerminal.meta.json")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "/usr/local/share/qore/metadata/ncurses" TYPE FILE FILES
    "/home/david/src/qore/git/module-ncurses/build/ncurses.meta.json"
    "/home/david/src/qore/git/module-ncurses/build/QC_Session.meta.json"
    "/home/david/src/qore/git/module-ncurses/build/QC_Window.meta.json"
    "/home/david/src/qore/git/module-ncurses/build/QC_Panel.meta.json"
    "/home/david/src/qore/git/module-ncurses/build/QC_Ansi.meta.json"
    "/home/david/src/qore/git/module-ncurses/build/QC_TestTerminal.meta.json"
    )
endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
if(CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "/home/david/src/qore/git/module-ncurses/build/install_local_manifest.txt"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
if(CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_COMPONENT MATCHES "^[a-zA-Z0-9_.+-]+$")
    set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INSTALL_COMPONENT}.txt")
  else()
    string(MD5 CMAKE_INST_COMP_HASH "${CMAKE_INSTALL_COMPONENT}")
    set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INST_COMP_HASH}.txt")
    unset(CMAKE_INST_COMP_HASH)
  endif()
else()
  set(CMAKE_INSTALL_MANIFEST "install_manifest.txt")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "/home/david/src/qore/git/module-ncurses/build/${CMAKE_INSTALL_MANIFEST}"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
