#!/usr/bin/env bash
# File Organization Check Hook — blocks new files in project root that belong in subdirectories.
# Runs on: PreToolUse (Write). Exit 2 = block the action.

source "$(dirname "$0")/lib/common.sh"

parse_input || exit 2

# No file path or cwd — can't check
if [ -z "$HOOK_FILE_PATH" ] || [ -z "$HOOK_CWD" ]; then
  exit 0
fi

# Get the directory containing the file
FILE_DIR=$(dirname "$HOOK_FILE_PATH")

# Only check files directly in the project root
if [ "$FILE_DIR" != "$HOOK_CWD" ]; then
  exit 0
fi

# Only check if file doesn't already exist (new files only)
if [ -f "$HOOK_FILE_PATH" ]; then
  exit 0
fi

FILENAME=$(basename "$HOOK_FILE_PATH")

# Allow standard root files (configs, dotfiles, build files)
case "$FILENAME" in
  .* | \
  Makefile | makefile | GNUmakefile | \
  Dockerfile | docker-compose* | \
  justfile | Justfile | \
  LICENSE* | CHANGELOG* | CONTRIBUTING* | \
  pyproject.toml | setup.py | setup.cfg | \
  package.json | package-lock.json | \
  tsconfig*.json | vite.config.* | vitest.config.* | \
  *.toml | *.yaml | *.yml | *.json | *.cfg | *.ini | *.lock | \
  *.sh | \
  render.yaml | Procfile | runtime.txt | requirements*.txt )
    exit 0
    ;;
esac

# Block source/test/doc files in root
case "$FILENAME" in
  *.py | *.ts | *.tsx | *.js | *.jsx | *.rb | *.go | *.rs | *.java)
    echo "BLOCKED: Source file '$FILENAME' should not be in the project root." >&2
    echo "Use /src for source code, /tests for tests, /scripts for utility scripts." >&2
    exit 2
    ;;
  *.md)
    echo "BLOCKED: Markdown file '$FILENAME' should not be in the project root." >&2
    echo "Use /docs for documentation files." >&2
    exit 2
    ;;
  *.test.* | *.spec.* | *_test.* | *_spec.*)
    echo "BLOCKED: Test file '$FILENAME' should not be in the project root." >&2
    echo "Use /tests for test files." >&2
    exit 2
    ;;
esac

exit 0
