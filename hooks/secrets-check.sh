#!/usr/bin/env bash
# Secrets Check Hook — blocks writes/edits that contain secrets or credentials.
# Runs on: PreToolUse (Write|Edit|MultiEdit). Exit 2 = block the action.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Extract the content being written/edited
CONTENT=""
case "$TOOL_NAME" in
  Write)
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    ;;
  Edit)
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty' 2>/dev/null)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    ;;
  MultiEdit)
    CONTENT=$(echo "$INPUT" | jq -r '[.tool_input.edits[]?.new_string // empty] | join("\n")' 2>/dev/null)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    ;;
esac

# Nothing to check
if [ -z "$CONTENT" ]; then
  exit 0
fi

# Check if writing to a .env file
case "$FILE_PATH" in
  *.env|*.env.*|*/.env|*/.env.*)
    echo "BLOCKED: Writing to .env file ($FILE_PATH). Environment files must not be created or modified by Claude Code." >&2
    exit 2
    ;;
esac

# Check for AWS access keys (AKIA pattern)
if echo "$CONTENT" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  echo "BLOCKED: Content contains what appears to be an AWS Access Key ID (AKIA...). Never hardcode credentials." >&2
  exit 2
fi

# Check for private keys
if echo "$CONTENT" | grep -qe '-----BEGIN.*PRIVATE KEY-----'; then
  echo "BLOCKED: Content contains a private key. Never include private keys in source files." >&2
  exit 2
fi

# Check for common secret patterns (skip test files and fixtures)
case "$FILE_PATH" in
  */test*|*/spec*|*/fixture*|*/__mocks__/*|*/mock*)
    # More lenient for test files — skip password check
    ;;
  *)
    # Check for hardcoded passwords/secrets in assignment patterns
    if echo "$CONTENT" | grep -qiE "(password|secret|api_key|apikey|token|private_key)[[:space:]]*[=:][[:space:]]*[\"'][A-Za-z0-9+/=_-]{8,}[\"']"; then
      echo "BLOCKED: Content appears to contain a hardcoded secret (password/key/token assignment). Use environment variables instead." >&2
      exit 2
    fi
    ;;
esac

exit 0
