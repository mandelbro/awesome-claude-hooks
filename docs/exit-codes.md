# Hook Exit Code Reference

## Exit Code Semantics

| Exit Code | PreToolUse | PostToolUse | SessionStart | Stop | PreCompact |
|-----------|------------|-------------|--------------|------|------------|
| **0** | Allow action | (ignored) | (ignored) | (ignored) | (ignored) |
| **1** | Allow action (hook error) | (ignored) | (ignored) | (ignored) | (ignored) |
| **2** | **Block action** | (ignored) | (ignored) | (ignored) | (ignored) |

Only PreToolUse hooks can block actions. All other lifecycle events ignore exit codes.

### The "Fails Open" Design

Exit code 1 means "this hook crashed." Claude Code treats crashes as non-blocking to avoid a broken hook stopping all work. This is by design, but it means:

- **Missing jq**: If jq is absent and a hook crashes, the action proceeds unchecked
- **Syntax errors**: A bash error in a security hook silently stops protecting you
- **Mitigation**: Use `require_jq` from `lib/common.sh` and convert parse failures to `exit 2` in PreToolUse hooks

### Choosing the Right Exit Code

**PreToolUse hooks (blocking):**
- `exit 0` — action is safe, allow it
- `exit 2` — action is unsafe, block it
- On parse failure: `exit 2` (block when we cannot verify safety)

**All other hooks (advisory):**
- `exit 0` — normal completion
- `exit 1` — acceptable for errors (action already happened or hasn't started)
- Output goes to stdout as context for Claude

## Stop Hook Guard: Preventing Infinite Loops

Stop hooks MUST check `stop_hook_active` before producing output. When a Stop hook emits output, Claude processes it, which triggers another Stop event. Without the guard, this creates an infinite loop.

### The `stop_hook_active` Flag

Claude Code passes `"stop_hook_active": true` in the JSON input when a stop event was triggered by a previous stop hook's output. Hooks must check this flag and exit immediately when it is `true`.

### Using `guard_stop_loop` from `hooks/lib/common.sh`

```bash
source "$(dirname "$0")/lib/common.sh"
parse_input || exit 0
guard_stop_loop  # exits 0 immediately if stop_hook_active is true

# ... rest of hook logic only runs on genuine stop events ...
```

This replaces the manual pattern that was previously used:

```bash
# OLD (manual) — replaced by guard_stop_loop
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi
```

All Stop hooks MUST use `guard_stop_loop()` or implement the check manually.

## Hook Execution Order

Within a lifecycle event, hooks run in the order listed in `settings.json`. For PreToolUse hooks:

- If an earlier hook exits with `2` (block), later hooks for the same event are **not executed**
- If an earlier hook exits with `0` or `1`, later hooks still run

This means ordering matters: place the most critical blocking hooks (e.g., `secrets-check.sh`) before advisory hooks. A blocked secret write correctly prevents the commit format checker from running.

Hook ordering is configured in `config/settings-hooks.json`.

## Common Mistakes

1. **Using `exit 1` to block in PreToolUse:** Exit 1 means "hook crashed" and the action is **allowed**. Use `exit 2` to block.
2. **Using `parse_input || exit 0` in a security hook:** If JSON parsing fails in a PreToolUse hook, `exit 0` allows the action unchecked. Use `parse_input || exit 2` instead.
3. **Forgetting `guard_stop_loop` in Stop hooks:** Omitting this causes infinite recursion when the hook produces output.
4. **Expecting PostToolUse to block:** Only PreToolUse can block. PostToolUse exit codes are ignored; the action has already completed.

## The `parse_input` Safety Decision

Each hook must decide what happens when `parse_input` fails (bad JSON, missing jq):

- **Security hooks (PreToolUse):** Use `parse_input || exit 2` to block when safety cannot be verified.
- **Advisory hooks (all others):** Use `parse_input || exit 0` to fail silently rather than crash.
