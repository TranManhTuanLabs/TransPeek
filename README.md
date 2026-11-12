<p align="center">
  <img src="Resources/AppIcon.icon/Assets/TransPeek.png" width="128" height="128" alt="TransPeek Icon" />
</p>

<h1 align="center">TransPeek</h1>

<p align="center"><em>Translate anywhere, Peek instantly!</em></p>

<p align="center">
  A lightweight, native macOS menu bar translator. Select text, get translation.
  Peek at any text, translate instantly — with dictionary links, screenshot OCR and click-to-speak.
  Fork of [MoePeek](https://github.com/cosZone/MoePeek) by cosZone, licensed under AGPL-3.0.
</p>

<p align="center">
  English | <a href="README_zh.md">中文</a>
</p>

<p align="center">
  <a href="https://github.com/TranManhTuanLabs/TransPeek/releases/latest"><img src="https://img.shields.io/github/v/release/TranManhTuanLabs/TransPeek" alt="GitHub Release" /></a>
  <a href="https://github.com/TranManhTuanLabs/TransPeek/releases"><img src="https://img.shields.io/github/downloads/TranManhTuanLabs/TransPeek/total" alt="Downloads" /></a>
  <img src="https://img.shields.io/badge/platform-macOS%2015%2B-blue" alt="Platform" />
  <img src="https://img.shields.io/badge/swift-6.0-orange" alt="Swift" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-AGPL--3.0-green" alt="License" /></a>
</p>

<p align="center">
  <img src="Resources/MoePeek-promo.webp" alt="TransPeek Preview" />
</p>

## Features

**Translation Modes**

- **Smart Translation**: Use selected content first, fall back to the clipboard snapshot captured when invoked, or open manual input when both are empty
- **Select & Translate**: Select text in any app, get instant translation in a floating panel
- **OCR Screenshot**: Capture a screen region and translate the recognized text — from the menu bar, ⌥S, or the OCR button in the float panel (Vision OCR, Vietnamese + English)
- **Clipboard Translation**: Translate whatever's on your clipboard
- **Manual Input**: Type or paste text to translate on demand

**Built-in Translation Services**

| Free | API | LLM | System |
|------|-----|-----|--------|
| Google Translate | DeepL | OpenAI | Apple Translation |
| Bing Translate | Baidu | Anthropic | *(macOS 15+, on-device)* |
| Youdao Translate | NiuTrans | DeepSeek | |
| | Caiyun | OpenRouter | |
| | DeepLX | Requesty | |
| | | 智谱 GLM | |
| | | Ollama (local) | |
| | | LM Studio (local) | |

**And More**

- Smart language detection across 14 languages, auto-flips translation direction
- Click the floating icon to hear the selected text spoken (System TTS); dictionary links (Oxford, Cambridge, Google Dictionary, YouGlish) at the bottom of the float panel
- Text-to-speech playback for translated text using Apple's built-in speech synthesis
- Non-activating floating panels that never steal focus from your current app
- 3-tier text grabbing: Accessibility API → AppleScript → Clipboard fallback
- Markdown rendering for LLM results, plus optional rich text capture that keeps formatting and images from apps like Word
- Fully customizable keyboard shortcuts
- Built-in auto-updater via Sparkle

## Why TransPeek

- **~7 MB app size**: Pure Swift 6, only 4 dependencies. No Electron, no WebView.
- **~50 MB background memory**: Systematic memory leak prevention for long-running sessions.
- **Privacy-friendly**: Apple Translation runs entirely on-device.
- **Open source**: AGPL-3.0 licensed. Issues and feedback welcome.

## Limitations & Alternatives

TransPeek is a personal, **AI vibe-coded** side project. It works well for my own use cases, but it's not designed to be a polished, production-grade tool — there are plenty of edge cases in text selection and window handling that commercial tools have spent years ironing out, and TransPeek likely misses many of them.

If you need a more robust solution, these apps are excellent:

- **[Clicknow](https://clicknow.ai/)** — feature-rich, actively maintained selection translator
- **[PopClip](https://www.popclip.app/)** — the gold standard for macOS text selection actions, with a rich extension ecosystem

## Installation

Download the latest `.dmg` or `.zip` from [GitHub Releases](https://github.com/TranManhTuanLabs/TransPeek/releases) and drag `TransPeek.app` into `/Applications`.

## Usage

On first launch, TransPeek walks you through an onboarding flow to grant the required permissions:

- **Accessibility**: Needed to grab selected text via the Accessibility API
- **Screen Recording**: Needed for OCR screenshot translation

### Default Shortcuts

| Action | Shortcut |
|--------|----------|
| Smart Translation | Not set |
| Translate Selection | `⌥ D` |
| OCR Screenshot | `⌥ S` |
| Manual Input | `⌥ A` |
| Clipboard Translation | `⌥ V` |

All shortcuts can be customized in **Settings → General**. Smart Translation is opt-in and never changes existing shortcut bindings; assign it there if you want the unified fallback behavior.

### OpenClip Integration

Use [OpenClip](https://github.com/ganeshmshetty/openclip) to send selected text to TransPeek:

1. Install TransPeek and complete its initial setup.
2. Download [`TransPeek.openclipext.zip`](https://github.com/TranManhTuanLabs/TransPeek/releases/latest/download/TransPeek.openclipext.zip) from the latest release and unzip it.
3. Open `TransPeek.openclipext` with OpenClip and confirm the installation.
4. Select text and choose **TransPeek** in OpenClip. The translation appears in TransPeek using your configured services and target language.

### PopClip Integration

If you use [PopClip](https://www.popclip.app/), you can translate selected text with a single click from the PopClip bar.

**Install the extension:**

1. Make sure TransPeek is installed and running.
2. Download [`TransPeek.popclipext.zip`](https://github.com/TranManhTuanLabs/TransPeek/releases/latest/download/TransPeek.popclipext.zip) from the latest release and unzip it.
3. Remove the quarantine attribute so macOS allows the extension to load:
   ```bash
   xattr -dr com.apple.quarantine /path/to/TransPeek.popclipext
   ```
4. Double-click `TransPeek.popclipext` — PopClip will install it automatically.
5. Select any text in any app → click the **TransPeek** icon in the PopClip bar.

> **Note:** If PopClip shows an error, also make sure TransPeek.app itself has been un-quarantined — see the [FAQ below](#transpeekapp-is-damaged-and-cant-be-opened). ([Related issue](https://github.com/TranManhTuanLabs/TransPeek/issues/9#issuecomment-4167992729))

## FAQ

### "TransPeek.app is damaged and can't be opened"

The app is not notarized with Apple, so macOS Gatekeeper may block it. This does not mean the file is corrupted. To fix:

1. Open **Terminal**
2. Run:

```bash
sudo xattr -r -d com.apple.quarantine /Applications/TransPeek.app
```

Then launch the app as usual.

### Onboarding screen doesn't appear / want to re-trigger onboarding

Reset all user preferences to restore the first-launch state:

```bash
defaults delete com.tranmanhtuanlabs.transpeek
```

Then relaunch the app.

## Contributing

Issues and PRs are welcome! A few things to know:

- I work a day job, so I may not respond immediately — I typically batch-process issues and PRs on weekends.
- Feel free to fork and build your own version. Per the AGPL-3.0 license, derivative works **must also be open source**.

## Support

If this app is useful to you, buy me a coffee to keep improving it!

<img src="Resources/DonateQR.png" width="240" alt="Donate via VietQR" />

**BIDV — 2600786466 — TRAN MANH TUAN**

## Acknowledgements

TransPeek was inspired by [Easydict](https://github.com/tisfeng/Easydict) and [Bob](https://github.com/ripperhe/Bob). Thank you for paving the way.

Built with:

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus
- [Defaults](https://github.com/sindresorhus/Defaults) by Sindre Sorhus
- [Sparkle](https://sparkle-project.org/) for auto-updates
- [Textual](https://github.com/gonzalezreal/textual) for Markdown rendering

## Contributors

<a href="https://github.com/TranManhTuanLabs/TransPeek/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=TranManhTuanLabs/TransPeek" />
</a>

## Sponsor

<a href="https://afdian.com/a/cosyu"><img width="20%" src="https://pic1.afdiancdn.com/static/img/welcome/button-sponsorme.jpg" alt="Sponsor on Afdian"></a>

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=TranManhTuanLabs/TransPeek&type=date&legend=top-left)](https://www.star-history.com/#TranManhTuanLabs/TransPeek&type=date&legend=top-left)

## License

[AGPL-3.0](LICENSE)
