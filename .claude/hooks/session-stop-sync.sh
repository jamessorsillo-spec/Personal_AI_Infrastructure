#!/usr/bin/env bash
# ============================================================
# PAI Config Sync — Session Stop
# ============================================================
# Auto-commits and pushes any .claude/ directory changes made
# during this session so they propagate to all devices.
#
# SCOPE: Only touches files under .claude/ — never modifies,
#        stages, or commits other project files.
#
# Runs automatically via .claude/settings.json SessionEnd hook.
# Safe to run manually: bash .claude/hooks/session-stop-sync.sh
# ============================================================

set -euo pipefail

# Locate repo root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$REPO_ROOT"

# ── Detect .claude/ changes ──────────────────────────────────
MODIFIED="$(git diff --name-only -- .claude/ 2>/dev/null || true)"
STAGED="$(git diff --cached --name-only -- .claude/ 2>/dev/null || true)"
UNTRACKED="$(git ls-files --others --exclude-standard -- .claude/ 2>/dev/null || true)"

# Nothing to sync — exit cleanly
if [[ -z "$MODIFIED" && -z "$STAGED" && -z "$UNTRACKED" ]]; then
  exit 0
fi

# ── Stage only .claude/ files ────────────────────────────────
git add .claude/

# ── Build a descriptive commit message ───────────────────────
CHANGED_FILES="$(git diff --cached --name-only -- .claude/ 2>/dev/null)"

# Exit if staging produced nothing (e.g., only gitignored files)
[[ -z "$CHANGED_FILES" ]] && exit 0

FILE_COUNT="$(echo "$CHANGED_FILES" | wc -l | tr -d ' ')"
SUMMARY="$(echo "$CHANGED_FILES" | head -3 | sed 's|\.claude/||' | paste -sd ', ' -)"

if [ "$FILE_COUNT" -gt 3 ]; then
  SUMMARY="$SUMMARY (+$((FILE_COUNT - 3)) more)"
fi

git commit -m "sync: update PAI config — $SUMMARY [skip ci]" 2>/dev/null || exit 0

# ── Push with retry + exponential backoff ────────────────────
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || exit 0
[[ "$BRANCH" == "HEAD" ]] && exit 0

for attempt in 1 2 3 4; do
  if git push -u origin "$BRANCH" 2>/dev/null; then
    break
  fi
  [ "$attempt" -lt 4 ] && sleep $((attempt * 2))
done

exit 0
