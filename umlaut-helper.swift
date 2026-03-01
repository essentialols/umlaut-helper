// umlaut-helper.swift
// Tiny CGEventTap-based tool that makes Caps Lock + vowel produce German umlauts.
// Caps Lock is remapped to F18 via hidutil (see install.sh), so this tool
// intercepts F18 key events and synthesizes ä/ö/ü/ß when combined with A/O/U/S.
// No virtual HID keyboard, no Karabiner, ~1-5ms latency.

import Foundation
import CoreGraphics

// F18 virtual key code (Caps Lock is remapped to this via hidutil)
let kF18KeyCode: Int64 = 79

// State
var capsHeld = false
var usedAsModifier = false
var activeTap: CFMachPort?

// Umlaut mappings: keyCode -> (lowercase, uppercase)
let umlautMap: [Int64: (String, String)] = [
    0:  ("ä", "Ä"),  // A
    1:  ("ß", "ß"),  // S (no uppercase ß in standard use)
    31: ("ö", "Ö"),  // O
    32: ("ü", "Ü"),  // U
]

func postUnicodeString(_ str: String) {
    let chars = Array(str.utf16)
    if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
        keyDown.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
    }
    if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}

let callback: CGEventTapCallBack = { proxy, type, event, refcon in
    // Re-enable tap if system disabled it
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = activeTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

    // Track F18 (remapped Caps Lock) held state
    if keyCode == kF18KeyCode {
        if type == .keyDown {
            capsHeld = true
            usedAsModifier = false
        } else if type == .keyUp {
            capsHeld = false
        }
        return nil // suppress F18 events entirely
    }

    // While "Caps Lock" is held, check for umlaut keys
    if type == .keyDown && capsHeld {
        if let (lower, upper) = umlautMap[keyCode] {
            usedAsModifier = true
            let shiftHeld = event.flags.contains(.maskShift)
            postUnicodeString(shiftHeld ? upper : lower)
            return nil // suppress original key event
        }
    }

    return Unmanaged.passUnretained(event)
}

// Create event tap
let eventMask: CGEventMask =
    (1 << CGEventType.keyDown.rawValue) |
    (1 << CGEventType.keyUp.rawValue)

guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: eventMask,
    callback: callback,
    userInfo: nil
) else {
    fputs("ERROR: Failed to create event tap.\n", stderr)
    fputs("Grant Accessibility permissions:\n", stderr)
    fputs("  System Settings > Privacy & Security > Accessibility > umlaut-helper\n", stderr)
    exit(1)
}

activeTap = tap
let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

fputs("umlaut-helper running. Caps Lock + A/O/U/S = ä/ö/ü/ß\n", stderr)
CFRunLoopRun()
