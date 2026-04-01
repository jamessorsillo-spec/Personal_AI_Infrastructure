#!/bin/bash
# Uninstall Homebrew Tailscale (the broken instance)
#
# Keeps: /Applications/Tailscale.app (the working Mac App Store version)
# Removes: /opt/homebrew/bin/tailscale (Homebrew install)
#
# Run: ./uninstall-homebrew-tailscale.sh

set -euo pipefail

echo "=== Uninstall Homebrew Tailscale ==="
echo ""
echo "This will REMOVE:  Homebrew tailscale (/opt/homebrew/bin/tailscale)"
echo "This will KEEP:    Tailscale.app (/Applications/Tailscale.app)"
echo ""

# Safety check: make sure the App version is running
if /Applications/Tailscale.app/Contents/MacOS/Tailscale status &>/dev/null; then
    echo "[OK] Tailscale.app is running and healthy"
else
    echo "[WARNING] Tailscale.app doesn't appear to be running."
    echo "Make sure your working Tailscale is active before removing the other one."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

# Check if homebrew tailscale exists
if ! brew list tailscale &>/dev/null 2>&1; then
    echo "[INFO] Homebrew tailscale not found via 'brew list'."
    if [[ -x /opt/homebrew/bin/tailscale ]]; then
        echo "[INFO] But /opt/homebrew/bin/tailscale binary exists."
        echo "It may have been installed outside Homebrew or partially removed."
    else
        echo "Nothing to uninstall."
        exit 0
    fi
fi

read -p "Proceed with uninstall? (y/N) " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || exit 1

echo ""
echo "Stopping Homebrew tailscale daemon if running..."
# Stop the homebrew tailscale daemon (launchd service)
brew services stop tailscale 2>/dev/null || true
sudo brew services stop tailscale 2>/dev/null || true

echo "Uninstalling via Homebrew..."
brew uninstall tailscale 2>/dev/null || brew remove tailscale 2>/dev/null || true

# Clean up any leftover homebrew tailscale state
if [[ -d /opt/homebrew/var/tailscale ]]; then
    echo "Removing Homebrew tailscale state dir..."
    sudo rm -rf /opt/homebrew/var/tailscale
fi

# Remove any homebrew tailscale launchd plists
for plist in ~/Library/LaunchAgents/*tailscale* /Library/LaunchDaemons/*tailscale*; do
    if [[ -f "$plist" && "$plist" != *"com.tailscale.ipn.macsys"* ]]; then
        echo "Removing leftover plist: $plist"
        sudo launchctl unload "$plist" 2>/dev/null || true
        sudo rm -f "$plist"
    fi
done

echo ""
echo "=== Done ==="
echo ""

# Verify the app version still works
if /Applications/Tailscale.app/Contents/MacOS/Tailscale status &>/dev/null; then
    echo "[OK] Tailscale.app is still running fine"
    echo ""
    echo "You can also remove the stale device 'l772n9c7v0' from your Tailscale admin console"
    echo "at https://login.tailscale.com/admin/machines — it's the old Homebrew instance"
    echo "(shows as offline 5d+). Your active device is 'l772n9c7v0-1'."
else
    echo "[WARNING] Tailscale.app may need to be restarted."
    echo "Open Tailscale from /Applications to restart it."
fi
