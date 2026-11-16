# Glossa (ග්‍ලෝසා)

<p align="center">
  <img src="Resources/AppIcon.icns" alt="Glossa App Icon" width="128" height="128" style="border-radius: 28px; box-shadow: 0 8px 24px rgba(0,0,0,0.15);" />
</p>

<p align="center">
  <strong>Instant English-to-Sinhala Translation & Professional Grammar Polishing for macOS.</strong><br />
  A native, lightweight macOS menu bar utility built with Swift 6 and SwiftUI.
</p>

<p align="center">
  <a href="https://github.com/sajanaKaru/LingoBar/releases/latest">
    <img src="https://img.shields.io/github/v/release/sajanaKaru/LingoBar?style=flat-square&color=007AFF&label=Release" alt="Latest Release" />
  </a>
  <img src="https://img.shields.io/badge/macOS-13.0%2B-blue?style=flat-square&logo=apple&logoColor=white" alt="macOS 13.0+" />
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.0" />
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20%2F%20Intel-000000?style=flat-square" alt="Universal Binary" />
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="MIT License" />
  </a>
</p>

---

<p align="center">
  <a href="https://github.com/sajanaKaru/LingoBar/releases/latest/download/Glossa-Installer.dmg">
    <img src="https://img.shields.io/badge/⬇️%20Download-Glossa_Installer.dmg-007AFF?style=for-the-badge&logo=apple&logoColor=white" alt="Download Glossa for macOS" />
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/sajanaKaru/LingoBar/releases/latest/download/Glossa-macOS.zip">
    <img src="https://img.shields.io/badge/📦%20Download-Portable_ZIP-5856D6?style=for-the-badge&logo=apple&logoColor=white" alt="Download Portable ZIP" />
  </a>
</p>

---

## 🌟 Why Glossa?

Working across English and Sinhala often requires constant context switching between browsers, chat apps, and translation tools. **Glossa** lives unobtrusively in your macOS menu bar (`LSUIElement = true`), ready to assist with a single keystroke:

1. **Highlight text anywhere** — in Safari, Chrome, Slack, Xcode, Mail, or Notes.
2. **Press `⌥Space`** for immediate, natural spoken Sinhala translation (`සරල සිංහල`).
3. **Press `⌥⇧R`** to rewrite drafts into polished, professional workplace English with automatic clipboard copy.

No browser tabs. No subscription fees. No data harvesting. Your API keys are kept strictly local in your macOS Keychain.

---

## ✨ Key Features

- 🇱🇰 **Natural Spoken Sinhala Translation (`⌥Space` / `⌥⇧L`)**<br />
  Produces natural, everyday spoken Sinhala (`සරල සිංහල`) rather than robotic or archaic textbook phrasing.

- ✍️ **Professional Rewrite & Auto-Copy (`⌥⇧R`)**<br />
  Refines emails, PR reviews, Slack messages, and documentation into fluent, natural business English and instantly copies the result to your clipboard.

- ⚡ **Global Carbon Hotkey Engine**<br />
  Sub-millisecond shortcut capture with automatic registration conflict detection and menu bar fallback.

- 🚀 **Auto-Startup (Launch at Login)**<br />
  Integrated with modern macOS `SMAppService.mainApp` — turn it on with a single toggle so Glossa is always ready when your Mac boots.

- 📖 **Built-in Bilingual User Guide**<br />
  Full English and Sinhala (`සිංහල`) onboarding guide with shortcut cheatsheets and configuration tips.

- 🔐 **Multi-Provider AI with Keychain Isolation**
  Seamlessly choose between:
  - **Groq** (`llama-3.3-70b-versatile`, `llama-3.1-8b-instant` — ultra-fast sub-second latency)
  - **OpenAI** (`gpt-4o-mini`, `gpt-4o`)
  - **Google Gemini** (`gemini-2.0-flash`, `gemini-2.0-flash-lite`, `gemini-1.5-flash`, `gemini-1.5-pro`)<br />
  All credentials are saved securely in your macOS Keychain (`kSecClassGenericPassword`).

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| <kbd>⌥ Option</kbd> + <kbd>Space</kbd> | **Translate Selection to Sinhala** | Global (System-wide) |
| <kbd>⌥ Option</kbd> + <kbd>⇧ Shift</kbd> + <kbd>L</kbd> | **Alternative Translate Shortcut** | Global (System-wide) |
| <kbd>⌥ Option</kbd> + <kbd>⇧ Shift</kbd> + <kbd>R</kbd> | **Rewrite Selection (Professional Polish & Auto-Copy)** | Global (System-wide) |
| <kbd>⌥ Option</kbd> + <kbd>Return</kbd> | **Make Professional & Auto-Copy** | Inside Popover HUD |
| <kbd>Return ↵</kbd> | **Translate Manual Input** | Inside Popover HUD |
| <kbd>⌘ Command</kbd> + <kbd>,</kbd> | **Open Glossa Settings** | Menu Bar / HUD |
| <kbd>Esc</kbd> | **Dismiss Popover / Close Window** | Everywhere |

