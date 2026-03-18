#!/usr/bin/env bash
# Memory Nudge Hook — periodically reminds Claude to update graphiti-memory.
# Runs on: Stop event. Every 3rd invocation outputs a reminder.
# Uses a temp counter file keyed by session_id.

INPUT=$(cat)

# Check stop_hook_active to avoid contributing to infinite loops
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
COUNTER_FILE="/tmp/claude-memory-nudge-${SESSION_ID}"

# Initialize or increment counter
if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(cat "$COUNTER_FILE")
  COUNT=$((COUNT + 1))
else
  COUNT=1
fi
echo "$COUNT" > "$COUNTER_FILE"

# Every 3rd stop, output a memory reminder
if [ $((COUNT % 3)) -eq 0 ]; then
  cat <<'NUDGE'
[MEMORY REMINDER] You have been working for a while. Consider updating graphiti-memory:
- New preferences or procedures discovered this session
- Decisions made with rationale
- Patterns or solutions that should be remembered
- Requirements that were clarified or changed
Use add_memory to persist these before they are lost to context compaction.
NUDGE
fi

exit 0
