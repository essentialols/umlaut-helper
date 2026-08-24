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

## Status

This is a single-purpose utility rather than a general remapping framework. The repository contains the Swift event-tap implementation plus install/uninstall scripts; there is no automated test suite or Continuous Integration (CI) configuration.

The original motivation for the project was an observed push-to-talk latency problem with Karabiner-Elements. The initial repository notes reported roughly **~400 ms** of perceived delay with that setup versus **~1–5 ms** with this helper. Those figures are preserved as motivating observations, not as independently benchmarked guarantees for every Mac, keyboard, or Karabiner version.

## How it works

1. `install.sh` uses `/usr/bin/hidutil` to replace the current `UserKeyMapping` with a Caps Lock → F18 mapping.
2. `umlaut-helper.swift` compiles to a small binary that installs a Core Graphics event tap (`CGEventTap`).
3. The event tap suppresses F18 and, while it is held, converts A/O/U/S key-down events into Unicode ä/ö/ü/ß characters.
4. Two LaunchAgents are written under `~/Library/LaunchAgents`: one reapplies the `hidutil` mapping at login and one keeps the compiled helper running.

Option, Control, Command, and other modifiers are otherwise passed through by the helper.

## Important install-state caveats

### Existing `hidutil` mappings are overwritten

The installer does **not** merge with an existing `UserKeyMapping`. It sets the entire value to the single Caps Lock → F18 mapping:

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

- macOS 12 Monterey or later, as originally targeted by this repository
- Xcode Command Line Tools (`xcode-select --install`)
- Accessibility permission for the compiled helper

Install:

```bash
git clone https://github.com/essentialols/umlaut-helper.git
cd umlaut-helper
./install.sh
```

Then grant Accessibility permission:

1. Open **System Settings → Privacy & Security → Accessibility**.
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
| `install.sh` | Compiles the binary, installs the Caps Lock → F18 mapping, and writes/loads both LaunchAgents |
| `uninstall.sh` | Unloads/removes the LaunchAgents and clears `UserKeyMapping` |
| `.gitignore` | Excludes the locally compiled `umlaut-helper` binary and local/editor artifacts |
| `LICENSE` | MIT license |

The repository is intentionally flat: these are a handful of directly related entrypoints, and moving the Swift source would require updating the explicit path used by `install.sh` without providing a meaningful navigation benefit.

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

Common macOS virtual key codes used by the original guide:

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

The original guide used these USB Human Interface Device (HID) usage codes:

| Key | HID usage code |
| --- | --- |
| Caps Lock | `0x700000039` |
| Right Command | `0x7000000E7` |
| Right Option | `0x7000000E6` |
| Right Control | `0x7000000E4` |
| Section (§) | `0x700000064` |

F18 is `0x70000006D` and its macOS virtual key code in the Swift source is `79`. If you choose a different destination, update `kF18KeyCode` as well.

The original F-key virtual-code reference was: F13=105, F14=107, F15=113, F16=106, F17=64, F18=79, F19=80, F20=90.

## More complex remaps

There is no `handleEvent` function in the current source. Event handling lives directly in the `callback` closure assigned to `CGEventTapCallBack`.

For multi-character sequences, dead-key behavior, or additional layers, extend that callback and keep any state beside the existing `capsHeld` / `usedAsModifier` state. For example, a compose-like layer could store the first key while the remapped modifier is held and consume the next key before calling `postUnicodeString`.

If you add another remapped modifier layer, use a distinct destination key and track that key's held state separately. Keep the corresponding `hidutil` mappings, virtual key codes, and event-tap logic in sync.

## Comparison with a full remapping tool

This project deliberately makes a narrower tradeoff than Karabiner-Elements:

| | Karabiner-Elements | umlaut-helper |
| --- | --- | --- |
| Intended scope | General-purpose keyboard remapping | One small custom layer |
| Event architecture | Virtual keyboard/remapping stack | `hidutil` + Core Graphics event tap |
| Keys handled | Broad remapping rules | Only the configured event-tap behavior |
| Persistence | Managed by Karabiner's services/configuration | Reapplied by LaunchAgents |
| Flexibility | High | Requires editing Swift/shell code |
| Reported motivation in this repo | Perceived ~400 ms push-to-talk delay in the original setup | Reported ~1–5 ms in the original setup |

The latency row records the project's original observations; it should not be read as a current general benchmark of Karabiner-Elements.

## License

MIT
