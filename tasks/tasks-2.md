## Summary (tasks-2.md)

- **Tasks in this file**: 8
- **Task IDs**: 011 - 020 (017 and 019 eliminated -- folded into 013 and 005 respectively)
- **Total Points**: 15

### Phase 2 End (P1) + Phase 3: Clean Up (P2)

Phase 2 concludes with the TDD naming-convention spike and Phase 2 regression tests. Phase 3 migrates all hooks to the shared library, fixes latent bugs, and adds documentation for future hook development.

---

## Tasks

### Task ID: 011

- **Title**: Spike: TDD naming-convention matcher design
- **File**: docs/spike-tdd-naming-convention.md
- **Complete**: [x]
- **Sprint Points**: 2

- **User Story (business-facing)**: As a hook developer, I want a documented design for correlating source files to their test files by naming convention, so that the TDD system can detect when a specific source file lacks a corresponding test (not just any test).
- **Outcome (what this delivers)**: A spike document defining the convention map per language, the matching algorithm, and the scope/limitations of naming-convention-based TDD correlation.

#### Prompt:

```markdown
**Objective:** Design (do not implement) a naming-convention matcher that correlates source files to test files.
**File to Create:** `docs/spike-tdd-naming-convention.md`
**Discovery Reference:** Section 2.4b (TDD naming-convention matcher)

**Prerequisites:**
- Task 010 (TDD tracker fix) should be complete
- Review the complexity discussion in Section 2.4b

**Detailed Instructions:**

Produce a spike document that covers:

1. **Convention Map**: For each supported language, document the expected test file naming convention:
   - Python: `src/module/file.py` -> `tests/module/test_file.py` OR `tests/test_module_file.py`
   - TypeScript/JavaScript: `src/module/file.ts` -> `src/module/__tests__/file.test.ts` OR `tests/module/file.test.ts`
   - Ruby: `lib/module/file.rb` -> `spec/module/file_spec.rb`
   - Go: `pkg/module/file.go` -> `pkg/module/file_test.go` (same directory)

2. **Matching Algorithm**: Given a source file path, generate candidate test file paths using the convention map. Check if any candidate exists OR was written during the current TDD window.

3. **Ambiguity Resolution**: When multiple conventions exist for a language, try each one. If ANY matches, consider it satisfied.

4. **Configuration**: Propose a simple config format (JSON or shell variables) for users to customize the convention map for their project structure.

5. **Scope and Limitations**:
   - What this catches: new source file without any correspondingly-named test file
   - What this misses: behavioral changes to existing files without test updates
   - False positives: utility files, generated files, config files that happen to match source patterns

6. **Implementation Estimate**: Based on the design, estimate the effort to implement as a `classify_and_match()` function in common.sh.

7. **Recommendation**: Implement or defer? Consider whether the complexity is justified given that the current binary check (source files exist + no test files = remind) catches the most common case.

**Acceptance Criteria:**
- [ ] Convention map covers at least Python, TypeScript/JavaScript, Ruby, and Go
- [ ] Matching algorithm is described with pseudocode
- [ ] Known ambiguities and limitations are documented
- [ ] Implementation effort is estimated
- [ ] Clear recommendation: implement, defer, or simplify
- [ ] Document is under 200 lines
```

---

### Task ID: 012

- **Title**: Write regression tests for Phase 2 fixes
- **File**: tests/test-commit.sh, tests/test-tdd.sh
- **Complete**: [x]
- **Sprint Points**: 2

- **User Story (business-facing)**: As a hook developer, I want regression tests for the commit format and TDD tracker fixes, so that Phase 2 improvements are protected against future regressions.
- **Outcome (what this delivers)**: Additional test functions covering the new commit format extraction patterns and the TDD rolling-window behavior.

#### Prompt:

