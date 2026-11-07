#!/bin/bash
# Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
# Runs inside the existing Ubuntu job; Chromium's glibc runtime is not an Alpine target.
set -euo pipefail
module_dir=$(cd "$(dirname "$0")/../.." && pwd)
node_dir=$(mktemp -d /tmp/ncurses-review-node.XXXXXX)
chmod 755 "$node_dir"
archive=node-v24.11.1-linux-x64.tar.xz
curl --fail --location --silent --show-error "https://nodejs.org/dist/v24.11.1/$archive" --output "$node_dir/$archive"
echo "60e3b0a8500819514aca603487c254298cd776de0698d3cd08f11dba5b8289a8  $node_dir/$archive" | sha256sum --check --status
tar -xJf "$node_dir/$archive" -C "$node_dir"
export PATH="$node_dir/node-v24.11.1-linux-x64/bin:$PATH"
export NCURSES_BUILD_DIR="$module_dir/build"
export PLAYWRIGHT_BROWSERS_PATH=/tmp/ncurses-review-browsers
export CI=true
cd "$module_dir/review"
gosu qore:qore npm ci --no-audit --no-fund
# Native packages are installed as root; builds/tests and the local bridge run unprivileged.
node node_modules/playwright/cli.js install --with-deps chromium
gosu qore:qore npm run build
gosu qore:qore npm test
gosu qore:qore npm run review
