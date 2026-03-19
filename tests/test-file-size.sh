# shellcheck shell=bash
# Tests for hooks/file-size-check.sh
# PostToolUse hook — always exits 0, warns via stdout for large files.
# Since fixtures reference non-existent paths, the hook exits early with no output.

test_filesize_no_warning_small_file() {
  run_hook "$HOOKS_DIR/file-size-check.sh" "$SCRIPT_DIR/fixtures/write-clean.json"
  assert_exit 0 "$RUN_EXIT" "file-size: exits 0 for non-existent file path"
  assert_output_not_contains "FILE SIZE" "$RUN_OUTPUT" "file-size: no warning when file does not exist"
}

test_filesize_warns_large_file() {
  # Create a temp file with >500 lines to trigger the warning
  local tmpfile="/tmp/claude-test-large-file.py"
  for i in $(seq 1 501); do echo "# line $i" >> "$tmpfile"; done
  local fixture='{"tool_name":"Write","tool_input":{"file_path":"'"$tmpfile"'","content":"x"},"session_id":"test","cwd":"/tmp"}'
  RUN_OUTPUT=$(echo "$fixture" | bash "$HOOKS_DIR/file-size-check.sh" 2>&1)
  RUN_EXIT=$?
  assert_exit 0 "$RUN_EXIT" "file-size: exits 0 even for large file"
  assert_output_contains "FILE SIZE WARNING" "$RUN_OUTPUT" "file-size: warns for 500+ line file"
  rm -f "$tmpfile"
}
