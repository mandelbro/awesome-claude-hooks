#!/usr/bin/env bash
# Test runner for Claude Code hook tests.
# Discovers test_* functions from test-*.sh files and runs them.
# Usage: bash tests/run-tests.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC2034 # HOOKS_DIR is used by sourced test files
HOOKS_DIR="$(cd "$SCRIPT_DIR/../hooks" && pwd)"

PASS=0
FAIL=0
ERRORS=""

# --- Assert helpers (used by sourced test-*.sh files) ---

# shellcheck disable=SC2317,SC2329 # Invoked indirectly by sourced test files
assert_exit() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: ${label} (expected exit ${expected}, got ${actual})\n"
  fi
}

# shellcheck disable=SC2317,SC2329 # Invoked indirectly by sourced test files
assert_output_contains() {
  local needle="$1" haystack="$2" label="$3"
  if echo "$haystack" | grep -q "$needle"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: ${label} (expected output to contain '${needle}')\n"
  fi
}

# shellcheck disable=SC2317,SC2329 # Invoked indirectly by sourced test files
assert_output_not_contains() {
  local needle="$1" haystack="$2" label="$3"
  if echo "$haystack" | grep -q "$needle"; then
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: ${label} (expected output NOT to contain '${needle}')\n"
  else
    PASS=$((PASS + 1))
  fi
}

# --- Hook runner helper ---
# Runs a hook in a subshell so exit calls don't kill the runner.
# Usage: run_hook <hook_script> <fixture_file>
# Sets: RUN_EXIT (exit code), RUN_OUTPUT (combined stdout+stderr)
# shellcheck disable=SC2317,SC2329 # Invoked indirectly by sourced test files
run_hook() {
  local hook_script="$1"
  local fixture_file="$2"
  # shellcheck disable=SC2034 # RUN_OUTPUT and RUN_EXIT are read by sourced test files
  RUN_OUTPUT=$(bash "$hook_script" < "$fixture_file" 2>&1)
  # shellcheck disable=SC2034
  RUN_EXIT=$?
}

# --- Test discovery and execution ---

echo "=== Claude Code Hook Test Runner ==="
echo ""

FOUND_FILES=0

for test_file in "$SCRIPT_DIR"/test-*.sh; do
  # Handle case where no test files exist
  [ -f "$test_file" ] || continue

  FOUND_FILES=$((FOUND_FILES + 1))
  test_filename=$(basename "$test_file")
  echo "--- ${test_filename} ---"

  # Snapshot current functions
  BEFORE=$(declare -F | awk '{print $3}')

  # shellcheck source=/dev/null
  source "$test_file"

  # Find newly defined test_* functions
  AFTER=$(declare -F | awk '{print $3}')
  NEW_FUNCS=$(comm -13 <(echo "$BEFORE" | sort) <(echo "$AFTER" | sort) | grep '^test_')

  if [ -z "$NEW_FUNCS" ]; then
    echo "  (no test functions found)"
    continue
  fi

  # Run each discovered test function
  while IFS= read -r func; do
    echo -n "  ${func}: "
    if $func; then
      echo "ok"
    else
      echo "FAILED"
    fi
  done <<< "$NEW_FUNCS"

  echo ""
done

# --- Summary ---

echo "=== Results ==="
echo "Files: ${FOUND_FILES}, Passed: ${PASS}, Failed: ${FAIL}"

if [ -n "$ERRORS" ]; then
  echo ""
  echo "=== Failures ==="
  echo -e "$ERRORS"
fi

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
