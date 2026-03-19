# shellcheck shell=bash
# Tests for install.sh and uninstall.sh
# Integration tests using sandboxed temp directories as fake HOME.

REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# SKIP_POST_INSTALL_TESTS prevents infinite recursion: install.sh runs
# run-tests.sh which sources this file which runs install.sh again...
export SKIP_POST_INSTALL_TESTS=1

_setup_sandbox() {
  SANDBOX="$(mktemp -d)"
  FAKE_HOME="$SANDBOX/home"
  mkdir -p "$FAKE_HOME/.claude"
}

_teardown_sandbox() {
  [ -n "${SANDBOX:-}" ] && rm -rf "$SANDBOX"
}

test_dry_run_makes_no_changes() {
  _setup_sandbox
  HOME="$FAKE_HOME" bash "$REPO_DIR/install.sh" --dry-run --force >/dev/null 2>&1

  # Hooks directory should NOT exist after dry run
  if [ -d "$FAKE_HOME/.claude/hooks" ]; then
    _teardown_sandbox
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: installer dry-run: hooks dir should not exist\n"
    return 1
  fi
  PASS=$((PASS + 1))

  # Settings file should NOT exist after dry run
  if [ -f "$FAKE_HOME/.claude/settings.json" ]; then
    _teardown_sandbox
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: installer dry-run: settings.json should not exist\n"
    return 1
  fi
  PASS=$((PASS + 1))
  _teardown_sandbox
}

test_force_overwrites_existing() {
  _setup_sandbox
  mkdir -p "$FAKE_HOME/.claude/hooks"
  echo "old content" > "$FAKE_HOME/.claude/hooks/secrets-check.sh"

  HOME="$FAKE_HOME" bash "$REPO_DIR/install.sh" --force >/dev/null 2>&1

  # The hook should be overwritten with repo content
  if grep -q "old content" "$FAKE_HOME/.claude/hooks/secrets-check.sh" 2>/dev/null; then
    _teardown_sandbox
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: installer force: should overwrite existing hook\n"
    return 1
  fi
  PASS=$((PASS + 1))

  # The new file should contain actual hook content
  if ! grep -q "secrets" "$FAKE_HOME/.claude/hooks/secrets-check.sh" 2>/dev/null; then
    _teardown_sandbox
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: installer force: overwritten file should have hook content\n"
    return 1
  fi
  PASS=$((PASS + 1))
  _teardown_sandbox
}

test_hooks_only_skips_settings() {
  _setup_sandbox

  HOME="$FAKE_HOME" bash "$REPO_DIR/install.sh" --force --hooks-only >/dev/null 2>&1

  # Hooks should be installed
  if [ ! -f "$FAKE_HOME/.claude/hooks/secrets-check.sh" ]; then
    _teardown_sandbox
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: installer hooks-only: hooks should be installed\n"
    return 1
  fi
  PASS=$((PASS + 1))

  # Settings file should NOT exist (was never created)
  if [ -f "$FAKE_HOME/.claude/settings.json" ]; then
    _teardown_sandbox
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: installer hooks-only: settings.json should not be created\n"
    return 1
  fi
  PASS=$((PASS + 1))
  _teardown_sandbox
}

test_settings_merge_preserves_existing() {
  _setup_sandbox
  # Create a settings file with a custom key
  echo '{"customKey": "customValue", "permissions": {"allow": ["read"]}}' \
    > "$FAKE_HOME/.claude/settings.json"

  HOME="$FAKE_HOME" bash "$REPO_DIR/install.sh" --force >/dev/null 2>&1

  # Custom key should be preserved after merge
  if ! jq -e '.customKey == "customValue"' "$FAKE_HOME/.claude/settings.json" >/dev/null 2>&1; then
    _teardown_sandbox
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: installer merge: should preserve existing keys\n"
    return 1
  fi
  PASS=$((PASS + 1))

  # Hooks key should now exist from the merge
  if ! jq -e '.hooks' "$FAKE_HOME/.claude/settings.json" >/dev/null 2>&1; then
    _teardown_sandbox
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: installer merge: should add hooks key\n"
    return 1
  fi
  PASS=$((PASS + 1))
  _teardown_sandbox
}

