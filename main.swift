import SwiftUI
import AppKit
import ApplicationServices
import Carbon
import Combine

// MARK: - App Entry Point
@main
struct GlossaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - Native Carbon Global Hotkey Manager
final class GlobalHotKeyManager {
    static let shared = GlobalHotKeyManager()
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    var onTrigger: (() -> Void)?
    var onRewriteTrigger: (() -> Void)?
    var hasRegistrationConflict: Bool = false

    func setup() -> Bool {
        teardown()
        hasRegistrationConflict = false

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, theEvent, _ -> OSStatus in
            guard let theEvent = theEvent else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                theEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            if status == noErr {
                DispatchQueue.main.async {
                    if hotKeyID.id == 3 {
                        GlobalHotKeyManager.shared.onRewriteTrigger?()
                    } else {
                        GlobalHotKeyManager.shared.onTrigger?()
                    }
                }
            }
            return noErr
        }

        let installStatus = InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandler)
        guard installStatus == noErr else {
            NSLog("[Glossa] InstallEventHandler failed with status: %d", installStatus)
            hasRegistrationConflict = true
            return false
        }

        // 1. Option + Space (kVK_Space = 49, optionKey = 0x0800)
        let spaceID = EventHotKeyID(signature: OSType(0x474C5353), id: 1) // 'GLSS', 1
        var spaceRef: EventHotKeyRef?
        let spaceStatus = RegisterEventHotKey(UInt32(kVK_Space), UInt32(optionKey), spaceID, GetApplicationEventTarget(), 0, &spaceRef)
        if spaceStatus == noErr, let r = spaceRef {
            hotKeyRefs.append(r)
            NSLog("[Glossa] Successfully registered Carbon Global HotKey: Option+Space")
        } else {
            NSLog("[Glossa] Failed to register Carbon Global HotKey Option+Space with status: %d", spaceStatus)
            hasRegistrationConflict = true
        }

        // 2. Option + Shift + L (kVK_ANSI_L = 37, optionKey | shiftKey)
        let lID = EventHotKeyID(signature: OSType(0x474C5353), id: 2) // 'GLSS', 2
        var lRef: EventHotKeyRef?
        let lStatus = RegisterEventHotKey(UInt32(kVK_ANSI_L), UInt32(optionKey | shiftKey), lID, GetApplicationEventTarget(), 0, &lRef)
        if lStatus == noErr, let r = lRef {
            hotKeyRefs.append(r)
            NSLog("[Glossa] Successfully registered Carbon Global HotKey: Option+Shift+L")
        } else {
            NSLog("[Glossa] Failed to register Carbon Global HotKey Option+Shift+L with status: %d", lStatus)
            hasRegistrationConflict = true
        }

        // 3. Option + Shift + R (kVK_ANSI_R = 15, optionKey | shiftKey)
        let rID = EventHotKeyID(signature: OSType(0x474C5353), id: 3) // 'GLSS', 3
        var rRef: EventHotKeyRef?
        let rStatus = RegisterEventHotKey(UInt32(kVK_ANSI_R), UInt32(optionKey | shiftKey), rID, GetApplicationEventTarget(), 0, &rRef)
        if rStatus == noErr, let r = rRef {
            hotKeyRefs.append(r)
            NSLog("[Glossa] Successfully registered Carbon Global HotKey: Option+Shift+R")
        } else {
            NSLog("[Glossa] Failed to register Carbon Global HotKey Option+Shift+R with status: %d", rStatus)
            hasRegistrationConflict = true
        }

        // If any hotkey registration failed, unregister any already registered hotkeys
        if hasRegistrationConflict {
            for ref in hotKeyRefs {
                UnregisterEventHotKey(ref)
            }
            hotKeyRefs.removeAll()
            return false
        }

        return true
    }

    func teardown() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}

// MARK: - Lightweight Non-Activating Inline Popover Panel
final class InlinePopoverPanel: NSPanel {
    var allowKeyForInput: Bool = false

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .popUpMenu
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool {
        return allowKeyForInput
    }

    override var canBecomeMain: Bool {
        return false
    }
}

// MARK: - Action Trigger Modes
enum ActionTriggerMode {
    case translate
    case rewrite
}

