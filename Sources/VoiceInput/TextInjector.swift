import AppKit
import CoreGraphics

/// Injects text into the currently focused text field.
/// Primary: CGEvent-based keyboard typing (character by character)
/// Fallback: NSPasteboard + Cmd+V simulation
enum TextInjector {
    private static let sessionTap = CGEventTapLocation(rawValue: 0)!
    /// Type text into the focused text field using CGEvent keyboard events.
    /// Supports Unicode characters including CJK.
    static func typeText(_ text: String) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            fallbackPaste(text)
            return
        }

        let chars = Array(text)

        for char in chars {
            // For basic ASCII, use keyboard events
            if char.isASCII, let scalar = char.unicodeScalars.first {
                let keyCode = keyCodeForASCII(scalar)
                if keyCode != 0xFF {
                    typeKeyCode(keyCode, characters: String(char), source: source)
                    continue
                }
            }

            // For Unicode (CJK, emoji, etc.), use the Unicode text input event
            typeUnicode(String(char), source: source)
        }
    }

    // MARK: - Private

    private static func typeKeyCode(_ code: UInt16, characters: String, source: CGEventSource) {
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true) else { return }
        keyDown.post(tap: sessionTap)

        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) else { return }
        keyUp.post(tap: sessionTap)
    }

    private static func typeUnicode(_ char: String, source: CGEventSource) {
        var codeUnits = Array(char.utf16)
        let length = codeUnits.count

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else { return }
        keyDown.keyboardSetUnicodeString(stringLength: length, unicodeString: &codeUnits)
        keyDown.post(tap: sessionTap)

        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
        keyUp.keyboardSetUnicodeString(stringLength: length, unicodeString: &codeUnits)
        keyUp.post(tap: sessionTap)
    }

    private static func keyCodeForASCII(_ scalar: Unicode.Scalar) -> UInt16 {
        // Common key codes for ASCII characters
        switch scalar {
        case "a": return 0x00; case "s": return 0x01; case "d": return 0x02; case "f": return 0x03
        case "h": return 0x04; case "g": return 0x05; case "z": return 0x06; case "x": return 0x07
        case "c": return 0x08; case "v": return 0x09; case "b": return 0x0B; case "q": return 0x0C
        case "w": return 0x0D; case "e": return 0x0E; case "r": return 0x0F; case "y": return 0x10
        case "t": return 0x11; case "1": return 0x12; case "2": return 0x13; case "3": return 0x14
        case "4": return 0x15; case "6": return 0x16; case "5": return 0x17; case "=": return 0x18
        case "9": return 0x19; case "7": return 0x1A; case "-": return 0x1B; case "8": return 0x1C
        case "0": return 0x1D; case "]": return 0x1E; case "o": return 0x1F; case "u": return 0x20
        case "[": return 0x21; case "i": return 0x22; case "p": return 0x23; case "l": return 0x25
        case "j": return 0x26; case "'": return 0x27; case "k": return 0x28; case ";": return 0x29
        case "\\": return 0x2A; case ",": return 0x2B; case "/": return 0x2C; case "n": return 0x2D
        case "m": return 0x2E; case ".": return 0x2F; case "`": return 0x32; case " ": return 0x31
        default: return 0xFF  // Not a direct key code
        }
    }

    private static func fallbackPaste(_ text: String) {
        // Copy to clipboard, then simulate Cmd+V
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        // Cmd key down
        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true) else { return }
        cmdDown.flags = .maskCommand
        cmdDown.post(tap: sessionTap)

        // V key down
        guard let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) else { return }
        vDown.flags = .maskCommand
        vDown.post(tap: sessionTap)

        // V key up
        guard let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else { return }
        vUp.flags = .maskCommand
        vUp.post(tap: sessionTap)

        // Cmd key up
        guard let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) else { return }
        cmdUp.post(tap: sessionTap)
    }
}
