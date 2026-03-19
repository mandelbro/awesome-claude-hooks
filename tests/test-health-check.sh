# shellcheck shell=bash
# Tests for hooks/hook-health-check.sh
# Validates that the health check hook reports status correctly.

test_health_check_exits_zero() {
  run_hook "$HOOKS_DIR/hook-health-check.sh" "$SCRIPT_DIR/fixtures/session-start.json"
  assert_exit 0 "$RUN_EXIT" "health-check: exits 0 on session start"
}

test_health_check_reports_issues() {
  # Create a temporary non-executable script to trigger a health warning
  local tmp_script="$HOOKS_DIR/_test-non-executable.sh"
  echo '#!/usr/bin/env bash' > "$tmp_script"
  chmod -x "$tmp_script"

  run_hook "$HOOKS_DIR/hook-health-check.sh" "$SCRIPT_DIR/fixtures/session-start.json"
  assert_exit 0 "$RUN_EXIT" "health-check: still exits 0 even with issues"
  assert_output_contains "not executable" "$RUN_OUTPUT" "health-check: reports non-executable script"

  # Clean up
  rm -f "$tmp_script"
}
