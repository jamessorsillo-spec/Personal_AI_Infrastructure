#!/usr/bin/env bash
set -euo pipefail

# Install Email Triage Copilot into PAI
#
# Usage:
#   bash install.sh [--pai-dir ~/.claude] [--dry-run]
#
# This copies the skill, actions, pipeline, and context into your PAI installation.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAI_DIR="${PAI_DIR:-$HOME/.claude}"
DRY_RUN=false

for arg in "$@"; do
  case $arg in
    --pai-dir=*) PAI_DIR="${arg#*=}" ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      echo "Usage: bash install.sh [--pai-dir=~/.claude] [--dry-run]"
      echo ""
      echo "Installs Email Triage Copilot into your PAI directory."
      echo ""
      echo "Options:"
      echo "  --pai-dir=PATH  PAI installation directory (default: ~/.claude)"
      echo "  --dry-run       Show what would be installed without copying"
      exit 0
      ;;
  esac
done

echo "Email Triage Copilot — Installer"
echo "================================"
echo ""
echo "PAI directory: $PAI_DIR"
echo ""

install_component() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] $label"
    echo "    $src → $dst"
  else
    mkdir -p "$(dirname "$dst")"
    cp -r "$src" "$dst"
    echo "  [OK] $label"
    echo "    → $dst"
  fi
}

echo "Installing components:"
echo ""

# 1. Skill
install_component \
  "$SCRIPT_DIR/skill" \
  "$PAI_DIR/skills/Utilities/EmailTriage" \
  "PAI Skill: EmailTriage"

# 2. Actions
install_component \
  "$SCRIPT_DIR/actions/A_TRIAGE_EMAIL" \
  "$PAI_DIR/PAI/USER/ACTIONS/A_TRIAGE_EMAIL" \
  "Action: A_TRIAGE_EMAIL"

install_component \
  "$SCRIPT_DIR/actions/A_DRAFT_EMAIL_REPLY" \
  "$PAI_DIR/PAI/USER/ACTIONS/A_DRAFT_EMAIL_REPLY" \
  "Action: A_DRAFT_EMAIL_REPLY"

# 3. Pipeline
install_component \
  "$SCRIPT_DIR/pipeline" \
  "$PAI_DIR/PAI/USER/PIPELINES/Email_Triage" \
  "Pipeline: P_EMAIL_TRIAGE"

# 4. Email context (only if USER/WORK exists)
if [ -d "$PAI_DIR/PAI/USER/WORK" ]; then
  install_component \
    "$SCRIPT_DIR/../EmailTriageCopilot/../../Releases/v4.0.3/.claude/PAI/USER/WORK/EMAIL.md" \
    "$PAI_DIR/PAI/USER/WORK/EMAIL.md" \
    "Context: EMAIL.md"
else
  echo "  [SKIP] USER/WORK/EMAIL.md — directory does not exist"
fi

# 5. CLAUDE.md for copilot mode
install_component \
  "$SCRIPT_DIR/CLAUDE.md" \
  "$PAI_DIR/PAI/USER/WORK/EMAIL_TRIAGE_CLAUDE.md" \
  "Copilot Instructions: CLAUDE.md"

echo ""
echo "Installation complete."
echo ""
echo "Next steps:"
echo "  1. Ensure Gmail MCP servers are connected (see mcp-servers.json)"
echo "  2. In Claude Code, say: 'triage my inbox'"
echo "  3. Or run: /email-triage"
echo ""
echo "For cloud deployment (Cloudflare Workers):"
echo "  bash $SCRIPT_DIR/deploy.sh all"
echo "  bash $SCRIPT_DIR/deploy.sh secrets"
