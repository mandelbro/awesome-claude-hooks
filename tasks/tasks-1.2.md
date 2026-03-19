## Summary (tasks-1.2.md)

- **Tasks in this file**: 5
- **Task IDs**: 006 - 010
- **Total Points**: 17

### Phase 1: Foundation (P0) -- Part 2 + Phase 2 Start (P1)

Completes the P0 security fixes (silent failures, Bash secrets bypass) with regression tests, then begins Phase 2 with commit format and TDD tracker improvements.

---

## Tasks

### Task ID: 006

- **Title**: Integrate require_jq and set -u into blocking hooks
- **File**: hooks/secrets-check.sh, hooks/file-org-check.sh, hooks/commit-format-check.sh
- **Complete**: [x]
- **Sprint Points**: 3

- **User Story (business-facing)**: As a Claude Code user, I want blocking hooks (PreToolUse) to fail loudly when jq is missing, so that a broken dependency does not silently disable my security enforcement.
- **Outcome (what this delivers)**: All PreToolUse hooks use `require_jq` with `exit 2` on failure, and `set -u` catches undefined variables instead of silently falling through.

#### Prompt:

```markdown
**Objective:** Fix the silent failure mode in PreToolUse hooks by integrating require_jq and set -u.
**Files to Modify:** `hooks/secrets-check.sh`, `hooks/file-org-check.sh`, `hooks/commit-format-check.sh`
**Discovery Reference:** Section 2.2 Parts B and C

**Prerequisites:**
- Task 001 (lib/common.sh) must be complete
- Task 004 (baseline tests) must be complete -- run tests before and after to confirm no regressions
- Copy current hooks from `~/.claude/hooks/` to `hooks/` if not already done

**Detailed Instructions:**

For each of the three PreToolUse hooks:

1. Add `source "$(dirname "$0")/lib/common.sh"` near the top (after shebang)
2. Replace the manual `INPUT=$(cat)` + individual `jq` calls with a call to `parse_input`. On parse failure, exit 2 (block the action for safety since we cannot verify the content)
3. Replace individual `jq` field extractions with HOOK_ variables
4. Remove all `2>/dev/null` from jq calls (the shared library handles errors)
5. Update content extraction to use `extract_content` where applicable

**Important:** Do NOT change the core detection logic in each hook at this point. This task is specifically about replacing the input parsing and error handling, not about changing what the hooks detect. The Bash secrets scanning (Task 007) is a separate change.

**Testing:**
- Run baseline tests (Task 004) before changes to confirm green
- Run again after changes to confirm no regressions
- Verify that with jq unavailable, the hooks now exit 2 with an error message instead of silently passing

**Acceptance Criteria:**
- [ ] All three hooks source lib/common.sh
- [ ] All three hooks use parse_input with exit 2 on failure
- [ ] No `2>/dev/null` remains on jq calls in these hooks
- [ ] Missing jq causes exit 2 with clear error message (not silent pass-through)
- [ ] All baseline tests still pass
- [ ] No changes to detection logic -- only input parsing and error handling
```

---

### Task ID: 007

- **Title**: Implement Bash command secrets scanning with settings.json matcher
- **File**: hooks/secrets-check.sh
- **Complete**: [x]
- **Sprint Points**: 5

- **User Story (business-facing)**: As a Claude Code user, I want secrets detection to also scan Bash commands that write files, so that shell redirections writing credentials are caught the same way direct file writes are caught.
- **Outcome (what this delivers)**: The secrets-check hook fires on Bash tool use and scans commands for secret patterns combined with write operators (>, >>, tee, heredoc).

#### Prompt:

