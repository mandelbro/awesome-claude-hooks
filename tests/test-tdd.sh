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

test_tdd_tracker_includes_timestamp() {
  local tracker="/tmp/claude-tdd-tracker-test-session-001"
  rm -f "$tracker"

  run_hook "$HOOKS_DIR/tdd-tracker.sh" "$SCRIPT_DIR/fixtures/write-clean.json"
  assert_exit 0 "$RUN_EXIT" "tdd-tracker: exits 0 for timestamped entry"

  local content=""
  [ -f "$tracker" ] && content=$(cat "$tracker")
  # Verify TIMESTAMP:TYPE:PATH format (timestamp is digits)
  local has_ts_format=""
  if echo "$content" | grep -qE '^[0-9]+:SRC:'; then
    has_ts_format="yes"
  fi
  assert_output_contains "yes" "$has_ts_format" "tdd-tracker: entry has TIMESTAMP:TYPE:PATH format"

  rm -f "$tracker"
}

test_tdd_entries_persist_source_only() {
  local tracker="/tmp/claude-tdd-tracker-test-session-001"
  local now
  now=$(date +%s)

  # Pre-populate with recent source-only entries
  echo "${now}:SRC:/project/src/utils/helpers.py" > "$tracker"

  run_hook "$HOOKS_DIR/tdd-reminder.sh" "$SCRIPT_DIR/fixtures/stop-normal.json"
  assert_exit 0 "$RUN_EXIT" "tdd-reminder: exits 0 with source-only entries"

  # Tracker should still exist (not cleared when only source files present)
  local tracker_exists="no"
  [ -f "$tracker" ] && tracker_exists="yes"
  assert_output_contains "yes" "$tracker_exists" "tdd-reminder: tracker persists when only source files present"

  rm -f "$tracker"
}

test_tdd_entries_pruned_old() {
  local tracker="/tmp/claude-tdd-tracker-test-session-001"
  local old_ts
  old_ts=$(( $(date +%s) - 3600 ))  # 1 hour ago, well past 30-min window

  # Pre-populate with old entries only
  echo "${old_ts}:SRC:/project/src/old_file.py" > "$tracker"

  run_hook "$HOOKS_DIR/tdd-reminder.sh" "$SCRIPT_DIR/fixtures/stop-normal.json"
  assert_exit 0 "$RUN_EXIT" "tdd-reminder: exits 0 after pruning old entries"

  # Tracker should be removed (no recent entries remain)
  local tracker_exists="no"
  [ -f "$tracker" ] && tracker_exists="yes"
  assert_output_contains "no" "$tracker_exists" "tdd-reminder: tracker removed when all entries are old"

  rm -f "$tracker"
}

test_tdd_tracker_clears_on_complete_cycle() {
  local tracker="/tmp/claude-tdd-tracker-test-session-001"
  local now
  now=$(date +%s)

  # Pre-populate with both SRC and TEST entries (complete TDD cycle)
  printf "%s:SRC:/project/src/utils/helpers.py\n%s:TEST:/project/tests/test_helpers.py\n" "$now" "$now" > "$tracker"

  run_hook "$HOOKS_DIR/tdd-reminder.sh" "$SCRIPT_DIR/fixtures/stop-normal.json"
  assert_exit 0 "$RUN_EXIT" "tdd-reminder: exits 0 on complete cycle"

  # Tracker should be cleared when both src and test are present
  local tracker_exists="no"
  [ -f "$tracker" ] && tracker_exists="yes"
  assert_output_contains "no" "$tracker_exists" "tdd-reminder: tracker cleared on complete TDD cycle"
  assert_output_not_contains "TDD REMINDER" "$RUN_OUTPUT" "tdd-reminder: no reminder on complete cycle"

  rm -f "$tracker"
}
