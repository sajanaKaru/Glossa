import AppKit
import ApplicationServices
import Carbon

/// Outcome of attempting an in-place text replacement
enum InPlaceReplacementOutcome: Equatable {
    case success
    case uneditableTarget
    case failed
}

/// Two-Tier In-Place Text Replacement Engine for macOS with Strict Editability Detection
final class InPlaceTextReplacer {
    /// Commits replacement text into the active target application.
    /// - Tier 1: Direct Accessibility attribute write (`kAXSelectedTextAttribute`) for zero-clipboard mutation.
    /// - Tier 2: Universal synthetic `Cmd + V` paste fallback with clipboard backup.
    /// - Returns: `InPlaceReplacementOutcome` indicating success, uneditable target, or failure.
    @discardableResult
    static func replaceSelectedText(
        with text: String,
        targetElement: AXUIElement?
    ) -> InPlaceReplacementOutcome {
        guard !text.isEmpty else { return .failed }

        // 1. Check if target element is genuinely editable before attempting replacement
        if !isElementEditable(targetElement) {
            // Target is read-only or non-interactive (e.g. Preview PDF, static text, uneditable document).
            // Safely back up the polished text to the clipboard so the user's work is not lost.
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return .uneditableTarget
        }

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
                return .success
            }
        }

        // Tier 2: Universal Synthetic Cmd+V Paste Fallback
        let pasted = pasteViaSyntheticCommandV(text)
        if pasted {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .alignment,
                performanceTime: .default
            )
            return .success
        }

        return .failed
    }

    /// Determines whether the target accessibility element is genuinely editable.
    /// Strict positive-confirmation: defaults to false (fail-safe read-only).
    static func isElementEditable(_ element: AXUIElement?) -> Bool {
        guard let elem = element else {
            // Unresolvable element -> fail-safe to read-only so standard dialog opens
            return false
        }

        // 1. Explicit exclusion of known non-editable application bundles
        if let bundleId = getOwningBundleIdentifier(for: elem) {
            let readOnlyBundles: Set<String> = [
                "com.apple.Preview",
                "com.apple.quicklook",
                "com.apple.QuickLookDaemon",
                "com.apple.quicklook.QuickLookUIService"
            ]
            if readOnlyBundles.contains(bundleId) || bundleId.localizedCaseInsensitiveContains("quicklook") {
                return false
            }
        }

        // 2. Check disabled state
        var enabledVal: AnyObject?
        if AXUIElementCopyAttributeValue(elem, kAXEnabledAttribute as CFString, &enabledVal) == .success,
           let isEnabled = (enabledVal as? NSNumber)?.boolValue, !isEnabled {
            return false
        }

        // 3. Inspect Accessibility Role
        var roleVal: AnyObject?
        let role = (AXUIElementCopyAttributeValue(elem, kAXRoleAttribute as CFString, &roleVal) == .success)
            ? (roleVal as? String) : nil

        // Non-editable roles by default
        let nonEditableRoles: Set<String> = [
            "AXStaticText",
            "AXHeading",
            "AXImage",
            "AXWebArea",
            "AXGroup",
            "AXScrollArea"
        ]
        if let role, nonEditableRoles.contains(role) {
            // Must verify explicit editable ancestor (e.g. contenteditable web container)
            return hasEditableAncestor(elem)
        }

        // 4. Direct attribute settability check (Tier 1 confirmation)
        var isSelSettable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(elem, kAXSelectedTextAttribute as CFString, &isSelSettable) == .success,
           isSelSettable.boolValue {
            return true
        }

        // 5. Text Field / Text Area settability check
        if role == "AXTextField" || role == "AXTextArea" {
            var isValSettable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(elem, kAXValueAttribute as CFString, &isValSettable) == .success,
               isValSettable.boolValue {
                return true
            }
        }

        // 6. Ancestor traversal for web contenteditable containers
        return hasEditableAncestor(elem)
    }

    /// Traverses up to 3 parent levels checking for editable ancestors
    private static func hasEditableAncestor(_ element: AXUIElement) -> Bool {
        var currentElem = element
        for _ in 0..<3 {
            var parentVal: AnyObject?
            guard AXUIElementCopyAttributeValue(currentElem, kAXParentAttribute as CFString, &parentVal) == .success,
                  let parent = parentVal else { break }
            let parentElem = parent as! AXUIElement

            var isSelSettable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(parentElem, kAXSelectedTextAttribute as CFString, &isSelSettable) == .success,
               isSelSettable.boolValue {
                return true
            }

            var isValSettable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(parentElem, kAXValueAttribute as CFString, &isValSettable) == .success,
               isValSettable.boolValue {
                var roleVal: AnyObject?
                let role = (AXUIElementCopyAttributeValue(parentElem, kAXRoleAttribute as CFString, &roleVal) == .success)
                    ? (roleVal as? String) : nil
                if role == "AXTextField" || role == "AXTextArea" || role == "AXWebArea" {
                    return true
                }
            }

            currentElem = parentElem
        }
        return false
    }

    /// Obtains the bundle identifier of the application owning the AX element
    private static func getOwningBundleIdentifier(for element: AXUIElement) -> String? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid > 0 else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
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
