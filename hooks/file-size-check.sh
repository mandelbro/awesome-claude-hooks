#!/usr/bin/env bash
# File Size Check Hook — warns when edited/written files exceed size guidelines.
# Runs on: PostToolUse (Write|Edit|MultiEdit). Never blocks.
source "$(dirname "$0")/lib/common.sh"
parse_input || exit 0

[ -z "$HOOK_FILE_PATH" ] && exit 0

# Skip generated/vendored files
case "$HOOK_FILE_PATH" in
  *.lock|*.min.*|*/node_modules/*|*/dist/*|*/.git/*|*/vendor/*|*/__pycache__/*) exit 0 ;;
esac

[ ! -f "$HOOK_FILE_PATH" ] && exit 0

LINE_COUNT=$(wc -l < "$HOOK_FILE_PATH" 2>/dev/null | tr -d ' ')
[ -z "$LINE_COUNT" ] && exit 0

FILE_TYPE=$(classify_file "$HOOK_FILE_PATH")

if [ "$LINE_COUNT" -gt 1000 ]; then
  echo "[FILE SIZE VIOLATION] $HOOK_FILE_PATH ($FILE_TYPE) is $LINE_COUNT lines (HARD LIMIT: 1000). This file MUST be split immediately."
elif [ "$LINE_COUNT" -gt 500 ]; then
  echo "[FILE SIZE WARNING] $HOOK_FILE_PATH ($FILE_TYPE) is $LINE_COUNT lines (target: 100-500). Evaluate for splitting."
elif [ "$LINE_COUNT" -gt 400 ]; then
  echo "[FILE SIZE NOTE] $HOOK_FILE_PATH ($FILE_TYPE) is $LINE_COUNT lines — approaching the 500-line target."
fi

exit 0
