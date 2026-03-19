# Tests for hooks/secrets-check.sh
# Validates that secret patterns are blocked and clean content is allowed.

test_secrets_blocks_aws_key() {
  run_hook "$HOOKS_DIR/secrets-check.sh" "$SCRIPT_DIR/fixtures/write-with-secret.json"
  assert_exit 2 "$RUN_EXIT" "secrets: blocks AWS access key"
  assert_output_contains "BLOCKED" "$RUN_OUTPUT" "secrets: AWS key outputs BLOCKED"
}

test_secrets_blocks_env_file() {
  run_hook "$HOOKS_DIR/secrets-check.sh" "$SCRIPT_DIR/fixtures/write-env-file.json"
  assert_exit 2 "$RUN_EXIT" "secrets: blocks .env file write"
  assert_output_contains "BLOCKED" "$RUN_OUTPUT" "secrets: env file outputs BLOCKED"
}

test_secrets_blocks_private_key() {
  run_hook "$HOOKS_DIR/secrets-check.sh" "$SCRIPT_DIR/fixtures/edit-with-private-key.json"
  assert_exit 2 "$RUN_EXIT" "secrets: blocks private key in edit"
  assert_output_contains "BLOCKED" "$RUN_OUTPUT" "secrets: private key outputs BLOCKED"
}

test_secrets_allows_clean_write() {
  run_hook "$HOOKS_DIR/secrets-check.sh" "$SCRIPT_DIR/fixtures/write-clean.json"
  assert_exit 0 "$RUN_EXIT" "secrets: allows clean write"
}

test_secrets_allows_clean_edit() {
  run_hook "$HOOKS_DIR/secrets-check.sh" "$SCRIPT_DIR/fixtures/edit-clean.json"
  assert_exit 0 "$RUN_EXIT" "secrets: allows clean edit"
}

# --- Bash command secret scanning tests ---

test_secrets_bash_echo_redirect_blocked() {
  run_hook "$HOOKS_DIR/secrets-check.sh" "$SCRIPT_DIR/fixtures/bash-echo-secret-to-file.json"
  assert_exit 2 "$RUN_EXIT" "secrets: blocks bash echo secret to file"
  assert_output_contains "BLOCKED" "$RUN_OUTPUT" "secrets: bash echo secret outputs BLOCKED"
}

test_secrets_bash_grep_allowed() {
  run_hook "$HOOKS_DIR/secrets-check.sh" "$SCRIPT_DIR/fixtures/bash-grep-secret-pattern.json"
  assert_exit 0 "$RUN_EXIT" "secrets: allows bash grep (read-only, no write operator)"
}

test_secrets_bash_clean_redirect_allowed() {
  run_hook "$HOOKS_DIR/secrets-check.sh" "$SCRIPT_DIR/fixtures/bash-clean-redirect.json"
  assert_exit 0 "$RUN_EXIT" "secrets: allows bash clean redirect (no secret)"
}

test_secrets_bash_tee_secret_blocked() {
  run_hook "$HOOKS_DIR/secrets-check.sh" "$SCRIPT_DIR/fixtures/bash-tee-secret.json"
  assert_exit 2 "$RUN_EXIT" "secrets: blocks bash tee with secret"
  assert_output_contains "BLOCKED" "$RUN_OUTPUT" "secrets: bash tee secret outputs BLOCKED"
}

test_secrets_bash_cat_stdout_allowed() {
  run_hook "$HOOKS_DIR/secrets-check.sh" "$SCRIPT_DIR/fixtures/bash-cat-stdout.json"
  assert_exit 0 "$RUN_EXIT" "secrets: allows bash cat to stdout (read-only)"
}

test_secrets_jq_missing_blocks() {
  # Temporarily hide jq from PATH to simulate it being missing
  RUN_OUTPUT=$(PATH="/usr/bin:/bin" bash "$HOOKS_DIR/secrets-check.sh" < "$SCRIPT_DIR/fixtures/write-clean.json" 2>&1)
  RUN_EXIT=$?
  # If jq is at /usr/bin/jq or /bin/jq, it will still be found — skip gracefully
  if command -v /usr/bin/jq &>/dev/null || command -v /bin/jq &>/dev/null; then
    # jq is in the restricted PATH, so require_jq won't fail — test that hook still works
    assert_exit 0 "$RUN_EXIT" "secrets: jq available in restricted PATH, hook works"
  else
    assert_exit 2 "$RUN_EXIT" "secrets: missing jq causes exit 2"
    assert_output_contains "jq is required" "$RUN_OUTPUT" "secrets: missing jq outputs error"
  fi
}
