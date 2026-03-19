#!/usr/bin/env bash
# install.sh — Install Claude Code user hooks to ~/.claude/hooks/
# Usage: bash install.sh [--force] [--dry-run] [--hooks-only]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.claude/hooks"
TARGET_LIB="$TARGET_DIR/lib"
SETTINGS_FILE="$HOME/.claude/settings.json"
HOOKS_SRC="$SCRIPT_DIR/hooks"
CONFIG_SRC="$SCRIPT_DIR/config/settings-hooks.json"

FORCE=false
DRY_RUN=false
HOOKS_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --force)      FORCE=true ;;
    --dry-run)    DRY_RUN=true ;;
    --hooks-only) HOOKS_ONLY=true ;;
    -h|--help)
      echo "Usage: bash install.sh [--force] [--dry-run] [--hooks-only]"
      echo "  --force       Overwrite existing hooks without prompting"
      echo "  --dry-run     Show what would be done without making changes"
      echo "  --hooks-only  Install hooks only; skip settings.json merge"
      exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

info()  { echo "[install] $*"; }
warn()  { echo "[install] WARNING: $*" >&2; }
error() { echo "[install] ERROR: $*" >&2; exit 1; }
dry()   { if $DRY_RUN; then info "(dry-run) $*"; return 0; else return 1; fi; }

# --- Step 1: Validate prerequisites ---
info "Checking prerequisites..."
command -v jq &>/dev/null || error "jq is required but not installed. Install: brew install jq"

BASH_MAJOR="${BASH_VERSINFO[0]:-0}"
BASH_MINOR="${BASH_VERSINFO[1]:-0}"
if [ "$BASH_MAJOR" -lt 3 ] || { [ "$BASH_MAJOR" -eq 3 ] && [ "$BASH_MINOR" -lt 2 ]; }; then
  error "bash 3.2+ required (found ${BASH_VERSION:-unknown})"
fi

[ -d "$HOOKS_SRC" ] || error "hooks/ directory not found at $HOOKS_SRC"
[ -f "$CONFIG_SRC" ] || error "config/settings-hooks.json not found at $CONFIG_SRC"
jq empty "$CONFIG_SRC" 2>/dev/null || error "config/settings-hooks.json is invalid JSON"

info "Prerequisites OK."

# --- Step 2: Create target directories ---
if ! dry "Would create $TARGET_DIR and $TARGET_LIB"; then
  mkdir -p "$TARGET_DIR" "$TARGET_LIB"
  info "Created $TARGET_DIR"
fi

# --- Step 3: Backup existing hooks ---
BACKUP_DIR=""
if [ -d "$TARGET_DIR" ] && ls "$TARGET_DIR"/*.sh &>/dev/null 2>&1; then
  TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="$TARGET_DIR/backup/$TIMESTAMP"
  if ! dry "Would backup existing hooks to $BACKUP_DIR"; then
    mkdir -p "$BACKUP_DIR"
    for f in "$TARGET_DIR"/*.sh; do
      [ -f "$f" ] && cp "$f" "$BACKUP_DIR/"
    done
    [ -f "$TARGET_LIB/common.sh" ] && cp "$TARGET_LIB/common.sh" "$BACKUP_DIR/"
    info "Backed up existing hooks to $BACKUP_DIR"
  fi
fi

# --- Step 4: Copy hook scripts ---
COPIED=0
for script in "$HOOKS_SRC"/*.sh; do
  [ -f "$script" ] || continue
  dest="$TARGET_DIR/$(basename "$script")"
  if [ -f "$dest" ] && ! $FORCE && ! $DRY_RUN; then
    read -r -p "[install] Overwrite $(basename "$script")? [y/N] " answer
    [[ "$answer" =~ ^[Yy] ]] || { info "Skipping $(basename "$script")"; continue; }
  fi
  if ! dry "Would copy $(basename "$script") -> $dest"; then
    cp "$script" "$dest"
    chmod +x "$dest"
    COPIED=$((COPIED + 1))
  fi
done

# Copy lib/common.sh
if [ -f "$HOOKS_SRC/lib/common.sh" ]; then
  if ! dry "Would copy lib/common.sh -> $TARGET_LIB/common.sh"; then
    cp "$HOOKS_SRC/lib/common.sh" "$TARGET_LIB/common.sh"
    chmod +x "$TARGET_LIB/common.sh"
    COPIED=$((COPIED + 1))
  fi
fi

info "Copied $COPIED files."

# --- Step 5: Merge settings.json ---
SETTINGS_MERGED=false
if ! $HOOKS_ONLY; then
  info "Merging hook configuration into $SETTINGS_FILE..."

  if $DRY_RUN; then
    info "(dry-run) Would merge config/settings-hooks.json into $SETTINGS_FILE"
    SETTINGS_MERGED=true
  else
    # Ensure settings file exists
    if [ ! -f "$SETTINGS_FILE" ]; then
      echo '{}' > "$SETTINGS_FILE"
    fi

    # Backup current settings
    SETTINGS_BACKUP="${SETTINGS_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$SETTINGS_FILE" "$SETTINGS_BACKUP"

    # Atomic merge: append new hook entries per lifecycle event (preserves existing)
    TMP_SETTINGS="$(mktemp)"
    if jq -s '.[0] as $base | .[1] as $new |
      $base * {hooks: (
        ($base.hooks // {}) as $bh | ($new.hooks // {}) |
        to_entries | reduce .[] as $e ($bh;
          .[$e.key] = ((.[$e.key] // []) + [$e.value[] |
            select(.hooks[0].command as $cmd |
              [$bh[$e.key] // [] | .[].hooks[]?.command] |
              index($cmd) | not)])
        )
      )}' "$SETTINGS_FILE" "$CONFIG_SRC" > "$TMP_SETTINGS" 2>/dev/null; then
      # Validate the merged JSON
      if jq empty "$TMP_SETTINGS" 2>/dev/null; then
        mv "$TMP_SETTINGS" "$SETTINGS_FILE"
        SETTINGS_MERGED=true
        info "Settings merged successfully."
      else
        warn "Merged settings produced invalid JSON. Restoring backup."
        cp "$SETTINGS_BACKUP" "$SETTINGS_FILE"
        rm -f "$TMP_SETTINGS"
      fi
    else
      warn "Settings merge failed. Restoring backup."
      cp "$SETTINGS_BACKUP" "$SETTINGS_FILE"
      rm -f "$TMP_SETTINGS"
    fi
  fi
else
  info "Skipping settings.json merge (--hooks-only)."
fi

# --- Step 6: Run tests ---
if [ -f "$SCRIPT_DIR/tests/run-tests.sh" ] && ! $DRY_RUN; then
  info "Running hook tests..."
  if bash "$SCRIPT_DIR/tests/run-tests.sh"; then
    info "All tests passed."
  else
    warn "Some tests failed. Hooks are installed but may have issues."
  fi
fi

# --- Step 7: Summary ---
echo ""
echo "=== Installation Summary ==="
echo "  Hooks directory: $TARGET_DIR"
echo "  Files copied:    $COPIED"
echo "  Settings merged: $SETTINGS_MERGED"
[ -n "$BACKUP_DIR" ] && echo "  Backup location: $BACKUP_DIR"
echo ""
if $DRY_RUN; then
  echo "  (dry-run mode — no changes were made)"
fi
echo "Done."
