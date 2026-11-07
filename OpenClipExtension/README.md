# TransPeek for OpenClip

Select text in [OpenClip](https://github.com/ganeshmshetty/openclip), then choose **TransPeek** to open the translation popup. Translation uses the services and target language configured in TransPeek.

## Install

1. Install TransPeek and OpenClip, and complete TransPeek's initial setup.
2. Download `TransPeek.openclipext.zip` from the [latest TransPeek release](https://github.com/TranManhTuanLabs/TransPeek/releases/latest) and unzip it.
3. Open `TransPeek.openclipext` with OpenClip and confirm the extension installation.
4. Select text and choose **TransPeek** from OpenClip's actions.

For a source checkout, open `OpenClipExtension/TransPeek.openclipext` with OpenClip.

The extension uses TransPeek's existing `transpeek://translate?text=…` URL entry point. OpenClip percent-encodes the selected text, including newlines and URL punctuation. It opens TransPeek's translation window; it does not replace the selected text or return the translation to OpenClip.
