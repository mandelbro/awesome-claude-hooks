## Summary (tasks-3.2.md)

- **Tasks in this file**: 5
- **Task IDs**: 026 - 030
- **Total Points**: 8

### Phase 4: Repository Packaging -- Part 2 (Section 9)

Documentation and CI for the public hooks repository.

---

## Tasks

### Task ID: 026

- **Title**: Create customization guide documentation
- **File**: docs/customization.md
- **Complete**: [x]
- **Sprint Points**: 2

- **User Story (business-facing)**: As a user who wants to add or modify hooks, I want a guide explaining the hook development patterns, so that I can extend the system with my own custom hooks.
- **Outcome (what this delivers)**: A docs/customization.md guide covering how to create new hooks, use the shared library, handle different lifecycle events, and test custom hooks.

#### Prompt:

```markdown
**Objective:** Create a guide for users who want to add or modify hooks.
**File to Create:** `docs/customization.md`
**Discovery Reference:** Section 9 (Customization Guidance), Section 5 (Shared Library API)

**Prerequisites:**
- All hooks and shared library should be complete

**Detailed Instructions:**

Cover these topics:

1. **Adding a New Hook**:
   - Create the script file in `~/.claude/hooks/`
   - Source lib/common.sh
   - Call parse_input to read stdin
   - Use HOOK_ variables for tool input data
   - Add the hook entry to `~/.claude/settings.json`
   - Make the script executable

2. **Lifecycle Event Guide**:
   - When to use PreToolUse (blocking enforcement)
   - When to use PostToolUse (advisory warnings)
   - When to use SessionStart (setup, validation)
   - When to use Stop (end-of-cycle checks)
   - When to use PreCompact (context preservation)

3. **Shared Library Reference**:
   - All available functions with signatures and descriptions
   - HOOK_ variable reference
   - When to call parse_input vs extract_content

4. **Stop Hook Requirements**:
   - MUST use guard_stop_loop() to prevent infinite loops
   - Explain the stop_hook_active field

5. **Testing Custom Hooks**:
   - How to create fixture JSON files
   - How to add tests to the test suite
   - How to run tests

6. **Common Patterns**:
   - Blocking with exit 2 and a BLOCKED message
   - Advisory warnings (exit 0 with output)
   - Temp file management with session_tmp()

**Acceptance Criteria:**
- [ ] New hook creation process is documented step by step
- [ ] Each lifecycle event is explained with when/why to use it
- [ ] Shared library functions are referenced
- [ ] Stop hook guard requirement is prominent
- [ ] Testing process is documented
- [ ] Under 200 lines
```

---

### Task ID: 027

- **Title**: Complete exit-codes.md reference documentation
- **File**: docs/exit-codes.md
- **Complete**: [x]
- **Sprint Points**: 1

- **User Story (business-facing)**: As a hook developer, I want a quick reference for Claude Code hook exit code behavior, so that I choose the correct exit code for each lifecycle event without guessing.
- **Outcome (what this delivers)**: A complete docs/exit-codes.md reference expanding on the preliminary content from Task 020.

#### Prompt:

```markdown
**Objective:** Complete the exit-codes reference documentation.
**File to Modify:** `docs/exit-codes.md`
**Discovery Reference:** Section 1 (Exit Code Semantics), Section 10.2 (Exit Code 1 Fails Open)

**Prerequisites:**
- Task 020 should have created preliminary content
- Review the exit code table and implications in Section 1

**Detailed Instructions:**

Expand the document to include:

1. **Exit Code Table**: Full table from Section 1 with all lifecycle events and exit codes
2. **The "Fails Open" Design**: Explain that exit 1 (hook error) always allows the action to proceed. This is by design but means broken hooks silently stop protecting you.
3. **Choosing the Right Exit Code**:
   - PreToolUse: exit 2 to block, exit 0 to allow
   - All others: exit codes don't affect execution
4. **Common Mistakes**:
   - Using exit 1 thinking it will block (it won't)
   - Not checking for missing dependencies (hook crashes, action proceeds)
5. **The parse_input Safety Decision**: In the shared library, parse_input returns 1 on failure. For PreToolUse hooks, callers should convert this to exit 2 (block when we can't verify safety). For other hooks, exit 1 is fine.

**Acceptance Criteria:**
- [ ] All exit codes for all lifecycle events are documented
- [ ] Fails-open behavior is clearly explained
- [ ] Guidance for choosing exit codes is actionable
- [ ] Common mistakes are called out
- [ ] Under 100 lines
```

---

### Task ID: 028

- **Title**: Create troubleshooting guide
- **File**: docs/troubleshooting.md
- **Complete**: [x]
- **Sprint Points**: 2

- **User Story (business-facing)**: As a user experiencing issues with hooks, I want a troubleshooting guide covering common problems, so that I can diagnose and fix issues without reading the full discovery document.
- **Outcome (what this delivers)**: A docs/troubleshooting.md with common problems, diagnostic steps, and solutions.

#### Prompt:

