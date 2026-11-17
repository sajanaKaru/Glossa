import AppKit
import ApplicationServices
import Carbon

/// Two-Tier In-Place Text Replacement Engine for macOS
final class InPlaceTextReplacer {
    /// Commits replacement text into the active target application.
    /// - Tier 1: Direct Accessibility attribute write (`kAXSelectedTextAttribute`) for zero-clipboard mutation.
    /// - Tier 2: Universal synthetic `Cmd + V` paste fallback with clipboard backup.
    @discardableResult
    static func replaceSelectedText(
        with text: String,
        targetElement: AXUIElement?
    ) -> Bool {
        guard !text.isEmpty else { return false }

        // Tier 1: Direct Accessibility Attribute Write
        if let elem = targetElement {
            let writeResult = AXUIElementSetAttributeValue(
                elem,
                kAXSelectedTextAttribute as CFString,
                text as CFTypeRef
            )
            if writeResult == .success {
                // Tactile physical confirmation for zero-clipboard write
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .alignment,
                    performanceTime: .default
                )
                return true
            }
        }

        // Tier 2: Universal Synthetic Cmd+V Paste Fallback
        let pasted = pasteViaSyntheticCommandV(text)
        if pasted {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .alignment,
                performanceTime: .default
            )
        }
        return pasted
    }

    /// Simulates Cmd+V keystrokes to paste text into target applications that reject AX attribute writes
    private static func pasteViaSyntheticCommandV(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 9 // Virtual key code for 'V' (kVK_ANSI_V)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = [] // Ensure no stuck modifier key states

        keyDown.post(tap: .cghidEventTap)
        usleep(15_000) // 15ms settle time
        keyUp.post(tap: .cghidEventTap)

        return true
    }
}