```markdown
**Objective:** Close the only unguarded secret injection path by adding Bash command scanning to secrets-check.sh. This is an atomic change -- the script update and settings.json matcher update must ship together.
**Files to Modify:** `hooks/secrets-check.sh`
**Files to Create/Modify:** `config/settings-hooks.json` (add Bash to secrets-check matcher)
**Discovery Reference:** Section 2.1 (Bash Command Bypass for Secrets + Missing Bash Matcher)

**Prerequisites:**
- Task 006 (require_jq integration) must be complete
- Understand the false-positive risk: grep, log searches, etc. should NOT trigger
- Review the heuristic: only flag when command contains BOTH a secret pattern AND a write operator

**Detailed Instructions:**

**Part 1: Update secrets-check.sh**

1. The hook already uses extract_content from common.sh (Task 006). Verify HOOK_CONTENT contains the full command string when tool_name is Bash.

2. Add Bash-specific pre-filter logic AFTER content extraction:
   - For Bash commands, first check if the command contains a write operator (>, >>, tee, heredoc <<)
   - If no write operator is present, exit 0 immediately (command reads but does not write)
   - If a write operator IS present, proceed with the same secret pattern scanning used for Write/Edit

3. Apply the same secret patterns already used for Write/Edit:
   - AWS access key pattern (AKIA prefix + 16 chars)
   - Private key headers (BEGIN...PRIVATE KEY)
   - Generic secret assignment patterns (password/secret/api_key/token = value)

4. When a Bash command is blocked, the output message should indicate it was a Bash command and show a truncated version of the command.

**Part 2: Document matcher change for Task 021**

Document that the secrets-check matcher in `config/settings-hooks.json` (created in Task 021) must include Bash alongside Write, Edit, and MultiEdit. Do NOT create settings-hooks.json here -- Task 021 owns that file.

**Known Limitations (document in code comments):**
- Interpreted one-liners (python -c, ruby -e) bypass the write-operator heuristic
- Piped commands where the secret arrives via network, not the command string
- This is defense-in-depth, not a complete gate (Section 10.1)

**Testing:**
- Bash command echoing a secret to a file: should exit 2
- Clean bash command (ls, grep): should exit 0 (no write operator)
- Git commit command: should exit 0 (no secret pattern)
- Bash grep for a secret-like pattern: should exit 0 (no write operator)

**Acceptance Criteria:**
- [ ] Bash commands with secret patterns AND write operators are blocked (exit 2)
- [ ] Bash commands that only READ (grep, cat to stdout, ls) are NOT blocked
- [ ] Settings matcher includes Bash alongside Write, Edit, MultiEdit
- [ ] False-positive risk documented in code comments
- [ ] Blocked message includes the detected pattern and truncated command
- [ ] All existing secrets tests still pass (Write/Edit behavior unchanged)
```

---

### Task ID: 008

- **Title**: Write regression tests for Bash secrets scanning and silent failure fixes
- **File**: tests/test-secrets.sh, tests/test-health-check.sh
- **Complete**: [x]
- **Sprint Points**: 3

- **User Story (business-facing)**: As a hook developer, I want regression tests covering the Bash secrets bypass fix and the silent failure fixes, so that these critical security improvements cannot regress undetected.
- **Outcome (what this delivers)**: Additional test functions in test-secrets.sh for Bash scanning edge cases, plus a new test-health-check.sh for the SessionStart health check hook.

#### Prompt:

```markdown
**Objective:** Add regression tests for the Phase 1 security and reliability fixes.
**Files to Modify:** `tests/test-secrets.sh`
**Files to Create:** `tests/test-health-check.sh`
**Discovery Reference:** Section 2.1 (Bash bypass), Section 2.2 (silent failures), Section 6 (testing framework)

**Prerequisites:**
- Tasks 001-007 must be complete
- All existing tests must pass before adding new ones

**Detailed Instructions:**

**Add to test-secrets.sh -- Bash scanning tests:**
- Test: Bash echo-redirect with secret pattern -- should exit 2
- Test: Bash grep for secret pattern (no write operator) -- should exit 0
- Test: Bash cat to stdout (no redirect) -- should exit 0
- Test: Bash tee with secret pattern -- should exit 2
- Test: Bash heredoc with secret pattern -- should exit 2
- Test: Bash clean redirect (no secret pattern) -- should exit 0

**Create test-health-check.sh:**
- Test: health check always exits 0
- Test: health check reports missing dependencies (may require PATH manipulation)
- Test: health check reports non-executable hook scripts

**Create new fixture files as needed** in tests/fixtures/ for the new Bash test cases.

**Acceptance Criteria:**
- [ ] At least 6 new Bash-specific test functions in test-secrets.sh
- [ ] At least 2 test functions in test-health-check.sh
- [ ] All new fixtures are valid JSON
- [ ] All tests pass with `bash tests/run-tests.sh`
- [ ] Tests cover both blocking (exit 2) and allowing (exit 0) cases for Bash commands
```

---

### Task ID: 009

- **Title**: Fix commit format edge cases
- **File**: hooks/commit-format-check.sh
- **Complete**: [ ]
- **Sprint Points**: 3

- **User Story (business-facing)**: As a Claude Code user, I want the commit format checker to handle --message= flags, combined flags (-am), and heredoc messages, so that valid conventional commits are not silently bypassed.
- **Outcome (what this delivers)**: Improved commit message extraction that handles the known failure modes from Section 2.5, with Option A (simplify input) as the preferred approach.

