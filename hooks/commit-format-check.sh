#!/usr/bin/env bash
# Commit Format Check Hook — blocks git commits with non-conventional messages.
# Runs on: PreToolUse (Bash). Exit 2 = block the command.

source "$(dirname "$0")/lib/common.sh"

parse_input || exit 2

# Extract command from tool_input (not directly parsed by parse_input)
COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // empty')

# Only check git commit commands
if ! echo "$COMMAND" | grep -q 'git commit'; then
  exit 0
fi

# Skip --amend without -m (reuses previous message)
if echo "$COMMAND" | grep -q '\-\-amend' && ! echo "$COMMAND" | grep -q '\-m'; then
  exit 0
fi

# Extract commit message from -m flag
# Handle: -m "message", -m 'message', -m "$(cat <<'EOF'...EOF)"
COMMIT_MSG=""

# Try heredoc pattern first: -m "$(cat <<'EOF' ... EOF )"
if echo "$COMMAND" | grep -qE 'cat <<'; then
  # Extract content between EOF markers
  COMMIT_MSG=$(echo "$COMMAND" | sed -n "/cat <<['\"]\\{0,1\\}EOF/,/EOF/p" | head -1 | sed "s/.*cat <<['\"]\\{0,1\\}EOF['\"]\\{0,1\\}//")
  if [ -z "$COMMIT_MSG" ]; then
    # Multi-line heredoc — extract the first non-empty line after EOF marker
    COMMIT_MSG=$(echo "$COMMAND" | awk '/cat <</{found=1; next} found && /^[[:space:]]*[^[:space:]]/{print; exit}')
  fi
fi

# Try simple -m "message" or -m 'message'
if [ -z "$COMMIT_MSG" ]; then
  COMMIT_MSG=$(echo "$COMMAND" | grep -oE '\-m ["\x27]([^"\x27]+)["\x27]' | head -1 | sed "s/-m [\"']//;s/[\"']$//")
fi

# If we couldn't extract a message, let it through (might be interactive or complex)
if [ -z "$COMMIT_MSG" ]; then
  exit 0
fi

# Trim leading whitespace
COMMIT_MSG=$(echo "$COMMIT_MSG" | sed 's/^[[:space:]]*//')

# Validate conventional commits format
PATTERN='^(feat|fix|refactor|test|docs|style|chore|build|ci)(\([a-zA-Z0-9_./-]+\))?: .+'
if echo "$COMMIT_MSG" | grep -qE "$PATTERN"; then
  exit 0
fi

# Block with explanation
echo "Commit message does not follow Conventional Commits format." >&2
echo "Expected: <type>[scope]: <description>" >&2
echo "Types: feat, fix, refactor, test, docs, style, chore, build, ci" >&2
echo "Example: feat(auth): add magic link authentication" >&2
echo "Got: $COMMIT_MSG" >&2
exit 2
