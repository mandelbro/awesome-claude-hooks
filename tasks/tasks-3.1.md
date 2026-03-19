## Summary (tasks-3.1.md)

- **Tasks in this file**: 6
- **Task IDs**: 021 - 025 (includes 023-1)
- **Total Points**: 20

### Phase 4: Repository Packaging -- Part 1 (Section 9)

Configuration files, installer, uninstaller, and README for public distribution of the hooks system.

---

## Tasks

### Task ID: 021

- **Title**: Create settings-hooks.json configuration file
- **File**: config/settings-hooks.json
- **Complete**: [x]
- **Sprint Points**: 2

- **User Story (business-facing)**: As a user installing the hooks system, I want a JSON configuration file defining all hook entries, so that the installer can merge them into my existing Claude Code settings without manual editing.
- **Outcome (what this delivers)**: A `config/settings-hooks.json` file containing all hook entries organized by lifecycle event, ready for the installer to merge into `~/.claude/settings.json`.

#### Prompt:

```markdown
**Objective:** Create the settings-hooks.json file that the installer uses to merge hook entries into the user's settings.json.
**File to Create:** `config/settings-hooks.json`
**Discovery Reference:** Section 9 (Settings Merge Format)

**Prerequisites:**
- Task 000 (settings schema reconciliation) must be complete -- use the ACTUAL nested schema documented there
- All hook scripts from Phases 1-3 must be complete (or at least their file names and matchers finalized)
- Review `docs/settings-schema-reference.md` (Task 000) for the correct nested `matcher -> hooks[]` structure
- Review the complete settings structure in Section 9 (note: discovery doc may use simplified flat schema -- the actual schema is nested)

**Detailed Instructions:**

1. Create `config/` directory
2. Create `settings-hooks.json` with the complete hook configuration:
   - **SessionStart**: hook-health-check.sh (matcher: startup|resume), guidelines-reminder.sh (matcher: startup|resume|compact)
   - **PreCompact**: pre-compact-guidelines.sh (no matcher -- matches all)
   - **PreToolUse**: secrets-check.sh (matcher: Write|Edit|MultiEdit|Bash), file-org-check.sh (matcher: Write), commit-format-check.sh (matcher: Bash)
   - **PostToolUse**: file-size-check.sh (matcher: Write|Edit|MultiEdit), tdd-tracker.sh (matcher: Write|Edit|MultiEdit), memory-ops-confirm.sh (matcher: graphiti|pi-brain)
   - **Stop**: tdd-reminder.sh (no matcher), memory-nudge.sh (no matcher)

3. All commands should use the format: `bash ~/.claude/hooks/{script-name}.sh`
4. All timeouts: 3000ms for most hooks, 5000ms for tdd-reminder.sh (needs time to evaluate)
5. Ensure the JSON is valid and well-formatted

**Important ordering note (Section 10.5):** In PreToolUse, secrets-check MUST come before commit-format-check. When both match the Bash tool, secrets-check running first ensures security takes priority. An exit 2 from secrets-check prevents commit-format-check from running (which is correct behavior).

**Acceptance Criteria:**
- [ ] Valid JSON (passes `jq .` validation)
- [ ] All 11 hook scripts are represented
- [ ] Matchers match the discovery document specifications
- [ ] secrets-check appears before commit-format-check in PreToolUse array
- [ ] Timeouts are appropriate for each hook's workload
- [ ] Command paths use `~/.claude/hooks/` prefix
```

---

### Task ID: 022

- **Title**: Create guidelines-template.txt customization file
- **File**: config/guidelines-template.txt
- **Complete**: [x]
- **Sprint Points**: 1

- **User Story (business-facing)**: As a user installing the hooks system, I want a template file for my guidelines content, so that I can customize the guidelines-reminder hook with my own rules before installation.
- **Outcome (what this delivers)**: A `config/guidelines-template.txt` with sensible defaults and clear markers for customization, used by guidelines-reminder.sh and the installer.

#### Prompt:

