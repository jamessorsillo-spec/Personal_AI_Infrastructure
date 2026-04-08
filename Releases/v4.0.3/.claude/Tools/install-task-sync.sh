#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Apple Notes Task Sync — Install/Uninstall LaunchAgent
# ═══════════════════════════════════════════════════════════════════════════════
#
# Sets up a macOS LaunchAgent that automatically syncs your Apple Notes
# task list to PAI every 30 minutes + on login.
#
# USAGE:
#   ./install-task-sync.sh              # Install (interactive)
#   ./install-task-sync.sh --uninstall  # Remove the scheduled job
#   ./install-task-sync.sh --status     # Check if running
#
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── Configuration ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SERVICE_NAME="com.pai.apple-notes-sync"
PLIST_PATH="$HOME/Library/LaunchAgents/${SERVICE_NAME}.plist"
SYNC_SCRIPT="${SCRIPT_DIR}/apple-notes-sync.sh"
LOG_DIR="$HOME/Library/Logs"
LOG_PATH="${LOG_DIR}/pai-apple-notes-sync.log"
PAI_DIR="${PAI_DIR:-$HOME/.claude}"
CONFIG_FILE="${PAI_DIR}/MEMORY/TASKS/sync-config.json"

# Default sync interval in seconds (30 minutes)
SYNC_INTERVAL=1800

# ── Platform Check ────────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
  echo -e "${RED}ERROR: LaunchAgent is macOS only.${NC}"
  echo "On Linux, use cron or systemd timer instead."
  exit 1
fi

# ── Argument Parsing ──────────────────────────────────────────────────────────
ACTION="install"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall|--remove)
      ACTION="uninstall"
      shift
      ;;
    --status)
      ACTION="status"
      shift
      ;;
    --interval)
      SYNC_INTERVAL="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: install-task-sync.sh [--uninstall] [--status] [--interval SECONDS]"
      echo ""
      echo "Options:"
      echo "  --uninstall    Remove the LaunchAgent"
      echo "  --status       Check sync status"
      echo "  --interval N   Sync interval in seconds (default: 1800 = 30min)"
      echo "  --help         Show this help"
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

# ── Status ────────────────────────────────────────────────────────────────────
if [[ "$ACTION" == "status" ]]; then
  echo -e "${BLUE}═══ Apple Notes Task Sync Status ═══${NC}"
  echo ""

  if launchctl list | grep -q "$SERVICE_NAME" 2>/dev/null; then
    echo -e "${GREEN}  Status: RUNNING${NC}"
    launchctl list "$SERVICE_NAME" 2>/dev/null || true
  else
    echo -e "${YELLOW}  Status: NOT RUNNING${NC}"
  fi

  if [[ -f "$PLIST_PATH" ]]; then
    echo -e "${GREEN}  LaunchAgent: Installed${NC}"
    echo "  Path: $PLIST_PATH"
  else
    echo -e "${YELLOW}  LaunchAgent: Not installed${NC}"
  fi

  TASKS_FILE="${PAI_DIR}/MEMORY/TASKS/master-tasks.md"
  if [[ -f "$TASKS_FILE" ]]; then
    LAST_SYNC=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$TASKS_FILE" 2>/dev/null || echo "unknown")
    LINES=$(wc -l < "$TASKS_FILE")
    echo -e "${GREEN}  Last sync: ${LAST_SYNC}${NC}"
    echo "  Task file: ${LINES} lines"
  else
    echo -e "${YELLOW}  Task file: Not yet created (run first sync)${NC}"
  fi

  if [[ -f "$LOG_PATH" ]]; then
    echo ""
    echo "  Recent log:"
    tail -5 "$LOG_PATH" | sed 's/^/    /'
  fi

  exit 0
fi

# ── Uninstall ─────────────────────────────────────────────────────────────────
if [[ "$ACTION" == "uninstall" ]]; then
  echo -e "${BLUE}═══ Uninstalling Apple Notes Task Sync ═══${NC}"
  echo ""

  if launchctl list | grep -q "$SERVICE_NAME" 2>/dev/null; then
    echo -e "${YELLOW}> Stopping service...${NC}"
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    echo -e "${GREEN}OK Service stopped${NC}"
  fi

  if [[ -f "$PLIST_PATH" ]]; then
    rm "$PLIST_PATH"
    echo -e "${GREEN}OK LaunchAgent removed${NC}"
  fi

  echo ""
  echo -e "${GREEN}Uninstalled. Task files in MEMORY/TASKS/ are preserved.${NC}"
  exit 0
fi

# ── Install ───────────────────────────────────────────────────────────────────
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}     Apple Notes Task Sync — Installation${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}> Checking prerequisites...${NC}"

if [[ ! -f "$SYNC_SCRIPT" ]]; then
  echo -e "${RED}X Sync script not found: ${SYNC_SCRIPT}${NC}"
  exit 1
fi
echo -e "${GREEN}OK Sync script found${NC}"

# Check for existing installation
if launchctl list | grep -q "$SERVICE_NAME" 2>/dev/null; then
  echo -e "${YELLOW}! Task sync is already installed${NC}"
  read -p "  Reinstall? (y/n): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    echo -e "${GREEN}OK Existing service stopped${NC}"
  else
    echo "Installation cancelled."
    exit 0
  fi
fi

# Configure note name
echo ""
echo -e "${YELLOW}> Configuration${NC}"
DEFAULT_NOTE="Master Task List"
read -p "  Apple Note name to sync [${DEFAULT_NOTE}]: " NOTE_NAME
NOTE_NAME="${NOTE_NAME:-$DEFAULT_NOTE}"

