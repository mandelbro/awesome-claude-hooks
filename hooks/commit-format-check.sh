#!/usr/bin/env bash
# Commit Format Check Hook — blocks non-conventional commit messages.
# Runs on: PreToolUse (Bash). Exit 2 = block.
source "$(dirname "$0")/lib/common.sh"
parse_input || exit 2
extract_content

# HOOK_CONTENT holds the Bash command via extract_content
echo "$HOOK_CONTENT" | grep -q 'git commit' || exit 0

# Skip --amend without -m (reuses previous message)
if echo "$HOOK_CONTENT" | grep -q '\-\-amend' && ! echo "$HOOK_CONTENT" | grep -q '\-m'; then
  exit 0
fi

# Extract commit message — try heredoc first, then flag patterns
COMMIT_MSG=""
if echo "$HOOK_CONTENT" | grep -qE 'cat <<'; then
  COMMIT_MSG=$(echo "$HOOK_CONTENT" | awk '
    /cat <</ { found=1; next }
    found && /^[[:space:]]*EOF/ { exit }
    found && /^[[:space:]]*$/ { next }
    found && /^[[:space:]]*[^[:space:]]/ { sub(/^[[:space:]]+/, ""); print; exit }
  ')
fi

Q='["'"'"']'; NQ='[^"'"'"']'
[ -z "$COMMIT_MSG" ] && COMMIT_MSG=$(echo "$HOOK_CONTENT" | grep -oE "\-\-message=${Q}(${NQ}+)${Q}" | head -1 | sed "s/--message=[\"']//;s/[\"']$//")
[ -z "$COMMIT_MSG" ] && COMMIT_MSG=$(echo "$HOOK_CONTENT" | grep -oE "\-\-message ${Q}(${NQ}+)${Q}" | head -1 | sed "s/--message [\"']//;s/[\"']$//")
[ -z "$COMMIT_MSG" ] && COMMIT_MSG=$(echo "$HOOK_CONTENT" | grep -oE "\-[a-z]*m ${Q}(${NQ}+)${Q}" | head -1 | sed "s/-[a-z]*m [\"']//;s/[\"']$//")
[ -z "$COMMIT_MSG" ] && COMMIT_MSG=$(echo "$HOOK_CONTENT" | grep -oE "\-m ${Q}(${NQ}+)${Q}" | head -1 | sed "s/-m [\"']//;s/[\"']$//")

if [ -z "$COMMIT_MSG" ]; then
  echo "Warning: could not extract commit message from command; allowing through." >&2
  exit 0
fi

COMMIT_MSG=$(echo "$COMMIT_MSG" | sed 's/^[[:space:]]*//')
PATTERN='^(feat|fix|refactor|test|docs|style|chore|build|ci)(\([a-zA-Z0-9_./-]+\))?: .+'
echo "$COMMIT_MSG" | grep -qE "$PATTERN" && exit 0

echo "Commit message does not follow Conventional Commits format." >&2
echo "Expected: <type>[scope]: <description>" >&2
echo "Types: feat, fix, refactor, test, docs, style, chore, build, ci" >&2
echo "Example: feat(auth): add magic link authentication" >&2
echo "Got: $COMMIT_MSG" >&2
exit 2