// MARK: - App Delegate & Coordinate-Anchored Inline Popover Lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: InlinePopoverPanel!
    var statusItem: NSStatusItem?
    var viewModel = PopoverViewModel()
    var settingsWindow: NSWindow?
    var guideWindow: NSWindow?
    var aboutWindow: NSWindow?
    
    private var globalKeyDownMonitor: Any?
    private var localKeyDownMonitor: Any?
    private var globalMouseDownMonitor: Any?
    private var globalScrollMonitor: Any?
    private var hostingController: NSHostingController<InlinePopoverView>?
    private var cancellables = Set<AnyCancellable>()
    private var currentAnchorRect: NSRect?

    // Headless Polish & Selection Replacement state
    var isHeadlessPolishActive: Bool = false
    var headlessTargetElement: AXUIElement?
    var headlessTargetBounds: NSRect?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let popoverView = InlinePopoverView(
            vm: viewModel,
            onClose: { [weak self] in
                self?.dismissPopover()
            }
        )

        let hc = NSHostingController(rootView: popoverView)
        self.hostingController = hc

        panel = InlinePopoverPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 140))
        panel.contentViewController = hc

        // Menu Bar Companion
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupHotKeysAndMonitors()
        updateMenuBarMenu()
        observeContentFittingSize()

        // Prompt accessibility system dialog if not trusted
        let isTrusted = AXIsProcessTrusted()
        if !isTrusted {
            let promptOpts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(promptOpts)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: NSNotification.Name("OpenSettings"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openUserGuide),
            name: NSNotification.Name("OpenUserGuide"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openAbout),
            name: NSNotification.Name("OpenAbout"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkForUpdates),
            name: NSNotification.Name("CheckForUpdates"),
            object: nil
        )
        handleAppDidBecomeActive()

        // Check startup guide suppression preference
        let suppressGuide = UserDefaults.standard.bool(forKey: "suppressGuideOnStartup")
        if !suppressGuide {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.openUserGuide()
            }
        }
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(isPresented: Binding(
                get: { [weak self] in self?.settingsWindow?.isVisible ?? false },
                set: { [weak self] isPres in
                    if !isPres {
                        self?.settingsWindow?.orderOut(nil)
                    }
                }
            ), onKeySaved: { [weak self] in
                self?.viewModel.refreshApiKey()
            })
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 630),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Glossa Settings"
            window.center()
            window.contentView = NSHostingView(rootView: settingsView)
            window.isReleasedWhenClosed = false
            self.settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func openAbout() {
        if aboutWindow == nil {
            let aboutView = AboutView(isPresented: Binding(
                get: { [weak self] in self?.aboutWindow?.isVisible ?? false },
                set: { [weak self] isPres in
                    if !isPres {
                        self?.aboutWindow?.orderOut(nil)
                    }
                }
            ))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "About Glossa"
            window.level = .floating
            window.center()
            window.contentView = NSHostingView(rootView: aboutView)
            window.isReleasedWhenClosed = false
            self.aboutWindow = window
        } else {
            aboutWindow?.level = .floating
        }
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.center()
        aboutWindow?.makeKeyAndOrderFront(nil)
        aboutWindow?.orderFrontRegardless()
    }

    @objc func openUserGuide() {
        if guideWindow == nil {
            let guideView = UserGuideView(isPresented: Binding(
                get: { [weak self] in self?.guideWindow?.isVisible ?? false },
                set: { [weak self] isPres in
                    if !isPres {
                        self?.guideWindow?.orderOut(nil)
                    }
                }
            ))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 530),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Glossa - User Guide / භාවිත උපදෙස්"
            window.level = .floating
            window.center()
            window.contentView = NSHostingView(rootView: guideView)
            window.isReleasedWhenClosed = false
            self.guideWindow = window
        } else {
            guideWindow?.level = .floating
        }
        NSApp.activate(ignoringOtherApps: true)
        guideWindow?.center()
        guideWindow?.makeKeyAndOrderFront(nil)
        guideWindow?.orderFrontRegardless()
    }

    @objc func checkForUpdates() {
        if let url = URL(string: "https://github.com/sajanaKaru/Glossa/releases/latest") {
            NSWorkspace.shared.open(url)
        }
    }

    private func updateMenuBarMenu() {
        guard let button = statusItem?.button else { return }

        button.title = ""

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About Glossa...", action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let translateItem = NSMenuItem(title: "Translate Selection", action: #selector(triggerFromMenu), keyEquivalent: "")
        let rewriteItem = NSMenuItem(title: "✨ Rewrite Selection", action: #selector(triggerRewriteFromMenu), keyEquivalent: "")

        if !viewModel.hotKeyConflictMessage.isEmpty {
            let conflictIcon = NSImage(systemSymbolName: "exclamationmark.bubble", accessibilityDescription: "Glossa - Shortcut Conflict: Click to Translate")
            conflictIcon?.isTemplate = true
            button.image = conflictIcon
            button.toolTip = "Glossa - Shortcut Conflict: Click to Translate"

            let conflictItem = NSMenuItem(title: "⚠️ Shortcut Conflict: Use Menu to Translate", action: nil, keyEquivalent: "")
            conflictItem.isEnabled = false
            menu.addItem(conflictItem)
            menu.addItem(NSMenuItem.separator())

            translateItem.keyEquivalent = ""
            translateItem.keyEquivalentModifierMask = []
            rewriteItem.keyEquivalent = ""
            rewriteItem.keyEquivalentModifierMask = []
        } else {
            let normalIcon = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "Glossa")
            normalIcon?.isTemplate = true
            button.image = normalIcon
            button.toolTip = "Glossa - Option+Space"

            translateItem.keyEquivalent = " "
            translateItem.keyEquivalentModifierMask = [.option]
            rewriteItem.keyEquivalent = "r"
            rewriteItem.keyEquivalentModifierMask = [.option, .shift]
        }

        menu.addItem(translateItem)
        menu.addItem(rewriteItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "📖 Glossa User Guide (භාවිත උපදෙස්)...", action: #selector(openUserGuide), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Glossa Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Glossa", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSApplication.didBecomeActiveNotification, object: nil)
        GlobalHotKeyManager.shared.teardown()
        teardownMonitors()
        viewModel.cleanup()
    }

    @objc private func handleAppDidBecomeActive() {
        let isTrusted = AXIsProcessTrustedWithOptions(nil)
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.isAccessibilityTrusted = isTrusted
        }
    }

    @objc func triggerFromMenu() {
        triggerInstantAction(mode: .translate)
    }

    @objc func triggerRewriteFromMenu() {
        triggerInstantAction(mode: .rewrite)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func setupHotKeysAndMonitors() {
        // 1. Native Carbon Hotkey Manager (Intercepts Option+Space, Option+Shift+L, Option+Shift+R globally)
        GlobalHotKeyManager.shared.onTrigger = { [weak self] in
            self?.triggerInstantAction(mode: .translate)
        }
        GlobalHotKeyManager.shared.onRewriteTrigger = { [weak self] in
            self?.triggerInstantAction(mode: .rewrite)
        }
        let hotKeySuccess = GlobalHotKeyManager.shared.setup()
        if !hotKeySuccess {
            viewModel.hotKeyConflictMessage = "Global shortcut conflicted with another application. Click menu bar icon or reassign."
        } else {
            viewModel.hotKeyConflictMessage = ""
        }

        // 2. Global Hotkey Monitor as secondary backup
        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if (flags == [.option, .shift] && event.keyCode == 37) ||
               (flags == [.option] && event.keyCode == 49) {
                DispatchQueue.main.async {
                    self?.triggerInstantAction(mode: .translate)
                }
            } else if (flags == [.option, .shift] && event.keyCode == 15) { // Option + Shift + R
                DispatchQueue.main.async {
                    self?.triggerInstantAction(mode: .rewrite)
                }
            } else if event.keyCode == 53 { // Esc key
                DispatchQueue.main.async {
                    if self?.isHeadlessPolishActive == true {
                        self?.cancelHeadlessPolish()
                    } else if SelectionOverlayController.shared.isErrorHUDVisible {
                        SelectionOverlayController.shared.hideErrorHUD()
                    } else if self?.panel.isVisible == true {
                        self?.dismissPopover()
                    }
                }
            } else if flags.contains(.option) && (event.keyCode == 36 || event.keyCode == 76) && (self?.panel.isVisible == true) { // Option + Return to polish
                DispatchQueue.main.async {
                    self?.viewModel.runProfessionalPolishAndCopy()
                }
            }
        }

        // 3. Local Monitor for events when Glossa is foregrounded
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }
            if event.keyCode == 53 { // Esc key
                if self.isHeadlessPolishActive {
                    self.cancelHeadlessPolish()
                    return nil
                }
                if SelectionOverlayController.shared.isErrorHUDVisible {
                    SelectionOverlayController.shared.hideErrorHUD()
                    return nil
                }
                if self.panel.isVisible {
                    self.dismissPopover()
                    return nil
                }
            }
            guard self.panel.isVisible else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == [.option, .shift] && event.keyCode == 15 { // Option + Shift + R
                self.triggerInstantAction(mode: .rewrite)
                return nil
            }
            if flags.contains(.option) && (event.keyCode == 36 || event.keyCode == 76) { // Option + Return
                self.viewModel.runProfessionalPolishAndCopy()
                return nil
            }
            return event
        }

        // 4. Global Mouse Down Monitor to dismiss when clicking outside
        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            if SelectionOverlayController.shared.isErrorHUDVisible {
                DispatchQueue.main.async {
                    SelectionOverlayController.shared.hideErrorHUD()
                }
            }
            guard self.panel.isVisible else { return }
            let clickLocation = NSEvent.mouseLocation
            if !self.panel.frame.contains(clickLocation) {
                DispatchQueue.main.async {
                    self.dismissPopover()
                }
            }
        }

        // 5. Global Scroll Monitor to dismiss on page / window scroll
        globalScrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] _ in
            guard let self = self else { return }
            if SelectionOverlayController.shared.isErrorHUDVisible {
                DispatchQueue.main.async {
                    SelectionOverlayController.shared.hideErrorHUD()
                }
            }
            guard self.panel.isVisible else { return }
            DispatchQueue.main.async {
                self.dismissPopover()
            }
        }
    }

    private func teardownMonitors() {
        if let gkm = globalKeyDownMonitor {
            NSEvent.removeMonitor(gkm)
            globalKeyDownMonitor = nil
        }
        if let lkm = localKeyDownMonitor {
            NSEvent.removeMonitor(lkm)
            localKeyDownMonitor = nil
        }
        if let gmm = globalMouseDownMonitor {
            NSEvent.removeMonitor(gmm)
            globalMouseDownMonitor = nil
        }
        if let gsm = globalScrollMonitor {
            NSEvent.removeMonitor(gsm)
            globalScrollMonitor = nil
        }
    }

    private func observeContentFittingSize() {
        // Dynamically adjust popover frame height smoothly as content streams in
        viewModel.$outputText
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updatePopoverSize()
            }
            .store(in: &cancellables)

        viewModel.$errorMessage
            .sink { [weak self] _ in
                self?.updatePopoverSize()
            }
            .store(in: &cancellables)

        viewModel.$isTruncated
            .sink { [weak self] _ in
                self?.updatePopoverSize()
            }
            .store(in: &cancellables)

        viewModel.$hadStreamParseError
            .sink { [weak self] _ in
                self?.updatePopoverSize()
            }
            .store(in: &cancellables)

        viewModel.$isManualInputMode
            .sink { [weak self] isManual in
                self?.panel.allowKeyForInput = isManual
                self?.updatePopoverSize()
            }
            .store(in: &cancellables)

        viewModel.$isAccessibilityTrusted
            .sink { [weak self] _ in
                self?.updatePopoverSize()
            }
            .store(in: &cancellables)

        viewModel.$hotKeyConflictMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePopoverSize()
                self?.updateMenuBarMenu()
            }
            .store(in: &cancellables)

        viewModel.$polishedOutputText
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updatePopoverSize()
            }
            .store(in: &cancellables)

        viewModel.$isPolishing
            .sink { [weak self] _ in
                self?.updatePopoverSize()
            }
            .store(in: &cancellables)

        viewModel.$polishErrorMessage
            .sink { [weak self] _ in
                self?.updatePopoverSize()
            }
            .store(in: &cancellables)

        viewModel.$polishedAutoCopiedToast
            .sink { [weak self] _ in
                self?.updatePopoverSize()
            }
            .store(in: &cancellables)
    }

    private func updatePopoverSize() {
        guard panel.isVisible, let hc = hostingController, let anchor = currentAnchorRect else { return }
        let fitting = hc.sizeThatFits(in: CGSize(width: 380, height: 600))
        let targetHeight = min(max(fitting.height, 120), 520)
        let newSize = NSSize(width: 380, height: targetHeight)
        
        if abs(panel.frame.height - newSize.height) > 2 {
            positionPanel(anchoredTo: anchor, desiredHeight: newSize.height)
        }
    }

    func dismissPopover() {
        guard panel.isVisible else { return }
        panel.allowKeyForInput = false
        panel.orderOut(nil)
        currentAnchorRect = nil
        viewModel.resetToEmptyState()
    }

    func triggerInstantAction(mode: ActionTriggerMode = .translate) {
        if isHeadlessPolishActive {
            cancelHeadlessPolish()
            return
        }

        if panel.isVisible {
            dismissPopover()
            return
        }

        // 1. Check Accessibility permissions and prompt system dialog if not trusted
        let isTrusted = AXIsProcessTrusted()
        if !isTrusted {
            let promptOpts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(promptOpts)
        }
        viewModel.isAccessibilityTrusted = isTrusted

        let captureResult = captureSelectedTextAndBounds()
        currentAnchorRect = captureResult.bounds

        viewModel.resetToEmptyState()
        viewModel.isAccessibilityTrusted = isTrusted
        viewModel.activeTriggerMode = mode

        // Check for Headless In-Place Polish Mode
        let autoReplaceOnPolish = UserDefaults.standard.bool(forKey: "autoReplaceOnPolish")
        if mode == .rewrite && autoReplaceOnPolish {
            if let text = captureResult.text, !text.isEmpty {
                let isEditable = InPlaceTextReplacer.isElementEditable(captureResult.focusedElement)
                if isEditable {
                    // Verified editable target: run headless in-place replacement
                    startHeadlessPolish(text: text, bounds: captureResult.bounds, targetElement: captureResult.focusedElement)
                    return
                }
                // Read-only target detected: smoothly fall through to standard popover dialog
            }
        }

        if let text = captureResult.text, !text.isEmpty {
            // Selected text found
            viewModel.isManualInputMode = false
            panel.allowKeyForInput = false
            viewModel.inputText = text

            positionPanel(anchoredTo: captureResult.bounds, desiredHeight: 140)
            panel.orderFrontRegardless()

            if mode == .rewrite {
                viewModel.runProfessionalPolishAndCopy()
            } else {
                viewModel.runTranslate()
            }
        } else {
            // No selection found: open inline pill with manual input field at cursor
            viewModel.isManualInputMode = true
            panel.allowKeyForInput = true

            positionPanel(anchoredTo: captureResult.bounds, desiredHeight: 140)
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func startHeadlessPolish(text: String, bounds: NSRect, targetElement: AXUIElement?) {
        dismissPopover()
        cancelHeadlessPolish()

        isHeadlessPolishActive = true
        headlessTargetBounds = bounds
        headlessTargetElement = targetElement

        SelectionOverlayController.shared.showOverlay(at: bounds)

        viewModel.inputText = text
        viewModel.activeTriggerMode = .rewrite

        viewModel.onPolishFinished = { [weak self] polishedText in
            guard let self = self, self.isHeadlessPolishActive else { return }
            self.isHeadlessPolishActive = false
            SelectionOverlayController.shared.hideOverlay()

            let targetElem = self.headlessTargetElement
            let targetBounds = self.headlessTargetBounds ?? bounds
            self.headlessTargetElement = nil
            self.headlessTargetBounds = nil

            let outcome = InPlaceTextReplacer.replaceSelectedText(
                with: polishedText,
                targetElement: targetElem
            )
            switch outcome {
            case .success:
                break
            case .uneditableTarget:
                SelectionOverlayController.shared.showErrorHUD(
                    message: "Selected text is read-only. Polished text copied to clipboard.",
                    near: targetBounds
                )
            case .failed:
                SelectionOverlayController.shared.showErrorHUD(
                    message: "Could not replace text. Polished text copied to clipboard.",
                    near: targetBounds
                )
            }
        }

        viewModel.onPolishFailed = { [weak self] errorMsg in
            guard let self = self, self.isHeadlessPolishActive else { return }
            self.isHeadlessPolishActive = false
            SelectionOverlayController.shared.hideOverlay()

            let targetBounds = self.headlessTargetBounds ?? bounds
            self.headlessTargetElement = nil
            self.headlessTargetBounds = nil

            SelectionOverlayController.shared.showErrorHUD(
                message: errorMsg,
                near: targetBounds
            )
        }

        viewModel.runProfessionalPolishAndCopy()
    }

    func cancelHeadlessPolish() {
        guard isHeadlessPolishActive else { return }
        isHeadlessPolishActive = false
        viewModel.cancelPolishTask()
        SelectionOverlayController.shared.hideOverlay()
        headlessTargetElement = nil
        headlessTargetBounds = nil
    }

    /// Positions the popover panel above or below the selection bounds clamped to the current screen
    private func positionPanel(anchoredTo targetRect: NSRect, desiredHeight: CGFloat) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(targetRect) }) ?? NSScreen.main else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let panelWidth: CGFloat = 380
        let panelHeight: CGFloat = desiredHeight
        let margin: CGFloat = 8

        // Try placing below selection first
        var originX = targetRect.origin.x + (targetRect.width - panelWidth) / 2.0
        var originY = targetRect.origin.y - panelHeight - margin

        // If below screen bottom edge, place above the selection
        if originY < visibleFrame.minY {
            originY = targetRect.origin.y + targetRect.height + margin
        }

        // Horizontal clamping within visible screen bounds
        if originX < visibleFrame.minX + margin {
            originX = visibleFrame.minX + margin
        } else if originX + panelWidth > visibleFrame.maxX - margin {
            originX = visibleFrame.maxX - panelWidth - margin
        }

        // Vertical clamping
        if originY + panelHeight > visibleFrame.maxY - margin {
            originY = visibleFrame.maxY - panelHeight - margin
        }
        if originY < visibleFrame.minY + margin {
            originY = visibleFrame.minY + margin
        }

        panel.setFrame(NSRect(x: round(originX), y: round(originY), width: panelWidth, height: panelHeight), display: true, animate: false)
    }

    /// Captures selected text and converts its AX screen bounds to AppKit desktop coordinates
    private func captureSelectedTextAndBounds() -> (text: String?, bounds: NSRect, focusedElement: AXUIElement?) {
        let mouseLocation = NSEvent.mouseLocation
        let fallbackRect = NSRect(x: mouseLocation.x - 10, y: mouseLocation.y - 10, width: 20, height: 20)

        let systemWide = AXUIElementCreateSystemWide()

        // 1. Try focused application -> focused UI element
        var focusedElement: AXUIElement?
        var focusedApp: AnyObject?
        if AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
           let app = focusedApp {
            var focusedUIElement: AnyObject?
            if AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedUIElement) == .success,
               let elem = focusedUIElement {
                focusedElement = (elem as! AXUIElement)
            }
        }

        // 2. Try system-wide focused UI element directly
        if focusedElement == nil {
            var directElem: AnyObject?
            if AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &directElem) == .success,
               let elem = directElem {
                focusedElement = (elem as! AXUIElement)
            }
        }

        var selectedText: String? = nil
        var calculatedBounds: NSRect? = nil

        if let elem = focusedElement {
            // Helper to extract text from a single element
            func extractText(from targetElem: AXUIElement) -> String? {
                // 1. Direct kAXSelectedTextAttribute
                var selectedTextValue: AnyObject?
                if AXUIElementCopyAttributeValue(targetElem, kAXSelectedTextAttribute as CFString, &selectedTextValue) == .success,
                   let text = selectedTextValue as? String {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        return trimmed
                    }
                }

                // 2. Range-based extraction
                var selectedRangeVal: AnyObject?
                let rangeResult = AXUIElementCopyAttributeValue(targetElem, kAXSelectedTextRangeAttribute as CFString, &selectedRangeVal)
                if rangeResult == .success, let rangeAX = selectedRangeVal, CFGetTypeID(rangeAX) == AXValueGetTypeID() {
                    let axRange = rangeAX as! AXValue

                    // Parameterized string for range (Safari, WebKit, Pages, TextEdit)
                    var strVal: AnyObject?
                    let strResult = AXUIElementCopyParameterizedAttributeValue(
                        targetElem,
                        kAXStringForRangeParameterizedAttribute as CFString,
                        axRange,
                        &strVal
                    )
                    if strResult == .success, let text = strVal as? String {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            return trimmed
                        }
                    }

                    // Sliced kAXValueAttribute (Chromium, TextFields, Electron)
                    var cfRange = CFRange()
                    if AXValueGetValue(axRange, .cfRange, &cfRange) && cfRange.length > 0 {
                        var valAttr: AnyObject?
                        if AXUIElementCopyAttributeValue(targetElem, kAXValueAttribute as CFString, &valAttr) == .success {
                            let rawString = (valAttr as? String) ?? ((valAttr as? NSAttributedString)?.string)
                            if let fullText = rawString {
                                let nsString = fullText as NSString
                                if cfRange.location >= 0 && cfRange.location + cfRange.length <= nsString.length {
                                    let sub = nsString.substring(with: NSRange(location: cfRange.location, length: cfRange.length))
                                    let trimmed = sub.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty {
                                        return trimmed
                                    }
                                }
                            }
                        }
                    }
                }

                return nil
            }

            // Attempt extraction on focused element
            selectedText = extractText(from: elem)

            // Extract bounds from focused element if available
            var selectedRangeVal: AnyObject?
            let rangeResult = AXUIElementCopyAttributeValue(elem, kAXSelectedTextRangeAttribute as CFString, &selectedRangeVal)
            if rangeResult == .success, let rangeAX = selectedRangeVal, CFGetTypeID(rangeAX) == AXValueGetTypeID() {
                var boundsVal: AnyObject?
                let boundsResult = AXUIElementCopyParameterizedAttributeValue(
                    elem,
                    kAXBoundsForRangeParameterizedAttribute as CFString,
                    rangeAX as! AXValue,
                    &boundsVal
                )
                if boundsResult == .success, let bVal = boundsVal, CFGetTypeID(bVal) == AXValueGetTypeID() {
                    var axRect = CGRect.zero
                    if AXValueGetValue(bVal as! AXValue, .cgRect, &axRect) && axRect.width > 0 && axRect.height > 0 {
                        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
                        let appKitY = primaryScreenHeight - axRect.origin.y - axRect.height
                        calculatedBounds = NSRect(x: axRect.origin.x, y: appKitY, width: axRect.width, height: axRect.height)
                    }
                }
            }

            // Traverse up to 3 parent levels if text still not found (common in web views / compound controls)
            if selectedText == nil {
                var currentElem = elem
                for _ in 0..<3 {
                    var parentVal: AnyObject?
                    if AXUIElementCopyAttributeValue(currentElem, kAXParentAttribute as CFString, &parentVal) == .success,
                       let parent = parentVal {
                        let parentElem = parent as! AXUIElement
                        if let parentText = extractText(from: parentElem) {
                            selectedText = parentText
                            focusedElement = parentElem
                            break
                        }
                        currentElem = parentElem
                    } else {
                        break
                    }
                }
            }
        }

        // Fallback: Universal Synthetic Cmd+C Copy when AX APIs do not expose selection
        if selectedText == nil || selectedText!.isEmpty {
            if let copied = copySelectedTextViaSyntheticCommandC() {
                selectedText = copied
            }
        }

        return (selectedText, calculatedBounds ?? fallbackRect, focusedElement)
    }

    /// Universal fallback: simulates Cmd+C to capture highlighted text when Accessibility APIs do not expose selection.
    private func copySelectedTextViaSyntheticCommandC() -> String? {
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount

        let source = CGEventSource(stateID: .combinedSessionState)
        let cKeyCode: CGKeyCode = 8 // kVK_ANSI_C

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: false) else {
            return nil
        }

        keyDown.flags = .maskCommand
        keyUp.flags = []

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        // Poll pasteboard for up to 150ms (15 iterations x 10ms)
        var copiedString: String? = nil
        for _ in 0..<15 {
            usleep(10_000)
            if pasteboard.changeCount != initialChangeCount {
                if let str = pasteboard.string(forType: .string) {
                    let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        copiedString = trimmed
                    }
                }
                break
            }
        }

        return copiedString
    }
}

