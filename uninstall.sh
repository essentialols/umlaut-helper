#!/bin/bash
# uninstall.sh - Remove umlaut-helper and restore Caps Lock

set -e

PLIST_DIR="$HOME/Library/LaunchAgents"

echo "=== Stopping services ==="
launchctl bootout gui/$(id -u) "$PLIST_DIR/com.user.umlaut-helper.plist" 2>/dev/null && echo "Stopped umlaut-helper" || true
launchctl bootout gui/$(id -u) "$PLIST_DIR/com.user.capslock-remap.plist" 2>/dev/null && echo "Stopped capslock-remap" || true

echo ""
echo "=== Removing LaunchAgents ==="
rm -f "$PLIST_DIR/com.user.umlaut-helper.plist"
rm -f "$PLIST_DIR/com.user.capslock-remap.plist"
echo "Removed plist files"

echo ""
echo "=== Restoring Caps Lock ==="
hidutil property --set '{"UserKeyMapping": []}' > /dev/null
echo "Caps Lock restored to normal"

echo ""
echo "=== Done ==="
echo "Caps Lock is back to normal. Reboot recommended to fully clear the remap."
