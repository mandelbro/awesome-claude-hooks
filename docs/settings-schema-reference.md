# Claude Code Settings.json Hook Schema Reference

## Actual Schema Structure

Hook entries in `~/.claude/settings.json` use a **nested** structure where each lifecycle event contains an array of matcher groups, and each group contains its own `hooks` array:

```json
{
  "hooks": {
    "<LifecycleEvent>": [
      {
        "matcher": "<regex pattern>",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/script-name.sh",
            "timeout": 3000
          }
        ]
      }
    ]
  }
}
```

## Key Structural Details

- **Top level**: `hooks` object with lifecycle event keys
- **Per event**: Array of matcher group objects
- **Per matcher group**: `matcher` (optional regex) + `hooks` array of command entries
- **Per command entry**: `type` ("command"), `command` (shell string), `timeout` (ms)
- When `matcher` is omitted, the group matches all tools for that event

## Lifecycle Events

| Event | Stdin | Can Block | Exit 2 Behavior |
|-------|-------|-----------|-----------------|
| SessionStart | JSON (session_id) | No | Informational only |
| PreCompact | JSON | No | Informational only |
| PreToolUse | JSON (tool_name, tool_input) | Yes | Blocks the tool action |
| PostToolUse | JSON (tool_name, tool_input) | No | Informational only |
| Stop | JSON (session_id, stop_hook_active) | No | Informational only |

## Installer Merge Strategy

The installer must walk the nested structure:
1. For each lifecycle event in the source config
2. For each matcher group in that event
3. Check if an identical matcher already exists in the target
4. If yes: merge hooks arrays (avoid duplicating by command path)
5. If no: append the entire matcher group

## Uninstaller Removal Strategy

1. For each lifecycle event, iterate matcher groups
2. Within each group's `hooks` array, remove entries matching known command paths
3. If a group's `hooks` array becomes empty, remove the entire group
4. If a lifecycle event's array becomes empty, remove the event key

## Common Assumptions to Avoid

- The schema is NOT flat (`matcher` is NOT a field on individual hook entries)
- Each matcher group can contain multiple hooks (e.g., Write matcher has both secrets-check and file-org-check)
- Stop hooks typically omit the `matcher` field (match all)
