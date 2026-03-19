# shellcheck shell=bash
# Tests for hooks/file-org-check.sh
# Validates that source files in the project root are blocked and nested files are allowed.

test_fileorg_blocks_root_source() {
  run_hook "$HOOKS_DIR/file-org-check.sh" "$SCRIPT_DIR/fixtures/write-root-source.json"
  assert_exit 2 "$RUN_EXIT" "file-org: blocks source file in project root"
  assert_output_contains "BLOCKED" "$RUN_OUTPUT" "file-org: root source outputs BLOCKED"
}

test_fileorg_allows_nested_source() {
  run_hook "$HOOKS_DIR/file-org-check.sh" "$SCRIPT_DIR/fixtures/write-clean.json"
  assert_exit 0 "$RUN_EXIT" "file-org: allows source file in nested directory"
}