read -p "  Apple Notes folder (leave blank for all): " NOTE_FOLDER

read -p "  Auto git push after sync? (y/n) [y]: " -n 1 -r AUTO_PUSH
echo
AUTO_PUSH=${AUTO_PUSH:-y}

INTERVAL_MIN=$((SYNC_INTERVAL / 60))
read -p "  Sync interval in minutes [${INTERVAL_MIN}]: " CUSTOM_INTERVAL
if [[ -n "$CUSTOM_INTERVAL" ]]; then
  SYNC_INTERVAL=$((CUSTOM_INTERVAL * 60))
fi

# Save config
echo -e "${YELLOW}> Saving configuration...${NC}"
mkdir -p "$(dirname "$CONFIG_FILE")"
cat > "$CONFIG_FILE" << EOF
{
  "note_name": "${NOTE_NAME}",
  "note_folder": "${NOTE_FOLDER}",
  "auto_push": $([ "$AUTO_PUSH" = "y" ] && echo "true" || echo "false"),
  "sync_interval_seconds": ${SYNC_INTERVAL},
  "installed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
echo -e "${GREEN}OK Config saved to ${CONFIG_FILE}${NC}"

# Build sync command
SYNC_CMD="${SYNC_SCRIPT}"
[[ -n "$NOTE_FOLDER" ]] && SYNC_CMD="$SYNC_CMD --folder \"${NOTE_FOLDER}\""
SYNC_CMD="$SYNC_CMD --note \"${NOTE_NAME}\""
[[ "$AUTO_PUSH" =~ ^[Yy]$ ]] && SYNC_CMD="$SYNC_CMD --push"

# Create wrapper script (LaunchAgent needs a simple command)
WRAPPER_SCRIPT="${SCRIPT_DIR}/apple-notes-sync-runner.sh"
cat > "$WRAPPER_SCRIPT" << EOF
#!/bin/bash
# Auto-generated wrapper for LaunchAgent
# Do not edit — regenerated by install-task-sync.sh

export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:\$PATH"
export PAI_DIR="${PAI_DIR}"

LOG="${LOG_PATH}"
echo "" >> "\$LOG"
echo "═══ Sync started: \$(date) ═══" >> "\$LOG"

${SYNC_CMD} >> "\$LOG" 2>&1
EXIT_CODE=\$?

echo "═══ Sync finished: \$(date) (exit \$EXIT_CODE) ═══" >> "\$LOG"
exit \$EXIT_CODE
EOF
chmod +x "$WRAPPER_SCRIPT"
echo -e "${GREEN}OK Wrapper script created${NC}"

# Create LaunchAgent plist
echo -e "${YELLOW}> Creating LaunchAgent...${NC}"
mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$LOG_DIR"

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${SERVICE_NAME}</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${WRAPPER_SCRIPT}</string>
    </array>

    <!-- Run on login -->
    <key>RunAtLoad</key>
    <true/>

    <!-- Run every ${SYNC_INTERVAL} seconds (${INTERVAL_MIN} minutes) -->
    <key>StartInterval</key>
    <integer>${SYNC_INTERVAL}</integer>

    <!-- Also run when the task file is deleted (re-sync) -->
    <key>WatchPaths</key>
    <array>
        <string>${PAI_DIR}/MEMORY/TASKS/.sync-trigger</string>
    </array>

    <key>StandardOutPath</key>
    <string>${LOG_PATH}</string>

    <key>StandardErrorPath</key>
    <string>${LOG_PATH}</string>

    <!-- Don't keep retrying on failure -->
    <key>KeepAlive</key>
    <false/>

    <!-- Nice priority — don't hog resources -->
    <key>Nice</key>
    <integer>10</integer>

    <key>ProcessType</key>
    <string>Background</string>
</dict>
</plist>
EOF

echo -e "${GREEN}OK LaunchAgent created at ${PLIST_PATH}${NC}"

# Load the agent
echo -e "${YELLOW}> Starting service...${NC}"
launchctl load "$PLIST_PATH"
echo -e "${GREEN}OK Service started${NC}"

# Run first sync immediately
echo ""
echo -e "${YELLOW}> Running first sync...${NC}"
chmod +x "$SYNC_SCRIPT"
bash "$WRAPPER_SCRIPT" &
SYNC_PID=$!
wait $SYNC_PID 2>/dev/null && echo -e "${GREEN}OK First sync complete${NC}" || echo -e "${YELLOW}! First sync may have had issues — check log${NC}"

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}     Installation Complete${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""
echo "  Note:     \"${NOTE_NAME}\""
[[ -n "$NOTE_FOLDER" ]] && echo "  Folder:   \"${NOTE_FOLDER}\""
echo "  Interval: Every $((SYNC_INTERVAL / 60)) minutes + on login"
echo "  Auto-push: $([ "$AUTO_PUSH" = "y" ] && echo "Yes" || echo "No")"
echo "  Log:      ${LOG_PATH}"
echo ""
echo "  Commands:"
echo "    Check status:  $0 --status"
echo "    Force sync:    touch ${PAI_DIR}/MEMORY/TASKS/.sync-trigger"
echo "    View log:      tail -f ${LOG_PATH}"
echo "    Uninstall:     $0 --uninstall"
echo ""
echo -e "${GREEN}Your Apple Notes tasks will now auto-sync to PAI.${NC}"
