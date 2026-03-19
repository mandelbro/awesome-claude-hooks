#!/usr/bin/env bash
# TDD Tracker Hook — records whether source or test files are being written.
# Runs on: PostToolUse (Write|Edit|MultiEdit). Writes to a temp tracking file
# that tdd-reminder.sh reads on Stop to check TDD compliance.
# Format: TIMESTAMP:TYPE:PATH (e.g., 1710700000:SRC:src/auth/middleware.py)

source "$(dirname "$0")/lib/common.sh"
parse_input || exit 0

[ -z "$HOOK_FILE_PATH" ] && exit 0

TRACKER=$(session_tmp "tdd-tracker")
TIMESTAMP=$(date +%s)

# Use classify_file to determine file type
FILE_TYPE=$(classify_file "$HOOK_FILE_PATH")

case "$FILE_TYPE" in
  test)
    echo "${TIMESTAMP}:TEST:${HOOK_FILE_PATH}" >> "$TRACKER"
    ;;
  source)
    echo "${TIMESTAMP}:SRC:${HOOK_FILE_PATH}" >> "$TRACKER"
    ;;
  # config/other — not tracked for TDD purposes
esac

exit 0
