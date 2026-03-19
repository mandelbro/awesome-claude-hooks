# Tests for hooks/commit-format-check.sh
# Validates conventional commit message enforcement.

test_commit_allows_valid() {
  run_hook "$HOOKS_DIR/commit-format-check.sh" "$SCRIPT_DIR/fixtures/bash-git-commit-valid.json"
  assert_exit 0 "$RUN_EXIT" "commit: allows valid conventional commit"
}

test_commit_blocks_invalid() {
  run_hook "$HOOKS_DIR/commit-format-check.sh" "$SCRIPT_DIR/fixtures/bash-git-commit-invalid.json"
  assert_exit 2 "$RUN_EXIT" "commit: blocks non-conventional commit message"
  assert_output_contains "Conventional Commits" "$RUN_OUTPUT" "commit: invalid msg outputs format hint"
}

test_commit_ignores_non_commit() {
  run_hook "$HOOKS_DIR/commit-format-check.sh" "$SCRIPT_DIR/fixtures/bash-clean.json"
  assert_exit 0 "$RUN_EXIT" "commit: ignores non-git-commit bash commands"
}
