# Tailscale WiFi Manager

Automatically starts and stops Tailscale based on your WiFi network. When you connect to a target network (e.g., "Takeda Guest"), Tailscale turns on. When you disconnect, it turns off.

## Quick Start

### 1. Install Dependencies

```bash
brew install jq
```

### 2. Configure

Edit `config.json`:

```json
{
  "target_ssid": "Takeda Guest",
  "tailscale_cli": "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
  "tailscale_up_args": "",
  "tailscale_instance": "default"
}
```

**Fields:**
- `target_ssid` - WiFi network name that triggers Tailscale to start
- `tailscale_cli` - Path to Tailscale CLI binary (see below for finding yours)
- `tailscale_up_args` - Extra args passed to `tailscale up` (e.g., `"--exit-node=mynode"`)

### 3. Find Your Tailscale CLI Path

If you have **two Tailscale instances**, you need the path to the specific one you want to control:

```bash
# Default Tailscale.app location
/Applications/Tailscale.app/Contents/MacOS/Tailscale

# If installed via Mac App Store
# Same path as above

# If installed via Homebrew
/opt/homebrew/bin/tailscale

# If you have a second instance (e.g., Tailscale for work)
# Check: ls /Applications/Tailscale*.app/Contents/MacOS/Tailscale
```

### 4. Test It

```bash
# Check current status
./tailscale-wifi-monitor.sh --status

# Run once manually
./tailscale-wifi-monitor.sh
```

### 5. Install the LaunchAgent (Recommended)

This installs a background service that watches for network changes:

```bash
./tailscale-wifi-monitor.sh --install
```

The LaunchAgent triggers on:
- **Network state changes** (instant detection via `/Library/Preferences/SystemConfiguration`)
- **Every 30 seconds** as a safety net

### Uninstall

```bash
./tailscale-wifi-monitor.sh --uninstall
```

## How It Works

```
WiFi connects to "Takeda Guest"
  → macOS detects network change
  → LaunchAgent triggers monitor script
  → Script sees SSID matches target
  → Runs: tailscale up
  
WiFi disconnects / switches network
  → macOS detects network change  
  → LaunchAgent triggers monitor script
  → Script sees SSID doesn't match
  → Runs: tailscale down
```

## Commands

| Command | Description |
|---------|-------------|
| `./tailscale-wifi-monitor.sh` | Run once (check WiFi, toggle Tailscale) |
| `./tailscale-wifi-monitor.sh --status` | Show current WiFi and Tailscale state |
| `./tailscale-wifi-monitor.sh --install` | Install macOS LaunchAgent |
| `./tailscale-wifi-monitor.sh --uninstall` | Remove LaunchAgent |
| `./tailscale-wifi-monitor.sh --daemon` | Run in polling mode (every 5s) |

## Logs

- Main log: `~/.tailscale-wifi-monitor.log`
- LaunchAgent stdout: `~/.tailscale-wifi-monitor-stdout.log`
- LaunchAgent stderr: `~/.tailscale-wifi-monitor-stderr.log`

## Two Tailscale Instances

If you have two Tailscale installations (e.g., personal + work), this tool controls **one** of them based on the `tailscale_cli` path in `config.json`. Set it to whichever instance you need active on the guest WiFi.

To manage both instances on different networks, duplicate the tool directory and create separate configs with different `target_ssid` and `tailscale_cli` values.

## Troubleshooting

**"You are not associated with an AirPort network"**
- You're not connected to any WiFi. Tailscale will be stopped (expected behavior).

**Tailscale doesn't start/stop**
- Check the CLI path: run the path in `tailscale_cli` directly in Terminal
- Check permissions: Tailscale may need admin approval for `up`/`down`
- Check logs: `cat ~/.tailscale-wifi-monitor.log`

**LaunchAgent not triggering**
- Verify it's loaded: `launchctl list | grep tailscale`
- Reload: `launchctl unload ~/Library/LaunchAgents/com.pai.tailscale-wifi-monitor.plist && launchctl load ~/Library/LaunchAgents/com.pai.tailscale-wifi-monitor.plist`
