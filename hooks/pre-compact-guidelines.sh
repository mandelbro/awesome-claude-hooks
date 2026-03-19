#!/usr/bin/env bash
# Pre-Compact Guidelines Hook — re-injects guidelines before context compaction
# so they survive in the compacted summary.
# Runs on: PreCompact (all matchers)

source "$(dirname "$0")/lib/common.sh"

# Import emit_guidelines() from guidelines-reminder.sh.
# WARNING: Do NOT run guidelines-reminder.sh via subshell or pipe — that script
# reads stdin when executed directly, which would consume the hook's JSON input
# and leave downstream parsing with an empty stream. The BASH_SOURCE guard in
# guidelines-reminder.sh prevents auto-execution when sourced.
source "$(dirname "$0")/guidelines-reminder.sh"

emit_guidelines
exit 0
