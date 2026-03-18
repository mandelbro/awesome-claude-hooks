#!/usr/bin/env bash
# TDD Reminder Hook — reminds about TDD when source files were written without test files.
# Runs on: Stop event. Checks a tracking file populated by tdd-tracker.sh (PostToolUse).
# No LLM, no JSON validation — pure deterministic check.

INPUT=$(cat)

# Check stop_hook_active to avoid loops
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
TRACKER="/tmp/claude-tdd-tracker-${SESSION_ID}"

# No tracker file means no source files were written this cycle
if [ ! -f "$TRACKER" ]; then
  exit 0
fi

# Read tracked files
SRC_FILES=$(grep '^SRC:' "$TRACKER" 2>/dev/null | sed 's/^SRC://' | sort -u)
TEST_FILES=$(grep '^TEST:' "$TRACKER" 2>/dev/null | sed 's/^TEST://' | sort -u)

# Count unique entries
if [ -n "$SRC_FILES" ]; then
  SRC_COUNT=$(echo "$SRC_FILES" | wc -l | tr -d ' ')
else
  SRC_COUNT=0
fi
if [ -n "$TEST_FILES" ]; then
  TEST_COUNT=$(echo "$TEST_FILES" | wc -l | tr -d ' ')
else
  TEST_COUNT=0
fi

# Clear tracker for next cycle
rm -f "$TRACKER"

# If source files were written but no test files, remind about TDD
if [ "$SRC_COUNT" -gt 0 ] && [ "$TEST_COUNT" -eq 0 ]; then
  echo "[TDD REMINDER] ${SRC_COUNT} source file(s) were written/edited this cycle but no test files were touched. Per TDD guidelines: write a failing test BEFORE implementation. Consider adding tests for the changes made."
fi

exit 0
