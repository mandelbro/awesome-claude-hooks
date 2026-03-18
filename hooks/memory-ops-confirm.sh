#!/usr/bin/env bash
# Memory Operations Confirmation Hook — logs when graphiti/pi-brain tools are used.
# Runs on: PostToolUse (mcp__graphiti-memory__|mcp__pi-brain__)
# Outputs a confirmation to stdout so the user sees memory activity in the session.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Nothing to check
if [ -z "$TOOL_NAME" ]; then
  exit 0
fi

# Extract key details based on tool
case "$TOOL_NAME" in
  mcp__graphiti-memory__add_memory)
    echo "[MEMORY OK] graphiti-memory: memory added"
    ;;
  mcp__graphiti-memory__search_memory_nodes)
    QUERY=$(echo "$INPUT" | jq -r '.tool_input.query // "unknown"' 2>/dev/null)
    echo "[MEMORY OK] graphiti-memory: node search executed (query: ${QUERY:0:80})"
    ;;
  mcp__graphiti-memory__search_memory_facts)
    QUERY=$(echo "$INPUT" | jq -r '.tool_input.query // "unknown"' 2>/dev/null)
    echo "[MEMORY OK] graphiti-memory: fact search executed (query: ${QUERY:0:80})"
    ;;
  mcp__graphiti-memory__delete_entity_edge|mcp__graphiti-memory__delete_episode)
    echo "[MEMORY OK] graphiti-memory: deletion executed"
    ;;
  mcp__graphiti-memory__get_entity_edge|mcp__graphiti-memory__get_episodes)
    echo "[MEMORY OK] graphiti-memory: retrieval executed"
    ;;
  mcp__graphiti-memory__clear_graph)
    echo "[MEMORY WARN] graphiti-memory: graph cleared"
    ;;
  mcp__pi-brain__brain_search)
    QUERY=$(echo "$INPUT" | jq -r '.tool_input.query // "unknown"' 2>/dev/null)
    echo "[MEMORY OK] pi-brain: search executed (query: ${QUERY:0:80})"
    ;;
  mcp__pi-brain__brain_share)
    TITLE=$(echo "$INPUT" | jq -r '.tool_input.title // "unknown"' 2>/dev/null)
    echo "[MEMORY OK] pi-brain: knowledge shared (title: ${TITLE:0:80})"
    ;;
  mcp__pi-brain__brain_vote)
    echo "[MEMORY OK] pi-brain: vote cast"
    ;;
  mcp__pi-brain__brain_get|mcp__pi-brain__brain_list)
    echo "[MEMORY OK] pi-brain: retrieval executed"
    ;;
  mcp__pi-brain__brain_delete)
    echo "[MEMORY OK] pi-brain: memory deleted"
    ;;
  mcp__pi-brain__brain_drift)
    echo "[MEMORY OK] pi-brain: drift check executed"
    ;;
  mcp__pi-brain__brain_page_*)
    ACTION=$(echo "$TOOL_NAME" | sed 's/mcp__pi-brain__brain_page_//')
    echo "[MEMORY OK] pi-brain: brainpedia page ${ACTION} executed"
    ;;
  mcp__pi-brain__brain_*)
    ACTION=$(echo "$TOOL_NAME" | sed 's/mcp__pi-brain__brain_//')
    echo "[MEMORY OK] pi-brain: ${ACTION} executed"
    ;;
  mcp__graphiti-memory__*)
    ACTION=$(echo "$TOOL_NAME" | sed 's/mcp__graphiti-memory__//')
    echo "[MEMORY OK] graphiti-memory: ${ACTION} executed"
    ;;
esac

exit 0