// MARK: - Popover View Model with Robust Multibyte UTF-8 Streaming & Error Handling
class PopoverViewModel: NSObject, ObservableObject, URLSessionDataDelegate {
    @Published var inputText: String = ""
    @Published var outputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var copied: Bool = false
    @Published var isTruncated: Bool = false
    @Published var hadStreamParseError: Bool = false
    @Published var isManualInputMode: Bool = false
    @Published var isAccessibilityTrusted: Bool = true
    @Published var hotKeyConflictMessage: String = ""

    // Dedicated Professional Grammar & Polishing state
    @Published var isPolishing: Bool = false
    @Published var polishedOutputText: String = ""
    @Published var polishedAutoCopiedToast: Bool = false
    @Published var polishedCopied: Bool = false
    @Published var polishErrorMessage: String = ""
    @Published var activeTriggerMode: ActionTriggerMode = .translate

    // Backward compatibility aliases
    var isTranslating: Bool {
        get { isLoading }
        set { isLoading = newValue }
    }
    var sinhalaOutputText: String {
        get { outputText }
        set { outputText = newValue }
    }
    var sinhalaCopied: Bool {
        get { copied }
        set { copied = newValue }
    }

    @Published var apiKey: String = ""
    @Published var activeProvider: AIProvider = AIProvider.current
    @Published var storageError: String = ""
    @Published var fallbackWarning: String = ""
    @Published var loadingPlaceholder: String = "Translating to spoken Sinhala..."

