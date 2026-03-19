#!/usr/bin/env bash
# Guidelines Reminder Hook — injects condensed user guidelines into Claude's context.
# Runs on: SessionStart (startup|resume|compact), also sourced by pre-compact-guidelines.sh
# Output goes to stdout → Claude Code injects it as a system-reminder.

emit_guidelines() {
cat <<'GUIDELINES'
=== ACTIVE USER GUIDELINES ===

FILE SIZE
- Target: 100-500 lines per file. Evaluate for splitting at 400 lines.
- NEVER exceed 1000 lines without explicit architectural justification.
- Single responsibility per file. Modular design with clear naming.

TDD (Test-Driven Development)
- Write a FAILING test BEFORE implementation. Red-Green-Refactor cycle.
- Never delete failing tests to make the build pass.
- Capture bugs with a failing test first, then fix.
- Test behavior, not implementation details. Only test public methods.

CONVENTIONAL COMMITS
- Format: <type>[scope]: <description> (imperative mood, present tense)
- Types: feat, fix, refactor, test, docs, style, chore, build, ci
- One logical unit per commit. Never commit half-done work.

FILE ORGANIZATION
- NEVER save source, test, doc, or script files to the project root.
- Use /src for source, /tests for tests, /docs for docs, /config for config, /scripts for scripts.

SECRETS & SECURITY
- NEVER hardcode API keys, secrets, or credentials in source files.
- NEVER commit .env files or any file containing secrets.
- Validate user input at system boundaries. Sanitize file paths.

PATHS
- Always use absolute/full paths. Never use ../ relative navigation.

MEMORY MANAGEMENT (graphiti-memory)
- SESSION START: Search graphiti-memory nodes and facts for relevant context BEFORE beginning work.
- DURING SESSION: Update memory when you discover new preferences, procedures, decisions, patterns, or requirements. Do not wait until the end.
- SESSION END: Capture key learnings, document decisions with rationale, update relationships, record next steps and open questions.

TASK WORKFLOW
- After completing a task: run tests, run linters, update Complete status, update tasks-index.md counts and Points Complete.
- Commit after each task before proceeding to the next.

POST-REQUEST
- After each request: provide a summary of what was accomplished and clear next steps.

CONCURRENCY
- Batch all parallel operations in a single message (file reads, tool calls, agent spawns).

SEQUENTIAL THINKING
- Use for complex problems requiring 5+ reasoning steps.
- Skip for simple, single-step tasks.

EXTERNAL LIBRARIES (context7)
- ALWAYS retrieve and review documentation via context7 BEFORE implementing code that uses external libraries.
- No exceptions, even for commonly known libraries.

=== END GUIDELINES ===
GUIDELINES
}

# Only auto-execute when run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  emit_guidelines
  exit 0
fi
