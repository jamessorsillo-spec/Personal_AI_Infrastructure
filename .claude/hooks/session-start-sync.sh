#!/usr/bin/env bash
# ============================================================
# PAI Config Sync — Session Start
# ============================================================
# Pulls the latest .claude/ configuration from origin so that
# CLAUDE.md, settings, hooks, and context files are current
# across all devices (Mac CLI, web, mobile).
#
# Runs automatically via .claude/settings.json SessionStart hook.
# Safe to run manually: bash .claude/hooks/session-start-sync.sh
# ============================================================

set -euo pipefail

# Locate repo root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$REPO_ROOT"

# Get current branch — skip if detached HEAD
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || exit 0
[[ "$BRANCH" == "HEAD" ]] && exit 0

# Only pull if the branch exists on origin
git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1 || exit 0

# Pull latest with rebase + autostash to avoid merge commits
# and preserve any in-progress local work.
# Retry up to 3 times with exponential backoff for network issues.
for attempt in 1 2 3; do
  if git pull --rebase --autostash origin "$BRANCH" 2>/dev/null; then
    break
  fi
  [ "$attempt" -lt 3 ] && sleep $((attempt * 2))
done

exit 0
