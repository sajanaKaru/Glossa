import SwiftUI
import AppKit

// MARK: - Non-Activating Floating Selection Overlay Panel
final class SelectionOverlayPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .floating
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool {
        return false
    }

    override var canBecomeMain: Bool {
        return false
    }
}

// MARK: - Pulsing Selection Highlight View
struct PulsingSelectionHighlightView: View {
    @State private var isPulsing = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.purple.opacity(isPulsing ? 0.38 : 0.16),
                        Color.blue.opacity(isPulsing ? 0.48 : 0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(
                        Color.purple.opacity(isPulsing ? 0.70 : 0.28),
                        lineWidth: 1.5
                    )
            )
            .animation(
                Animation.easeInOut(duration: 0.85).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Transient Floating Error HUD Panel
final class TransientErrorHUDPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .popUpMenu
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool {
        return false
    }

    override var canBecomeMain: Bool {
        return false
    }
}

// MARK: - Transient Error HUD View
struct TransientErrorHUDView: View {
    let message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 13, weight: .semibold))

            Text(message)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 240, maxWidth: 360)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.red.opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Selection Overlay & Error HUD Controller
final class SelectionOverlayController {
    static let shared = SelectionOverlayController()

    private var overlayPanel: SelectionOverlayPanel?
    private var errorHUDPanel: TransientErrorHUDPanel?
    private var errorDismissWorkItem: DispatchWorkItem?

    var isOverlayVisible: Bool {
        overlayPanel?.isVisible ?? false
    }

    var isErrorHUDVisible: Bool {
        errorHUDPanel?.isVisible ?? false
    }

    // MARK: - Overlay Management
    func showOverlay(at rect: NSRect) {
        hideErrorHUD()

        // Ensure minimum dimensions and slight padding for aesthetics
        let paddedRect = NSRect(
            x: rect.origin.x - 2,
            y: rect.origin.y - 2,
            width: max(rect.width + 4, 24),
            height: max(rect.height + 4, 16)
        )

        if overlayPanel == nil {
            let panel = SelectionOverlayPanel(contentRect: paddedRect)
            panel.contentView = NSHostingView(rootView: PulsingSelectionHighlightView())
            self.overlayPanel = panel
        } else {
            overlayPanel?.setFrame(paddedRect, display: true, animate: false)
        }

        overlayPanel?.orderFrontRegardless()
    }

    func hideOverlay() {
        overlayPanel?.orderOut(nil)
        overlayPanel = nil
    }

    // MARK: - Error HUD Management
    func showErrorHUD(message: String, near targetRect: NSRect) {
        hideOverlay()
        errorDismissWorkItem?.cancel()

        if errorHUDPanel == nil {
            errorHUDPanel = TransientErrorHUDPanel()
        }

        let hudView = TransientErrorHUDView(
            message: message,
            onDismiss: { [weak self] in
                self?.hideErrorHUD()
            }
        )

        guard let hudPanel = errorHUDPanel else { return }
        hudPanel.contentView = NSHostingView(rootView: hudView)

        // Compute positioning anchored near the selection
        let hudSize = NSSize(width: 320, height: 50)
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(targetRect) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let margin: CGFloat = 8

        var originX = targetRect.origin.x + (targetRect.width - hudSize.width) / 2.0
        var originY = targetRect.origin.y - hudSize.height - margin

        // If below screen bottom edge, place above the selection
        if originY < visibleFrame.minY {
            originY = targetRect.origin.y + targetRect.height + margin
        }

        // Clamp within visible screen boundaries
        originX = min(max(originX, visibleFrame.minX + margin), visibleFrame.maxX - hudSize.width - margin)
        originY = min(max(originY, visibleFrame.minY + margin), visibleFrame.maxY - hudSize.height - margin)

        hudPanel.setFrame(NSRect(origin: CGPoint(x: round(originX), y: round(originY)), size: hudSize), display: true)
        hudPanel.orderFrontRegardless()

        // Auto-dismiss after 3.5 seconds
        let workItem = DispatchWorkItem { [weak self] in
            self?.hideErrorHUD()
        }
        self.errorDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: workItem)
    }

    func hideErrorHUD() {
        errorDismissWorkItem?.cancel()
        errorDismissWorkItem = nil
        errorHUDPanel?.orderOut(nil)
        errorHUDPanel = nil
    }
}
