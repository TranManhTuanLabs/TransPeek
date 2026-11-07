# TransPeek PopClip Extension

Translate selected text instantly with [TransPeek](https://github.com/TranManhTuanLabs/TransPeek) via PopClip.

## Requirements

- [TransPeek](https://github.com/TranManhTuanLabs/TransPeek) v0.8.0 or later
- [PopClip](https://www.popclip.app/) (Mac App Store)
- macOS 14.0+

## Installation

1. Make sure TransPeek is installed and running.
2. Double-click `TransPeek.popclipext` to install the extension into PopClip.
3. Select any text — click the TransPeek icon in the PopClip bar to translate.

## Icon

Place your app icon (512×512 PNG) at `TransPeek.popclipext/icon.png`.
You can export it from `Assets.xcassets` in the Xcode project.

## How it works

The extension uses PopClip's URL action to call `transpeek://translate?text=<selected text>`.
TransPeek handles the URL scheme and shows the translation panel at the cursor.
