import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class LaunchAtLoginHelper: ObservableObject {
    static let shared = LaunchAtLoginHelper()

    @Published var isEnabled: Bool = false
    @Published var status: SMAppService.Status = .notRegistered
    @Published var errorMessage: String = ""

    private init() {
        refreshStatus()
    }

    func refreshStatus() {
        if #available(macOS 13.0, *) {
            self.status = SMAppService.mainApp.status
            self.isEnabled = (status == .enabled)
        } else {
            self.isEnabled = false
        }
    }

    func setLaunchAtLogin(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                errorMessage = ""
            } catch {
                errorMessage = error.localizedDescription
                NSLog("[Glossa] SMAppService registration failed: %@", error.localizedDescription)
            }
            refreshStatus()
        }
    }

    func openSystemLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    var statusDescription: String {
        switch status {
        case .enabled:
            return "Active"
        case .requiresApproval:
            return "Requires Approval"
        case .notRegistered:
            return "Not Registered"
        case .notFound:
            return "Not Found"
        @unknown default:
            return "Unknown"
        }
    }
}
