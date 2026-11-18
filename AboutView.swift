import SwiftUI
import AppKit

struct AboutView: View {
    @Binding var isPresented: Bool

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.2.1"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "4"
    }

    private var appIconImage: NSImage {
        if let icon = NSImage(named: "AppIcon") {
            return icon
        }
        return NSApp.applicationIconImage
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main Branding Section
            VStack(spacing: 12) {
                // App Icon with subtle elevation
                Image(nsImage: appIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)

                // Title & Version
                VStack(spacing: 4) {
                    Text("Glossa")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Version \(appVersion) (\(appBuild))")
                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                // Tagline
                Text("Glossa — Instant English-to-Sinhala translation & professional grammar polish for macOS")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .lineSpacing(2)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 20)

            // Details & Tech Stack Card
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    Text("Powered by Swift 6, AppKit, Groq, OpenAI & Google Gemini")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.purple)
                    HStack(spacing: 4) {
                        Text("Developed by")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("Sajana Karunarathna")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }

                // Interactive Links
                HStack(spacing: 8) {
                    // Developer LinkedIn profile button (NO GitHub link, per user specification)
                    Button(action: openLinkedIn) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 10, weight: .bold))
                            Text("LinkedIn")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    // Open User Guide button
                    Button(action: openUserGuide) {
                        HStack(spacing: 4) {
                            Image(systemName: "book.pages")
                                .font(.system(size: 10, weight: .bold))
                            Text("User Guide")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    // Check for Updates button
                    Button(action: checkForUpdates) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10, weight: .bold))
                            Text("Updates")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)

            Spacer()

            Divider()

            // Footer / Legal Section
            HStack {
                Text("MIT License • Copyright © 2026 Sajana Karunarathna")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))

                Spacer()

                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.return, modifiers: [])
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 420, height: 380)
    }

    private func openLinkedIn() {
        if let url = URL(string: "https://www.linkedin.com/in/sajanakaru") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openUserGuide() {
        NotificationCenter.default.post(name: NSNotification.Name("OpenUserGuide"), object: nil)
    }

    private func checkForUpdates() {
        if let url = URL(string: "https://github.com/sajanaKaru/Glossa/releases/latest") {
            NSWorkspace.shared.open(url)
        }
    }
}
