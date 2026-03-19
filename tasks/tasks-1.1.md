## Summary (tasks-1.1.md)

- **Tasks in this file**: 7
- **Task IDs**: 000 - 005
- **Total Points**: 23

### Phase 1: Foundation (P0) -- Part 1

Establishes the settings schema baseline, copies existing hooks, builds the shared library, test infrastructure, fixtures, baseline tests, and the health-check hook. These are the foundational components that all subsequent work depends on.

---

## Tasks

### Task ID: 000

- **Title**: Reconcile settings.json schema with actual Claude Code format
- **File**: docs/settings-schema-reference.md
- **Complete**: [x]
- **Sprint Points**: 2

- **User Story (business-facing)**: As a hook developer, I want a documented reference of the actual Claude Code settings.json hook schema, so that the installer, uninstaller, and all config references use the correct format and do not produce broken configuration.
- **Outcome (what this delivers)**: A reference document capturing the actual `~/.claude/settings.json` hook schema, with corrections applied to the discovery doc and all downstream task references.

#### Prompt:

```markdown
**Objective:** Document the actual settings.json hook schema and reconcile it with the assumed schema in the discovery document and tasks.
**File to Create:** `docs/settings-schema-reference.md`
**Discovery Reference:** Section 9 (Settings Merge Format)

**Prerequisites:**
- Read the actual `~/.claude/settings.json` file to determine the real hook entry structure
- Compare against the schema assumed in the discovery document

**Detailed Instructions:**

1. Read `~/.claude/settings.json` and document the actual hook entry structure.
   The real format uses a nested structure per lifecycle event:
   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Write|Edit",
           "hooks": [
             { "type": "command", "command": "bash ~/.claude/hooks/secrets-check.sh", "timeout": 3000 }
           ]
         }
       ]
     }
   }
   ```
   NOT the flat structure (matcher per hook entry) assumed in the discovery document.

2. Create `docs/settings-schema-reference.md` documenting:
   - The actual schema with annotated examples
   - Key differences from common assumptions
   - How the installer's jq merge logic must handle the nested structure
   - How the uninstaller's removal logic must match by command path within nested hooks arrays

3. Note implications for Tasks 021, 023, and 024 which all need to use the correct schema.

**Acceptance Criteria:**
- [ ] Actual settings.json schema is documented with examples
- [ ] Nested `matcher -> hooks[]` structure is clearly explained
- [ ] Merge and removal strategies are described for the correct schema
- [ ] Document is under 100 lines
```

---

### Task ID: 000-1

- **Title**: Copy existing hook scripts into repository as baseline
- **File**: hooks/
- **Complete**: [x]
- **Sprint Points**: 1

- **User Story (business-facing)**: As a hook developer, I want the existing hook scripts copied into the repository as-is, so that baseline tests can validate current behavior before any modifications begin.
- **Outcome (what this delivers)**: All 10 existing hook scripts from `~/.claude/hooks/` copied verbatim into `hooks/` in the repository, preserving the unmodified baseline.

#### Prompt:

```markdown
**Objective:** Copy the existing hook scripts into the repository as the unmodified baseline.
**Target Directory:** `hooks/`

**Prerequisites:**
- None -- this is the very first implementation task

**Detailed Instructions:**

1. Create the `hooks/` directory in the repository
2. Copy all `.sh` files from `~/.claude/hooks/` into `hooks/`:
   - secrets-check.sh
   - file-org-check.sh
   - commit-format-check.sh
   - file-size-check.sh
   - tdd-tracker.sh
   - tdd-reminder.sh
   - memory-ops-confirm.sh
   - memory-nudge.sh
   - guidelines-reminder.sh
   - pre-compact-guidelines.sh
3. Do NOT modify any file content -- these are the verbatim originals
4. Make all scripts executable (`chmod +x`)
5. Do NOT copy lib/ or any other directories yet -- those are created by later tasks

**Acceptance Criteria:**
- [ ] All 10 hook scripts are present in hooks/
- [ ] Files are byte-identical to the originals in ~/.claude/hooks/
- [ ] All scripts are executable
- [ ] No modifications made to any file content
```

---

### Task ID: 001

- **Title**: Create shared utilities library (lib/common.sh)
- **File**: hooks/lib/common.sh
- **Complete**: [x]
- **Sprint Points**: 5

- **User Story (business-facing)**: As a hook developer, I want a shared utilities library with input parsing, file classification, and dependency validation, so that all hooks use consistent, tested, and fail-loud patterns instead of duplicated boilerplate.
- **Outcome (what this delivers)**: A `lib/common.sh` file providing `require_jq()`, `parse_input()`, `extract_content()`, `guard_stop_loop()`, `classify_file()`, `session_tmp()`, and `cleanup_stale_temps()` functions with `set -u` strict mode and `HOOK_` variable namespace.

#### Prompt:

```markdown
**Objective:** Create the shared utilities library that all hooks will eventually source.
**File to Create:** `hooks/lib/common.sh`
**Discovery Reference:** Section 5 (Proposal: Shared Utilities Library)

