#!/bin/bash
# Tailscale WiFi Monitor
# Automatically starts/stops Tailscale based on WiFi network
#
# When connected to the target WiFi (e.g., "Takeda Guest"):
#   - Starts Tailscale
# When disconnected from the target WiFi:
#   - Stops Tailscale
#
# Usage:
#   ./tailscale-wifi-monitor.sh              # Run once (for LaunchAgent)
#   ./tailscale-wifi-monitor.sh --daemon     # Run continuously (polling mode)
#   ./tailscale-wifi-monitor.sh --status     # Show current state
#   ./tailscale-wifi-monitor.sh --install    # Install LaunchAgent (recommended)
#   ./tailscale-wifi-monitor.sh --uninstall  # Remove LaunchAgent

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────
CONFIG_FILE="$(dirname "$0")/config.json"
LOG_FILE="$HOME/.tailscale-wifi-monitor.log"
STATE_FILE="$HOME/.tailscale-wifi-state"
POLL_INTERVAL=5  # seconds between checks in daemon mode

# ── Load Configuration ─────────────────────────────────────────────────
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: config.json not found at $CONFIG_FILE"
        echo "Copy config.example.json to config.json and edit it."
        exit 1
    fi

    # Requires jq
    if ! command -v jq &>/dev/null; then
        echo "ERROR: jq is required. Install with: brew install jq"
        exit 1
    fi

    TARGET_SSID=$(jq -r '.target_ssid // ""' "$CONFIG_FILE")
    TARGET_ROUTER=$(jq -r '.target_router // ""' "$CONFIG_FILE")
    TAILSCALE_INSTANCE=$(jq -r '.tailscale_instance // "default"' "$CONFIG_FILE")
    TAILSCALE_UP_ARGS=$(jq -r '.tailscale_up_args // ""' "$CONFIG_FILE")
    TAILSCALE_CLI=$(jq -r '.tailscale_cli // "/Applications/Tailscale.app/Contents/MacOS/Tailscale"' "$CONFIG_FILE")

    if [[ -z "$TARGET_ROUTER" ]]; then
        echo "ERROR: target_router not set in config.json"
        echo "Run: networksetup -getinfo Wi-Fi | grep Router"
        exit 1
    fi
}

# ── Logging ────────────────────────────────────────────────────────────
log() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S') $1"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg"
}

# ── Get Current WiFi Router/Gateway IP ─────────────────────────────────
# macOS redacts SSID without Location Services permission, so we identify
# the target network by its gateway/router IP instead — this is reliable
# and doesn't require any special permissions.
get_current_router() {
    local router=""

    # Primary: networksetup -getinfo (works without Location Services)
    router=$(networksetup -getinfo Wi-Fi 2>/dev/null | awk -F': ' '/^Router:/{print $2}')

    # Fallback: route table
    if [[ -z "$router" ]]; then
        router=$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')
    fi

    echo "$router"
}

# ── Check if on target network ─────────────────────────────────────────
is_on_target_network() {
    local current_router
    current_router=$(get_current_router)

    if [[ -z "$current_router" ]]; then
        return 1  # not connected to any network
    fi

    # Check against target router IP
    if [[ "$current_router" == "$TARGET_ROUTER" ]]; then
        return 0
    fi

    # Also check against IP subnet pattern if configured
    local target_subnet
    target_subnet=$(jq -r '.target_subnet // ""' "$CONFIG_FILE")
    if [[ -n "$target_subnet" ]]; then
        local current_ip
        current_ip=$(networksetup -getinfo Wi-Fi 2>/dev/null | awk -F': ' '/^IP address:/{print $2}')
        if [[ "$current_ip" == $target_subnet ]]; then
            return 0
        fi
    fi

    return 1
}

# ── Tailscale State Management ─────────────────────────────────────────
get_tailscale_status() {
    if "$TAILSCALE_CLI" status &>/dev/null; then
        echo "running"
    else
        echo "stopped"
    fi
}

start_tailscale() {
    local current_status
    current_status=$(get_tailscale_status)

    if [[ "$current_status" == "running" ]]; then
        log "Tailscale already running, skipping start"
        return 0
    fi

    log "Starting Tailscale (on target network, router: $TARGET_ROUTER)..."

    # Bring Tailscale up (no flags - just connect)
    "$TAILSCALE_CLI" up 2>&1 | while read -r line; do log "  tailscale: $line"; done

    # Set exit node and LAN access together
    local exit_node
    exit_node=$(jq -r '.exit_node // ""' "$CONFIG_FILE")
    if [[ -n "$exit_node" ]]; then
        log "Setting exit node: $exit_node (with LAN access)"
        "$TAILSCALE_CLI" set --exit-node="$exit_node" --exit-node-allow-lan-access 2>&1 | while read -r line; do log "  tailscale: $line"; done
    fi

    echo "running" > "$STATE_FILE"
    log "Tailscale started successfully"
}

stop_tailscale() {
    local current_status
    current_status=$(get_tailscale_status)

    if [[ "$current_status" == "stopped" ]]; then
        log "Tailscale already stopped, skipping"
        return 0
    fi

    log "Stopping Tailscale (not on target network)..."
    "$TAILSCALE_CLI" down 2>&1 | while read -r line; do log "  tailscale: $line"; done

    echo "stopped" > "$STATE_FILE"
    log "Tailscale stopped successfully"
}

# ── Core Logic ─────────────────────────────────────────────────────────
check_and_toggle() {
    if is_on_target_network; then
        start_tailscale
    else
        stop_tailscale
    fi
}

