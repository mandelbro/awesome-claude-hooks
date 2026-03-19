#!/usr/bin/env bash
# Version: 1.0.0
# Shared utilities library for Claude Code hooks
set -u

# Exported variables - initialized after set -u
HOOK_INPUT=""
HOOK_TOOL_NAME=""
HOOK_FILE_PATH=""
HOOK_SESSION_ID=""
HOOK_CWD=""
HOOK_CONTENT=""
export HOOK_INPUT HOOK_TOOL_NAME HOOK_FILE_PATH HOOK_SESSION_ID HOOK_CWD HOOK_CONTENT

require_jq() {
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed." >&2
    echo "Install: brew install jq (macOS) or apt-get install jq (Linux)" >&2
    return 1
  fi
}

parse_input() {
  HOOK_INPUT="$(cat)"
  require_jq || return 1

  HOOK_TOOL_NAME="$(echo "$HOOK_INPUT" | jq -r '.tool_name // ""' 2>/dev/null)" || true
  HOOK_FILE_PATH="$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)" || true
  HOOK_SESSION_ID="$(echo "$HOOK_INPUT" | jq -r '.session_id // ""' 2>/dev/null)" || true
  HOOK_CWD="$(echo "$HOOK_INPUT" | jq -r '.cwd // ""' 2>/dev/null)" || true

  # Validate we got valid JSON (at least one field should parse)
  if [ -z "$HOOK_INPUT" ] || ! echo "$HOOK_INPUT" | jq empty 2>/dev/null; then
    echo "Error: failed to parse input JSON" >&2
    return 1
  fi
}

extract_content() {
  case "$HOOK_TOOL_NAME" in
    Write)
      HOOK_CONTENT="$(echo "$HOOK_INPUT" | jq -r '.tool_input.content // ""')"
      ;;
    Edit)
      HOOK_CONTENT="$(echo "$HOOK_INPUT" | jq -r '.tool_input.new_string // ""')"
      ;;
    MultiEdit)
      HOOK_CONTENT="$(echo "$HOOK_INPUT" | jq -r '[.tool_input.edits[].new_string] | join("\n") // ""')"
      ;;
    Bash)
      HOOK_CONTENT="$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""')"
      ;;
    *)
      HOOK_CONTENT=""
      ;;
  esac
}

guard_stop_loop() {
  local active
  active="$(echo "$HOOK_INPUT" | jq -r '.stop_hook_active // "false"' 2>/dev/null)"
  if [[ "$active" == "true" ]]; then
    exit 0
  fi
}

classify_file() {
  local filepath="${1:?usage: classify_file <path>}"
  local basename
  basename="$(basename "$filepath")"
  local name_no_ext="${basename%%.*}"

  # Test patterns take precedence
  if [[ "$filepath" == */__tests__/* ]] || [[ "$filepath" == */tests/* ]]; then
    echo "test"; return
  fi
  if [[ "$name_no_ext" == test_* ]] || [[ "$name_no_ext" == *_test ]]; then
    echo "test"; return
  fi
  if [[ "$basename" == *.test.* ]] || [[ "$basename" == *.spec.* ]]; then
    echo "test"; return
  fi

  # Config patterns
  case "$basename" in
    *.json|*.yaml|*.yml|*.toml|*.ini|*.cfg|*.conf|.env*|Makefile|Dockerfile|justfile)
      echo "config"; return ;;
  esac
  case "$basename" in
    .*rc|.*rc.js|.*rc.cjs|.*rc.mjs)
      echo "config"; return ;;
  esac

  # Source patterns
  case "$basename" in
    *.sh|*.bash|*.py|*.js|*.ts|*.tsx|*.jsx|*.rb|*.go|*.rs|*.java|*.c|*.cpp|*.h)
      echo "source"; return ;;
  esac

  echo "other"
}

session_tmp() {
  echo "/tmp/claude-${1:?usage: session_tmp <label>}-${HOOK_SESSION_ID:-unknown}"
}

cleanup_stale_temps() {
  find /tmp -maxdepth 1 -name 'claude-*' -type f -mmin +1440 -delete 2>/dev/null || true
}