**Prerequisites:**
- Task 000-1 (copy existing hooks) must be complete
- Task 004 (baseline tests) should be complete -- ensures the unmodified hooks have a passing test baseline before any changes
- Review the complete API specification in Section 5 of the discovery document
- Review the strict mode decision (set -u yes, set -e no, set -o pipefail conditional)
- Review the classify_file precedence fix noted in Section 10.4

**Detailed Instructions:**

1. Create `hooks/lib/` directory and `common.sh` file
2. Add shebang `#!/usr/bin/env bash` and `set -u`
3. Add version comment: `# Version: 1.0.0`
4. Add usage documentation comment block explaining:
   - How to source the file
   - That sourcing does NOT consume stdin (parse_input must be called explicitly)
   - The HOOK_ variable namespace convention
5. Implement the following functions exactly as specified in Section 5:

   **require_jq()**: Validate jq is installed. Print error to stderr with install instructions. Return 1 on failure (callers decide exit code based on lifecycle event).

   **parse_input()**: Read stdin into HOOK_INPUT, validate jq, parse common fields (tool_name, file_path, session_id, cwd) using a single `jq -r` call with `@sh` formatting. Return 1 on parse failure.

   **extract_content()**: Case statement on HOOK_TOOL_NAME to extract content from Write (content), Edit (new_string), MultiEdit (edits[].new_string joined), Bash (command). Set HOOK_CONTENT.

   **guard_stop_loop()**: Read stop_hook_active from HOOK_INPUT, exit 0 if "true".

   **classify_file()**: Classify file path as "test", "source", "config", or "other". Test patterns MUST take precedence over source patterns. Use path-segment boundaries to avoid false matches. Handle common test patterns: test_ prefix, _test suffix, .test. and .spec. infixes, __tests__ and tests/ directories.

   **session_tmp()**: Return `/tmp/claude-${1}-${HOOK_SESSION_ID:-unknown}` path.

   **cleanup_stale_temps()**: Find and delete `/tmp/claude-*` files older than 24 hours. Suppress errors.

6. Initialize all HOOK_ variables to empty strings after set -u to prevent unbound variable errors before parse_input is called.

**Acceptance Criteria:**
- [ ] File is executable (`chmod +x`)
- [ ] `set -u` is active globally
- [ ] All exported variables use HOOK_ prefix
- [ ] `parse_input()` does NOT run on source -- stdin is only consumed when called explicitly
- [ ] `require_jq()` prints to stderr and returns 1 (not exit)
- [ ] `classify_file` correctly classifies source files, test files, config files, and handles known edge cases per Section 10.4
- [ ] `extract_content` handles Write, Edit, MultiEdit, Bash, and unknown tools
- [ ] File is under 150 lines
```

---

### Task ID: 002

- **Title**: Create test framework runner
- **File**: tests/run-tests.sh
- **Complete**: [x]
- **Sprint Points**: 3

- **User Story (business-facing)**: As a hook developer, I want a test runner that discovers and executes test functions from test files, so that I can validate hook behavior without running a full Claude Code session.
- **Outcome (what this delivers)**: A `run-tests.sh` script with `assert_exit`, `assert_output_contains`, and `assert_output_not_contains` helpers, plus automatic `test_*` function discovery from `test-*.sh` files.

#### Prompt:

```markdown
**Objective:** Create the test runner framework that all hook tests will use.
**File to Create:** `tests/run-tests.sh`
**Discovery Reference:** Section 6 (Proposal: Hook Testing Framework)

**Prerequisites:**
- Review the test runner design in Section 6
- Note that hooks use `exit` calls, so tests must run hooks in subshells (`bash ../hooks/script.sh`)

**Detailed Instructions:**

1. Create `tests/` directory and `run-tests.sh`
2. Add shebang and `set -u`
3. Implement counters: PASS=0, FAIL=0, ERRORS=""
4. Implement assert helpers:

   **assert_exit(expected, actual, label)**: Compare exit codes. Increment PASS or FAIL. Append to ERRORS on failure with format: `FAIL: {label} (expected exit {expected}, got {actual})`

   **assert_output_contains(needle, haystack, label)**: Check if needle exists in haystack using grep -q. Increment PASS or FAIL.

   **assert_output_not_contains(needle, haystack, label)**: Inverse of above.