test_settings_merge_uses_correct_schema() {
  _setup_sandbox
  echo '{}' > "$FAKE_HOME/.claude/settings.json"

  HOME="$FAKE_HOME" bash "$REPO_DIR/install.sh" --force >/dev/null 2>&1

  # Verify hooks schema has expected lifecycle events
  local has_pre has_post has_stop has_session
  has_pre=$(jq -e '.hooks.PreToolUse' "$FAKE_HOME/.claude/settings.json" >/dev/null 2>&1 && echo "yes" || echo "no")
  has_post=$(jq -e '.hooks.PostToolUse' "$FAKE_HOME/.claude/settings.json" >/dev/null 2>&1 && echo "yes" || echo "no")
  has_stop=$(jq -e '.hooks.Stop' "$FAKE_HOME/.claude/settings.json" >/dev/null 2>&1 && echo "yes" || echo "no")
  has_session=$(jq -e '.hooks.SessionStart' "$FAKE_HOME/.claude/settings.json" >/dev/null 2>&1 && echo "yes" || echo "no")

  if [ "$has_pre" = "yes" ] && [ "$has_post" = "yes" ] && [ "$has_stop" = "yes" ] && [ "$has_session" = "yes" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: installer schema: missing expected lifecycle events (pre=$has_pre post=$has_post stop=$has_stop session=$has_session)\n"
    return 1
  fi

  # Verify PreCompact is also present
  if ! jq -e '.hooks.PreCompact' "$FAKE_HOME/.claude/settings.json" >/dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: installer schema: missing PreCompact lifecycle event\n"
    return 1
  fi
  PASS=$((PASS + 1))
  _teardown_sandbox
}

test_idempotent_install() {
  _setup_sandbox

  # Run install twice
  HOME="$FAKE_HOME" bash "$REPO_DIR/install.sh" --force >/dev/null 2>&1
  local first_checksum
  first_checksum=$(md5sum "$FAKE_HOME/.claude/hooks/secrets-check.sh" 2>/dev/null | awk '{print $1}' || md5 -q "$FAKE_HOME/.claude/hooks/secrets-check.sh" 2>/dev/null)

  HOME="$FAKE_HOME" bash "$REPO_DIR/install.sh" --force >/dev/null 2>&1
  local second_checksum
  second_checksum=$(md5sum "$FAKE_HOME/.claude/hooks/secrets-check.sh" 2>/dev/null | awk '{print $1}' || md5 -q "$FAKE_HOME/.claude/hooks/secrets-check.sh" 2>/dev/null)

  # Content should be identical
  if [ "$first_checksum" = "$second_checksum" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: installer idempotent: second install changed file content\n"
    return 1
  fi

  # Settings should still be valid JSON
  if jq empty "$FAKE_HOME/.claude/settings.json" 2>/dev/null; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: installer idempotent: settings.json invalid after second install\n"
    return 1
  fi
  _teardown_sandbox
}

test_uninstall_removes_hooks() {
  _setup_sandbox

  # Install first
  HOME="$FAKE_HOME" bash "$REPO_DIR/install.sh" --force >/dev/null 2>&1

  # Verify hooks exist before uninstall
  if [ ! -f "$FAKE_HOME/.claude/hooks/secrets-check.sh" ]; then
    _teardown_sandbox
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: uninstaller: hooks should exist before uninstall\n"
    return 1
  fi

  # Run uninstall
  HOME="$FAKE_HOME" bash "$REPO_DIR/uninstall.sh" >/dev/null 2>&1

  # Known hooks should be removed
  if [ -f "$FAKE_HOME/.claude/hooks/secrets-check.sh" ]; then
    _teardown_sandbox
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}FAIL: uninstaller: secrets-check.sh should be removed\n"
    return 1
  fi
  PASS=$((PASS + 1))
  _teardown_sandbox
}
