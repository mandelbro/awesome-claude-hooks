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