5. Implement function discovery loop:
   - Resolve SCRIPT_DIR to absolute path
   - For each `test-*.sh` file in SCRIPT_DIR:
     - Print header with filename
     - Snapshot current functions with `declare -F`
     - Source the test file
     - Snapshot again, diff to find new `test_*` functions
     - Invoke each discovered function
   - After all files: print summary of pass/fail counts
   - Print accumulated ERRORS if any
   - Exit 1 if FAIL > 0, else exit 0

6. Add a helper function for running hooks safely in a subshell:
   ```bash
   run_hook() {
     local hook_script="$1"
     local fixture_file="$2"
     # Runs hook in subshell so exit calls don't kill the runner
     # Captures both stdout and stderr
   }
   ```

**Acceptance Criteria:**
- [ ] `run-tests.sh` is executable
- [ ] Discovers and runs `test_*` functions from all `test-*.sh` files in the same directory
- [ ] Reports pass/fail counts and detailed failure messages
- [ ] Exits 1 if any test fails, 0 if all pass
- [ ] Running with no test files produces 0 passed, 0 failed (not an error)
- [ ] Hooks run in subshells -- an `exit 2` in a hook does not kill the runner
```

---

### Task ID: 003

- **Title**: Create test fixture JSON files
- **File**: tests/fixtures/
- **Complete**: [x]
- **Sprint Points**: 2

- **User Story (business-facing)**: As a hook developer, I want representative JSON fixture files for each Claude Code lifecycle event, so that I can test hooks against realistic input without running a live session.
- **Outcome (what this delivers)**: A set of fixture JSON files in `tests/fixtures/` covering Write, Edit, MultiEdit, Bash, Stop, and SessionStart events with both clean and violation payloads.

#### Prompt:

```markdown
**Objective:** Create test fixture JSON files that mirror Claude Code's stdin format for each lifecycle event.
**Directory to Create:** `tests/fixtures/`
**Discovery Reference:** Section 6 (directory structure), Section 1 (shared patterns)

**Prerequisites:**
- Review the JSON field references in existing hook scripts at `~/.claude/hooks/`
- Note the fields used: tool_name, tool_input (file_path, content, new_string, edits, command), session_id, cwd, stop_hook_active

**Detailed Instructions:**

Create the following fixture files. Each must be valid JSON matching Claude Code's stdin format:

1. **write-clean.json**: Write tool with clean Python content, file_path `src/utils/helpers.py`
2. **write-with-secret.json**: Write tool with content containing a fake AWS access key pattern (A-K-I-A prefix followed by 16 alphanumeric chars). Use a clearly fake value.
3. **write-env-file.json**: Write tool with file_path `.env` and content containing a database URL
4. **write-root-source.json**: Write tool with file_path `app.py` (root-level source file, no directory prefix)
5. **edit-clean.json**: Edit tool with clean new_string, file_path `src/auth/login.py`
6. **edit-with-private-key.json**: Edit tool with new_string containing a BEGIN PRIVATE KEY header
7. **multiedit-clean.json**: MultiEdit tool with edits array containing two clean edits
8. **bash-git-commit-valid.json**: Bash tool with command using valid conventional commit format
9. **bash-git-commit-invalid.json**: Bash tool with command using non-conventional commit message
10. **bash-echo-secret-to-file.json**: Bash tool with echo command redirecting a fake secret pattern to a file
11. **bash-clean.json**: Bash tool with a harmless command like `ls -la src/`
12. **stop-normal.json**: Stop event with stop_hook_active: false, session_id present
13. **stop-recursive.json**: Stop event with stop_hook_active: true
14. **session-start.json**: SessionStart event with session_id

All secret/credential values in fixtures must be obviously fake test values. Reference the patterns used by secrets-check.sh in the discovery doc Section 2.1.

**Acceptance Criteria:**
- [ ] All 14 fixture files are valid JSON (pass `jq .` validation)
- [ ] Secret patterns use obviously fake test values
- [ ] File paths in fixtures are realistic project paths
- [ ] Each fixture includes session_id and cwd fields where applicable
- [ ] Stop fixtures include stop_hook_active field
- [ ] Bash commit fixtures use realistic git commit command formats
```

---

### Task ID: 004

- **Title**: Write baseline tests for existing hook behavior
- **File**: tests/test-secrets.sh, tests/test-file-org.sh, tests/test-commit.sh, tests/test-file-size.sh, tests/test-tdd.sh
- **Complete**: [x]
- **Sprint Points**: 8

- **User Story (business-facing)**: As a hook developer, I want baseline tests that validate current hook behavior, so that I can refactor and improve hooks with confidence that existing functionality is preserved.
- **Outcome (what this delivers)**: Test files covering the core behavior of secrets-check, file-org-check, commit-format-check, file-size-check, and tdd-tracker/tdd-reminder hooks using the fixture files and test runner.

#### Prompt:

```markdown
**Objective:** Write baseline tests for existing hooks to establish a regression safety net before making changes.
**Files to Create:** `tests/test-secrets.sh`, `tests/test-file-org.sh`, `tests/test-commit.sh`, `tests/test-file-size.sh`, `tests/test-tdd.sh`
**Discovery Reference:** Section 6 (test examples), Section 2 (gap analysis for known behaviors)

