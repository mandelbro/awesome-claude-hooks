# Hook Exit Code Reference

## Exit Code Semantics

| Exit Code | PreToolUse | PostToolUse | SessionStart | Stop | PreCompact |
|-----------|------------|-------------|--------------|------|------------|
| **0** | Allow action | (ignored) | (ignored) | (ignored) | (ignored) |
| **1** | Allow action (hook error) | (ignored) | (ignored) | (ignored) | (ignored) |
| **2** | **Block action** | (ignored) | (ignored) | (ignored) | (ignored) |

Only PreToolUse hooks can block actions. All other lifecycle events ignore exit codes.

## The "Fails Open" Design

Exit code 1 means "this hook crashed." Claude Code treats crashes as non-blocking to avoid a broken hook stopping all work. This is by design, but it means:

- **Missing jq**: If jq is absent and a hook crashes, the action proceeds unchecked
- **Syntax errors**: A bash error in a security hook silently stops protecting you
- **Mitigation**: Use `require_jq` from `lib/common.sh` and convert parse failures to `exit 2` in PreToolUse hooks

## Choosing the Right Exit Code

**PreToolUse hooks (blocking):**
- `exit 0` — action is safe, allow it
- `exit 2` — action is unsafe, block it
- On parse failure: `exit 2` (block when we cannot verify safety)

**All other hooks (advisory):**
- `exit 0` — normal completion
- `exit 1` — acceptable for errors (action already happened or hasn't started)
- Output goes to stdout as context for Claude

## Stop Hook Guard Requirement

Stop hooks MUST check `stop_hook_active` before producing output. When a Stop hook emits output, Claude processes it, which triggers another Stop event. Without the guard, this creates an infinite loop.

**How `guard_stop_loop()` works:**
```bash
source "$(dirname "$0")/lib/common.sh"
parse_input || exit 0
guard_stop_loop  # exits 0 if stop_hook_active is true
```

All new Stop hooks MUST use `guard_stop_loop()` or implement the check manually.

## Hook Execution Order

Within a lifecycle event, hooks run in array order. If an earlier PreToolUse hook exits 2, later hooks in the same event do NOT run. This means:
- `secrets-check.sh` must come before `commit-format-check.sh` in PreToolUse
- A blocked secret write prevents the commit format checker from running (correct behavior)

This ordering is configured in `config/settings-hooks.json`.
