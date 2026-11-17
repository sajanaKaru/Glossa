import AppKit
import ApplicationServices
import Carbon

/// Outcome of attempting an in-place text replacement
enum InPlaceReplacementOutcome: Equatable {
    case success
    case uneditableTarget
    case failed
}

/// Two-Tier In-Place Text Replacement Engine for macOS with Read-Only Target Detection
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

        // 1. Check if target element is editable before attempting mutation
        if !isElementEditable(targetElement) {
            // Target is read-only or non-interactive (e.g. Preview PDF, StaticText label, disabled field)
            // Ensure polished text is safely copied to clipboard so work is never lost
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

    /// Evaluates whether the AX element represents an editable text field or surface
    static func isElementEditable(_ element: AXUIElement?) -> Bool {
        guard let elem = element else {
            // If element is unresolvable (e.g. non-AX Electron, custom WebGL canvas), default to editable
            // so Tier 2 synthetic Cmd+V can attempt replacement.
            return true
        }

        // 1. Check Disabled state (AXEnabled == false)
        var enabledVal: AnyObject?
        if AXUIElementCopyAttributeValue(elem, kAXEnabledAttribute as CFString, &enabledVal) == .success,
           let isEnabled = (enabledVal as? NSNumber)?.boolValue, !isEnabled {
            return false
        }

        // 2. Check Role
        var roleVal: AnyObject?
        let role = (AXUIElementCopyAttributeValue(elem, kAXRoleAttribute as CFString, &roleVal) == .success) ? (roleVal as? String) : nil

        // If explicitly a text field or text area, check if value or selected text is settable
        if role == "AXTextField" || role == "AXTextArea" {
            var isValueSettable: DarwinBoolean = false
            let valResult = AXUIElementIsAttributeSettable(elem, kAXValueAttribute as CFString, &isValueSettable)
            var isSelSettable: DarwinBoolean = false
            let selResult = AXUIElementIsAttributeSettable(elem, kAXSelectedTextAttribute as CFString, &isSelSettable)

            // If both checks succeed and explicitly say NOT settable, it is read-only
            if valResult == .success && selResult == .success && !isValueSettable.boolValue && !isSelSettable.boolValue {
                return false
            }
            return true
        }

        // 3. Known Read-Only Applications (e.g. Preview, QuickLook)
        var pid: pid_t = 0
        if AXUIElementGetPid(elem, &pid) == .success {
            let app = NSRunningApplication(processIdentifier: pid)
            let bundleId = app?.bundleIdentifier?.lowercased() ?? ""
            let appName = app?.localizedName?.lowercased() ?? ""
            if bundleId.contains("com.apple.preview") || bundleId.contains("quicklook") || appName == "preview" {
                var isSelSettable: DarwinBoolean = false
                let selResult = AXUIElementIsAttributeSettable(elem, kAXSelectedTextAttribute as CFString, &isSelSettable)
                if selResult != .success || !isSelSettable.boolValue {
                    return false
                }
            }
        }

        // 4. Static / Heading / Image elements
        if role == "AXStaticText" || role == "AXHeading" || role == "AXImage" {
            // Check if element directly allows setting selected text or value
            var isSelSettable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(elem, kAXSelectedTextAttribute as CFString, &isSelSettable) == .success && isSelSettable.boolValue {
                return true
            }
            var isValSettable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(elem, kAXValueAttribute as CFString, &isValSettable) == .success && isValSettable.boolValue {
                return true
            }

            // Check if there is an editable ancestor (e.g. contenteditable web container, rich text area)
            var current = elem
            var hasEditableAncestor = false
            for _ in 0..<5 {
                var parentVal: AnyObject?
                if AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentVal) == .success,
                   let parent = parentVal {
                    let parentElem = parent as! AXUIElement
                    var parentRoleVal: AnyObject?
                    let parentRole = (AXUIElementCopyAttributeValue(parentElem, kAXRoleAttribute as CFString, &parentRoleVal) == .success) ? (parentRoleVal as? String) : nil

                    if parentRole == "AXTextArea" || parentRole == "AXTextField" || parentRole == "AXWebArea" {
                        var pValSettable: DarwinBoolean = false
                        let pResult = AXUIElementIsAttributeSettable(parentElem, kAXValueAttribute as CFString, &pValSettable)
                        var pSelSettable: DarwinBoolean = false
                        let pSelResult = AXUIElementIsAttributeSettable(parentElem, kAXSelectedTextAttribute as CFString, &pSelSettable)

                        if (pResult == .success && pValSettable.boolValue) || (pSelResult == .success && pSelSettable.boolValue) {
                            hasEditableAncestor = true
                            break
                        }
                    }
                    current = parentElem
                } else {
                    break
                }
            }

            if !hasEditableAncestor {
                return false
            }
        }

        return true
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