```markdown
**Objective:** Add regression tests for Phase 2 changes (commit format edge cases and TDD rolling window).
**Files to Modify:** `tests/test-commit.sh`, `tests/test-tdd.sh`
**Discovery Reference:** Section 2.5 (commit format), Section 2.4a (TDD tracker)

**Prerequisites:**
- Task 009 (commit format fix) must be complete
- Task 010 (TDD tracker fix) must be complete

**Detailed Instructions:**

**Add to test-commit.sh:**
- Test: `--message="feat: thing"` format is validated correctly
- Test: `-am "fix: resolve bug"` combined flag format is validated
- Test: heredoc with valid conventional commit is accepted
- Test: unextractable commit message degrades to exit 0 (not blocked)

**Add to test-tdd.sh:**
- Test: tracker entries include timestamp prefix after Task 010 changes
- Test: entries persist when only source files are in the rolling window
- Test: entries are pruned when older than 30-minute window
- Test: tracker clears when complete TDD cycle detected (source + test)
- Test: empty tracker after pruning produces no reminder

**Create new fixtures as needed.**

**Acceptance Criteria:**
- [ ] At least 4 new test functions in test-commit.sh
- [ ] At least 4 new test functions in test-tdd.sh
- [ ] All new fixtures are valid JSON
- [ ] All tests pass with `bash tests/run-tests.sh`
```

---

### Task ID: 013

- **Title**: Migrate Layer 1 hooks to shared library (guidelines, pre-compact)
- **File**: hooks/guidelines-reminder.sh, hooks/pre-compact-guidelines.sh
- **Complete**: [ ]
- **Sprint Points**: 2

- **User Story (business-facing)**: As a hook developer, I want all hooks to use the shared library consistently, so that boilerplate is eliminated and future maintenance touches one place instead of ten.
- **Outcome (what this delivers)**: guidelines-reminder.sh and pre-compact-guidelines.sh refactored to use common.sh, with the pre-compact source bug (Section 3.2) addressed as part of the migration.

#### Prompt:

```markdown
**Objective:** Migrate the Layer 1 (context injection) hooks to use lib/common.sh.
**Files to Modify:** `hooks/guidelines-reminder.sh`, `hooks/pre-compact-guidelines.sh`
**Discovery Reference:** Section 2.6 (Hook Maintainability), Section 3.2 (pre-compact source bug), Section 5 (Migration Impact)

**Prerequisites:**
- Task 001 (lib/common.sh) must be complete
- Task 004 (baseline tests) should be passing

**Detailed Instructions:**

**guidelines-reminder.sh:**
1. Source lib/common.sh
2. Replace manual INPUT parsing with parse_input (if the script reads stdin)
3. The core of this hook is the heredoc output -- preserve that entirely
4. Estimated reduction: ~63 lines to ~45 lines

**pre-compact-guidelines.sh:**
1. Source lib/common.sh
2. **Fix Section 3.2 bug:** Currently this script sources guidelines-reminder.sh, which calls `INPUT=$(cat)` consuming pre-compact's stdin. Fix by extracting the guidelines content into a shared data source (function or file) that both scripts use without stdin interaction.
3. Options:
   a. Extract guidelines heredoc into a function `emit_guidelines()` in guidelines-reminder.sh that both scripts call
   b. Move guidelines content to `config/guidelines-template.txt` and have both scripts cat it
   c. Have pre-compact call guidelines-reminder.sh as a subprocess instead of sourcing it
4. Option (a) is recommended -- it keeps the content co-located with guidelines-reminder.sh while avoiding the stdin consumption issue.

**Testing:**
- Verify guidelines output is unchanged after migration
- Verify pre-compact produces the same output
- All existing tests still pass

**Acceptance Criteria:**
- [ ] Both hooks source lib/common.sh
- [ ] pre-compact no longer sources guidelines-reminder.sh directly (Section 3.2 fix)
- [ ] Guidelines content is shared via a function or file, not stdin consumption
- [ ] Output of both hooks is identical to pre-migration behavior
- [ ] All tests pass
- [ ] (Absorbed from Task 017) A regression test verifies pre-compact works independently without sourcing guidelines-reminder.sh
- [ ] (Absorbed from Task 017) Code comment explains WHY sourcing guidelines-reminder.sh directly is dangerous
```