---

## 📦 Installation

### Option 1: Drag-and-Drop Installer (Recommended)
1. Download **[`Glossa-Installer.dmg`](https://github.com/sajanaKaru/LingoBar/releases/latest/download/Glossa-Installer.dmg)**.
2. Double-click the downloaded `.dmg` file to mount the custom installer window.
3. Drag the **Glossa** icon into the **Applications** folder shortcut.
4. Eject the disk image and launch **Glossa** from Applications or Spotlight (<kbd>⌘ Space</kbd>).

### Option 2: Portable ZIP Archive
1. Download **[`Glossa-macOS.zip`](https://github.com/sajanaKaru/LingoBar/releases/latest/download/Glossa-macOS.zip)**.
2. Unzip the archive and move `Glossa.app` into `/Applications`.

---

## 🔒 Security & macOS Permissions

### 1. macOS Accessibility Permission (Required)
Glossa requires **Accessibility** permissions to capture selected text across third-party applications when you trigger `⌥Space` or `⌥⇧R`:
1. When launched, macOS will prompt you to grant Accessibility access.
2. If prompted, open **System Settings** → **Privacy & Security** → **Accessibility**.
3. Toggle the switch next to **Glossa** to **ON**.
4. Glossa is ready to capture text globally!

> **Note on Privacy**: Glossa only reads text when you explicitly press a shortcut. It does not monitor, log, or record keystrokes.

### 2. First Launch Notice (Gatekeeper)
Because Glossa is an open-source tool signed with an ad-hoc developer signature rather than a paid Apple Developer certificate ($99/year), macOS Gatekeeper may display a security alert on first launch:
1. **Right-click** (or Control-click) `Glossa.app` in `/Applications`.
2. Click **Open** from the context menu.
3. In the security dialog, click **Open**.
4. You will only need to perform this confirmation once.

---

## ⚙️ Configuration & API Keys

Glossa connects directly to your chosen AI provider using your personal API key:

1. Click the **Glossa** menu bar icon → **Glossa Settings...** (or press <kbd>⌘ ,</kbd>).
2. Choose your preferred AI Provider:
   - **Groq** (Fastest, free tier available at [console.groq.com](https://console.groq.com/keys))
   - **OpenAI** ([platform.openai.com](https://platform.openai.com/api-keys))
   - **Google Gemini** (Free tier available at [aistudio.google.com](https://aistudio.google.com/app/apikey))
3. Paste your API key and click **Test Connection**.
4. Once verified (green checkmark), click **Save**.

Your key is stored encrypted in your macOS Keychain and never leaves your computer except to contact the provider's official API endpoint.

---

## 🔄 Checking for Updates

Glossa includes built-in update checks:
- Click the Glossa menu bar icon → **Check for Updates...**
- Or open **About Glossa** and click **Updates**.

Both direct you to the [latest GitHub Releases page](https://github.com/sajanaKaru/LingoBar/releases/latest) where new installer packages and release notes are posted.

---

## 🛠️ Building from Source

To compile Glossa locally on macOS:

```bash
# Clone the repository
git clone https://github.com/sajanaKaru/LingoBar.git Glossa
cd Glossa

# Build Glossa.app
./build.sh

# Build Glossa-Installer.dmg and Glossa-macOS.zip
./package.sh
```

**Prerequisites**:
- macOS 13.0 (Ventura) or newer
- Xcode Command Line Tools (`xcode-select --install`)
- Python 3 with Pillow (for DMG installer canvas rendering)

---

## 👨‍💻 Developer & Credits

Designed and developed with ❤️ by:

**Sajana Karunarathna**<br />
Connect on LinkedIn: [linkedin.com/in/sajanakaru](https://www.linkedin.com/in/sajanakaru)

---

## 📄 License

Glossa is licensed under the **[MIT License](LICENSE)**. Free for personal and commercial use.