```markdown
**Objective:** Create a customizable guidelines template that the installer prompts users to edit.
**File to Create:** `config/guidelines-template.txt`
**Discovery Reference:** Section 9 (Customizable guidelines)

**Prerequisites:**
- Review the current guidelines-reminder.sh heredoc content at `~/.claude/hooks/guidelines-reminder.sh`

**Detailed Instructions:**

1. Extract the guidelines content from the current guidelines-reminder.sh heredoc into a standalone text file
2. Add comment markers (lines starting with #) indicating which sections users should customize:
   ```
   # === CUSTOMIZE: Replace the content below with YOUR project guidelines ===
   ```
3. Include sensible defaults that demonstrate the format:
   - File organization rules
   - Testing requirements
   - Code style reminders
   - Security practices
4. Keep the template generic enough to be useful across different project types
5. Update guidelines-reminder.sh to read from this template file (or document that the installer handles the integration)

**Acceptance Criteria:**
- [ ] Template contains sensible default guidelines
- [ ] Customization markers are clear and obvious
- [ ] File works as a standalone reference for users
- [ ] Content is generic (not specific to any one project)
- [ ] Under 50 lines
```

---

### Task ID: 023

- **Title**: Create install.sh interactive installer
- **File**: install.sh
- **Complete**: [x]
- **Sprint Points**: 8

- **User Story (business-facing)**: As a reader of the hooks article, I want a single install command that sets up the complete hooks system, so that I can start using enforcement hooks without manually copying files and editing settings.
- **Outcome (what this delivers)**: An interactive installer that validates dependencies, backs up existing hooks, copies scripts, merges settings, and runs the test suite to validate the installation.

#### Prompt:

```markdown
**Objective:** Create a safe, idempotent, non-destructive installer script.
**File to Create:** `install.sh`
**Discovery Reference:** Section 9 (Install Script Design)

**Prerequisites:**
- Task 021 (settings-hooks.json) must be complete
- Task 022 (guidelines-template.txt) must be complete
- All hook scripts must be finalized

**Detailed Instructions:**

1. Add shebang `#!/usr/bin/env bash` and `set -euo pipefail`
2. Support command-line flags:
   - `--force`: Overwrite existing hooks without prompting
   - `--dry-run`: Show what would be done without doing it
   - `--hooks-only`: Skip settings.json merge, install scripts only
   - No flags: Interactive mode (prompt before overwriting)

3. **Step 1 - Dependency validation:**
   - Check `jq` is installed (required for settings merge and all hooks)
   - Check `bash` version is 3.2+ (macOS ships 3.2 -- do NOT require 4+)
   - If dependencies missing: print install instructions and exit 1

4. **Step 2 - Directory setup:**
   - Create `~/.claude/hooks/` if it does not exist
   - Create `~/.claude/hooks/lib/` if it does not exist

5. **Step 3 - Backup existing hooks:**
   - If any `.sh` files exist in `~/.claude/hooks/`, copy them to `~/.claude/hooks/backup/{timestamp}/`
   - Print the backup location
   - In `--dry-run` mode, only print what would be backed up

6. **Step 4 - Copy hook scripts:**
   - Copy all files from repo `hooks/` to `~/.claude/hooks/`
   - Copy `hooks/lib/common.sh` to `~/.claude/hooks/lib/common.sh`
   - Make all `.sh` files executable
   - In `--force` mode, overwrite without asking
   - In interactive mode, prompt for each file that already exists

7. **Step 5 - Settings merge** (skip if `--hooks-only`):
   - Read existing `~/.claude/settings.json` (or create empty structure if absent)
   - Read `config/settings-hooks.json`
   - **CRITICAL: Use the correct nested schema** from Task 000 (`docs/settings-schema-reference.md`). The actual format is `{ "matcher": "...", "hooks": [...] }` per entry, NOT flat entries with matcher as a field.
   - Merge hook entries from config into existing settings using jq
   - Preserve all existing non-hook settings
   - Preserve existing hook entries not defined in our config
   - Write merged result back to `~/.claude/settings.json`
   - The merge must be additive, never destructive

8. **Step 6 - Guidelines customization prompt** (interactive only):
   - Ask if user wants to customize guidelines now
   - If yes, open `config/guidelines-template.txt` in `$EDITOR` (or vi)
   - Copy customized content to the appropriate location