```markdown
**Objective:** Create a troubleshooting guide for common hook issues.
**File to Create:** `docs/troubleshooting.md`
**Discovery Reference:** Section 10 (Risks and Known Limitations), Section 11 (Open Questions)

**Prerequisites:**
- All hooks, installer, and test framework should be complete

**Detailed Instructions:**

Cover these common issues:

1. **Hooks not firing at all**:
   - Check settings.json has the hook entries
   - Check scripts are executable (chmod +x)
   - Check matchers match the tool name
   - Run the test suite to validate

2. **Hooks silently passing everything**:
   - Check jq is installed
   - Run hook-health-check output at session start
   - Verify lib/common.sh is present and readable

3. **False positives from secrets-check**:
   - Documentation files containing example credential patterns
   - Workaround: the hook checks file content, not file type
   - Known limitation per Section 2.1 bonus finding

4. **TDD reminders not appearing**:
   - Check temp file exists at /tmp/claude-tdd-tracker-{session}
   - Verify tdd-tracker and tdd-reminder use the same session ID
   - Check the rolling window (entries may have aged out)

5. **Commit format check not catching invalid commits**:
   - Review the known edge cases from Section 2.5
   - Check that the Bash matcher is configured
   - Known limitation: shell parsing in shell is inherently fragile

6. **Temp files accumulating**:
   - Run a new session (health check cleans old files)
   - Manual cleanup: `rm /tmp/claude-*`

7. **Installation issues**:
   - jq not installed
   - Settings merge failed (use --hooks-only and merge manually)
   - Backup location for rollback

**Acceptance Criteria:**
- [ ] At least 7 common issues covered
- [ ] Each issue has diagnostic steps and a solution
- [ ] Known limitations are acknowledged honestly
- [ ] Under 150 lines
```

---

### Task ID: 029

- **Title**: Add CI workflow for test suite
- **File**: .github/workflows/test.yml
- **Complete**: [x]
- **Sprint Points**: 2

- **User Story (business-facing)**: As a contributor to the hooks repository, I want the test suite to run automatically on PRs and pushes, so that regressions are caught before merging.
- **Outcome (what this delivers)**: A GitHub Actions workflow that runs the test suite on push and PR events.

#### Prompt:

```markdown
**Objective:** Set up CI to run the hook test suite automatically.
**File to Create:** `.github/workflows/test.yml`
**Discovery Reference:** Section 2.3 (CI integration note: "Run them in any CI pipeline with bash run-tests.sh")

**Prerequisites:**
- Task 002 (test runner) must be complete
- Task 004 (baseline tests) and Task 008/012 (regression tests) should be complete

**Detailed Instructions:**

1. Create `.github/workflows/` directory
2. Create `test.yml` with:
   - **Trigger**: on push to main, on pull_request to main
   - **OS Matrix**: ubuntu-latest and macos-latest (hooks target both)
   - **Steps**:
     a. Checkout the repository
     b. Install jq (apt-get on ubuntu, brew on macos -- or verify it's pre-installed on runners)
     c. Make all scripts executable: `chmod +x hooks/*.sh hooks/lib/*.sh tests/*.sh`
     d. Run the test suite: `bash tests/run-tests.sh`
   - **Name**: "Hook Tests"

3. Keep the workflow minimal -- this is a bash-only project with no build step.

4. Consider adding a shellcheck step:
   ```yaml
   - name: Shellcheck
     run: shellcheck hooks/*.sh hooks/lib/*.sh
   ```
   This catches common bash issues (quoting, undefined variables, etc.) statically.

**Acceptance Criteria:**
- [ ] Workflow triggers on push and PR to main
- [ ] Tests run on both ubuntu and macOS
- [ ] jq is available in the CI environment
- [ ] All scripts are executable before test run
- [ ] Optional shellcheck step included
- [ ] Workflow file is valid YAML
```

---

### Task ID: 030

- **Title**: Run ShellCheck across all scripts and fix findings
- **File**: hooks/*.sh, hooks/lib/*.sh, tests/*.sh, install.sh, uninstall.sh
- **Complete**: [x]
- **Sprint Points**: 1

- **User Story (business-facing)**: As a contributor, I want all shell scripts to pass ShellCheck static analysis, so that common bash pitfalls (unquoted variables, deprecated patterns, unreachable code) are caught before release.
- **Outcome (what this delivers)**: All `.sh` files in the repository pass `shellcheck` with no errors or warnings (or documented exclusions where necessary).

#### Prompt:

```markdown
**Objective:** Run ShellCheck on all scripts and fix any findings.
**Files to Check:** `hooks/*.sh`, `hooks/lib/*.sh`, `tests/*.sh`, `install.sh`, `uninstall.sh`

**Prerequisites:**
- All scripts from Phases 1-4 must be complete
- ShellCheck must be installed (`brew install shellcheck` on macOS, `apt-get install shellcheck` on Ubuntu)

**Detailed Instructions:**

1. Run `shellcheck hooks/*.sh hooks/lib/*.sh tests/*.sh install.sh uninstall.sh`
2. Fix all errors and warnings
3. For findings that are intentional (e.g., dynamic variable names, sourced files), add `# shellcheck disable=SCNNNN` with a comment explaining why
4. Document any disabled checks in a comment at the top of the affected file

**Acceptance Criteria:**
- [ ] `shellcheck` runs clean on all scripts (exit 0)
- [ ] Any disabled checks have explanatory comments
- [ ] No SC2086 (unquoted variable) findings remain without justification
```