    private var requestProvider: AIProvider = AIProvider.current
    private var session: URLSession!
    private var currentTask: URLSessionDataTask?
    private var currentRequestId: UUID = UUID()
    private var isTaskInFlight: Bool = false
    private var streamDataBuffer = Data()
    private var errorDataBuffer = Data()
    private var dismissWorkItem: DispatchWorkItem?
    private var responseStatusCode: Int = 200
    private var isEventStream: Bool = false
    private var receivedDone: Bool = false

    // Polish task lifecycle
    private var polishTask: URLSessionDataTask?
    private var polishRequestId: UUID = UUID()
    private var polishStreamBuffer = Data()
    private var polishErrorBuffer = Data()
    private var polishStatusCode: Int = 200
    private var polishIsEventStream: Bool = false
    private var polishReceivedDone: Bool = false
    private var polishToastWorkItem: DispatchWorkItem?

    // Polish completion callbacks for Headless In-Place Replacement
    var onPolishFinished: ((String) -> Void)?
    var onPolishFailed: ((String) -> Void)?

    override init() {
        super.init()
        do {
            try KeychainHelper.shared.migrateLegacyKeyIfNeeded()
            let provider = AIProvider.current
            self.activeProvider = provider
            self.requestProvider = provider
            self.apiKey = (try KeychainHelper.shared.getKey(account: provider.keychainAccount)) ?? ""
            self.fallbackWarning = (provider == .groq) ? (KeychainHelper.shared.fallbackRecoveryWarning ?? "") : ""
        } catch {
            self.storageError = "Keychain error: \(error.localizedDescription)"
            self.apiKey = ""
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20.0
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
    }

    func cancelInFlightTask() {
        // Invalidate request ID first so any queued or concurrent delegate callbacks fail the match guard immediately
        currentRequestId = UUID()
        if isTaskInFlight || currentTask != nil {
            currentTask?.cancel()
            currentTask = nil
            isTaskInFlight = false
        }
        isLoading = false
        streamDataBuffer.removeAll()
        errorDataBuffer.removeAll()
        cancelPolishTask()
    }

    func cancelPolishTask() {
        polishRequestId = UUID()
        if polishTask != nil {
            polishTask?.cancel()
            polishTask = nil
        }
        isPolishing = false
        polishStreamBuffer.removeAll()
        polishErrorBuffer.removeAll()
        polishToastWorkItem?.cancel()
        polishToastWorkItem = nil
    }

    func cancelTranslateTaskOnly() {
        currentRequestId = UUID()
        if isTaskInFlight || currentTask != nil {
            currentTask?.cancel()
            currentTask = nil
            isTaskInFlight = false
        }
        isLoading = false
        streamDataBuffer.removeAll()
        errorDataBuffer.removeAll()
    }

    func refreshApiKey() {
        DispatchQueue.main.async {
            let previousProvider = self.activeProvider
            let provider = AIProvider.current
            self.activeProvider = provider

            if previousProvider != provider {
                self.cancelInFlightTask()
            }

            do {
                self.apiKey = (try KeychainHelper.shared.getKey(account: provider.keychainAccount)) ?? ""
                self.fallbackWarning = (provider == .groq) ? (KeychainHelper.shared.fallbackRecoveryWarning ?? "") : ""
                self.storageError = ""
                if self.errorMessage.contains("API Key") {
                    self.errorMessage = ""
                }
            } catch {
                self.storageError = "Keychain error: \(error.localizedDescription)"
                self.apiKey = ""
            }
        }
    }

    func cleanup() {
        resetToEmptyState()
        session?.invalidateAndCancel()
    }

    func resetToEmptyState() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        cancelInFlightTask()
        responseStatusCode = 200
        isEventStream = false
        receivedDone = false
        hadStreamParseError = false
        inputText = ""
        outputText = ""
        errorMessage = ""
        copied = false
        isTruncated = false
        isManualInputMode = false

        // Polish state reset
        isPolishing = false
        polishedOutputText = ""
        polishedAutoCopiedToast = false
        polishedCopied = false
        polishErrorMessage = ""
        activeTriggerMode = .translate
    }

