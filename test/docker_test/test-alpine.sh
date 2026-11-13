#!/bin/bash

set -e
set -x

ENV_FILE=/tmp/env.sh

. ${ENV_FILE}

# setup MODULE_SRC_DIR env var
cwd=`pwd`
if [ -z "${MODULE_SRC_DIR}" ]; then
    if [ -e "$cwd/src/ncurses-internal.cpp" ]; then
        MODULE_SRC_DIR=$cwd
    else
        MODULE_SRC_DIR=$WORKDIR/module-ncurses
    fi
fi
echo "export MODULE_SRC_DIR=${MODULE_SRC_DIR}" >> ${ENV_FILE}

echo "export QORE_UID=1000" >> ${ENV_FILE}
echo "export QORE_GID=1000" >> ${ENV_FILE}

. ${ENV_FILE}

export MAKE_JOBS=4

python3 "${MODULE_SRC_DIR}/test/test_tree_tested.py"
python3 "${MODULE_SRC_DIR}/test/test_ci_environment.py"
# tree-tested-skip.sh falls back to a full job when the image cannot be fingerprinted;
# fail visibly instead, because successful-tree reuse could then never apply.
python3 "${MODULE_SRC_DIR}/test/docker_test/ci-environment.py"

# build module and install
echo && echo "-- building module --"
mkdir -p ${MODULE_SRC_DIR}/build
cd ${MODULE_SRC_DIR}/build
cmake .. -DCMAKE_BUILD_TYPE=debug -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX}
make -j${MAKE_JOBS}
make install

# add Qore user and group
if ! grep -q "^qore:x:${QORE_GID}" /etc/group; then
    addgroup -g ${QORE_GID} qore
fi
if ! grep -q "^qore:x:${QORE_UID}" /etc/passwd; then
    adduser -u ${QORE_UID} -D -G qore -h /home/qore -s /bin/bash qore
fi

# own everything by the qore user
chown -R qore:qore ${MODULE_SRC_DIR}

# run the tests — continue on failure so all test files run
export QORE_MODULE_DIR=${MODULE_SRC_DIR}/qlib:${MODULE_SRC_DIR}/build:${QORE_MODULE_DIR}
cd ${MODULE_SRC_DIR}
FAILED=0
# the tests must load the modules that this job built, not the copies that the image already has
${MODULE_SRC_DIR}/test/docker_test/check-loaded-modules.sh ${MODULE_SRC_DIR}/build gosu qore:qore

for test in test/*.qtest; do
    if ! gosu qore:qore qore --enable-debug --warnings-are-errors $test -vv; then
        echo "FAILED: $test"
        FAILED=1
    fi
done

# Registry/catalog drift and actual gallery CLI coverage share the native fixtures.
if ! gosu qore:qore python3 test/test_widget_catalog.py build; then
    FAILED=1
fi

# ... and they still do once the tests have run
${MODULE_SRC_DIR}/test/docker_test/check-loaded-modules.sh ${MODULE_SRC_DIR}/build gosu qore:qore
exit $FAILED
