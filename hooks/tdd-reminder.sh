#!/usr/bin/env bash
# TDD Reminder Hook — reminds about TDD when source files were written without test files.
# Runs on: Stop event. Uses a rolling 30-minute window instead of clearing every stop.
# Tracker format: TIMESTAMP:TYPE:PATH
# No LLM, no JSON validation — pure deterministic check.

source "$(dirname "$0")/lib/common.sh"
parse_input || exit 0
guard_stop_loop

TRACKER=$(session_tmp "tdd-tracker")

# No tracker file means no source files were written this cycle
if [ ! -f "$TRACKER" ]; then
  exit 0
fi

# Rolling window: prune entries older than 30 minutes (1800 seconds)
NOW=$(date +%s)
CUTOFF=$((NOW - 1800))

# Filter entries within the rolling window
RECENT_ENTRIES=""
while IFS= read -r line; do
  # Parse TIMESTAMP:TYPE:PATH format
  ENTRY_TS=$(echo "$line" | cut -d: -f1)
  # Handle legacy format (TYPE:PATH without timestamp) — treat as current
  if ! echo "$ENTRY_TS" | grep -qE '^[0-9]+$'; then
    RECENT_ENTRIES="${RECENT_ENTRIES}${line}"$'\n'
    continue
  fi
  if [ "$ENTRY_TS" -ge "$CUTOFF" ] 2>/dev/null; then
    RECENT_ENTRIES="${RECENT_ENTRIES}${line}"$'\n'
  fi
done < "$TRACKER"

# If no recent entries remain, remove tracker and exit
if [ -z "$RECENT_ENTRIES" ]; then
  rm -f "$TRACKER"
  exit 0
fi

# Write back only recent entries
printf '%s' "$RECENT_ENTRIES" > "$TRACKER"

# Extract types from recent entries (handle both TIMESTAMP:TYPE:PATH and TYPE:PATH)
SRC_FILES=$(echo "$RECENT_ENTRIES" | grep -E '(^[0-9]+:SRC:|^SRC:)' | sort -u)
TEST_FILES=$(echo "$RECENT_ENTRIES" | grep -E '(^[0-9]+:TEST:|^TEST:)' | sort -u)

# Count unique entries
if [ -n "$SRC_FILES" ]; then
  SRC_COUNT=$(echo "$SRC_FILES" | grep -c .)
else
  SRC_COUNT=0
fi
if [ -n "$TEST_FILES" ]; then
  TEST_COUNT=$(echo "$TEST_FILES" | grep -c .)
else
  TEST_COUNT=0
fi

# If both source AND test files present in window, cycle is complete — clear tracker
if [ "$SRC_COUNT" -gt 0 ] && [ "$TEST_COUNT" -gt 0 ]; then
  rm -f "$TRACKER"
  exit 0
fi

# If only source files, emit reminder but DO NOT clear tracker
if [ "$SRC_COUNT" -gt 0 ] && [ "$TEST_COUNT" -eq 0 ]; then
  echo "[TDD REMINDER] ${SRC_COUNT} source file(s) were written/edited this cycle but no test files were touched. Per TDD guidelines: write a failing test BEFORE implementation. Consider adding tests for the changes made."
fi

exit 0
