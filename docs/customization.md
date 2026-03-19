# Customization Guide

How to add, modify, and test hooks in the Claude Code user hooks system.

## Adding a New Hook

1. **Create the script** in `hooks/`:

   ```bash
   #!/usr/bin/env bash
   # My Custom Hook — one-line description of what it does.
   # Runs on: <lifecycle event> (<matcher>). Exit 0 = allow, Exit 2 = block.
   source "$(dirname "$0")/lib/common.sh"
   parse_input || exit 0   # exit 0 for advisory hooks, exit 2 for blocking hooks
   extract_content          # optional: only if you need file content

   # Your logic here
   echo "Advisory message for Claude's context"
   exit 0
   ```

2. **Make it executable**: `chmod +x hooks/my-hook.sh`

3. **Register it** in `config/settings-hooks.json` under the appropriate lifecycle event:

   ```json
   {
     "matcher": "Write|Edit",
     "hooks": [
       {
         "type": "command",
         "command": "bash ~/.claude/hooks/my-hook.sh",
         "timeout": 3000
       }
     ]
   }
   ```

4. **Add tests** in `tests/test-my-hook.sh` (see Testing Custom Hooks below).

5. **Add to uninstaller**: Add your hook filename to the `KNOWN_HOOKS` array in `uninstall.sh`.

6. **Reinstall**: Run `bash install.sh --force` to deploy.

## Lifecycle Event Guide

| Event | When It Fires | Can Block? | Use For |
|-------|---------------|------------|---------|
| **SessionStart** | Session begins, resumes, or compacts | No | Environment checks, injecting guidelines |
| **PreCompact** | Before context window compaction | No | Re-injecting critical context that must survive |
| **PreToolUse** | Before Claude executes a tool | **Yes** (exit 2) | Security gates, format validation |
| **PostToolUse** | After a tool completes | No | Tracking, size checks, confirmations |
| **Stop** | Claude finishes its response | No | Reminders, nudges, cleanup |

### Choosing the Right Event

- Need to **prevent** something? Use **PreToolUse** with exit code 2.
- Need to **observe** what happened? Use **PostToolUse**.
- Need to **inject context** at start? Use **SessionStart**.
- Need to **remind** before Claude stops? Use **Stop**.
- Need context to **survive compaction**? Use **PreCompact**.

## Shared Library Reference

Source the library at the top of every hook:

```bash
source "$(dirname "$0")/lib/common.sh"
```

### Functions

| Function | Purpose |
|----------|---------|
| `parse_input` | Reads stdin JSON, populates HOOK_ variables. Returns 1 on failure. |
| `extract_content` | Sets `HOOK_CONTENT` from the tool input (Write, Edit, MultiEdit, Bash). |
| `guard_stop_loop` | Exits 0 if `stop_hook_active` is true. Required in Stop hooks. |
| `classify_file <path>` | Returns `test`, `config`, `source`, or `other`. |
| `session_tmp <label>` | Returns `/tmp/claude-<label>-<session_id>`. |
| `cleanup_stale_temps` | Removes `/tmp/claude-*` files older than 24 hours. |
| `require_jq` | Returns 1 if jq is not installed. |

### Variables (set by `parse_input`)

| Variable | Contents |
|----------|----------|
| `HOOK_INPUT` | Full JSON input from stdin |
| `HOOK_TOOL_NAME` | Tool name (Write, Edit, Bash, etc.) |
| `HOOK_FILE_PATH` | Target file path from `tool_input.file_path` |
| `HOOK_SESSION_ID` | Current session identifier |
| `HOOK_CWD` | Working directory |
| `HOOK_CONTENT` | Extracted content (set by `extract_content`) |

## Stop Hook Requirements

Stop hooks **must** prevent infinite loops. When a Stop hook produces output, Claude processes it, which triggers another Stop event. Use `guard_stop_loop` as the first logic after `parse_input`:

```bash
source "$(dirname "$0")/lib/common.sh"
parse_input || exit 0
guard_stop_loop           # exits 0 if this is a recursive stop

# ... your logic ...
```

## Testing Custom Hooks

1. **Create a fixture** in `tests/fixtures/` (JSON matching your hook's expected input).

2. **Create a test file** `tests/test-my-hook.sh`:

   ```bash
   # Tests for hooks/my-hook.sh

   test_my_hook_allows_clean_input() {
     run_hook "$HOOKS_DIR/my-hook.sh" "$SCRIPT_DIR/fixtures/write-clean.json"
     assert_exit 0 "$RUN_EXIT" "my-hook: allows clean write"
   }

   test_my_hook_blocks_bad_input() {
     run_hook "$HOOKS_DIR/my-hook.sh" "$SCRIPT_DIR/fixtures/my-bad-input.json"
     assert_exit 2 "$RUN_EXIT" "my-hook: blocks bad input"
     assert_output_contains "BLOCKED" "$RUN_OUTPUT" "my-hook: outputs BLOCKED"
   }
   ```

3. **Run tests**: `bash tests/run-tests.sh`

## Common Patterns

### Pattern: Blocking on content match

```bash
extract_content
if echo "$HOOK_CONTENT" | grep -qE 'DANGEROUS_PATTERN'; then
  echo "BLOCKED: Found dangerous pattern"
  exit 2
fi
exit 0
```

### Pattern: Advisory message with session tracking

```bash
COUNTER_FILE="$(session_tmp "my-counter")"
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

if [ $((COUNT % 5)) -eq 0 ]; then
  echo "Reminder: every 5th operation message"
fi
exit 0
```

### Pattern: File-type-specific logic

```bash
FILE_TYPE="$(classify_file "$HOOK_FILE_PATH")"
case "$FILE_TYPE" in
  test)   echo "Test file detected" ;;
  source) echo "Source file detected" ;;
  *)      exit 0 ;;  # skip for config/other
esac
```