9. **Step 7 - Post-install validation:**
   - Run `tests/run-tests.sh` from the repo
   - If tests pass: print success summary
   - If tests fail: print warning but do not roll back (hooks are still functional)

10. **Step 8 - Summary:**
    - Print list of installed hooks with their lifecycle events
    - Print the backup location (if backup was created)
    - Print next steps (customize guidelines, review settings)

**Error handling:**
- If any copy operation fails, print error and continue with remaining files
- If settings merge jq command fails (non-zero exit), **automatically restore the backup** of settings.json. Do not leave the user with a corrupted config. Then print error and suggest `--hooks-only` mode.
- Never leave settings.json in a corrupted state (write to temp file first, then move)

**Acceptance Criteria:**
- [ ] `--dry-run` makes no filesystem changes
- [ ] `--force` overwrites without prompting
- [ ] `--hooks-only` skips settings merge
- [ ] Existing hooks are backed up before overwriting
- [ ] Settings merge is additive (never deletes existing config)
- [ ] Settings.json is written atomically (temp file + move)
- [ ] Post-install test suite runs and reports results
- [ ] Script is idempotent (running twice produces same result)
- [ ] Missing jq is caught before any filesystem changes
- [ ] Script is under 200 lines
```

---

### Task ID: 023-1

- **Title**: Create installer integration tests
- **File**: tests/test-installer.sh
- **Complete**: [x]
- **Sprint Points**: 3

- **User Story (business-facing)**: As a contributor, I want integration tests that validate the installer and uninstaller against real scenarios, so that packaging regressions are caught before release.
- **Outcome (what this delivers)**: An integration test file that validates `--dry-run` makes no changes, `--force` overwrites correctly, `--hooks-only` skips settings merge, the uninstall cycle preserves custom hooks, and the settings merge handles the actual nested schema.

#### Prompt:

```markdown
**Objective:** Create integration tests for the install/uninstall lifecycle.
**File to Create:** `tests/test-installer.sh`
**Discovery Reference:** Section 9 (Install/Uninstall Scripts)

**Prerequisites:**
- Task 023 (install.sh) must be complete
- Task 024 (uninstall.sh) must be complete

**Detailed Instructions:**

1. Create a test file with functions that exercise the installer in a sandboxed environment:
   - Use a temp directory as a fake `~/.claude/` to avoid touching the real config
   - Set HOME or a config variable to redirect the installer

2. **Test cases:**
   - `test_dry_run_makes_no_changes`: Run install.sh --dry-run, verify no files created
   - `test_force_overwrites_existing`: Create a dummy hook, run --force, verify it was replaced
   - `test_hooks_only_skips_settings`: Run --hooks-only, verify settings.json untouched
   - `test_settings_merge_preserves_existing`: Create a settings.json with custom entries, run installer, verify custom entries preserved
   - `test_settings_merge_uses_correct_schema`: Verify merged output uses nested matcher->hooks[] structure
   - `test_uninstall_removes_only_known_hooks`: Install, add a custom hook, uninstall, verify custom hook preserved
   - `test_uninstall_restores_clean_settings`: Install then uninstall, verify settings.json has no hook entries from this system
   - `test_idempotent_install`: Run install twice, verify same result

3. Each test must clean up its temp directory.

**Acceptance Criteria:**
- [ ] At least 6 integration test functions
- [ ] Tests use sandboxed directories (never touch real ~/.claude/)
- [ ] Settings merge tests validate the correct nested schema
- [ ] Uninstall tests verify custom hooks are preserved
- [ ] All tests pass with `bash tests/run-tests.sh`
```

---

### Task ID: 024

- **Title**: Create uninstall.sh removal script
- **File**: uninstall.sh
- **Complete**: [x]
- **Sprint Points**: 3

- **User Story (business-facing)**: As a user who wants to remove the hooks system, I want a clean uninstall script that removes only the hooks this system installed, so that other Claude Code configuration is preserved.
- **Outcome (what this delivers)**: An uninstall script that removes known hook scripts, the lib directory, and hook entries from settings.json, while preserving backups and other configuration.

#### Prompt:

```markdown
**Objective:** Create a clean removal script that only removes files and config this system installed.
**File to Create:** `uninstall.sh`
**Discovery Reference:** Section 9 (Uninstall Script)

