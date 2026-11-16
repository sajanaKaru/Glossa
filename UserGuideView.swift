import SwiftUI
import AppKit

enum GuideLanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case sinhala = "සිංහල"

    var id: String { rawValue }
}

struct KeyBadgeView: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
    }
}

struct UserGuideView: View {
    @Binding var isPresented: Bool
    @State private var selectedLanguage: GuideLanguage = .english
    @AppStorage("suppressGuideOnStartup") private var suppressGuideOnStartup: Bool = false
    @ObservedObject private var launchHelper = LaunchAtLoginHelper.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Glossa")
                            .font(.system(size: 16, weight: .bold))
                        Text(selectedLanguage == .english ? "Glossa Guide & Shortcuts / භාවිත උපදෙස්" : "භාවිත උපදෙස් සහ කෙටිමං")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Picker("", selection: $selectedLanguage) {
                    ForEach(GuideLanguage.allCases) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            // Content Area
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 14) {
                    // Feature 1: Instant Translation
                    guideCard(
                        icon: "character.bubble.fill",
                        iconColor: .blue,
                        title: selectedLanguage == .english ? "1. Instant Translation to Sinhala" : "1. සරල සිංහල පරිවර්තනය",
                        description: selectedLanguage == .english
                            ? "Highlight any English text in any app (browser, document, chat) and press Option+Space or Option+Shift+L. Glossa appears instantly with natural, everyday spoken Sinhala (සරල සිංහල)."
                            : "ඕනෑම මෘදුකාංගයක ඇති ඉංග්‍රීසි පාඨයක් තෝරා (highlight කර) Option+Space හෝ Option+Shift+L ඔබන්න. Glossa මඟින් එදිනෙදා ව්‍යවහාරික සරල සිංහල අර්ථය ක්ෂණිකව දිස්වනු ඇත.",
                        shortcuts: [
                            ["⌥", "Space"],
                            ["⌥", "⇧", "L"]
                        ]
                    )

                    // Feature 2: Professional Rewrite & Grammar Polish
                    guideCard(
                        icon: "sparkles",
                        iconColor: .purple,
                        title: selectedLanguage == .english ? "2. Professional Rewrite & Auto-Copy" : "2. වෘත්තීය ඉංග්‍රීසි සංස්කරණය සහ පිටපත් කිරීම",
                        description: selectedLanguage == .english
                            ? "Draft an email, PR, or Slack message and press Option+Shift+R (or click 'Make Professional'). Glossa fixes all grammatical errors, refines workplace tone, and automatically copies the polished sentence to your clipboard."
                            : "ඔබ ලියූ ඉංග්‍රීසි වාක්‍යයක් තෝරා Option+Shift+R ඔබන්න. Glossa මඟින් ව්‍යාකරණ දෝෂ නිවැරදි කර, පැහැදිලි වෘත්තීය මට්ටමේ වාක්‍යයක් සකසා ක්ෂණිකව Clipboard එකට Copy කර දෙනු ඇත.",
                        shortcuts: [
                            ["⌥", "⇧", "R"],
                            ["⌥", "Return"]
                        ]
                    )

                    // Feature 3: Status Bar Menu & Settings
                    guideCard(
                        icon: "menubar.rectangle",
                        iconColor: .orange,
                        title: selectedLanguage == .english ? "3. Menu Bar Actions & Settings" : "3. මෙනු බාර් පහසුකම් සහ සැකසුම්",
                        description: selectedLanguage == .english
                            ? "Click the Glossa menu bar icon to trigger Translate or Rewrite on demand, open this User Guide, or access Settings to configure your API keys (Groq, OpenAI, or Gemini) securely in macOS Keychain."
                            : "මෙනු බාර් හි ඇති Glossa අයිකනය මඟින් පරිවර්තන, සංස්කරණ, මෙම උපදෙස් පත්‍රිකාව හෝ Settings වෙත පිවිසිය හැක. Groq, OpenAI සහ Gemini සේවාවන් Keychain මඟින් සුරක්ෂිතව භාවිතා කරන්න.",
                        shortcuts: [
                            ["⌘", ","]
                        ]
                    )

                    // Feature 4: Auto-Startup on Login (Launch at Login)
                    launchAtLoginCard()

                    // Quick Shortcut Cheatsheet Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedLanguage == .english ? "Keyboard Shortcuts Summary" : "කෙටිමං සාරාංශය")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)

                        shortcutRow(
                            keys: ["⌥", "Space"],
                            altKeys: ["⌥", "⇧", "L"],
                            label: selectedLanguage == .english ? "Translate Selection to Sinhala" : "තෝරාගත් කොටස සිංහලට පරිවර්තනය"
                        )

                        shortcutRow(
                            keys: ["⌥", "⇧", "R"],
                            altKeys: nil,
                            label: selectedLanguage == .english ? "Rewrite Selection (Professional English)" : "තෝරාගත් කොටස වෘත්තීය මට්ටමින් සංස්කරණය"
                        )

                        shortcutRow(
                            keys: ["⌥", "Return"],
                            altKeys: nil,
                            label: selectedLanguage == .english ? "Make Professional & Copy (inside HUD)" : "HUD එක තුළින් සංස්කරණය කර Copy කිරීම"
                        )

                        shortcutRow(
                            keys: ["Esc"],
                            altKeys: nil,
                            label: selectedLanguage == .english ? "Dismiss Popover / Close Guide" : "පොප්ඕවරය හෝ උපදෙස් පත්‍රිකාව වසන්න"
                        )
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Toggle(isOn: $suppressGuideOnStartup) {
                    Text(selectedLanguage == .english
                         ? "Don't show this guide on startup"
                         : "යෙදුම ආරම්භයේදී මෙම උපදෙස් පත්‍රිකාව නැවත නොපෙන්වන්න")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                .toggleStyle(.checkbox)

                Spacer()

                Button(action: {
                    isPresented = false
                }) {
                    Text(selectedLanguage == .english ? "Got it!" : "ආරම්භ කරන්න")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 540, height: 530)
    }

    private func guideCard(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        shortcuts: [[String]]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(iconColor)
                    .frame(width: 22, height: 22)
                    .background(iconColor.opacity(0.12))
                    .clipShape(Circle())

                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 6) {
                    ForEach(0..<shortcuts.count, id: \.self) { idx in
                        HStack(spacing: 2) {
                            ForEach(shortcuts[idx], id: \.self) { k in
                                KeyBadgeView(key: k)
                            }
                        }
                        if idx < shortcuts.count - 1 {
                            Text("/")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Text(description)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private func shortcutRow(keys: [String], altKeys: [String]?, label: String) -> some View {
        HStack {
            HStack(spacing: 2) {
                ForEach(keys, id: \.self) { k in
                    KeyBadgeView(key: k)
                }
                if let alt = altKeys {
                    Text("/")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    ForEach(alt, id: \.self) { k in
                        KeyBadgeView(key: k)
                    }
                }
            }

            Spacer()

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private func launchAtLoginCard() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "macwindow.badge.plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
                    .frame(width: 22, height: 22)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Circle())

                Text(selectedLanguage == .english ? "4. Auto-Startup on Login (Recommended)" : "4. පරිගණකය ආරම්භයේදී ස්වයංක්‍රීයව අරඹන්න")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { launchHelper.isEnabled },
                    set: { newVal in launchHelper.setLaunchAtLogin(newVal) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
            }

            Text(selectedLanguage == .english
                ? "Glossa functions as a lightweight background accessory. Enabling Launch at Login ensures your global shortcuts (⌥Space and ⌥⇧R) are immediately available each time your Mac starts."
                : "Glossa පසුබිමේ ක්‍රියාත්මක වන යෙදුමක් බැවින්, Mac පරිගණකය ආරම්භ වන විටම ක්‍රියාත්මක වීමෙන් ⌥Space සහ ⌥⇧R කෙටිමං ඕනෑම වේලාවක භාවිතයට සූදානම්ව පවතී.")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Status Indicator & Actions
            HStack(spacing: 8) {
                if launchHelper.isEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 11))
                        Text(selectedLanguage == .english ? "Active — Ready on startup" : "සක්‍රියයි — ආරම්භයේදීම සූදානම්")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
                } else if launchHelper.status == .requiresApproval {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 11))
                        Text(selectedLanguage == .english ? "Approval Required in System Settings" : "System Settings තුළින් අනුමැතිය අවශ්‍යයි")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)

                    Button(action: {
                        launchHelper.openSystemLoginItemsSettings()
                    }) {
                        Text(selectedLanguage == .english ? "Open Settings" : "සැකසුම් විවෘත කරන්න")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                        Text(selectedLanguage == .english ? "Disabled" : "අක්‍රියයි")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                }

                Spacer()

                Button(action: {
                    launchHelper.openSystemLoginItemsSettings()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10))
                        Text(selectedLanguage == .english ? "Login Items" : "Login Items විවෘත කරන්න")
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help(selectedLanguage == .english ? "Open macOS System Settings > Login Items" : "macOS System Settings හි Login Items විවෘත කරන්න")
            }

            if !launchHelper.errorMessage.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 10))
                    Text(launchHelper.errorMessage)
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}