---

### Task ID: 014

- **Title**: Migrate Layer 2 blocking hooks to shared library
- **File**: hooks/secrets-check.sh, hooks/file-org-check.sh, hooks/commit-format-check.sh
- **Complete**: [ ]
- **Sprint Points**: 2

- **User Story (business-facing)**: As a hook developer, I want the Layer 2 blocking hooks fully migrated to shared library patterns, so that content extraction, file classification, and error handling are consistent across all enforcement hooks.
- **Outcome (what this delivers)**: All three PreToolUse hooks fully use common.sh utilities for input parsing, content extraction, and file classification, with reduced line counts per the Section 5 migration impact table.

#### Prompt:

```markdown
**Objective:** Complete the migration of Layer 2 blocking hooks to lib/common.sh. Task 006 added parse_input; this task completes the migration by replacing remaining duplicated logic with shared functions.
**Files to Modify:** `hooks/secrets-check.sh`, `hooks/file-org-check.sh`, `hooks/commit-format-check.sh`
**Discovery Reference:** Section 2.6 (Hook Maintainability), Section 5 (Migration Impact table)

**Prerequisites:**
- Task 006 (require_jq integration) -- hooks already source common.sh and use parse_input
- Task 007 (Bash secrets) -- secrets-check already has Bash handling
- Task 009 (commit format fix) -- commit-format-check already has edge case handling

**Detailed Instructions:**

For each hook, replace remaining duplicated logic:

**secrets-check.sh** (target: ~35 lines from 64):
1. Replace manual content extraction with `extract_content`
2. Use HOOK_FILE_PATH instead of manual jq extraction for .env file checking
3. Consolidate the secret pattern matching into a clear function

**file-org-check.sh** (target: ~45 lines from 65):
1. Replace manual file extension classification with `classify_file`
2. Use HOOK_FILE_PATH from parse_input
3. Simplify the root-file detection logic using shared variables
4. **Add allowlist for expected root files**: `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `LICENSE`, `Makefile`, `Justfile` -- these are standard root-level files that should not be blocked. Without this, the hook blocks the project's own README.md (Task 025).

**commit-format-check.sh** (target: ~45 lines from 57):
1. Replace manual command extraction with HOOK_CONTENT from `extract_content`
2. The commit detection and validation logic is hook-specific -- keep it but simplify input handling

**Testing:**
- All baseline and regression tests must pass after migration
- No behavior changes expected -- this is pure refactoring

**Acceptance Criteria:**
- [ ] secrets-check.sh is under 40 lines
- [ ] file-org-check.sh is under 50 lines
- [ ] commit-format-check.sh is under 50 lines
- [ ] No duplicated jq calls remain in any of the three hooks
- [ ] All tests pass with no behavior changes
```

---

### Task ID: 015

- **Title**: Migrate PostToolUse hooks to shared library
- **File**: hooks/file-size-check.sh, hooks/tdd-tracker.sh, hooks/memory-ops-confirm.sh
- **Complete**: [ ]
- **Sprint Points**: 3

- **User Story (business-facing)**: As a hook developer, I want PostToolUse hooks migrated to the shared library, so that file size checking, TDD tracking, and memory operation logging all benefit from consistent input parsing and error handling.
- **Outcome (what this delivers)**: file-size-check.sh, tdd-tracker.sh, and memory-ops-confirm.sh fully use common.sh utilities.

#### Prompt:

```markdown
**Objective:** Migrate PostToolUse hooks to use lib/common.sh consistently.
**Files to Modify:** `hooks/file-size-check.sh`, `hooks/tdd-tracker.sh`, `hooks/memory-ops-confirm.sh`
**Discovery Reference:** Section 2.6 (Hook Maintainability), Section 5 (Migration Impact table)

