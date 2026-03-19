# Tests for hooks/tdd-tracker.sh and hooks/tdd-reminder.sh
# Validates TDD tracking and reminder behavior.

test_tdd_tracker_records_source() {
  local tracker="/tmp/claude-tdd-tracker-test-session-001"
  rm -f "$tracker"

  # write-clean.json has file_path ending in .py and session_id test-session-001
  run_hook "$HOOKS_DIR/tdd-tracker.sh" "$SCRIPT_DIR/fixtures/write-clean.json"
  assert_exit 0 "$RUN_EXIT" "tdd-tracker: exits 0 for source file"

  local content=""
  [ -f "$tracker" ] && content=$(cat "$tracker")
  assert_output_contains "SRC:" "$content" "tdd-tracker: records SRC entry for .py file"

  rm -f "$tracker"
}

test_tdd_tracker_records_test() {
  local tracker="/tmp/claude-tdd-tracker-test-session-001"
  rm -f "$tracker"

  # Create a fixture-like input with a test file path via heredoc
  local tmp_fixture="/tmp/claude-test-fixture-tdd-test-file.json"
  cat > "$tmp_fixture" <<'FIXTURE'
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/project/tests/test_helpers.py",
    "content": "def test_slugify():\n    assert slugify('Hello World') == 'hello-world'\n"
  },
  "session_id": "test-session-001",
  "cwd": "/project"
}
FIXTURE

  run_hook "$HOOKS_DIR/tdd-tracker.sh" "$tmp_fixture"
  assert_exit 0 "$RUN_EXIT" "tdd-tracker: exits 0 for test file"

  local content=""
  [ -f "$tracker" ] && content=$(cat "$tracker")
  assert_output_contains "TEST:" "$content" "tdd-tracker: records TEST entry for test file"

  rm -f "$tracker" "$tmp_fixture"
}

test_tdd_reminder_warns_source_only() {
  local tracker="/tmp/claude-tdd-tracker-test-session-001"
  echo "SRC:/project/src/utils/helpers.py" > "$tracker"

  run_hook "$HOOKS_DIR/tdd-reminder.sh" "$SCRIPT_DIR/fixtures/stop-normal.json"
  assert_exit 0 "$RUN_EXIT" "tdd-reminder: exits 0"
  assert_output_contains "TDD REMINDER" "$RUN_OUTPUT" "tdd-reminder: warns when only source files written"

  rm -f "$tracker"
}

test_tdd_reminder_silent_with_both() {
  local tracker="/tmp/claude-tdd-tracker-test-session-001"
  printf "SRC:/project/src/utils/helpers.py\nTEST:/project/tests/test_helpers.py\n" > "$tracker"

  run_hook "$HOOKS_DIR/tdd-reminder.sh" "$SCRIPT_DIR/fixtures/stop-normal.json"
  assert_exit 0 "$RUN_EXIT" "tdd-reminder: exits 0 with both src and test"
  assert_output_not_contains "TDD REMINDER" "$RUN_OUTPUT" "tdd-reminder: silent when test files present"

  rm -f "$tracker"
}

test_tdd_reminder_exits_on_recursive() {
  run_hook "$HOOKS_DIR/tdd-reminder.sh" "$SCRIPT_DIR/fixtures/stop-recursive.json"
  assert_exit 0 "$RUN_EXIT" "tdd-reminder: exits 0 on recursive stop"
  assert_output_not_contains "TDD REMINDER" "$RUN_OUTPUT" "tdd-reminder: no output on recursive stop"
}
