#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/react-application-end-to-end-testing-suite-293562-293571/playwright_test_suite"
cd "$WORKSPACE"
mkdir -p "$WORKSPACE/.validation" "$WORKSPACE/tests"
# BUILD: prefer npm ci when package-lock.json exists
if [ -f package-lock.json ]; then
  npm ci --no-audit --no-fund --silent --no-progress 2>&1 | tee "$WORKSPACE/.validation/npm_ci.log"
else
  npm i --no-audit --no-fund --silent --no-progress 2>&1 | tee "$WORKSPACE/.validation/npm_install.log"
fi
