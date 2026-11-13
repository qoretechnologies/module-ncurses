#!/bin/sh
# Copyright (C) 2026 Qore Technologies, s.r.o.
# SPDX-License-Identifier: MIT
# Source before pending status/build/test commands. Adapted from qore commit
# 22a9b5c721. Returning runs the full job; exiting skips its already-tested work.

# Record this job's image fingerprint before anything is built or installed, in
# every job, so that a later pipeline can compare its image with this one. The
# image's environment file provides QORE_MODULE_DIR; a subshell keeps it local.
qore_tt_env_file=${QORE_CI_ENV_FILE:-/tmp/env.sh}
rm -f ci-environment.txt ci-environment.txt.tmp
if (if [ -r "$qore_tt_env_file" ]; then . "$qore_tt_env_file"; fi
        python3 "${QORE_CI_TOOLS_DIR:-test/docker_test}/ci-environment.py") > ci-environment.txt.tmp; then
    mv ci-environment.txt.tmp ci-environment.txt
else
    rm -f ci-environment.txt.tmp
    echo "the CI environment fingerprint is unavailable: running the full job"
    return 0
fi

# Upstream pipelines trigger develop pipelines (source "pipeline") after changing
# Qore; their image fingerprint decides whether this tree's result still applies.
case "${CI_PIPELINE_SOURCE:-}" in
    push|pipeline) ;;
    *) return 0 ;;
esac
if [ "${CI_COMMIT_BRANCH:-}" != develop ] \
        || [ "${QORE_CI_FORCE_FULL:-}" = 1 ] || [ "${QORE_TREE_TESTED_CHECKED:-}" != 1 ]; then
    return 0
fi
case "${CI_JOB_NAME:-}" in
    test-ubuntu) qore_tt_tested_env=${QORE_TREE_TESTED_ENV_TEST_UBUNTU:-} ;;
    test-alpine) qore_tt_tested_env=${QORE_TREE_TESTED_ENV_TEST_ALPINE:-} ;;
    *) return 0 ;;
esac
case "$qore_tt_tested_env" in
    ''|*[!0-9a-f]*) return 0 ;;
esac
if [ "${#qore_tt_tested_env}" -ne 64 ] \
        || [ "$(cat ci-environment.txt)" != "$qore_tt_tested_env" ]; then
    echo "the CI image differs from the one that tested this tree: running the full job"
    return 0
fi
case "${QORE_TREE_TESTED_IN:-}" in
    ''|*[!0-9]*|0) return 0 ;;
esac
case "${QORE_TREE_TESTED_SHA:-}" in
    ''|*[!0-9a-f]*) return 0 ;;
esac
if [ "${#QORE_TREE_TESTED_SHA}" -ne 40 ] && [ "${#QORE_TREE_TESTED_SHA}" -ne 64 ]; then
    return 0
fi
current_tree=$(git rev-parse 'HEAD^{tree}' 2>/dev/null) || return 0
if [ "${QORE_TREE_TESTED_IN}" = "${CI_PIPELINE_ID:-}" ] \
        || [ "${QORE_TREE_TESTED_TREE:-}" != "$current_tree" ] \
        || [ -z "${GITHUB_ACCESS_TOKEN:+set}" ] || [ -z "${CI_PROJECT_URL:-}" ] \
        || [ -z "${CI_COMMIT_SHA:-}" ] || [ -z "${REPO_NAME:-}" ]; then
    return 0
fi

tested_url="${CI_PROJECT_URL}/-/pipelines/${QORE_TREE_TESTED_IN}"
echo "this tree passed both platform jobs in pipeline ${QORE_TREE_TESTED_IN}: ${tested_url}"
# Never trace the credential. If the status cannot be published, run the full
# job so its normal status/reporting path remains responsible for the result.
set +x
if curl -fsS --max-time 30 \
        "https://api.github.com/repos/qoretechnologies/${REPO_NAME}/statuses/${CI_COMMIT_SHA}" \
        -X POST --oauth2-bearer "${GITHUB_ACCESS_TOKEN}" -H "Content-Type: application/json" \
        -d "{\"state\":\"success\",\"context\":\"${REPO_NAME}\",\"description\":\"tree tested in pipeline ${QORE_TREE_TESTED_IN}\",\"target_url\":\"${tested_url}\"}" \
        > /dev/null; then
    exit 0
fi
echo "could not publish the successful-tree status: running the full job"
