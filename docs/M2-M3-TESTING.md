# TransPeek M2+M3 — Testing Notes (branch `m2-m3-tts-ocr`)

M2+M3 merged milestone (SPEC v0.1 §4.2–4.3, §3.3, §5). Built on branch
`m2-m3-tts-ocr` from main head `b7bad69`. **Do not merge to main until M1
passes its gate**; if M1 needs fixes, rebase this branch onto fixed main.

## What changed

- **TTS provider metadata** (`TTSProvider`): `needsNetwork`, `needsAPIKey`,
  `supportedLanguages`, `quality`, `status` — same shape as
  `TranslationProvider` / `OcrProvider`. Apple provider is now named
  **System (Apple TTS)** and stays the default + last-resort fallback.
- **Edge TTS** (`Sources/Services/TTS/EdgeTTSProvider.swift`): neural voices
  via the unofficial Edge Read Aloud WebSocket
  (`wss://speech.platform.bing.com/.../edge/v1`), free, no key, 400+ voices.
  Optional only, never the default. 30s watchdog; any failure throws a clear
  network error and the coordinator falls back.
- **Fallback chain** (`Sources/Core/TTSFallbackChain.swift`,
  `TTSCoordinator.speak`): chosen engine → EdgeTTS → System → dictionary
  audio (single word only, via free key-free dictionaryapi.dev) → clear error.
  Never fails silently. Stop cancels mid-chain without falling through.
- **Autoswitch** (`Sources/Services/TTS/TTSAutoswitch.swift`): voice follows
  `LanguageDetector` when Settings → Audio → "Autoswitch voice…" is on.
  **Develop feature, OFF by default** — short text is often mis-detected.
- **System voices for more languages**: Settings → Audio → "More languages
  (System)" lists every voice installed on the Mac (not hardcoded); EN/VI
  keep their own pickers.
- **Tesseract OCR** (`Sources/Core/OCR/TesseractOCRProvider.swift`,
  `OcrProviderRegistry.swift`): fallback-only engine behind `IOcrProvider`.
  Vision stays default. Engine = Homebrew `tesseract` CLI 5.5.x
  (`brew install tesseract tesseract-lang`); language files download on
  demand from `tessdata_best` into `~/Library/Application Support/TransPeek/tessdata/`
  (Settings → OCR → Download), never bundled. Capture flow:
  Vision → Tesseract (when enabled) → error; or Tesseract → Vision when
  Tesseract is picked first.

## Spike results (2026-11-07, Linux VM — no Mac, no Xcode)

- **Edge TTS endpoint: ALIVE, with caveats.**
  - `edge-tts` (official Python client) `--list-voices` works from this VM:
    full voice list returned, including `vi-VN-HoaiMyNeural`.
  - A bare REST fetch of the voices-list URL returns **401** without the
    client's full headers/token handling, and a plain-HTTPS POST to the
    synthesize endpoint hangs. The provider therefore uses the WebSocket
    protocol (like `edge-tts`), not REST.
  - Real synthesis could **not** be verified here: the `edge-tts` client's
    WebSocket connect fails in this sandbox with
    `SSL: WRONG_VERSION_NUMBER` (sandbox TLS proxy rejects the WS upgrade;
    plain HTTPS to the same host works). **Live synthesis stability is the
    #1 Mac test item below.**
