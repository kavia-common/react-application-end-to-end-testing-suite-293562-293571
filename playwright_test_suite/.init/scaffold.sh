#!/usr/bin/env bash
set -euo pipefail
# scaffold minimal Playwright project files (idempotent)
WORKSPACE="/home/kavia/workspace/code-generation/react-application-end-to-end-testing-suite-293562-293571/playwright_test_suite"
mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
# detect node early to avoid engine mismatches
NODE_VER=$(node -v 2>/dev/null || echo "v0")
NODE_MAJOR=$(echo "$NODE_VER" | sed -E 's/v([0-9]+).*/\1/')
# create package.json only if missing
if [ ! -f package.json ]; then
  if [ "${NODE_MAJOR:-0}" -ge 10 ]; then
    cat > package.json <<'JSON'
{
  "name": "playwright_test_suite",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "test": "playwright test",
    "playwright:install": "npx playwright install chromium"
  }
}
JSON
  else
    cat > package.json <<'JSON'
{ "name": "playwright_test_suite", "version": "0.1.0", "private": true, "scripts": { "test": "playwright test", "playwright:install": "npx playwright install chromium" } }
JSON
  fi
fi
# Decide runner: default to @playwright/test unless PLAYWRIGHT_ONLY=1
USE_PLAYWRIGHT_TEST=1
if [ "${PLAYWRIGHT_ONLY:-0}" = "1" ]; then USE_PLAYWRIGHT_TEST=0; fi
# Only use TS if tsconfig.json already exists
USE_TS=0
if [ -f "$WORKSPACE/tsconfig.json" ]; then USE_TS=1; fi
mkdir -p "$WORKSPACE/tests"
if [ "$USE_PLAYWRIGHT_TEST" -eq 1 ]; then
  if [ "$USE_TS" -eq 1 ]; then
    # ensure a minimal tsconfig exists
    [ -f "$WORKSPACE/tsconfig.json" ] || cat > "$WORKSPACE/tsconfig.json" <<'TS'
{
  "compilerOptions": { "target": "ES2019", "module": "commonjs", "esModuleInterop": true }
}
TS
    cat > "$WORKSPACE/tests/example.spec.ts" <<'TS'
import { test, expect } from '@playwright/test';

test('example dot com loads', async ({ page }) => {
  await page.goto('https://example.com');
  await expect(page).toHaveTitle(/Example Domain/i);
});
TS
  else
    cat > "$WORKSPACE/tests/example.spec.js" <<'JS'
const { test, expect } = require('@playwright/test');

test('example dot com loads', async ({ page }) => {
  await page.goto('https://example.com');
  await expect(page).toHaveTitle(/Example Domain/i);
});
JS
  fi
else
  cat > "$WORKSPACE/tests/example_basic.js" <<'JS'
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('https://example.com');
  console.log('title:', await page.title());
  await browser.close();
})();
JS
fi
# playwright.config.js: explicit headless unless DISPLAY indicates a GUI
cat > "$WORKSPACE/playwright.config.js" <<'JS'
const headless = (typeof process.env.DISPLAY === 'undefined' || process.env.DISPLAY === '') ? true : false;
module.exports = {
  timeout: 30 * 1000,
  expect: { timeout: 5000 },
  testDir: './tests',
  use: {
    headless,
    launchOptions: { args: ['--no-sandbox','--disable-dev-shm-usage','--disable-gpu'] },
    env: { DISPLAY: process.env.DISPLAY }
  },
  projects: [{ name: 'chromium', use: { browserName: 'chromium' } }]
};
JS
# ensure .validation exists for future steps
mkdir -p .validation
# output minimal confirmation
printf "scaffolded: %s\n" "$WORKSPACE"
