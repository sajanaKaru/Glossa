# Glossa v1.1.0 — Native macOS Translation & Grammar Polisher

We are excited to announce the official release of **Glossa v1.1.0** (formerly LingoBar), a native, lightweight macOS menu bar utility built for seamless language translation and instant professional grammar rewriting.

---

### 🌟 What's New in v1.1.0

- **Brand Rebranding & Polish**: Fully rebranded from LingoBar to **Glossa** (`com.glossa.macos`), featuring unified iconography, updated bundle identifiers, and cohesive macOS dark-mode styling.
- **Natural Spoken Sinhala Translation (`⌥Space` / `⌥⇧L`)**: Real-time translation between English and natural, conversational Sinhala (ස්වභාවික කථන සිංහල), designed specifically to avoid rigid literal translations.
- **Instant Grammar Polisher & Rewrite (`⌥⇧R`)**: One-stroke professional English rewrite that polishes tone, grammar, and sentence structure, copying the polished text back to your clipboard in under a second.
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
- **Permissions**: Accessibility permission is required for instant global hotkey capture (`⌥⇧R`).

#### Checksums
SHA-256 checksums are attached alongside each asset file (`.sha256`) for cryptographic integrity verification:
```bash
shasum -a 256 -c Glossa-Installer.dmg.sha256
```

---

*Engineered with precision in native Swift 6 and SwiftUI by [Sajana Karunarathna](https://www.linkedin.com/in/sajanakaru).*
