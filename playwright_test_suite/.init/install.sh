#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/react-application-end-to-end-testing-suite-293562-293571/playwright_test_suite"
cd "$WORKSPACE"
mkdir -p "$WORKSPACE/.validation"
# record node/npm early
node -v > "$WORKSPACE/.validation/node_version.txt" 2>&1 || true
npm --version > "$WORKSPACE/.validation/npm_version.txt" 2>&1 || true
# Node major check
NODE_MAJOR=$(node -v | sed -E 's/v([0-9]+).*/\1/' 2>/dev/null || echo 0)
if [ "${NODE_MAJOR:-0}" -lt 16 ]; then
  echo "WARNING: Node <16 detected ($(node -v)). Playwright may require newer Node. Proceeding but tests may fail." > "$WORKSPACE/.validation/node_warning.txt"
fi
# Ensure package.json exists
[ -f package.json ] || (echo "ERROR: package.json missing in $WORKSPACE" >&2; exit 20)
# Decide packages
PLAYWRIGHT_PKG=${PLAYWRIGHT_VERSION:-"playwright"}
if [ "${PLAYWRIGHT_ONLY:-0}" = "1" ]; then
  PLAYWRIGHT_TEST_PKG=""
else
  PLAYWRIGHT_TEST_PKG=${PLAYWRIGHT_TEST_VERSION:-"@playwright/test"}
fi
# EXTRA_DEPS when TypeScript config present
EXTRA_DEPS=()
if [ -f tsconfig.json ]; then
  EXTRA_DEPS+=(typescript ts-node)
fi
# Prefer npm ci for reproducible installs
if [ -f package-lock.json ]; then
  npm ci --no-audit --no-fund --silent --no-progress 2>&1 | tee "$WORKSPACE/.validation/npm_ci.log"
else
  ARGS=("-D" "--no-audit" "--no-fund" "--silent" "--no-progress")
  ARGS+=("$PLAYWRIGHT_PKG")
  [ -n "${PLAYWRIGHT_TEST_PKG}" ] && ARGS+=("$PLAYWRIGHT_TEST_PKG")
  if [ "${#EXTRA_DEPS[@]}" -gt 0 ]; then
    for d in "${EXTRA_DEPS[@]}"; do ARGS+=("$d"); done
  fi
  npm i "${ARGS[@]}" 2>&1 | tee "$WORKSPACE/.validation/npm_install.log"
fi
# Record package.json deps and top-level npm ls
node -e "try{const p=require('./package.json'); console.log(JSON.stringify(p.dependencies||{},null,2)); console.log(JSON.stringify(p.devDependencies||{},null,2));}catch(e){console.error(e.message)}" > "$WORKSPACE/.validation/package_json_deps.txt" 2>&1 || true
npm ls --depth=0 2>/dev/null > "$WORKSPACE/.validation/npm_ls_top.txt" || true
# Determine playwright command: prefer npx, else local bin
if command -v npx >/dev/null 2>&1; then
  PLAYWRIGHT_CMD=(npx playwright)
else
  PLAYWRIGHT_CMD=("$WORKSPACE/node_modules/.bin/playwright")
fi
# Source persisted env if exists
[ -f /etc/profile.d/playwright_env.sh ] && source /etc/profile.d/playwright_env.sh || true
export PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-0}
# Run playwright install for chromium and log
"${PLAYWRIGHT_CMD[@]}" install chromium 2>&1 | tee "$WORKSPACE/.validation/playwright_install.log"
# Validate browser binaries across common cache locations
: > "$WORKSPACE/.validation/playwright_browser_dirs.txt" || true
# check node_modules cache
if [ -d "$WORKSPACE/node_modules/.cache/ms-playwright" ]; then
  find "$WORKSPACE/node_modules/.cache/ms-playwright" -maxdepth 4 -type d -name "*chromium*" -print >> "$WORKSPACE/.validation/playwright_browser_dirs.txt" || true
fi
# check home cache
if [ -d "$HOME/.cache/ms-playwright" ]; then
  find "$HOME/.cache/ms-playwright" -maxdepth 4 -type d -name "*chromium*" -print >> "$WORKSPACE/.validation/playwright_browser_dirs.txt" || true
fi
# check workspace-level cache
if [ -d "$WORKSPACE/.cache/ms-playwright" ]; then
  find "$WORKSPACE/.cache/ms-playwright" -maxdepth 4 -type d -name "*chromium*" -print >> "$WORKSPACE/.validation/playwright_browser_dirs.txt" || true
fi
# If PLAYWRIGHT_BROWSERS_PATH is a directory, record it
if [ "${PLAYWRIGHT_BROWSERS_PATH}" != "0" ] && [ -d "${PLAYWRIGHT_BROWSERS_PATH}" ]; then
  echo "${PLAYWRIGHT_BROWSERS_PATH}" >> "$WORKSPACE/.validation/playwright_browser_dirs.txt" || true
fi
# Final validation: require at least one discovered path
if [ ! -s "$WORKSPACE/.validation/playwright_browser_dirs.txt" ]; then
  echo "ERROR: browser binaries not found in expected cache locations; see $WORKSPACE/.validation/playwright_install.log" >&2
  exit 21
fi
# Record installed playwright versions
(npm ls playwright --depth=0 2>/dev/null || true) > "$WORKSPACE/.validation/playwright_version.txt"
(npm ls @playwright/test --depth=0 2>/dev/null || true) > "$WORKSPACE/.validation/playwright_test_version.txt"
# Ensure logs are readable
chmod -R a+r "$WORKSPACE/.validation" || true
