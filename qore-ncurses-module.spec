# Copyright (C) 2026 Qore Technologies, s.r.o.
# SPDX-License-Identifier: MIT
# Use the pinned source epoch for RPM headers and installed file timestamps.
%global source_date_epoch_from_changelog 1
%global use_source_date_epoch_as_buildtime 1
%if v"%{rpmversion}" >= v"4.20"
%global build_mtime_policy clamp_to_source_date_epoch
%else
%global clamp_mtime_to_source_date_epoch 1
%endif
%bcond_without tests
%bcond_without docs
Name: qore-ncurses-module
Version: 2.0.0
Release: 1%{?dist}
Summary: Terminal widgets and an interactive shell for Qore
License: MIT
URL: https://github.com/qoretechnologies/module-ncurses
Source0: %{name}-%{version}.tar.xz
%global _find_debuginfo_dwz_opts %{nil}
BuildRequires: cmake >= 3.21
BuildRequires: make
BuildRequires: gcc-c++
BuildRequires: pkgconfig(ncursesw)
BuildRequires: pkgconfig(panelw)
BuildRequires: qore-magic-module >= 2.0
# AOT code references magic symbols when compiled with file-type detection.
Requires: qore-magic-module%{?_isa} >= 2.0
%if 0%{?suse_version}
Requires: terminfo-base
BuildRequires: terminfo-base
%else
Requires: ncurses-base
BuildRequires: ncurses-base
%endif
BuildRequires: python3
BuildRequires: qore-devel >= 3.0.0~
BuildRequires: qore-rpm-macros >= 3.0.0~
%if %{with docs}
BuildRequires: doxygen
%if 0%{?suse_version}
BuildRequires: util-linux
%else
BuildRequires: util-linux-core
%endif
%endif
%{?qore_enable_aot_post}

%description
Wide-character terminal control, the NcursesUi widget toolkit, NcursesReplUi
helpers and an interactive Qore shell. The magic module supplies file-type
detection in the compiled file browser.

%if %{with docs}
%package doc
Summary: Terminal module reference documentation and examples
BuildArch: noarch
%description doc
API references and headless test examples for Qore's terminal modules.
%endif

%prep
%autosetup
%build
%{?set_build_flags}
. %{_rpmconfigdir}/qore/module-env.sh
qore_set_source_prefix_maps "%{qore_debug_source_dir}"
cmake -S . -B build -G 'Unix Makefiles' \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS_RELEASE=-DNDEBUG \
  -DCMAKE_INSTALL_PREFIX=%{_prefix} -DCMAKE_INSTALL_LIBDIR=%{_lib} \
  -DCMAKE_SKIP_RPATH=ON -DCMAKE_IGNORE_PREFIX_PATH=/usr/local \
  -DQore_DIR=%{_libdir}/cmake/Qore -DQORE_EXECUTABLE=/usr/bin/qore \
  -DQORE_QPP_EXECUTABLE=/usr/bin/qpp -DQORE_QCC_EXECUTABLE=/usr/bin/qcc \
  -DQORE_BUILD_AOT_MODULES=ON -DQORE_AOT_LINK_SOURCE_MODULES=OFF \
  -DQORE_MODULE_DIR_FOR_DOCS:STRING="$QORE_MODULE_DIR:$PWD/qlib" \
  -DQORE_QM_METADATA_ENV:STRING="QORE_MODULE_DIR=$QORE_MODULE_DIR:$PWD/qlib;QORE_MODULE_DIR_ONLY=1;QORE_INCLUDE_DIR=;LD_LIBRARY_PATH=" \
  -DCMAKE_DISABLE_FIND_PACKAGE_Doxygen=%{!?with_docs:ON}%{?with_docs:OFF}
cmake --build build -- %{?_smp_mflags}
%if %{with docs}
for doxyfile in build/Doxyfile.final build/doxygen/Doxyfile.*; do
  printf "\nWARN_AS_ERROR = FAIL_ON_WARNINGS\n" >> "$doxyfile"
done
cmake --build build --target docs -- %{?_smp_mflags}
%endif
%install
DESTDIR=%{buildroot} cmake --install build
%qore_install_aot_sources qlib
find %{buildroot}%{_libdir}/qore-modules -type f -name '*.qmod' -exec chmod 755 {} +
sed -i '1s|.*|#!/usr/bin/qore|' %{buildroot}%{_bindir}/qrepl
install -Dm644 debian/qrepl.1 %{buildroot}%{_mandir}/man1/qrepl.1
%if %{with docs}
install -d %{buildroot}%{_docdir}/%{name}-doc
cp -a build/docs %{buildroot}%{_docdir}/%{name}-doc/
install -d %{buildroot}%{_docdir}/%{name}-doc/examples/test
install -m644 test/*.qtest test/TestHarness.qc %{buildroot}%{_docdir}/%{name}-doc/examples/test/
hardlink -t -O %{buildroot}%{_docdir}/%{name}-doc
%endif
%check
%if %{with tests}
. %{_rpmconfigdir}/qore/module-env.sh
export TERM=xterm-256color
for test in test/*.qtest; do
  timeout 300 /usr/bin/qore -b --enable-debug \
    -l "$PWD/build/ncurses-api-$(/usr/bin/qore --latest-module-api).qmod" \
    -l "$PWD/build/qlib-qmod/NcursesReplUi.qmod" \
    -l "$PWD/build/qlib-qmod/NcursesUi/NcursesUi.qmod" "$test" -v
done
%if %{with docs}
python3 -B -W error test/test_docs.py build -v
%endif
%endif
%files
%license COPYING
%{_bindir}/qrepl
%{_mandir}/man1/qrepl.1*
%{_libdir}/qore-modules/ncurses-api-*.qmod
%{_libdir}/qore-modules/NcursesUi/
%{_datadir}/qore-modules/NcursesUi/
%dir %{_datadir}/qore/metadata/ncurses
%{_datadir}/qore/metadata/ncurses/*.meta.json
%{_libdir}/qore-modules/NcursesReplUi.qmod
%{_datadir}/qore-modules/NcursesReplUi.qm
%if %{with docs}
%files doc
%license COPYING
%doc %{_docdir}/%{name}-doc/
%endif
%changelog
* Thu Oct 01 2026 David Nichols <david@qore.org> - 2.0.0-1
- Package native and compiled UI modules, qrepl, documentation and headless tests.