#### Prompt:

```markdown
**Objective:** Fix commit format edge cases that cause valid commits to bypass validation or invalid commits to pass through.
**File to Modify:** `hooks/commit-format-check.sh`
**Discovery Reference:** Section 2.5 (Commit Format Edge Cases)

**Prerequisites:**
- Task 006 (require_jq integration) must be complete
- Review the failure mode table in Section 2.5
- Implement Option A (simplify extraction) unless heredoc support is strictly required

**Detailed Instructions:**

1. Update the commit message extraction to handle these formats:
   - `-m "message"` (already working)
   - `-m 'message'` (single quotes)
   - `--message="message"` (long flag with equals)
   - `--message "message"` (long flag with space)
   - `-am "message"` and `-cm "message"` (combined flags)

2. For heredoc format, extract the first non-empty content line between EOF markers.

3. If the commit message cannot be extracted (empty after all extraction attempts), log a warning but DO NOT block (exit 0). A broken extractor should degrade to permissive, not block valid commits.

4. Add code comments documenting the known limitation: shell parsing in shell is inherently fragile.

**Testing:**
- Valid conventional commit with -m flag: exit 0
- Invalid commit format: exit 2
- Create new fixtures for --message= and combined flags
- Non-commit bash commands: exit 0

**Acceptance Criteria:**
- [ ] `--message=` format is handled
- [ ] Combined flags (`-am`, `-cm`) are handled
- [ ] Heredoc extraction handles the common case
- [ ] Unextractable messages degrade to exit 0 (permissive) with a warning
- [ ] All existing commit format tests still pass
- [ ] Known limitations documented in code comments
```

---

### Task ID: 010

- **Title**: Fix TDD tracker clear-on-stop behavior
- **File**: hooks/tdd-tracker.sh, hooks/tdd-reminder.sh
- **Complete**: [ ]
- **Sprint Points**: 3

- **User Story (business-facing)**: As a Claude Code user, I want the TDD tracker to maintain a rolling window of file operations instead of clearing on every stop, so that multi-response coding cycles do not produce false negative TDD reminders.
- **Outcome (what this delivers)**: The TDD tracker uses a rolling window (last 5 stop events or 30 minutes) instead of clearing the tracker file on every Stop event.

#### Prompt:

```markdown
**Objective:** Fix the TDD tracker clear-on-stop behavior that causes false negatives across multi-response cycles.
**Files to Modify:** `hooks/tdd-tracker.sh`, `hooks/tdd-reminder.sh`
**Discovery Reference:** Section 2.4a (Fix clear-on-stop behavior), Section 3.4 (merged)

**Prerequisites:**
- Task 006 (require_jq integration) should be complete
- Review the current clear behavior in tdd-reminder.sh
- Review the rolling window recommendation: clear entries older than 5 stop events OR 30 minutes

**Detailed Instructions:**

1. **Modify tdd-tracker.sh** to record timestamps with each entry:
   Format: `TIMESTAMP:TYPE:PATH`
   Example: `1710700000:source:src/auth/middleware.py`

2. **Modify tdd-reminder.sh**:
   - Instead of clearing the entire tracker file on every stop, implement a rolling window:
     a. Calculate the cutoff timestamp (current time minus 30 minutes)
     b. Remove entries older than the cutoff
     c. Evaluate the remaining entries for TDD compliance
   - Only clear the tracker when both source AND test files are present in the window (indicating a complete TDD cycle)
   - If only source files exist in the window, emit the reminder but do NOT clear

3. **Keep the stop_hook_active guard** -- this is critical and must not be removed.

4. **Edge case: empty tracker file after pruning.** If all entries are older than 30 minutes and get pruned, treat this as "no activity" and skip the reminder.

**Testing:**
- Update test-tdd.sh with new tests:
  - Verify entries include timestamp prefix
  - Verify entries persist across simulated stop events when only source files present
  - Verify tracker clears when both source + test entries exist

**Acceptance Criteria:**
- [ ] Tracker entries include timestamps in format `TIMESTAMP:TYPE:PATH`
- [ ] Entries older than 30 minutes are pruned
- [ ] Tracker is only cleared when a complete TDD cycle is detected (source + test)
- [ ] Source-only entries persist across stop events until either a test is written or they age out
- [ ] stop_hook_active guard is preserved
- [ ] All existing TDD tests pass (may need updating for new format)
```
