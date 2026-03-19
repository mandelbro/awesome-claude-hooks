#!/usr/bin/env bash
# TDD Tracker Hook — records whether source or test files are being written.
# Runs on: PostToolUse (Write|Edit|MultiEdit). Writes to a temp tracking file
# that tdd-reminder.sh reads on Stop to check TDD compliance.
# Format: TIMESTAMP:TYPE:PATH (e.g., 1710700000:SRC:src/auth/middleware.py)

source "$(dirname "$0")/lib/common.sh"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Nothing to track
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

TRACKER="/tmp/claude-tdd-tracker-${SESSION_ID}"
FILENAME=$(basename "$FILE_PATH")
TIMESTAMP=$(date +%s)

# Skip non-code files
case "$FILENAME" in
  *.md|*.txt|*.json|*.yaml|*.yml|*.toml|*.cfg|*.ini|*.lock|*.sh|*.env*)
    exit 0
    ;;
esac

# Classify as test or source file
case "$FILE_PATH" in
  *test*|*spec*|*__tests__*|*__mocks__*|*/tests/*|*/spec/*)
    echo "${TIMESTAMP}:TEST:${FILE_PATH}" >> "$TRACKER"
    ;;
  *.py|*.ts|*.tsx|*.js|*.jsx|*.rb|*.go|*.rs|*.java)
    echo "${TIMESTAMP}:SRC:${FILE_PATH}" >> "$TRACKER"
    ;;
esac

exit 0
