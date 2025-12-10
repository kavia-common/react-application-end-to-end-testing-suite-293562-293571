#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/react-application-end-to-end-testing-suite-293562-293571/playwright_test_suite"
cd "$WORKSPACE"
mkdir -p "$WORKSPACE/.validation" "$WORKSPACE/tests"
# Run build
bash ./.init/build.sh
# Start server
bash ./.init/start.sh
# Run tests
TEST_ERR=0
if ! bash ./.init/test.sh; then
  TEST_ERR=$?
fi
# Stop server regardless
bash ./.init/stop.sh || true
# Summarize
echo "test_exit=${TEST_ERR}" > "$WORKSPACE/.validation/validation_summary.txt"
if [ "$TEST_ERR" -ne 0 ]; then
  echo "Validation failed; see $WORKSPACE/.validation" >&2
  exit 1
fi
echo "Validation succeeded" > "$WORKSPACE/.validation/result.txt"