**Prerequisites:**
- Task 023 (install.sh) should be complete or in progress
- Know the exact list of hook filenames the installer creates

**Detailed Instructions:**

1. Add shebang and `set -euo pipefail`
2. Support `--dry-run` flag to preview changes without executing

3. **Step 1 - Remove hook scripts:**
   - Define the known list of hook filenames installed by this system
   - Remove only those files from `~/.claude/hooks/`
   - Do NOT remove files that are not in the known list (user's custom hooks)
   - Remove `~/.claude/hooks/lib/common.sh`
   - Remove `~/.claude/hooks/lib/` directory if empty

4. **Step 2 - Remove hook entries from settings.json:**
   - Read `~/.claude/settings.json`
   - **Use the correct nested schema** from Task 000 -- removal must walk the nested `matcher -> hooks[]` structure and match by command path within the inner hooks array
   - Remove hook entries whose command references any of the known hook filenames
   - Preserve all other hook entries and non-hook settings
   - Write back atomically (temp file + move)
   - If settings.json does not exist, skip this step

5. **Step 3 - Do NOT remove:**
   - The backup directory (`~/.claude/hooks/backup/`)
   - Any hook files not in the known list
   - Any non-hook settings in settings.json
   - The `~/.claude/` directory itself

6. **Step 4 - Print confirmation:**
   - List all removed files
   - Note any files that were already absent
   - Remind about backup directory location

**Acceptance Criteria:**
- [ ] Only removes files this system installed (by known filename list)
- [ ] Preserves user's custom hooks and other settings
- [ ] Settings.json removal is precise (by command path match)
- [ ] `--dry-run` previews without removing
- [ ] Backup directory is explicitly preserved
- [ ] Script handles missing files gracefully (no errors if already uninstalled)
```

---

### Task ID: 025

- **Title**: Create README.md for the repository
- **File**: README.md
- **Complete**: [x]
- **Sprint Points**: 3

- **User Story (business-facing)**: As a reader of the hooks article, I want a clear README that explains what this repository is, how to install it, and how to customize it, so that I can get started quickly without reading the full article.
- **Outcome (what this delivers)**: A comprehensive README with overview, quick start, hook reference table, customization guide, and links to the companion article.

#### Prompt:

```markdown
**Objective:** Create the repository README for public distribution.
**File to Create:** `README.md`
**Discovery Reference:** Section 9 (Repository Structure, Customization Guidance)

**Prerequisites:**
- All hooks, installer, and test framework should be complete
- Review the customization table in Section 9

**Detailed Instructions:**

Structure the README with these sections:

1. **Title and tagline**: "Claude Code Hooks System" with a one-line description
2. **Overview**: Brief explanation of the 4-layer hook architecture (2-3 paragraphs)
3. **Quick Start**:
   ```bash
   git clone git@github.com:mandelbro/awesome-claude-hooks.git
   cd awesome-claude-hooks
   ./install.sh
   ```
4. **Hook Reference Table**: All 11 hooks with lifecycle event, matcher, blocking status, and one-line description (use the table from Section 1 as a base)
5. **Customization Guide**: Which hooks need customization vs work out of the box (use the table from Section 9)
6. **Installation Options**: Document --force, --dry-run, --hooks-only flags
7. **Uninstallation**: How to remove
8. **Testing**: How to run the test suite
9. **Architecture**: Brief explanation of lib/common.sh and the shared utilities pattern
10. **Companion Article**: Link to the article with a note that the repo is the implementation companion
11. **License**: MIT (reference existing LICENSE file)

**Style guidelines:**
- Use clear, concise language
- Include code blocks for commands
- Keep it scannable (use tables, headers, bullet points)
- Target audience: developers who read the article and want to try it

**Acceptance Criteria:**
- [ ] Quick start section gets a user from clone to working hooks in 3 commands
- [ ] Hook reference table covers all 11 hooks
- [ ] Customization guidance is clear about what MUST be customized
- [ ] Installation, uninstallation, and testing are documented
- [ ] Companion article is linked
- [ ] Under 300 lines
```
