# umlaut-helper

A lightweight macOS tool that turns Caps Lock into a modifier key for typing German umlauts (ä, ö, ü, ß) without Karabiner-Elements.

**Why not Karabiner?** Karabiner-Elements creates a virtual HID keyboard device driver that routes ALL keyboard events through an extra layer. This adds ~400ms of latency to every keypress, which breaks push-to-talk apps like [Wispr Flow](https://www.wispr.flow/) by clipping the beginning of recordings. This tool uses `hidutil` + a lightweight `CGEventTap` instead, adding only ~1-5ms of latency.

## Default mappings

| Shortcut | Output |
|----------|--------|
| Caps Lock + A | ä |
| Caps Lock + O | ö |
| Caps Lock + U | ü |
| Caps Lock + S | ß |
| Caps Lock + Shift + A | Ä |
| Caps Lock + Shift + O | Ö |
| Caps Lock + Shift + U | Ü |

## How it works

1. **`hidutil`** remaps Caps Lock to F18 at the IOKit level (kernel-level, instant, no virtual device)
2. **`umlaut-helper`** (a compiled Swift binary) runs a `CGEventTap` in user space that intercepts F18 key events and synthesizes Unicode characters when combined with A/O/U/S
3. Two **LaunchAgents** auto-start both on login

Your Option, Control, Command, and all other modifier keys are completely unaffected.

## Installation

```bash
git clone https://github.com/essentialols/umlaut-helper.git
cd umlaut-helper
./install.sh
```

After installation, grant Accessibility permissions:

1. Open **System Settings > Privacy & Security > Accessibility**
2. Click **+** and navigate to the compiled `umlaut-helper` binary (the install script prints its path)
3. Toggle it ON

The tool will auto-restart after permissions are granted.

## Uninstallation

```bash
./uninstall.sh
```

This stops the services, removes the LaunchAgents, and restores Caps Lock to its default behavior.

## Requirements

- macOS 12+ (Monterey or later)
- Xcode Command Line Tools (`xcode-select --install`)
- Accessibility permissions (prompted on first run)

## Extending to other remaps

The architecture (hidutil + CGEventTap) is generic and can be adapted for any key remapping that Karabiner would normally handle. Here's how.

### Adding more characters

Edit the `umlautMap` dictionary in `umlaut-helper.swift`:

```swift
let umlautMap: [Int64: (String, String)] = [
    0:  ("ä", "Ä"),  // A
    1:  ("ß", "ß"),  // S
    31: ("ö", "Ö"),  // O
    32: ("ü", "Ü"),  // U
    // Add more:
    14: ("é", "É"),  // E  (French accent aigu)
    46: ("ñ", "Ñ"),  // M  (or whatever key makes sense)
]
```

macOS virtual key codes for common keys:

| Key | Code | Key | Code | Key | Code |
|-----|------|-----|------|-----|------|
| A | 0 | S | 1 | D | 2 |
| F | 3 | H | 4 | G | 5 |
| Z | 6 | X | 7 | C | 8 |
| V | 9 | B | 11 | Q | 12 |
| W | 13 | E | 14 | R | 15 |
| Y | 16 | T | 17 | 1 | 18 |
| 2 | 19 | 3 | 20 | 4 | 21 |
| 5 | 23 | 6 | 22 | 7 | 26 |
| 8 | 28 | 9 | 25 | 0 | 29 |
| O | 31 | U | 32 | I | 34 |
| P | 35 | L | 37 | J | 38 |
| K | 40 | N | 45 | M | 46 |

### Using a different modifier key

To use a key other than Caps Lock as the modifier, change the `hidutil` mapping in `install.sh`. The source key uses USB HID usage codes prefixed with `0x700000000`:

| Key | HID usage code |
|-----|---------------|
| Caps Lock | `0x700000039` |
| Right Command | `0x7000000E7` |
| Right Option | `0x7000000E6` |
| Right Control | `0x7000000E4` |
| Section (§) | `0x700000064` |

And update the destination. F18 (`0x70000006D`) is a good choice because no physical keyboard has it:

```json
{"UserKeyMapping": [{"HIDKeyboardModifierMappingSrc": 0x7000000E6, "HIDKeyboardModifierMappingDst": 0x70000006D}]}
```

Also update `kF18KeyCode` in the Swift file if you choose a different destination key. F-key virtual codes: F13=105, F14=107, F15=113, F16=106, F17=64, F18=79, F19=80, F20=90.

### Multi-character sequences and dead keys

For more complex behavior (dead keys, multi-character output, context-dependent mappings), extend the `handleEvent` function. For example, to implement a compose key:

```swift
// Track a "compose" state for multi-key sequences
var composeBuffer: Int64? = nil

// In handleEvent, after detecting the modifier is held:
if composeBuffer == nil {
    composeBuffer = keyCode  // store first key
    return nil
} else {
    // Look up the two-key combo
    let combo = (composeBuffer!, keyCode)
    composeBuffer = nil
    if let result = composeMappings[combo] {
        postUnicodeString(result)
        return nil
    }
}
```

### Multiple modifier layers

You can remap multiple keys to different F-keys and track them independently:

```swift
let kF18KeyCode: Int64 = 79  // Caps Lock -> umlaut layer
let kF19KeyCode: Int64 = 80  // Right Option -> math symbols layer

var layer1Active = false
var layer2Active = false
```

This gives you the equivalent of Karabiner's "layers" without the virtual HID overhead.

## How it compares to Karabiner-Elements

| | Karabiner-Elements | umlaut-helper |
|---|---|---|
| Architecture | DriverKit virtual HID keyboard | hidutil + CGEventTap |
| Latency | ~400ms (virtual device driver pipeline) | ~1-5ms (user-space event tap) |
| Scope | Intercepts ALL keyboard events | Only intercepts configured keys |
| Complexity | Full-featured remapping engine | Single-purpose, ~70 lines of Swift |
| Push-to-talk apps | Breaks them (delayed key events) | Compatible (no event pipeline delay) |
| Option key | Unaffected | Unaffected |
| Persists across reboots | Yes (kernel extension) | Yes (LaunchAgents) |

## License

MIT
