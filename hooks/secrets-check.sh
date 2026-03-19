#!/usr/bin/env bash
# Secrets Check Hook — blocks writes/edits that contain secrets or credentials.
# Also scans Bash commands that write to files.
# Runs on: PreToolUse (Write|Edit|MultiEdit|Bash). Exit 2 = block the action.

source "$(dirname "$0")/lib/common.sh"

parse_input || exit 2
extract_content

# --- Bash command handling ---
# For Bash tool, only scan commands that write to files.
# Known limitations:
#   - Cannot detect secrets in variables expanded at runtime (e.g., echo "$VAR" > file)
#   - Does not follow command substitutions or pipelines beyond simple patterns
#   - Heredoc detection is pattern-based, not a full parser
if [ "$HOOK_TOOL_NAME" = "Bash" ]; then
  # Check if command contains a write operator: >, >>, tee, or heredoc <<
  if ! echo "$HOOK_CONTENT" | grep -qE '>>?[[:space:]]|[[:space:]]tee[[:space:]]|<<'; then
    # Read-only command — no file write risk
    exit 0
  fi
  # Fall through to secret pattern checks below using HOOK_CONTENT
fi

# Nothing to check
if [ -z "$HOOK_CONTENT" ]; then
  exit 0
fi

# Check if writing to a .env file
case "$HOOK_FILE_PATH" in
  *.env|*.env.*|*/.env|*/.env.*)
    echo "BLOCKED: Writing to .env file ($HOOK_FILE_PATH). Environment files must not be created or modified by Claude Code." >&2
    exit 2
    ;;
esac

# Check for AWS access keys (AKIA pattern)
if echo "$HOOK_CONTENT" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  echo "BLOCKED: Content contains what appears to be an AWS Access Key ID (AKIA...). Never hardcode credentials." >&2
  exit 2
fi

# Check for private keys
if echo "$HOOK_CONTENT" | grep -qe '-----BEGIN.*PRIVATE KEY-----'; then
  echo "BLOCKED: Content contains a private key. Never include private keys in source files." >&2
  exit 2
fi

# Check for common secret patterns (skip test files and fixtures)
case "$HOOK_FILE_PATH" in
  */test*|*/spec*|*/fixture*|*/__mocks__/*|*/mock*)
    # More lenient for test files — skip password check
    ;;
  *)
    # Check for hardcoded passwords/secrets in assignment patterns
    if echo "$HOOK_CONTENT" | grep -qiE "(password|secret|api_key|apikey|token|private_key)[[:space:]]*[=:][[:space:]]*[\"'][A-Za-z0-9+/=_-]{8,}[\"']"; then
      echo "BLOCKED: Content appears to contain a hardcoded secret (password/key/token assignment). Use environment variables instead." >&2
      exit 2
    fi
    ;;
esac

exit 0
