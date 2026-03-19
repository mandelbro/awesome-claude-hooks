#!/usr/bin/env bash
# uninstall.sh — Remove Claude Code user hooks from ~/.claude/hooks/
# Usage: bash uninstall.sh [--dry-run]
set -euo pipefail

TARGET_DIR="$HOME/.claude/hooks"
TARGET_LIB="$TARGET_DIR/lib"
SETTINGS_FILE="$HOME/.claude/settings.json"

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      echo "Usage: bash uninstall.sh [--dry-run]"
      exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

info() { echo "[uninstall] $*"; }
dry()  { if $DRY_RUN; then info "(dry-run) $*"; return 0; else return 1; fi; }

KNOWN_HOOKS=(commit-format-check.sh file-org-check.sh file-size-check.sh
  guidelines-reminder.sh hook-health-check.sh memory-nudge.sh
  memory-ops-confirm.sh pre-compact-guidelines.sh secrets-check.sh
  tdd-reminder.sh tdd-tracker.sh)

# --- Remove known hook files ---
REMOVED=0
for hook in "${KNOWN_HOOKS[@]}"; do
  [ -f "$TARGET_DIR/$hook" ] || continue
  if ! dry "Would remove $TARGET_DIR/$hook"; then rm "$TARGET_DIR/$hook"; REMOVED=$((REMOVED + 1)); fi
done
info "Removed $REMOVED hook files."

# --- Remove lib/common.sh and empty lib/ ---
[ -f "$TARGET_LIB/common.sh" ] && { dry "Would remove $TARGET_LIB/common.sh" || rm "$TARGET_LIB/common.sh"; }
if [ -d "$TARGET_LIB" ] && [ -z "$(ls -A "$TARGET_LIB" 2>/dev/null)" ]; then
  dry "Would remove empty $TARGET_LIB" || rmdir "$TARGET_LIB"
fi

# --- Step 3: Remove hook entries from settings.json ---
if [ -f "$SETTINGS_FILE" ] && command -v jq &>/dev/null; then
  # Check if hooks key exists
  if jq -e '.hooks' "$SETTINGS_FILE" &>/dev/null; then
    info "Removing hook entries from $SETTINGS_FILE..."
    if $DRY_RUN; then
      info "(dry-run) Would remove .hooks entries matching ~/.claude/hooks/"
    else
      TMP_SETTINGS="$(mktemp)"
      # Remove any hook command entries that reference our hooks directory
      jq 'walk(
        if type == "array" then
          map(
            if type == "object" and .hooks then
              .hooks |= map(select(.command | test("~/.claude/hooks/") | not))
            else . end
          )
          | map(if type == "object" and .hooks and (.hooks | length) == 0 then empty else . end)
        else . end
      )
      | if .hooks then
          .hooks |= with_entries(select(.value | length > 0))
        else . end
      | if .hooks and (.hooks | length) == 0 then del(.hooks) else . end' \
        "$SETTINGS_FILE" > "$TMP_SETTINGS" 2>/dev/null

      if jq empty "$TMP_SETTINGS" 2>/dev/null; then
        mv "$TMP_SETTINGS" "$SETTINGS_FILE"
        info "Hook entries removed from settings.json."
      else
        rm -f "$TMP_SETTINGS"
        info "WARNING: Could not clean settings.json. Manual removal may be needed."
      fi
    fi
  else
    info "No hooks section found in settings.json."
  fi
else
  info "Skipping settings.json cleanup (file not found or jq not available)."
fi

# --- Summary ---
echo ""
echo "=== Uninstall Summary ==="
echo "  Hook files removed: $REMOVED"
echo "  Backups preserved:  $TARGET_DIR/backup/ (if present)"
echo "  Custom hooks:       Preserved (only known hooks were removed)"
if $DRY_RUN; then
  echo "  (dry-run mode — no changes were made)"
fi
echo "Done."
