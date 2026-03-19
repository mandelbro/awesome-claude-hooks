# Claude Code User Hooks

A production-ready, 4-layer hook system for Claude Code that enforces coding standards, catches secrets, and keeps your workflow honest.

## Overview

Claude Code supports user-level hooks that run at key points during a session. This repository provides 11 hooks organized into a layered architecture:

| Layer | Purpose | Hooks |
|-------|---------|-------|
| **Security** | Block dangerous writes before they happen | `secrets-check.sh` |
| **Quality Gates** | Enforce standards on code being written | `commit-format-check.sh`, `file-org-check.sh` |
| **Observation** | Track and measure what is happening | `file-size-check.sh`, `tdd-tracker.sh`, `memory-ops-confirm.sh` |
| **Guidance** | Inject reminders and nudges into context | `guidelines-reminder.sh`, `pre-compact-guidelines.sh`, `memory-nudge.sh`, `tdd-reminder.sh`, `hook-health-check.sh` |

## Quick Start

```bash
git clone https://github.com/your-org/user-claude-hooks.git
cd user-claude-hooks
bash install.sh --force
```

This copies hooks to `~/.claude/hooks/` and merges hook configuration into `~/.claude/settings.json`.

### Prerequisites

- **bash** 3.2+ (macOS default or Linux)
- **jq** (`brew install jq` or `apt-get install jq`)

## Hook Reference

| Hook | Lifecycle | Matcher | Blocking | Description |
|------|-----------|---------|----------|-------------|
| `hook-health-check.sh` | SessionStart | `startup\|resume\|compact` | No | Validates hook environment (jq, lib/common.sh) |
| `guidelines-reminder.sh` | SessionStart | `startup\|resume\|compact` | No | Injects condensed user guidelines into context |
| `pre-compact-guidelines.sh` | PreCompact | (all) | No | Re-injects guidelines before context compaction |
| `secrets-check.sh` | PreToolUse | `Write\|Edit\|MultiEdit\|Bash` | **Yes** | Blocks writes containing secrets or credentials |
| `file-org-check.sh` | PreToolUse | `Write` | **Yes** | Blocks new files in project root that belong in subdirs |
| `commit-format-check.sh` | PreToolUse | `Bash` | **Yes** | Blocks non-conventional commit messages |
| `file-size-check.sh` | PostToolUse | `Write\|Edit\|MultiEdit` | No | Warns when files exceed size guidelines |
| `tdd-tracker.sh` | PostToolUse | `Write\|Edit\|MultiEdit` | No | Records whether source or test files are written |
| `memory-ops-confirm.sh` | PostToolUse | `mcp__graphiti-memory__.*\|mcp__pi-brain__.*` | No | Logs graphiti/pi-brain tool usage |
| `memory-nudge.sh` | Stop | (all) | No | Periodically reminds Claude to update memory |
| `tdd-reminder.sh` | Stop | (all) | No | Reminds about TDD when source files lack tests |

## Customization

See [docs/customization.md](docs/customization.md) for a full guide on adding or modifying hooks, including:

- Step-by-step instructions for creating new hooks
- Lifecycle event reference (when to use each)
- Shared library functions and variables
- Stop hook infinite loop prevention

## Installation Options

```bash
bash install.sh                # Interactive install (prompts before overwriting)
bash install.sh --force        # Overwrite existing hooks without prompting
bash install.sh --dry-run      # Preview changes without modifying anything
bash install.sh --hooks-only   # Install hooks only; skip settings.json merge
```

The installer:

1. Validates prerequisites (bash 3.2+, jq, valid source files)
2. Creates `~/.claude/hooks/` and `~/.claude/hooks/lib/`
3. Backs up any existing hooks to a timestamped backup directory
4. Copies hook scripts and `lib/common.sh`
5. Merges `config/settings-hooks.json` into `~/.claude/settings.json`
6. Runs the test suite

## Uninstallation

```bash
bash uninstall.sh              # Remove known hooks and clean settings.json
bash uninstall.sh --dry-run    # Preview what would be removed
```

The uninstaller removes only the 11 known hooks. Custom hooks you added are preserved. Backups in `~/.claude/hooks/backup/` are also preserved.

## Testing

```bash
bash tests/run-tests.sh
```

The test runner discovers `test_*` functions from `tests/test-*.sh` files and executes them. Each test file uses fixtures from `tests/fixtures/` and the assertion helpers (`assert_exit`, `assert_output_contains`, `assert_output_not_contains`) provided by the runner.

## Architecture

### `hooks/lib/common.sh` — Shared Library

All hooks source `lib/common.sh` which provides:

- **`parse_input`** — Reads stdin JSON, populates `HOOK_INPUT`, `HOOK_TOOL_NAME`, `HOOK_FILE_PATH`, `HOOK_SESSION_ID`, `HOOK_CWD`
- **`extract_content`** — Sets `HOOK_CONTENT` based on tool type (Write, Edit, MultiEdit, Bash)
- **`guard_stop_loop`** — Prevents infinite loops in Stop hooks by checking `stop_hook_active`
- **`classify_file`** — Classifies a file path as `test`, `config`, `source`, or `other`
- **`session_tmp`** — Returns a session-scoped temp file path
- **`cleanup_stale_temps`** — Removes temp files older than 24 hours
- **`require_jq`** — Validates jq is available

### Exit Code Contract

| Exit Code | PreToolUse | All Other Events |
|-----------|------------|------------------|
| **0** | Allow action | Normal completion |
| **1** | Allow action (hook error, fails open) | Acceptable error |
| **2** | **Block action** | (ignored) |

See [docs/exit-codes.md](docs/exit-codes.md) for the full reference.

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for common issues and solutions.

## Companion Article

For the design rationale and lessons learned building this system, see the companion article (link TBD).

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.
