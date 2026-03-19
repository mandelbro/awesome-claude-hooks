# Tests for hooks/file-size-check.sh
# PostToolUse hook — always exits 0, warns via stdout for large files.
# Since fixtures reference non-existent paths, the hook exits early with no output.

test_filesize_no_warning_small_file() {
  run_hook "$HOOKS_DIR/file-size-check.sh" "$SCRIPT_DIR/fixtures/write-clean.json"
  assert_exit 0 "$RUN_EXIT" "file-size: exits 0 for non-existent file path"
  assert_output_not_contains "FILE SIZE" "$RUN_OUTPUT" "file-size: no warning when file does not exist"
}

test_filesize_exits_zero() {
  run_hook "$HOOKS_DIR/file-size-check.sh" "$SCRIPT_DIR/fixtures/write-clean.json"
  assert_exit 0 "$RUN_EXIT" "file-size: always exits 0 (PostToolUse)"
}
