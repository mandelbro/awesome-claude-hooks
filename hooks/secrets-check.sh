#!/usr/bin/env bash
# Secrets Check Hook — blocks writes/edits containing secrets or credentials.
# Runs on: PreToolUse (Write|Edit|MultiEdit|Bash). Exit 2 = block.
source "$(dirname "$0")/lib/common.sh"
parse_input || exit 2
extract_content

# For Bash, only scan commands that write to files (>, >>, tee, heredoc)
if [ "$HOOK_TOOL_NAME" = "Bash" ]; then
  echo "$HOOK_CONTENT" | grep -qE '>>?[[:space:]]|[[:space:]]tee[[:space:]]|<<' || exit 0
fi
[ -z "$HOOK_CONTENT" ] && exit 0

# Block writes to .env files
case "$HOOK_FILE_PATH" in
  *.env|*.env.*|*/.env|*/.env.*)
    echo "BLOCKED: Writing to .env file ($HOOK_FILE_PATH)." >&2; exit 2 ;;
esac

# AWS access keys (AKIA pattern)
if echo "$HOOK_CONTENT" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  echo "BLOCKED: Content contains what appears to be an AWS Access Key ID." >&2; exit 2
fi
# Private keys
if echo "$HOOK_CONTENT" | grep -qe '-----BEGIN.*PRIVATE KEY-----'; then
  echo "BLOCKED: Content contains a private key." >&2; exit 2
fi

# Hardcoded passwords/secrets (skip test files)
case "$HOOK_FILE_PATH" in
  */test*|*/spec*|*/fixture*|*/__mocks__/*|*/mock*) ;;
  *)
    if echo "$HOOK_CONTENT" | grep -qiE "(password|secret|api_key|apikey|token|private_key)[[:space:]]*[=:][[:space:]]*[\"'][A-Za-z0-9+/=_-]{8,}[\"']"; then
      echo "BLOCKED: Hardcoded secret detected. Use environment variables instead." >&2; exit 2
    fi ;;
esac
exit 0
