#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/react-application-end-to-end-testing-suite-293562-293571/playwright_test_suite"
cd "$WORKSPACE"
mkdir -p "$WORKSPACE/.validation" "$WORKSPACE/tests"
# Read port
if [ -f "$WORKSPACE/.validation/server.port" ]; then
  PORT=$(cat "$WORKSPACE/.validation/server.port")
else
  echo "ERROR: server.port not found; run start first" >&2
  exit 40
fi
# Create test targeting local server (uses @playwright/test if installed)
if npm ls @playwright/test --depth=0 >/dev/null 2>&1; then
  cat > "$WORKSPACE/tests/local.spec.js" <<'JS'
const { test, expect } = require('@playwright/test');
test('local server responds', async ({ page }) => {
  await page.goto('http://localhost:PORT_PLACEHOLDER');
  await expect(page).toHaveTitle(/Playwright local server/i);
});
JS
  sed -i "s/PORT_PLACEHOLDER/${PORT}/g" "$WORKSPACE/tests/local.spec.js"
  TEST_CMD=(npx playwright test --reporter=list)
else
  cat > "$WORKSPACE/tests/local_basic.js" <<'JS'
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('http://localhost:PORT_PLACEHOLDER');
  console.log('title:', await page.title());
  await browser.close();
})();
JS
  sed -i "s/PORT_PLACEHOLDER/${PORT}/g" "$WORKSPACE/tests/local_basic.js"
  # Use node to run the simple script if playwright test runner not present
  TEST_CMD=(node "$WORKSPACE/tests/local_basic.js")
fi
# Ensure env present and exported in this shell
[ -f /etc/profile.d/playwright_env.sh ] && source /etc/profile.d/playwright_env.sh || true
export PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-0}
# Run tests and capture logs
(
  set -o pipefail
  "${TEST_CMD[@]}" 2>&1 | tee "$WORKSPACE/.validation/validation_playwright_run.log"
)
TEST_EXIT=${PIPESTATUS[0]:-0}
# Record exit code
echo "$TEST_EXIT" > "$WORKSPACE/.validation/validation_test_exit_code.txt"
if [ "$TEST_EXIT" -ne 0 ]; then
  echo "Validation tests failed; see $WORKSPACE/.validation" >&2
  exit 32
fi