**Prerequisites:**
- Task 000-1 (copy existing hooks) must be complete -- baseline tests exercise the ORIGINAL unmodified hooks
- Task 002 (run-tests.sh) must be complete
- Task 003 (fixtures) must be complete
- Do NOT depend on Task 001 (common.sh) -- baseline tests must validate behavior before any modifications

**Detailed Instructions:**

Each test file should define `test_*` functions. Use the `run_hook` helper from run-tests.sh. Reference hooks relative to the test directory.

**test-secrets.sh:**
- Test that writes containing AWS key patterns are blocked (exit 2)
- Test that writes to .env files are blocked (exit 2)
- Test that edits containing private key headers are blocked (exit 2)
- Test that clean writes are allowed (exit 0)
- Test that clean edits are allowed (exit 0)

**test-file-org.sh:**
- Test that root-level source files are blocked (exit 2)
- Test that properly nested source files are allowed (exit 0)

**test-commit.sh:**
- Test that valid conventional commits are allowed (exit 0)
- Test that invalid commit formats are blocked (exit 2)
- Test that non-commit bash commands are ignored (exit 0)

**test-file-size.sh:**
- Test that the hook produces warnings for large files (PostToolUse, so exit 0 always)
- Test that small files produce no warning output

**test-tdd.sh:**
- Test that tdd-tracker records source file writes to temp file
- Test that tdd-tracker records test file writes
- Test that tdd-reminder warns when only source files present
- Test that tdd-reminder is silent when both source and test files present
- Test that tdd-reminder exits immediately on stop_hook_active: true

**Important:** Each test function must clean up any temp files it creates.

**Acceptance Criteria:**
- [ ] All test files follow the test_* function naming convention
- [ ] Tests use fixtures from tests/fixtures/
- [ ] Tests clean up temp files after each test function
- [ ] Running `bash tests/run-tests.sh` discovers and runs all tests
- [ ] All baseline tests pass against the current hook implementations
- [ ] At least 15 test functions across all test files
```

---

### Task ID: 005

- **Title**: Create hook-health-check.sh (SessionStart dependency validation)
- **File**: hooks/hook-health-check.sh
- **Complete**: [x]
- **Sprint Points**: 2

- **User Story (business-facing)**: As a Claude Code user, I want to be warned at session start if hook dependencies are missing or misconfigured, so that I know immediately when my enforcement system is degraded.
- **Outcome (what this delivers)**: A SessionStart hook that validates jq installation, script executability, and common.sh availability, emitting clear warnings that Claude relays to the user.

#### Prompt:

```markdown
**Objective:** Create a SessionStart hook that validates the hook environment on every session start.
**File to Create:** `hooks/hook-health-check.sh`
**Discovery Reference:** Section 2.2 Part A (Startup Validation)

**Prerequisites:**
- Task 001 (lib/common.sh) must be complete
- Understand that SessionStart hooks CANNOT block (exit codes are informational per Section 1)

**Detailed Instructions:**

1. Add shebang `#!/usr/bin/env bash`
2. Source lib/common.sh for set -u and utility functions
3. Call parse_input to consume stdin (SessionStart still provides JSON)
4. Initialize an ERRORS variable
5. Check dependencies:
   - `jq` is installed (`command -v jq`)
   - `wc` is available (`command -v wc`)
   - `bash` version is 3.2+ (macOS default)
6. Validate each hook script in the hooks directory:
   - Check that each `.sh` file is executable
   - Check that `lib/common.sh` exists and is readable
7. Call `cleanup_stale_temps` to prune old temp files (Section 10.3)
8. If any errors: print diagnostic output with remediation guidance
9. If no errors: print summary of validated hooks count
10. Always exit 0 (SessionStart cannot block)

**Acceptance Criteria:**
- [ ] Script sources lib/common.sh
- [ ] Detects missing jq and reports it
- [ ] Detects non-executable hook scripts and reports them
- [ ] Calls cleanup_stale_temps for temp file maintenance
- [ ] Always exits 0 regardless of findings
- [ ] Output is clear enough for Claude to relay to the user
- [ ] Calls `cleanup_stale_temps` to prune /tmp/claude-* files older than 24h (absorbs Task 019 scope)
- [ ] A test verifies old temp files are cleaned while recent files are preserved
- [ ] Script is under 50 lines
```
