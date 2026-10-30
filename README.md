# umlaut-helper

A small macOS helper that turns Caps Lock into a modifier for typing German umlauts without routing the whole keyboard through a full remapping application.

Default mappings:

| Shortcut | Output |
| --- | --- |
| Caps Lock + A | ä |
| Caps Lock + O | ö |
| Caps Lock + U | ü |
| Caps Lock + S | ß |
| Caps Lock + Shift + A | Ä |
| Caps Lock + Shift + O | Ö |
| Caps Lock + Shift + U | Ü |

## Why

Karabiner-Elements was too slow for push-to-talk dictation on the author's machine: roughly 400 ms of perceived delay, versus roughly 1-5 ms with this helper. These are informal observations, not benchmarks, and will vary by Mac, keyboard and Karabiner version.

This is a single-purpose utility, not a general remapping framework. It has no automated tests or CI.

## How it works

1. `install.sh` uses `/usr/bin/hidutil` to replace the current `UserKeyMapping` with a Caps Lock -> F18 mapping.
2. `umlaut-helper.swift` compiles to a small binary that installs a Core Graphics event tap (`CGEventTap`).
3. The event tap suppresses F18 and, while it is held, converts A/O/U/S key-down events into Unicode ä/ö/ü/ß characters.
4. Two LaunchAgents are written under `~/Library/LaunchAgents`: one reapplies the `hidutil` mapping at login and one keeps the compiled helper running.

Option, Control, Command, and other modifiers are otherwise passed through by the helper.

## Important install-state caveats

### Existing `hidutil` mappings are overwritten

The installer does **not** merge with an existing `UserKeyMapping`. It sets the entire value to the single Caps Lock -> F18 mapping:

```text
Caps Lock -> F18
```

Likewise, `uninstall.sh` restores Caps Lock by setting `UserKeyMapping` to an empty array. If you already use `hidutil` for other remaps, save/reapply those mappings yourself before installing or uninstalling this helper.

You can inspect the current mapping with:

```bash
hidutil property --get UserKeyMapping
```

### Keep the repository at the same path after installation

`install.sh` compiles the binary **inside this checkout** and writes its absolute path into `com.user.umlaut-helper.plist`. Moving or deleting the repository afterward can therefore break the LaunchAgent.

If you want to relocate the checkout, uninstall first, move it, and then run `./install.sh` again from the new location.

## Installation

Requirements:

- macOS 12 Monterey or later
- Xcode Command Line Tools (`xcode-select --install`)
- Accessibility permission for the compiled helper

Install:

```bash
git clone https://github.com/essentialols/umlaut-helper.git
cd umlaut-helper
./install.sh
```

Then grant Accessibility permission:

1. Open **System Settings -> Privacy & Security -> Accessibility**.
2. Click **+** and select the compiled `umlaut-helper` binary. The installer prints its absolute path.
3. Enable it.

The LaunchAgent is configured with `KeepAlive`, so the helper is restarted after it exits.

## Uninstallation

```bash
./uninstall.sh
```

The script unloads both LaunchAgents, removes their property-list files, and sets `UserKeyMapping` to `[]`.

Again, if you had unrelated `hidutil` mappings before installing this project, that command does **not** reconstruct them; reapply your saved mapping afterward.

## Repository layout

| Path | Purpose |
| --- | --- |
| `umlaut-helper.swift` | Event-tap implementation and character map |
| `install.sh` | Compiles the binary, installs the Caps Lock to F18 mapping, and writes/loads both LaunchAgents |
| `uninstall.sh` | Unloads/removes the LaunchAgents and clears `UserKeyMapping` |
| `LICENSE` | MIT license |

## Customizing the character map

Edit `umlautMap` in `umlaut-helper.swift`:

```swift
let umlautMap: [Int64: (String, String)] = [
    0:  ("ä", "Ä"),  // A
    1:  ("ß", "ß"),  // S
    31: ("ö", "Ö"),  // O
    32: ("ü", "Ü"),  // U
    // Examples:
    14: ("é", "É"),  // E
    46: ("ñ", "Ñ"),  // M
]
```

Common macOS virtual key codes:

| Key | Code | Key | Code | Key | Code |
| --- | ---: | --- | ---: | --- | ---: |
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

After changing the Swift source, rerun `./install.sh` so the installed binary is rebuilt.

## Using another modifier key

The Caps Lock source usage and F18 destination are embedded in `install.sh` in two places: the immediate `hidutil` command and the generated LaunchAgent. If you change the mapping, keep those two copies synchronized.

USB Human Interface Device (HID) usage codes for common source keys:

| Key | HID usage code |
| --- | --- |
| Caps Lock | `0x700000039` |
| Right Command | `0x7000000E7` |
| Right Option | `0x7000000E6` |
| Right Control | `0x7000000E4` |
| Section (§) | `0x700000064` |

F18 is `0x70000006D` and its macOS virtual key code in the Swift source is `79`. If you choose a different destination, update `kF18KeyCode` as well.

F-key virtual codes: F13=105, F14=107, F15=113, F16=106, F17=64, F18=79, F19=80, F20=90.

## More complex remaps

Event handling lives in the `callback` closure assigned to `CGEventTapCallBack`. For multi-character sequences, dead-key behavior or extra layers, extend that callback and keep any state beside the existing `capsHeld` / `usedAsModifier` state. If you add another remapped modifier layer, use a distinct destination key, track its held state separately, and keep the `hidutil` mappings, virtual key codes and event-tap logic in sync.

## Comparison with a full remapping tool

| | Karabiner-Elements | umlaut-helper |
| --- | --- | --- |
| Scope | General-purpose keyboard remapping | One small custom layer |
| Mechanism | Virtual keyboard/remapping stack | `hidutil` + Core Graphics event tap |
| Persistence | Managed by Karabiner's services | Reapplied by LaunchAgents |
| Flexibility | High | Requires editing Swift/shell code |
| Observed push-to-talk delay | about 400 ms | about 1-5 ms |

The latency row records informal observations from the author's setup, not a general benchmark of Karabiner-Elements.

## License

MIT, see [LICENSE](LICENSE).