- **Tesseract route: SwiftyTesseract REJECTED on evidence.**
  - Repo `SwiftyTesseract/SwiftyTesseract` is **archived** ("no longer
    maintained", author recommends Vision), 4.x pulls a ~219MB binary
    `libtesseract` xcframework, and has a known App Store Connect
    submission quirk (framework must be stripped post-build). It was NOT
    added as an SPM dependency. The provider uses the maintained Homebrew
    CLI instead; wiring SwiftyTesseract in later is a one-line
    `Package.swift` + `Project.swift` change if ever wanted.
  - dpScreenOCR was not ported (Qt, Windows+Linux only) — only its engine
    + on-demand language-download workflow was reused, per SPEC.
- **Not verified here (no Swift toolchain on this VM):** no `xcodebuild`,
  no `tuist generate`, no unit-test run. The Swift Testing suites below
  are pure logic and written to the same patterns as the existing
  `ProviderFallbackTests` / `VisionOCRProviderTests`, but they have never
  been compiled.

## New tests (Swift Testing, pure logic)

- `Tests/TTSFallbackChainTests.swift` — chain ordering / dedup / missing Edge.
- `Tests/TTSAutoswitchTests.swift` — effective language + EN fallback chain.
- `Tests/EdgeTTSProviderTests.swift` — voice resolution (EN/VI/accent/override),
  SSML escaping + rate formatting, audio-frame parsing, catalog coverage.
- `Tests/DictionaryAudioTests.swift` — single-word gate + audio-URL parsing.
- `Tests/OcrProviderRegistryTests.swift` — provider resolution + BCP 47 ↔
  Tesseract codes + `tessdata_best` download URLs + effective languages.

## Mac test checklist

Branch push alone does **not** run CI (`test.yml` triggers on push to main /
PR / `workflow_dispatch` only). Either run **Actions → Tests → Run workflow**
with branch `m2-m3-tts-ocr`, or open a draft PR to main.

```sh
git fetch origin && git checkout m2-m3-tts-ocr
tuist install && tuist generate
xcodebuild test -scheme MoePeek -destination 'platform=macOS'   # scheme/target still named MoePeek (M5 debt)
```

Live checks (all need a Mac; none were possible on the VM):

1. **EdgeTTS on:** Settings → Audio → TTS Service → Edge TTS → "Check
   connection", then Play Test with EN text and with VI text
   (`vi-VN-HoaiMyNeural`). Expect neural audio. Then turn Wi-Fi off (or
   pick a bad voice) and confirm speech still works via System fallback
   and the panel shows a clear error only when everything fails.
2. **EdgeTTS off / System default:** default path unchanged (System provider,
   EN/VI voice pickers, per-language rates).
3. **Autoswitch on:** enable Settings → Audio → "Autoswitch voice…", speak a
   Vietnamese sentence while language is English (and vice versa); confirm
   the voice switches. Then speak very short text ("ok", "ừ") — if the voice
   is wrong, that is the known develop limitation; leave the toggle OFF.
4. **Dictionary audio:** pick System provider, break Edge (offline), speak a
   single English word — expect a dictionary pronunciation clip; speak a
   phrase — expect a clear error, not silence.
5. **Tesseract fallback:** `brew install tesseract tesseract-lang`, then
   Settings → OCR → enable "Tesseract fallback", Download vie + eng.
   Screenshot-OCR the **same Vietnamese photo** with Vision (default) and
   with Tesseract picked as engine — compare accuracy, especially diacritics.
   If Vision already reads Vietnamese well, keep Tesseract as fallback only.
6. **OCR fallback path:** with Tesseract enabled, OCR an image Vision fails
   on (or temporarily pick Tesseract as engine) and confirm the other engine
   is tried before an error is shown.

## Known limitations / follow-ups (not M2+M3 scope)

- ElevenLabs, VieNeu-TTS, external-engine download button: M4.
- API keys still in per-provider Defaults, not Keychain: M1 debt, M5.
- Tuist target/scheme still named `MoePeek`: M5 (workflow files can't be
  edited via the GitHub connector — 403).
- Edge TTS `TrustedClientToken` is the public Edge client token; if Microsoft
  rotates it, synthesis will start failing and the token in
  `EdgeTTSProvider.trustedClientToken` is the first thing to refresh.
- `Sec-MS-GEC` header is not sent (the WS protocol works without it in
  current `edge-tts`-compatible clients); if Microsoft tightens the
  handshake, add token generation per the `edge-tts` client.