    func runTranslate() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        cancelInFlightTask()

        let provider = AIProvider.current
        self.activeProvider = provider
        self.requestProvider = provider
        self.loadingPlaceholder = "Translating to spoken Sinhala..."

        let key: String
        do {
            guard let retrieved = try KeychainHelper.shared.getKey(account: provider.keychainAccount), !retrieved.isEmpty else {
                self.apiKey = ""
                self.errorMessage = "\(provider.displayName) API Key not configured. Please open Settings (⌘,) to configure."
                return
            }
            key = retrieved
            self.apiKey = retrieved
        } catch {
            self.apiKey = ""
            self.errorMessage = "Keychain error accessing \(provider.displayName) API Key: \(error.localizedDescription)"
            return
        }

        let model = provider.selectedModel
        let url = provider.chatEndpoint

        let requestId = UUID()
        currentRequestId = requestId
        isLoading = true
        isTaskInFlight = true
        errorMessage = ""
        outputText = ""
        copied = false
        isTruncated = false
        hadStreamParseError = false
        responseStatusCode = 200
        isEventStream = false
        receivedDone = false
        streamDataBuffer.removeAll()
        errorDataBuffer.removeAll()

        let prompt = """
        You are an expert English-to-Sinhala translator focused on zero-friction natural clarity.
        Translate the following English text into simple, everyday, colloquial spoken-style Sinhala (සරල එදිනෙදා සිංහල).
        Strict Guidelines:
        - Output ONLY the Sinhala translation.
        - Do NOT include any English explanations, phonetic transcriptions, notes, or greetings.
        - Avoid archaic, overly formal dictionary literature words. Use natural spoken Sri Lankan idiom.

        Text to translate:
        \"\"\"\(inputText)\"\"\"
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.2,
            "max_tokens": 1024,
            "stream": true
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = session.dataTask(with: request)
        task.taskDescription = requestId.uuidString
        self.currentTask = task
        task.resume()
    }

    func runPolish(tone: String = "natural") {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        cancelInFlightTask()

        let provider = AIProvider.current
        self.activeProvider = provider
        self.requestProvider = provider
        self.loadingPlaceholder = "Polishing text (\(tone))..."

        let key: String
        do {
            guard let retrieved = try KeychainHelper.shared.getKey(account: provider.keychainAccount), !retrieved.isEmpty else {
                self.apiKey = ""
                self.errorMessage = "\(provider.displayName) API Key not configured. Please open Settings (⌘,) to configure."
                return
            }
            key = retrieved
            self.apiKey = retrieved
        } catch {
            self.apiKey = ""
            self.errorMessage = "Keychain error accessing \(provider.displayName) API Key: \(error.localizedDescription)"
            return
        }

        let model = provider.selectedModel
        let url = provider.chatEndpoint

        let requestId = UUID()
        currentRequestId = requestId
        isLoading = true
        isTaskInFlight = true
        errorMessage = ""
        outputText = ""
        copied = false
        isTruncated = false
        hadStreamParseError = false
        responseStatusCode = 200
        isEventStream = false
        receivedDone = false
        streamDataBuffer.removeAll()
        errorDataBuffer.removeAll()

        let prompt = """
        You are an expert English writing assistant and editor.
        Polish and refine the following text for \(tone) clarity, grammar, and natural flow.
        Strict Guidelines:
        - Output ONLY the polished text.
        - Do NOT include any explanations, greetings, quotes, or notes.
        - Preserve the original meaning and tone while making it fluent and error-free.

