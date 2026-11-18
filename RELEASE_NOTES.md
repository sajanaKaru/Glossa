# Glossa v1.2.1 — Native macOS Translation & In-Place Polish

We are excited to announce **Glossa v1.2.1**, introducing strict positive-confirmation read-only surface detection and seamless dialog box fallback for macOS.

---

### 🌟 What's New in v1.2.1

- **Strict Read-Only Surface Detection**: Implemented a positive-confirmation editability engine (`InPlaceTextReplacer.isElementEditable`). Accessibility elements are strictly classified as editable only upon explicit attribute write permission or confirmed editable container ancestry.
- **Seamless Popover Dialog Fallback**: When English Polish (`⌥⇧R` / `⌥Return`) is triggered on an uneditable surface (such as static web articles in Safari/Chrome, Preview PDF pages, or read-only documents) with auto-replace enabled, Glossa automatically falls back to opening the standard popover dialog at the selection bounds. The polished text streams visibly in the dialog and auto-copies to the clipboard with the confirmation toast ("✓ Copied to Clipboard!").
- **Multi-App Editability Protection**: Explicit exclusion of non-editable bundles (`com.apple.Preview`, `QuickLook`) and non-editable roles (`AXStaticText`, `AXHeading`, `AXImage`, `AXWebArea`, `AXGroup`, `AXScrollArea`) prevents disruptive synthetic keystroke injections into static text.

---

### 🌟 Previous Release: v1.2.0

- **Direct In-Place Auto-Replacement (`⌥⇧R`)**: When enabled, English Grammar Polish directly replaces the selected text in your active application (TextEdit, Notes, Safari, VSCode, Slack, etc.) without opening the Glossa popover window.
- **Pulsing Selection Visual Indicator**: A glowing, non-activating floating highlight pulses over your selected text on screen while Glossa processes the rewrite, providing intuitive visual feedback without stealing keyboard or window focus.
- **Two-Tier Replacement Architecture**:
  - **Tier 1 (Accessibility API)**: Direct attribute write via `kAXSelectedTextAttribute` for instant zero-clipboard mutation in native AppKit editors.
  - **Tier 2 (Synthetic Cmd+V Fallback)**: Automated synthetic paste fallback with clipboard backup for WebKit, Chromium, and Electron applications.
- **Settings Toggle & Accessibility Status (`SettingsView`)**: New "English Polish Behavior" configuration panel featuring the "Auto-replace selected text on Polish" toggle, real-time Accessibility permission badge, and deep link to macOS Privacy & Security settings.
- **Tactile Haptic Feedback**: Subtle physical haptic confirmation (`.alignment`) upon successful text replacement.
- **Transient Error & Cancellation HUD**: Pressing `Esc` immediately cancels the in-flight rewrite and dismisses the overlay. API errors display a transient floating HUD anchored near the selection without cluttering your workspace.

---

### 🌟 Previous Release: v1.1.0

- **Brand Rebranding & Polish**: Fully rebranded from LingoBar to **Glossa** (`com.glossa.macos`), featuring unified iconography, updated bundle identifiers, and cohesive macOS dark-mode styling.
- **Natural Spoken Sinhala Translation (`⌥Space` / `⌥⇧L`)**: Real-time translation between English and natural, conversational Sinhala (ස්වභාවික කථන සිංහල), designed specifically to avoid rigid literal translations.
- **Instant Grammar Polisher & Rewrite (`⌥⇧R`)**: One-stroke professional English rewrite that polishes tone, grammar, and sentence structure.
- **Custom Branded DMG Installer**: Production installer with a high-resolution dark-mode background, aligned drop targets (Application icon and `/Applications` alias), and Gatekeeper notarization guidance.
- **In-App Update Checker**: Menu item and About view action (`Check for Updates...`) linking directly to official GitHub releases.
- **Launch at Login**: Native macOS background startup integration using Apple's modern `SMAppService.mainApp` API.
- **Multi-Engine AI Support**: Bring your own API key for **Groq** (ultra-fast Llama 3 models), **OpenAI** (GPT-4o / GPT-4o-mini), or **Google Gemini** (Gemini 1.5 Flash / Pro).
- **Zero-Footprint Security**: API keys are isolated and encrypted inside the Apple macOS Keychain (`kSecClassGenericPassword`). No intermediate proxy or telemetry servers.
- **Bilingual In-App Documentation**: Comprehensive, interactive User Guide in English and Sinhala built right into the app window.

---

### 📦 Downloads & Verification

| Asset | Description |
| :--- | :--- |
| **`Glossa-Installer.dmg`** | Recommended drag-and-drop installer for macOS |
| **`Glossa-macOS.zip`** | Portable standalone application bundle |

#### System Requirements
- **macOS Version**: macOS 13.0 (Ventura), macOS 14.0 (Sonoma), macOS 15.0 (Sequoia), or later.
- **Architecture**: Universal binary support (Apple Silicon M1/M2/M3/M4 & Intel x86_64).
- **Permissions**: Accessibility permission is required for global hotkey capture and in-place text replacement.

#### Checksums
SHA-256 checksums are attached alongside each asset file (`.sha256`) for cryptographic integrity verification:
```bash
shasum -a 256 -c Glossa-Installer.dmg.sha256
```

---

*Engineered with precision in native Swift 6 and SwiftUI by [Sajana Karunarathna](https://www.linkedin.com/in/sajanakaru).*
