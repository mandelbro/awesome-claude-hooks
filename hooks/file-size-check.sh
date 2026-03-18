#!/usr/bin/env bash
# File Size Check Hook — warns when edited/written files exceed size guidelines.
# Runs on: PostToolUse (Write|Edit|MultiEdit)
# Outputs warning to stdout (enters Claude's context). Never blocks (PostToolUse can't undo).

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# No file path — nothing to check
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Skip generated/vendored files
case "$FILE_PATH" in
  *.lock|*.min.*|*/node_modules/*|*/dist/*|*/.git/*|*/vendor/*|*/__pycache__/*)
    exit 0
    ;;
esac

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

LINE_COUNT=$(wc -l < "$FILE_PATH" 2>/dev/null | tr -d ' ')

if [ -z "$LINE_COUNT" ]; then
  exit 0
fi

if [ "$LINE_COUNT" -gt 1000 ]; then
  echo "[FILE SIZE VIOLATION] $FILE_PATH is $LINE_COUNT lines (HARD LIMIT: 1000). This file MUST be split immediately. Extract utilities, separate concerns, or create sub-modules."
elif [ "$LINE_COUNT" -gt 500 ]; then
  echo "[FILE SIZE WARNING] $FILE_PATH is $LINE_COUNT lines (target: 100-500). Evaluate for splitting: extract utility functions, move related classes to dedicated modules, or separate concerns into logical boundaries."
elif [ "$LINE_COUNT" -gt 400 ]; then
  echo "[FILE SIZE NOTE] $FILE_PATH is $LINE_COUNT lines — approaching the 500-line target. Consider splitting opportunities if adding more code."
fi

exit 0