        Text to polish:
        \"\"\"\(inputText)\"\"\"
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.2,
            "max_tokens": 1024,
            "stream": true
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = session.dataTask(with: request)
        task.taskDescription = requestId.uuidString
        self.currentTask = task
        task.resume()
    }

    func copyAndDismiss(onDismiss: @escaping () -> Void) {
        guard !outputText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        copied = true

        dismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismissWorkItem = nil
            onDismiss()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    // MARK: - Professional Grammar Polish & Auto-Copy Implementation
    func runProfessionalPolishAndCopy() {
        guard !isPolishing, !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        cancelPolishTask()

        let provider = AIProvider.current
        self.activeProvider = provider

        let key: String
        do {
            guard let retrieved = try KeychainHelper.shared.getKey(account: provider.keychainAccount), !retrieved.isEmpty else {
                let msg = "\(provider.displayName) API Key not configured. Please open Settings (⌘,) to configure."
                self.polishErrorMessage = msg
                let failed = self.onPolishFailed
                DispatchQueue.main.async {
                    failed?(msg)
                }
                return
            }
            key = retrieved
        } catch {
            let msg = "Keychain error accessing \(provider.displayName) API Key: \(error.localizedDescription)"
            self.polishErrorMessage = msg
            let failed = self.onPolishFailed
            DispatchQueue.main.async {
                failed?(msg)
            }
            return
        }

        let model = provider.selectedModel
        let url = provider.chatEndpoint

        let requestId = UUID()
        polishRequestId = requestId
        isPolishing = true
        polishErrorMessage = ""
        polishedOutputText = ""
        polishedCopied = false
        polishedAutoCopiedToast = false
        polishStatusCode = 200
        polishIsEventStream = false
        polishReceivedDone = false
        polishStreamBuffer.removeAll()
        polishErrorBuffer.removeAll()

        let prompt = """
        You are an elite English editor and corporate communication specialist.
        Polish the provided English text to adhere to impeccable grammar, correct punctuation, natural syntax, and a confident, professional workplace tone.
        Rules:
        1. Fix all grammatical flaws, spelling errors, awkward sentence structures, and typos.
        2. Ensure the tone is polished, respectful, clear, and professional.
        3. Preserve the exact original core intent and meaning without adding unrequested information.
        4. Output ONLY the polished English sentence(s) with zero preambles, introductory commentary, or quotation marks.

        Text to polish:
        \"\"\"\(inputText)\"\"\"
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.2,
            "max_tokens": 1024,
            "stream": true
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = session.dataTask(with: request)
        task.taskDescription = requestId.uuidString
        self.polishTask = task
        task.resume()
    }

    private func autoCopyPolishedText(_ text: String) {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.polishedCopied = true
            self.polishedAutoCopiedToast = true

            // Tactile haptic feedback for physical macOS confirmation
            NSHapticFeedbackManager.defaultPerformer.perform(
                .alignment,
                performanceTime: .default
            )

            self.polishToastWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                self?.polishedAutoCopiedToast = false
                self?.polishToastWorkItem = nil
            }
            self.polishToastWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: item)
        }
    }

    func copyPolishedText() {
        guard !polishedOutputText.isEmpty else { return }
        autoCopyPolishedText(polishedOutputText)
    }

    private func sanitizePolishedText(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code fences if present
        if result.hasPrefix("```") {
            if let firstNewline = result.firstIndex(of: "\n") {
                result = String(result[result.index(after: firstNewline)...])
            }
            if result.hasSuffix("```") {
                result = String(result.dropLast(3))
            }
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Strip common AI preambles
        let preambles = [
            "Here is the polished version:",
            "Here is the polished sentence:",
            "Here is the polished text:",
            "Polished version:",
            "Polished sentence:",
            "Polished text:"
        ]
        for preamble in preambles {
            if result.lowercased().hasPrefix(preamble.lowercased()) {
                result = String(result.dropFirst(preamble.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Strip surrounding double or single quotation marks
        if (result.hasPrefix("\"") && result.hasSuffix("\"") && result.count >= 2) ||
           (result.hasPrefix("“") && result.hasSuffix("”") && result.count >= 2) ||
           (result.hasPrefix("'") && result.hasSuffix("'") && result.count >= 2) {
            result = String(result.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result
    }

    // MARK: - URLSessionDataDelegate (HTTP Status & Multibyte UTF-8 SSE Streaming)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let taskDesc = dataTask.taskDescription else {
            completionHandler(.cancel)
            return
        }

        let isTranslate = (taskDesc == currentRequestId.uuidString)
        let isPolish = (taskDesc == polishRequestId.uuidString)

        guard isTranslate || isPolish else {
            completionHandler(.cancel)
            return
        }

        if let httpResponse = response as? HTTPURLResponse {
            let code = httpResponse.statusCode
            var isStream = false
            if let mime = httpResponse.mimeType?.lowercased() {
                isStream = mime.contains("text/event-stream")
            } else if let contentType = httpResponse.allHeaderFields["Content-Type"] as? String {
                isStream = contentType.lowercased().contains("text/event-stream")
            }

            if isTranslate {
                self.responseStatusCode = code
                self.isEventStream = isStream

                if !(200...299).contains(code) {
                    self.isLoading = false
                    self.errorMessage = formatErrorMessage(for: self.requestProvider, code: code)
                } else if !isStream {
                    let name = self.requestProvider.displayName
                    self.errorMessage = "\(name) API error: Unexpected non-streaming response."
                    self.cancelTranslateTaskOnly()
                    completionHandler(.cancel)
                    return
                }
            } else if isPolish {
                self.polishStatusCode = code
                self.polishIsEventStream = isStream

                if !(200...299).contains(code) {
                    self.isPolishing = false
                    self.polishErrorMessage = formatErrorMessage(for: self.activeProvider, code: code)
                } else if !isStream {
                    let name = self.activeProvider.displayName
                    self.polishErrorMessage = "\(name) API error: Unexpected non-streaming response."
                    self.cancelPolishTask()
                    completionHandler(.cancel)
                    return
                }
            }
        }
        completionHandler(.allow)
    }

    private func formatErrorMessage(for provider: AIProvider, code: Int) -> String {
        let name = provider.displayName
        switch code {
        case 400:
            if provider == .gemini {
                return "\(name) API error (400): Invalid or unauthorized API key."
            } else {
                return "\(name) API error (400): Bad request."
            }
        case 401:
            return "\(name) API error (401): Invalid or unauthorized API key."
        case 403:
            return "\(name) API error (403): Access forbidden or restricted API key."
        case 429:
            return "\(name) API error (429): Rate limit or quota exceeded. Try again shortly."
        default:
            return "\(name) API error (\(code)): Unable to complete request."
        }
    }

    private func parseErrorMessage(from data: Data, provider: AIProvider, statusCode: Int) -> String? {
        guard !data.isEmpty else { return nil }
        let name = provider.displayName
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var extractedMessage: String?
            var extractedCode: String?

            if let errorObj = json["error"] as? [String: Any] {
                extractedMessage = errorObj["message"] as? String
                if let codeStr = errorObj["code"] as? String {
                    extractedCode = codeStr
                } else if let codeInt = errorObj["code"] as? Int {
                    extractedCode = String(codeInt)
                }
            } else if let errorStr = json["error"] as? String {
                extractedMessage = errorStr
            } else if let msgStr = json["message"] as? String {
                extractedMessage = msgStr
            }

            if let msg = extractedMessage, !msg.isEmpty {
                if extractedCode == "insufficient_quota" || msg.lowercased().contains("quota") {
                    let billingUrl: String
                    switch provider {
                    case .openAI:
                        billingUrl = "platform.openai.com/account/billing"
                    case .gemini:
                        billingUrl = "aistudio.google.com"
                    case .groq:
                        billingUrl = "console.groq.com"
                    }
                    return "\(name) API error: You have exceeded your account quota. Check billing at \(billingUrl)."
                }
                return "\(name) API error (\(statusCode)): \(msg)"
            }
        } else if let plainText = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !plainText.isEmpty {
            return "\(name) API error (\(statusCode)): \(plainText)"
        }
        return nil
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let taskDesc = dataTask.taskDescription else {
            return
        }

        let isTranslate = (taskDesc == currentRequestId.uuidString)
        let isPolish = (taskDesc == polishRequestId.uuidString)

        guard isTranslate || isPolish else { return }

        if isTranslate {
            // If non-2xx status, accumulate complete error response body (capped at 64KB)
            if !(200...299).contains(responseStatusCode) {
                let maxErrorBufferSize = 64 * 1024
                if errorDataBuffer.count < maxErrorBufferSize {
                    let remainingSpace = maxErrorBufferSize - errorDataBuffer.count
                    let slice = data.prefix(remainingSpace)
                    errorDataBuffer.append(slice)
                }
                if let detailedMsg = parseErrorMessage(from: errorDataBuffer, provider: self.requestProvider, statusCode: self.responseStatusCode) {
                    self.errorMessage = detailedMsg
                }
                return
            }

            // Multibyte-safe UTF-8 buffering: accumulate bytes and only decode complete lines at '\n'
            streamDataBuffer.append(data)

            let maxStreamBufferSize = 128 * 1024 // 128KB
            let newlineByte: UInt8 = 0x0A // \n
            while let newlineIndex = streamDataBuffer.firstIndex(of: newlineByte) {
                let lineData = streamDataBuffer.subdata(in: 0..<newlineIndex)
                streamDataBuffer.removeSubrange(0...newlineIndex)

                // Check individual line size limit before decoding
                if lineData.count > maxStreamBufferSize {
                    self.errorMessage = "Line exceeded maximum allowed size."
                    self.cancelTranslateTaskOnly()
                    return
                }

                // Safely decode the completed line chunk
                guard let lineStr = String(data: lineData, encoding: .utf8) else {
                    self.hadStreamParseError = true
                    continue
                }

                processSSELine(lineStr)
            }

            // Check remaining tail buffer size after draining all complete lines
            if streamDataBuffer.count > maxStreamBufferSize {
                self.errorMessage = "Stream buffer tail exceeded maximum allowed size."
                self.cancelTranslateTaskOnly()
                return
            }
        } else if isPolish {
            if !(200...299).contains(polishStatusCode) {
                let maxErrorBufferSize = 64 * 1024
                if polishErrorBuffer.count < maxErrorBufferSize {
                    let remainingSpace = maxErrorBufferSize - polishErrorBuffer.count
                    let slice = data.prefix(remainingSpace)
                    polishErrorBuffer.append(slice)
                }
                if let detailedMsg = parseErrorMessage(from: polishErrorBuffer, provider: self.activeProvider, statusCode: self.polishStatusCode) {
                    self.polishErrorMessage = detailedMsg
                }
                return
            }

            polishStreamBuffer.append(data)

            let maxStreamBufferSize = 128 * 1024
            let newlineByte: UInt8 = 0x0A
            while let newlineIndex = polishStreamBuffer.firstIndex(of: newlineByte) {
                let lineData = polishStreamBuffer.subdata(in: 0..<newlineIndex)
                polishStreamBuffer.removeSubrange(0...newlineIndex)

                if lineData.count > maxStreamBufferSize {
                    self.polishErrorMessage = "Line exceeded maximum allowed size."
                    self.cancelPolishTask()
                    return
                }

                guard let lineStr = String(data: lineData, encoding: .utf8) else {
                    continue
                }

                processPolishSSELine(lineStr)
            }

            if polishStreamBuffer.count > maxStreamBufferSize {
                self.polishErrorMessage = "Stream buffer tail exceeded maximum allowed size."
                self.cancelPolishTask()
                return
            }
        }
    }

    private func processPolishSSELine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix(":") { return }

        if trimmed == "data: [DONE]" {
            self.polishReceivedDone = true
            self.isPolishing = false
            return
        }

        if trimmed.hasPrefix("data: ") {
            let jsonStr = String(trimmed.dropFirst(6))
            guard let jsonData = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return
            }

            // Check for API-level error returned within stream
            if let errorObj = json["error"] as? [String: Any], let msg = errorObj["message"] as? String {
                let code = errorObj["code"] as? String
                let name = self.activeProvider.displayName
                if code == "insufficient_quota" || msg.lowercased().contains("quota") {
                    let billingUrl: String
                    switch self.activeProvider {
                    case .openAI:
                        billingUrl = "platform.openai.com/account/billing"
                    case .gemini:
                        billingUrl = "aistudio.google.com"
                    case .groq:
                        billingUrl = "console.groq.com"
                    }
                    self.polishErrorMessage = "\(name) API error: You have exceeded your account quota. Check billing at \(billingUrl)."
                } else {
                    self.polishErrorMessage = "\(name) API error: \(msg)"
                }
                let err = self.polishErrorMessage
                let failed = self.onPolishFailed
                self.cancelPolishTask()
                DispatchQueue.main.async {
                    failed?(err)
                }
                return
            }

            if let choices = json["choices"] as? [[String: Any]], let first = choices.first {
                if let delta = first["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    self.polishedOutputText.append(content)
                }
            }
        }
    }

    private func processSSELine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix(":") { return }

        if trimmed == "data: [DONE]" {
            self.receivedDone = true
            self.isLoading = false
            return
        }

        if trimmed.hasPrefix("data: ") {
            let jsonStr = String(trimmed.dropFirst(6))
            guard let jsonData = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                self.hadStreamParseError = true
                return
            }

            // Check for API-level error returned within stream
            if let errorObj = json["error"] as? [String: Any], let msg = errorObj["message"] as? String {
                let code = errorObj["code"] as? String
                let name = self.requestProvider.displayName
                if code == "insufficient_quota" || msg.lowercased().contains("quota") {
                    let billingUrl: String
                    switch self.requestProvider {
                    case .openAI:
                        billingUrl = "platform.openai.com/account/billing"
                    case .gemini:
                        billingUrl = "aistudio.google.com"
                    case .groq:
                        billingUrl = "console.groq.com"
                    }
                    self.errorMessage = "\(name) API error: You have exceeded your account quota. Check billing at \(billingUrl)."
                } else {
                    self.errorMessage = "\(name) API error: \(msg)"
                }
                self.cancelInFlightTask()
                return
            }

            if let choices = json["choices"] as? [[String: Any]], let first = choices.first {
                if let finishReason = first["finish_reason"] as? String, finishReason == "length" {
                    self.isTruncated = true
                }

                if let delta = first["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    self.outputText.append(content)
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let taskDesc = task.taskDescription else {
            return
        }

        let isTranslate = (taskDesc == currentRequestId.uuidString)
        let isPolish = (taskDesc == polishRequestId.uuidString)

        guard isTranslate || isPolish else { return }

        if isTranslate {
            self.isTaskInFlight = false
            self.currentTask = nil
            self.isLoading = false

            if let error = error as NSError? {
                if error.code == NSURLErrorCancelled { return }
                self.errorMessage = error.localizedDescription
                return
            }

            // If non-2xx status, parse the accumulated complete JSON error body
            if !(200...299).contains(responseStatusCode) {
                if let detailedMsg = parseErrorMessage(from: errorDataBuffer, provider: self.requestProvider, statusCode: self.responseStatusCode) {
                    self.errorMessage = detailedMsg
                }
                errorDataBuffer.removeAll()
                return
            }

            // Flush any trailing line in buffer
            if !streamDataBuffer.isEmpty {
                if let trailingStr = String(data: streamDataBuffer, encoding: .utf8) {
                    processSSELine(trailingStr)
                } else {
                    self.hadStreamParseError = true
                }
                streamDataBuffer.removeAll()
            }

            // Validate stream completeness for successful HTTP responses
            if (200...299).contains(responseStatusCode) && errorMessage.isEmpty {
                if outputText.isEmpty {
                    self.errorMessage = "Stream completed with empty output."
                } else if !receivedDone {
                    self.errorMessage = "Stream interrupted before completion."
                }
            }
        } else if isPolish {
            self.polishTask = nil
            self.isPolishing = false

            if let error = error as NSError? {
                if error.code == NSURLErrorCancelled { return }
                self.polishErrorMessage = error.localizedDescription
                let msg = self.polishErrorMessage
                let failed = self.onPolishFailed
                DispatchQueue.main.async {
                    failed?(msg)
                }
                return
            }

            if !(200...299).contains(polishStatusCode) {
                if let detailedMsg = parseErrorMessage(from: polishErrorBuffer, provider: self.activeProvider, statusCode: self.polishStatusCode) {
                    self.polishErrorMessage = detailedMsg
                }
                polishErrorBuffer.removeAll()
                let msg = self.polishErrorMessage
                let failed = self.onPolishFailed
                DispatchQueue.main.async {
                    failed?(msg)
                }
                return
            }

            if !polishStreamBuffer.isEmpty {
                if let trailingStr = String(data: polishStreamBuffer, encoding: .utf8) {
                    processPolishSSELine(trailingStr)
                }
                polishStreamBuffer.removeAll()
            }

            if (200...299).contains(polishStatusCode) && polishErrorMessage.isEmpty {
                if polishedOutputText.isEmpty {
                    self.polishErrorMessage = "Stream completed with empty output."
                    let msg = self.polishErrorMessage
                    let failed = self.onPolishFailed
                    DispatchQueue.main.async {
                        failed?(msg)
                    }
                } else {
                    self.polishedOutputText = sanitizePolishedText(self.polishedOutputText)
                    let text = self.polishedOutputText
                    autoCopyPolishedText(text)
                    let finished = self.onPolishFinished
                    DispatchQueue.main.async {
                        finished?(text)
                    }
                }
            } else if !polishErrorMessage.isEmpty {
                let msg = self.polishErrorMessage
                let failed = self.onPolishFailed
                DispatchQueue.main.async {
                    failed?(msg)
                }
            }
        }
    }
}

// MARK: - Native Tooltip / Popover Bubble UI with Dynamic Sizing & Scrollable Content
struct InlinePopoverView: View {
    @ObservedObject var vm: PopoverViewModel
    var onClose: () -> Void
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row: Status & Actions
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "character.book.closed.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 11))
                    Text("Glossa")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary.opacity(0.85))
                }

                Spacer()

                if vm.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                }

                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenUserGuide"), object: nil)
                }) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("User Guide / භාවිත උපදෙස්")

                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Settings (⌘,)")

                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenAbout"), object: nil)
                }) {
                    Image(systemName: "info")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("About Glossa")

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }

            // API Key Not Configured Banner
            if vm.apiKey.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "key.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(vm.activeProvider.displayName) API Key not configured.")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.orange)
                        Button("Configure in Settings (⌘,)") {
                            NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.blue)
                    }
                }
                .padding(6)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
            }

            // Accessibility Permission Banner (shown when AX permission is missing)
            if !vm.isAccessibilityTrusted {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility permission needed to auto-read highlighted text.")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.orange)
                        Button("Open Privacy & Security > Accessibility") {
                            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                            _ = AXIsProcessTrustedWithOptions(options)
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                vm.isAccessibilityTrusted = AXIsProcessTrustedWithOptions(nil)
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.blue)
                    }
                }
                .padding(6)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
            }

            // Global Hotkey Conflict Banner
            if !vm.hotKeyConflictMessage.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 10))
                    Text(vm.hotKeyConflictMessage)
                        .font(.system(size: 10))
                        .foregroundColor(.primary.opacity(0.8))
                }
                .padding(4)
                .background(Color.yellow.opacity(0.12))
                .cornerRadius(4)
            }

            // Manual Input Mode (shown when no text was selected)
            if vm.isManualInputMode && vm.outputText.isEmpty && !vm.isLoading && vm.polishedOutputText.isEmpty && !vm.isPolishing {
                HStack(spacing: 6) {
                    TextField(
                        vm.activeTriggerMode == .rewrite ? "Type English text to polish & rewrite..." : "Type English text to translate...",
                        text: $vm.inputText
                    )
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .padding(6)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(6)
                        .focused($isFieldFocused)
                        .onSubmit {
                            if vm.activeTriggerMode == .rewrite {
                                vm.runProfessionalPolishAndCopy()
                            } else {
                                vm.runTranslate()
                            }
                        }

                    Button(action: {
                        if vm.activeTriggerMode == .rewrite {
                            vm.runProfessionalPolishAndCopy()
                        } else {
                            vm.runTranslate()
                        }
                    }) {
                        Image(systemName: vm.activeTriggerMode == .rewrite ? "sparkles" : "arrow.right.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(vm.activeTriggerMode == .rewrite ? .purple : .blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isFieldFocused = true
                    }
                }
            }

            // Preserved Sinhala Translation Card
            if !vm.outputText.isEmpty || vm.isLoading || !vm.errorMessage.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Sinhala (සරල සිංහල)")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        if !vm.outputText.isEmpty {
                            Button(action: {
                                vm.copyAndDismiss(onDismiss: onClose)
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: vm.copied ? "checkmark.circle.fill" : "doc.on.doc")
                                    Text(vm.copied ? "Copied" : "Copy")
                                }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(vm.copied ? .green : .blue)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.blue.opacity(0.12))
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !vm.errorMessage.isEmpty {
                        Text(vm.errorMessage)
                            .font(.system(size: 11.5))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if vm.outputText.isEmpty && vm.isLoading {
                        Text(vm.loadingPlaceholder)
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            Text(vm.outputText)
                                .font(.system(size: 13, weight: .medium))
                                .lineSpacing(2.5)
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 1)
                        }
                        .frame(maxHeight: 120)
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
            }

            // Action Bar: Make Professional Button
            if !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack {
                    Button(action: {
                        vm.runProfessionalPolishAndCopy()
                    }) {
                        HStack(spacing: 5) {
                            if vm.isPolishing {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                                Text("Polishing English...")
                                    .font(.system(size: 11, weight: .semibold))
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .bold))
                                Text("✨ Make Professional & Copy")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(vm.isPolishing ? Color.purple.opacity(0.6) : Color.purple)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isPolishing || vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: [.option])

                    Spacer()

                    HStack(spacing: 3) {
                        Text("⌥ Return")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.8))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(4)
                    }
                }
            }

            // Polished English Result Card (Option A Stacked Layout)
            if vm.isPolishing || !vm.polishedOutputText.isEmpty || !vm.polishErrorMessage.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.purple)
                                .font(.system(size: 10))
                            Text("Polished Professional English")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.9))
                        }

                        Spacer()

                        // Auto-copied Toast Pill
                        if vm.polishedAutoCopiedToast {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("✓ Copied to Clipboard!")
                            }
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.18))
                            .cornerRadius(4)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        // Manual Copy Button
                        if !vm.polishedOutputText.isEmpty {
                            Button(action: {
                                vm.copyPolishedText()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: vm.polishedCopied ? "checkmark" : "doc.on.doc")
                                    Text(vm.polishedCopied ? "Copied" : "Copy")
                                }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(vm.polishedCopied ? .green : .purple)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.purple.opacity(0.12))
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !vm.polishErrorMessage.isEmpty {
                        Text(vm.polishErrorMessage)
                            .font(.system(size: 11.5))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if vm.polishedOutputText.isEmpty && vm.isPolishing {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                            Text("Refining grammar and elevating workplace tone...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            Text(vm.polishedOutputText)
                                .font(.system(size: 13, weight: .medium))
                                .lineSpacing(2.5)
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 1)
                        }
                        .frame(maxHeight: 140)
                    }
                }
                .padding(8)
                .background(Color.purple.opacity(0.08))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.purple.opacity(0.25), lineWidth: 1)
                )
            }

            // Truncation Warning Banner (if hit length limit)
            if vm.isTruncated {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 9.5))
                    Text("Output truncated due to token limit")
                        .font(.system(size: 9.5))
                        .foregroundColor(.orange)
                }
            }

            // Stream Parse Warning Banner (if corrupt chunks encountered)
            if vm.hadStreamParseError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 9.5))
                    Text("Warning: Stream encountered malformed data")
                        .font(.system(size: 9.5))
                        .foregroundColor(.yellow)
                }
            }

            // Subdued Hint
            HStack {
                Text(vm.isManualInputMode && vm.outputText.isEmpty && vm.polishedOutputText.isEmpty
                    ? (vm.activeTriggerMode == .rewrite ? "Press ↵ to polish • Esc to dismiss" : "Press ↵ to translate • ⌥↵ to polish • Esc to dismiss")
                    : "⌥↵ to polish • Click text to copy • Esc to dismiss")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary.opacity(0.6))
                Spacer()
            }
        }
        .padding(12)
        .frame(width: 380)
        .background(
            ZStack {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                Color(NSColor.windowBackgroundColor).opacity(0.65)
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
        .animation(.easeInOut(duration: 0.2), value: vm.polishedAutoCopiedToast)
        .animation(.easeInOut(duration: 0.2), value: vm.isPolishing)
        .onAppear {
            vm.isAccessibilityTrusted = AXIsProcessTrustedWithOptions(nil)
        }
    }
}

// MARK: - Native Liquid Glass Blur View
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Backward Compatibility Aliases
typealias AppViewModel = PopoverViewModel
typealias MainContentView = InlinePopoverView
