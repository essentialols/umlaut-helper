#!/bin/bash
# install.sh - Compile and install umlaut-helper
# Sets up: hidutil Caps Lock -> F18 remap + umlaut-helper LaunchAgent

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY="$SCRIPT_DIR/umlaut-helper"
PLIST_DIR="$HOME/Library/LaunchAgents"

echo "=== Compiling umlaut-helper ==="
swiftc -O "$SCRIPT_DIR/umlaut-helper.swift" -o "$BINARY"
echo "Built: $BINARY"

echo ""
echo "=== Setting up hidutil: Caps Lock -> F18 ==="
# Remap Caps Lock (0x700000039) to F18 (0x70000006D)
hidutil property --set '{"UserKeyMapping": [{"HIDKeyboardModifierMappingSrc": 0x700000039, "HIDKeyboardModifierMappingDst": 0x70000006D}]}' > /dev/null
echo "Caps Lock remapped to F18 (active now)"

echo ""
echo "=== Installing LaunchAgents ==="
mkdir -p "$PLIST_DIR"

# LaunchAgent for hidutil (reapply on login since hidutil doesn't persist across reboots)
cat > "$PLIST_DIR/com.user.capslock-remap.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.capslock-remap</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/hidutil</string>
        <string>property</string>
        <string>--set</string>
        <string>{"UserKeyMapping": [{"HIDKeyboardModifierMappingSrc": 0x700000039, "HIDKeyboardModifierMappingDst": 0x70000006D}]}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLIST

# LaunchAgent for umlaut-helper
cat > "$PLIST_DIR/com.user.umlaut-helper.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.umlaut-helper</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BINARY</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/tmp/umlaut-helper.log</string>
</dict>
</plist>
PLIST

# Load agents
launchctl bootout gui/$(id -u) "$PLIST_DIR/com.user.capslock-remap.plist" 2>/dev/null || true
launchctl bootout gui/$(id -u) "$PLIST_DIR/com.user.umlaut-helper.plist" 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$PLIST_DIR/com.user.capslock-remap.plist"
launchctl bootstrap gui/$(id -u) "$PLIST_DIR/com.user.umlaut-helper.plist"

echo ""
echo "=== Done ==="
echo "Caps Lock + A = ä    Caps Lock + Shift+A = Ä"
echo "Caps Lock + O = ö    Caps Lock + Shift+O = Ö"
echo "Caps Lock + U = ü    Caps Lock + Shift+U = Ü"
echo "Caps Lock + S = ß"
echo ""
echo "NOTE: You need to grant Accessibility permissions to umlaut-helper:"
echo "  System Settings > Privacy & Security > Accessibility"
echo "  Add: $BINARY"
echo ""
echo "To uninstall, run: $SCRIPT_DIR/uninstall.sh"
