#!/usr/bin/env bash
# Health Check Hook — validates hook environment on session start.
# Runs on: SessionStart. Always exits 0 (cannot block).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

parse_input || true  # SessionStart cannot block; continue even on parse failure

ERRORS=""

# Check dependencies
if ! command -v jq &>/dev/null; then
  ERRORS="${ERRORS}\n- jq is not installed (brew install jq / apt-get install jq)"
fi
if ! command -v wc &>/dev/null; then
  ERRORS="${ERRORS}\n- wc is not available"
fi
BASH_MAJOR="${BASH_VERSINFO[0]:-0}"
BASH_MINOR="${BASH_VERSINFO[1]:-0}"
if [ "$BASH_MAJOR" -lt 3 ] || { [ "$BASH_MAJOR" -eq 3 ] && [ "$BASH_MINOR" -lt 2 ]; }; then
  ERRORS="${ERRORS}\n- bash 3.2+ required (found ${BASH_VERSION:-unknown})"
fi

# Validate hook scripts
HOOK_COUNT=0
for script in "$SCRIPT_DIR"/*.sh; do
  [ -f "$script" ] || continue
  [ "$(basename "$script")" = "hook-health-check.sh" ] && continue
  HOOK_COUNT=$((HOOK_COUNT + 1))
  if [ ! -x "$script" ]; then
    ERRORS="${ERRORS}\n- $(basename "$script") is not executable (chmod +x)"
  fi
done

# Validate shared library
if [ ! -r "$SCRIPT_DIR/lib/common.sh" ]; then
  ERRORS="${ERRORS}\n- lib/common.sh is missing or not readable"
fi

# Clean up stale temp files
cleanup_stale_temps

if [ -n "$ERRORS" ]; then
  echo "[HOOK HEALTH] Issues detected:${ERRORS}"
else
  echo "[HOOK HEALTH] All ${HOOK_COUNT} hooks validated. Dependencies OK."
fi

exit 0
