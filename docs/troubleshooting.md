# Troubleshooting

Common issues and solutions for Claude Code user hooks.

## 1. Hooks Not Firing

**Symptoms:** No hook output appears. Claude operates without any guardrails.

**Causes and fixes:**

- **Settings not merged:** Run `bash install.sh --force` to merge hook configuration into `~/.claude/settings.json`. If you used `--hooks-only`, settings were skipped.
- **Wrong path in settings.json:** Hook commands must reference `~/.claude/hooks/<name>.sh`. Verify paths in `~/.claude/settings.json` match actual file locations.
- **Hooks not executable:** Run `chmod +x ~/.claude/hooks/*.sh`.
- **Matcher mismatch:** The `matcher` field in settings.json is a regex. Verify it matches the tool names Claude is using (e.g., `Write`, not `write`).
- **Claude Code version:** Hooks require Claude Code with hook support. Update to the latest version.

## 2. Hooks Silently Passing Everything

**Symptoms:** Hooks run but never block anything, even for obvious violations.

**Causes and fixes:**

- **Missing jq:** Hooks fail open (exit 1) when jq is missing because `parse_input` crashes. Install jq: `brew install jq` (macOS) or `apt-get install jq` (Linux).
- **Bash syntax error:** A crash in a PreToolUse hook exits 1 (allow) not 2 (block). Run `bash -n hooks/<name>.sh` to check syntax.
- **lib/common.sh missing:** If the shared library is absent, `source` fails and the hook crashes. Verify `~/.claude/hooks/lib/common.sh` exists.
- **Verify with health check:** Run `echo '{}' | bash ~/.claude/hooks/hook-health-check.sh` to validate the environment.

## 3. False Positives from Secrets Check

**Symptoms:** `secrets-check.sh` blocks legitimate code containing words like "key" or "token".

**Causes and fixes:**

- **Pattern too broad:** The secrets check uses specific patterns (e.g., AWS key ID prefixes, PEM private key headers). If you see false positives, check which pattern matched in the BLOCKED output.
- **Test data with real-looking secrets:** Use obviously fake values in test fixtures. The hook cannot distinguish real from fake secrets.
- **Bash read-only commands flagged:** Secrets in Bash commands are only flagged when combined with write operators (`>`, `>>`, `tee`). Read-only commands like `grep` should pass. If not, file an issue.

## 4. TDD Reminders Not Appearing

**Symptoms:** You write source files without tests but the Stop hook does not remind you.

**Causes and fixes:**

- **Tracker not running:** The `tdd-tracker.sh` (PostToolUse) must run to record file writes. Verify it is registered in settings.json under PostToolUse.
- **Session mismatch:** The tracker and reminder use session-scoped temp files. If the session ID changes, the reminder loses context.
- **30-minute window:** The TDD reminder uses a rolling 30-minute window. Files written more than 30 minutes ago are excluded.
- **File classification:** Only files classified as `source` by `classify_file` trigger the reminder. Config, test, and other file types are ignored.

## 5. Commit Format Check Issues

**Symptoms:** Conventional commit format check blocks valid commits or allows invalid ones.

**Causes and fixes:**

- **Not a git commit command:** The hook only activates for Bash commands containing `git commit`. Other Bash commands pass through.
- **Message extraction:** The hook parses the commit message from `-m "..."` or `-m '...'` flags. Heredoc-style messages and `--message=` syntax are also supported.
- **Allowed types:** The default conventional commit types are: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`. Scope is optional.
- **Amend commits:** Amend without `-m` is allowed through since the message is not being changed.

## 6. Temp Files Accumulating

**Symptoms:** Many `/tmp/claude-*` files accumulate over time.

**Causes and fixes:**

- **Normal behavior:** Hooks create session-scoped temp files for tracking state (e.g., TDD tracker, memory nudge counter). These are expected.
- **Automatic cleanup:** The `cleanup_stale_temps` function removes files older than 24 hours. It runs during `hook-health-check.sh` on session start.
- **Manual cleanup:** Run `find /tmp -name 'claude-*' -type f -mmin +1440 -delete` to remove stale files manually.
- **Disk space concern:** Each temp file is a few bytes. Thousands of sessions would be needed before this becomes a concern.

## 7. Installation Issues

**Symptoms:** The installer fails or produces unexpected results.

**Causes and fixes:**

- **"jq is required" error:** Install jq before running the installer. It is needed for settings.json merging.
- **"bash 3.2+ required" error:** Upgrade bash. On macOS, the default `/bin/bash` is 3.2 which is sufficient. If using a custom shell, ensure bash is in your PATH.
- **Permission denied:** Make sure `install.sh` is executable: `chmod +x install.sh`.
- **Settings merge conflict:** If `~/.claude/settings.json` has malformed JSON, the merge will fail. Fix the JSON first: `jq . ~/.claude/settings.json` to validate.
- **Backup restoration:** If something goes wrong, the installer creates backups at `~/.claude/hooks/backup/<timestamp>/`. Copy files back from there.
- **Partial install:** Run `bash install.sh --force` again. The installer is idempotent and safe to re-run.

## 8. Hook Timeout Errors

**Symptoms:** Claude reports a hook timed out.

**Causes and fixes:**

- **Slow jq parsing:** Large JSON inputs can slow jq. The default timeout is 3000-5000ms, which should be sufficient for normal inputs.
- **Network calls in hooks:** Hooks should not make network calls. All logic should be local and fast.
- **Increase timeout:** Edit `config/settings-hooks.json` and increase the `timeout` value (in milliseconds) for the affected hook.

## Getting More Help

1. Run the health check: `echo '{}' | bash ~/.claude/hooks/hook-health-check.sh`
2. Run the test suite: `bash tests/run-tests.sh`
3. Check hook output manually: `echo '<json>' | bash hooks/<name>.sh`
4. Review [docs/exit-codes.md](exit-codes.md) for exit code behavior