# ── Status Display ─────────────────────────────────────────────────────
show_status() {
    load_config

    local current_router ts_status on_target
    current_router=$(get_current_router)
    ts_status=$(get_tailscale_status)

    if is_on_target_network; then
        on_target="YES"
    else
        on_target="NO"
    fi

    echo "=== Tailscale WiFi Monitor Status ==="
    echo "Target network:  ${TARGET_SSID:-Takeda Guest} (router: $TARGET_ROUTER)"
    echo "Current router:  ${current_router:-<not connected>}"
    echo "On target WiFi:  $on_target"
    echo "Tailscale:       $ts_status"
    echo "Tailscale CLI:   $TAILSCALE_CLI"
    echo "Log file:        $LOG_FILE"

    if [[ -f "$STATE_FILE" ]]; then
        echo "Last state:      $(cat "$STATE_FILE")"
    fi
}

# ── LaunchAgent Installation ───────────────────────────────────────────
PLIST_NAME="com.pai.tailscale-wifi-monitor"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

install_launchagent() {
    local script_path
    script_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

    # Ensure the script is executable
    chmod +x "$script_path"

    cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${script_path}</string>
    </array>
    <!-- Trigger on ANY network state change -->
    <key>WatchPaths</key>
    <array>
        <string>/Library/Preferences/SystemConfiguration</string>
    </array>
    <!-- Also run every 30 seconds as a safety net -->
    <key>StartInterval</key>
    <integer>30</integer>
    <!-- Run immediately on load -->
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/.tailscale-wifi-monitor-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.tailscale-wifi-monitor-stderr.log</string>
</dict>
</plist>
EOF

    # Load the agent
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    launchctl load "$PLIST_PATH"

    echo "LaunchAgent installed and loaded."
    echo "  Plist: $PLIST_PATH"
    echo "  Triggers: network changes + every 30s safety net"
    echo "  Logs:  $LOG_FILE"
    echo ""
    echo "Tailscale will now automatically:"
    echo "  - START when you connect to '$TARGET_SSID'"
    echo "  - STOP  when you disconnect from '$TARGET_SSID'"
}

uninstall_launchagent() {
    if [[ -f "$PLIST_PATH" ]]; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        rm "$PLIST_PATH"
        echo "LaunchAgent uninstalled."
    else
        echo "LaunchAgent not found at $PLIST_PATH"
    fi
}

# ── Daemon Mode (polling fallback) ─────────────────────────────────────
run_daemon() {
    load_config
    log "Starting daemon mode (polling every ${POLL_INTERVAL}s for SSID: $TARGET_SSID)"

    trap 'log "Daemon stopped"; exit 0' SIGTERM SIGINT

    while true; do
        check_and_toggle
        sleep "$POLL_INTERVAL"
    done
}

# ── Detect Tailscale Installation ──────────────────────────────────────
detect_tailscale() {
    echo "=== Detecting Tailscale Installations ==="
    echo ""

    # Check common locations
    local found=0
    local locations=(
        "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
        "/opt/homebrew/bin/tailscale"
        "/usr/local/bin/tailscale"
    )

    # Also check for multiple Tailscale*.app
    while IFS= read -r -d '' app; do
        local cli="${app}/Contents/MacOS/Tailscale"
        # Add if not already in locations
        local already=0
        for loc in "${locations[@]}"; do
            [[ "$loc" == "$cli" ]] && already=1 && break
        done
        [[ $already -eq 0 ]] && locations+=("$cli")
    done < <(find /Applications -maxdepth 1 -name "Tailscale*.app" -print0 2>/dev/null)

    for cli in "${locations[@]}"; do
        if [[ -x "$cli" ]]; then
            found=$((found + 1))
            echo "[$found] FOUND: $cli"
            if "$cli" status &>/dev/null; then
                echo "    Status: RUNNING"
                # Show exit node info
                local exit_info
                exit_info=$("$cli" status 2>/dev/null | head -20)
                echo "    ---"
                echo "$exit_info" | sed 's/^/    /'
                echo "    ---"
                # Show current exit node if any
                local exit_node
                exit_node=$("$cli" exit-node list 2>/dev/null | grep 'selected' || true)
                if [[ -n "$exit_node" ]]; then
                    echo "    Exit node: $exit_node"
                fi
            else
                echo "    Status: STOPPED / NOT CONNECTED"
            fi
            echo ""
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo "No Tailscale installations found."
        echo "Check if Tailscale is installed at a custom location."
    else
        echo "Found $found installation(s)."
        echo ""
        echo "To configure, set 'tailscale_cli' in config.json to the RUNNING instance's path."
        echo "To capture your current exit node, run:"
        echo "  /Applications/Tailscale.app/Contents/MacOS/Tailscale exit-node list 2>/dev/null | grep selected"
        echo ""
        echo "Then set 'exit_node' in config.json to that node's hostname."
    fi
}

# ── Main ───────────────────────────────────────────────────────────────
case "${1:-}" in
    --daemon)
        run_daemon
        ;;
    --status)
        show_status
        ;;
    --detect)
        detect_tailscale
        ;;
    --install)
        load_config
        install_launchagent
        ;;
    --uninstall)
        uninstall_launchagent
        ;;
    --help|-h)
        echo "Tailscale WiFi Monitor - Auto start/stop Tailscale based on WiFi network"
        echo ""
        echo "Usage:"
        echo "  $0              Run once (check and toggle)"
        echo "  $0 --daemon     Run continuously (polling mode)"
        echo "  $0 --status     Show current state"
        echo "  $0 --detect     Find Tailscale installations and active exit node"
        echo "  $0 --install    Install macOS LaunchAgent (recommended)"
        echo "  $0 --uninstall  Remove LaunchAgent"
        echo ""
        echo "Configuration: Edit config.json in the same directory"
        ;;
    *)
        # Default: single run (used by LaunchAgent)
        load_config
        check_and_toggle
        ;;
esac
