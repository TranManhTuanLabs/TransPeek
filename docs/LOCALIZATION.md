# Localization

How TransPeek handles UI languages, and how to add a new one.

## Current state

- **macOS:** `Resources/Localizable.xcstrings`, source language English.
  416 keys. Translations exist for English (source) and Chinese
  Simplified (`zh-Hans`, inherited from upstream MoePeek).
- **Windows:** `src/TransPeek/Strings/en-US/Resources.resw`, 105 keys,
  read through the `AppStrings.Get` helper (falls back to English).
  Add a language by adding one file:
  `Strings/<bcp47>/Resources.resw` (for example `Strings/vi/Resources.resw`).
  No code or XAML changes are needed.
- **Policy (decided 2026-11-11):** English is the default UI language.
  Add Vietnamese, then Chinese/Korean, only when the app is finalized,
  so translations are not redone after every UI change.

## How the macOS catalog was completed

Upstream's catalog (319 keys) was stale: strings added after the fork
(menubar, TTS, newer Settings screens) were never extracted, so they
could not be translated later.

On 2026-11-11 the catalog was completed without Xcode, by script
(`extract_keys2.py`, kept outside the repo):

1. Scanned `Sources/` for every localizable position: `Text`, `Button`,
   `Toggle`, `Picker`, `Label`, `Menu`, `Section`, `TextField`,
   `SecureField`, `.help`, `String(localized:)`, `LocalizedStringKey`,
   `.alert`, `.confirmationDialog`.
2. Derived the catalog key from each literal: Swift interpolations
   `\(...)` become `%@` placeholders, in order
   (for example `"Version \(appVersion) (\(buildNumber))"` becomes
   `"Version %@ (%@)"`, which already existed in the catalog).
3. Added every missing key as an empty `{}` entry — the same shape
   Xcode writes for an extracted-but-untranslated string.
   Existing keys were not touched.

Counts: 319 keys (upstream) → 331 (+12 English strings fixed in
commit `41e5124`) → 416 (+85 in this round).

Deliberately **excluded** as data, not UI text: URLs, API-key
placeholders (`sk-...`, DeepL key pattern), model IDs
(`claude-sonnet-4-5-...`), pure numbers (`4096`), durations
(`300ms`, `500ms`), and `e.g. ...` examples.

## Verify with Xcode when possible

The script derivation is mechanical, but it is not Xcode. The first
time a Mac with Xcode is available, run **Product → Export
Localizations** and compare: Xcode may find keys the script missed
(for example strings built dynamically) and will normalize any
`%@` key whose argument order the script got wrong. A wrong key is
harmless until then — at runtime it simply falls back to English.

## Adding a language (macOS)

1. Add the language to `Localizable.xcstrings` (in Xcode, or by
   editing the JSON: add a localization object per key).
2. Translate every key. Keys with empty `{}` localizations fall back
   to the English source text.
3. No code changes are needed for strings already in the catalog.
   Any new UI string added in code after this must also be added to
   the catalog, or it will stay English in other languages.
