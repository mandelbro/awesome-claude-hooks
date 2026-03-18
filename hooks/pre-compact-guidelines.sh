#!/usr/bin/env bash
# Pre-Compact Guidelines Hook — re-injects guidelines before context compaction
# so they survive in the compacted summary.
# Runs on: PreCompact (all matchers)

# Source the same guidelines used at session start
source "$(dirname "$0")/guidelines-reminder.sh"
