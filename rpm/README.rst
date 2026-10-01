RPM packaging
=============

Copyright 2026 Qore Technologies, s.r.o.

The canonical qore-ncurses-module.spec supports Fedora, Enterprise Linux and
openSUSE. It requires the Qore 3.0 SDK and qore-rpm-macros from the same repository.
The default build includes module tests and a separate documentation package.
Dependencies on the installed Qore ABI and SDK version are generated from the
built module; do not replace them with an unversioned qore dependency.

Prepare a pinned source bundle with qore-packaging, then build it in the target
distribution with networking disabled::

    python3 tools/packaging.py prepare --repo ../module-ncurses --ref COMMIT \
      --name qore-ncurses-module --version 2.0.0 \
      --spec qore-ncurses-module.spec --output work/ncurses-source
    python3 tools/build-local.py --source work/ncurses-source \
      --image TARGET_SDK_IMAGE --output results/ncurses-build --jobs 2

These commands run from the qore-packaging repository. Source preparation uses
the committed tree. Install the SDK's language documentation index for complete
Doxygen cross-references. --without docs and --without tests are available for
local diagnosis; repository qualification uses the defaults and also runs the
suite against installed RPMs outside the checkout. Native modules retain the
distribution's normal ELF stripping and separate debug packages.

The package includes the native module, both compiled UI modules and their
source fallbacks, metadata, qrepl and its manual page. Terminal definitions are
required. The build uses magic so file-type detection is compiled in. Compiled code
references its symbols, so the RPM requires magic even though source-only
NcursesUi can run without it.

All eleven headless PTY suites run with debugging enabled. Strict Doxygen and
HTML checks verify public widget pages and links to sibling modules and the
QoreHistory SDK index. Examples retain test/TestHarness.qc beside the tests.
Run rpm/tests-installed/runtime from a source bundle after installing the RPMs,
with QORE_RPM_TEST_TMP set to a fresh writable directory outside the checkout.