**Prerequisites:**
- Task 001 (lib/common.sh) must be complete
- Task 010 (TDD tracker fix) should be complete -- tdd-tracker already has timestamp format

**Detailed Instructions:**

**file-size-check.sh** (target: ~25 lines from 40):
1. Source lib/common.sh
2. Replace manual parsing with parse_input
3. Use HOOK_FILE_PATH for the file being checked
4. Keep the line-counting logic (wc -l) as-is -- that is hook-specific

**tdd-tracker.sh** (target: ~20 lines from 35):
1. Source lib/common.sh
2. Replace manual parsing with parse_input
3. Use `classify_file "$HOOK_FILE_PATH"` instead of inline classification
4. Use `session_tmp "tdd-tracker"` for temp file path
5. Keep the timestamp-prefixed recording format from Task 010

**memory-ops-confirm.sh** (target: ~55 lines from 70):
1. Source lib/common.sh
2. Replace manual parsing with parse_input
3. Use HOOK_TOOL_NAME for tool identification
4. The per-tool confirmation messages are hook-specific -- keep them

**Testing:**
- All existing tests must pass
- Verify file-size warnings still emit correctly
- Verify TDD tracker still records to temp file
- Verify memory-ops-confirm still outputs tool-specific messages

**Acceptance Criteria:**
- [ ] All three hooks source lib/common.sh
- [ ] No manual `INPUT=$(cat)` or direct jq calls remain
- [ ] File sizes reduced per migration impact estimates
- [ ] All tests pass with no behavior changes
```

---

### Task ID: 016

- **Title**: Migrate Stop hooks to shared library
- **File**: hooks/tdd-reminder.sh, hooks/memory-nudge.sh
- **Complete**: [ ]
- **Sprint Points**: 2

- **User Story (business-facing)**: As a hook developer, I want Stop hooks migrated to the shared library so that the stop_hook_active guard and session temp file patterns are centralized and consistent.
- **Outcome (what this delivers)**: tdd-reminder.sh and memory-nudge.sh fully use common.sh for input parsing, stop loop guard, and session temp file management.

#### Prompt:

```markdown
**Objective:** Migrate Stop hooks to use lib/common.sh, centralizing the stop_hook_active guard and temp file patterns.
**Files to Modify:** `hooks/tdd-reminder.sh`, `hooks/memory-nudge.sh`
**Discovery Reference:** Section 2.6, Section 2.7 (Stop Hook Loop Guard), Section 5 (Migration Impact)

**Prerequisites:**
- Task 001 (lib/common.sh) must be complete
- Task 010 (TDD reminder rolling window) should be complete

**Detailed Instructions:**

**tdd-reminder.sh** (target: ~25 lines from 46):
1. Source lib/common.sh
2. Replace manual parsing with parse_input
3. Replace inline stop_hook_active check with `guard_stop_loop`
4. Use `session_tmp "tdd-tracker"` for temp file path (must match tdd-tracker.sh)
5. Keep the rolling-window evaluation logic from Task 010

**memory-nudge.sh** (target: ~20 lines from 38):
1. Source lib/common.sh
2. Replace manual parsing with parse_input
3. Replace inline stop_hook_active check with `guard_stop_loop`
4. Use `session_tmp "memory-nudge-counter"` for the counter temp file
5. Keep the modulo-3 reminder logic

**Testing:**
- All existing TDD and stop-hook tests must pass
- Verify memory-nudge still fires every 3rd stop event
- Verify guard_stop_loop prevents recursive invocation

**Acceptance Criteria:**
- [ ] Both hooks source lib/common.sh
- [ ] Both hooks use `guard_stop_loop` instead of inline stop_hook_active check
- [ ] Both hooks use `session_tmp` for temp file paths
- [ ] No manual `INPUT=$(cat)` or direct jq calls remain
- [ ] All tests pass with no behavior changes
```

---

### ~~Task ID: 017~~ (ELIMINATED)

> **Folded into Task 013.** The pre-compact source bug fix and its regression test are now acceptance criteria of Task 013 (Layer 1 migration). See Task 013 for details.

---

### Task ID: 018

- **Title**: Add defensive error handling to memory-ops-confirm.sh
- **File**: hooks/memory-ops-confirm.sh
- **Complete**: [ ]
- **Sprint Points**: 1

- **User Story (business-facing)**: As a hook developer, I want memory-ops-confirm.sh to handle unrecognized tools explicitly, so that matcher configuration drift does not produce silent no-ops.
- **Outcome (what this delivers)**: The catchall case in memory-ops-confirm.sh logs a warning when an unrecognized tool reaches the hook, making configuration drift visible.

#### Prompt:

```markdown
**Objective:** Add defensive error handling for unrecognized tools in memory-ops-confirm.sh.
**File to Modify:** `hooks/memory-ops-confirm.sh`
**Discovery Reference:** Section 3.3 (memory-ops-confirm error path)

**Prerequisites:**
- Task 015 (PostToolUse migration) should be complete

**Detailed Instructions:**

1. In the tool-name case statement, update the catchall (`*`) pattern to emit a warning:
   ```
   [HOOK WARNING] memory-ops-confirm: Unrecognized tool '{tool_name}'. Check settings.json matcher configuration.
   ```
2. Still exit 0 (PostToolUse hooks cannot block).
3. The warning makes it visible when the settings.json matcher sends unexpected tools to this hook.

**Acceptance Criteria:**
- [ ] Unrecognized tools produce a warning message
- [ ] Hook still exits 0 for all inputs
- [ ] Warning includes the tool name for debugging
```

---

### ~~Task ID: 019~~ (ELIMINATED)

> **Folded into Task 005.** Temp file cleanup via `cleanup_stale_temps` and its test are now acceptance criteria of Task 005 (hook-health-check.sh). See Task 005 for details.

---

### Task ID: 020

- **Title**: Document stop_hook_active requirement for new hooks
- **File**: docs/exit-codes.md
- **Complete**: [ ]
- **Sprint Points**: 1

- **User Story (business-facing)**: As a hook developer adding new Stop hooks, I want clear documentation about the stop_hook_active guard requirement, so that I do not accidentally create an infinite loop.
- **Outcome (what this delivers)**: Documentation in the exit-codes reference explaining the stop_hook_active guard, why it is required for Stop hooks, and how guard_stop_loop() in common.sh handles it automatically.

#### Prompt:

```markdown
**Objective:** Document the stop_hook_active requirement to prevent future Stop hooks from missing the guard.
**File to Create/Modify:** `docs/exit-codes.md` (will be fully written in Task 027; add a section here)
**Discovery Reference:** Section 2.7 (Stop Hook Loop Guard Consistency)

**Prerequisites:**
- Task 016 (Stop hook migration) should be complete -- guard_stop_loop is now in common.sh

**Detailed Instructions:**

Create a preliminary `docs/exit-codes.md` with at minimum:

1. **Exit Code Semantics table** from Section 1 of the discovery document
2. **Stop Hook Guard section** explaining:
   - What stop_hook_active is and why it exists
   - The infinite loop scenario that occurs without the guard
   - How `guard_stop_loop()` in common.sh handles it automatically
   - That all new Stop hooks MUST either use guard_stop_loop() or implement the check manually
3. **Hook execution order note** from Section 10.5 explaining that exit 2 from an earlier hook prevents later hooks from running

This document will be expanded in Task 027 (Phase 4 documentation). This task creates the safety-critical content first.

**Acceptance Criteria:**
- [ ] Exit code semantics table is present and accurate
- [ ] Stop hook guard requirement is clearly documented
- [ ] Hook execution order dependency is documented
- [ ] Document references guard_stop_loop() in common.sh
```
