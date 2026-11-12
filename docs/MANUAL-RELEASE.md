# How Manh manually publishes a TransPeek release (upload by hand)

This is the **fallback** when the automatic Release workflow
(`.github/workflows/release.yml`) is not used. The normal path is still:
push the tag `v<version>`, let the Release workflow go green, review the
draft it creates, publish it. Use the steps below only when you want to
upload the release files yourself on the GitHub website.

The app itself is **already code-signed by CI** (self-signed certificate
"TransPeek Self-Signed 100Years") — nobody re-signs the app here. The
only key you need is the **Sparkle EdDSA private key**, which signs the
`appcast.xml` so the app trusts the update. That key is
`transpeek-sparkle-eddsa.key` (Muse sent you the file separately).

## 0. What you need

- A Mac with Terminal.
- The Sparkle EdDSA private key file (`transpeek-sparkle-eddsa.key`).
  **Keep it safe and never share it, never commit it to git, never paste
  it into chat or a doc.** Anyone with this key can sign a fake update
  for your app. Store it somewhere safe (for example a password manager
  or an encrypted disk). If it is ever lost or leaked, generate a new
  keypair and rotate the public key in `test.yml` *before* the release
  build (see `GIT-CI-BUILD-SETUP.md` §4). A release shipped with the old
  key cannot be verified with a new one.
- A green `[build-app]` Tests run on `main` carrying the version you want
  to release. The app's build number (`CFBundleVersion`) is the CI run
  number. For v0.1.1, that is the run number of the final green
  `[build-app]` run (for example run #144 → build 144).
- The Sparkle CLI tools (downloaded in §3, version 2.8.1 — the same
  version pinned in `Package.resolved`).
- Optional: Homebrew + `create-dmg`, only if you want a DMG file as well
  as the ZIP. The ZIP is the essential file (Sparkle downloads the ZIP);
  the DMG is a convenience for users who prefer it. You can skip the DMG
  and the PopClip/OpenClip extension zips — the release works with just
  the ZIP + `appcast.xml`.

## 1. Download the tested app and check it

1. GitHub → Actions → the green `[build-app]` run → download the
   `TransPeek-macOS-<run>` artifact (for example `TransPeek-macOS-144`).
2. Unzip it. Inside is `TransPeek.app`.
3. Check the app's version, build number, Sparkle public key and feed URL
   (the Mac has no `defaults` in the VM sense — read the plist with
   Python; on your Mac this works in Terminal):

   ```bash
   python3 -c "import plistlib; d=plistlib.load(open('TransPeek.app/Contents/Info.plist','rb')); print(d.get('CFBundleShortVersionString'), d.get('CFBundleVersion'), d.get('SUPublicEDKey'), d.get('SUFeedURL'))"
   # must print: 0.1.1 <run number> +aGGc4fF2j3XJ3maoDbbwh/MmxP7BqDBdRs4A/r8f2M= https://github.com/TranManhTuanLabs/TransPeek/releases/latest/download/appcast.xml
   ```

   The version must be the one you want to release (`0.1.1`), the build
   must equal the Tests run number, and the public key must be the
   current one above. If any of these is wrong, stop — do not release
   this app.
4. Also confirm `_CodeSignature/CodeResources` exists inside the app
   (the app is signed).

## 2. Make the release files

Work in a clean folder (for example `~/Desktop/transpeek-release/`).
Put the verified `TransPeek.app` there.

```bash
cd ~/Desktop/transpeek-release/
mkdir -p build/release

# The release ZIP (this is the file Sparkle downloads).
# Name it TransPeek-v<version>-macOS.zip, matching the Release workflow.
ditto -c -k --sequesterRsrc --keepParent TransPeek.app \
  "TransPeek-v0.1.1-macOS.zip"
cp "TransPeek-v0.1.1-macOS.zip" build/release/

# Optional: DMG (needs create-dmg; install with: brew install create-dmg).
# Skip this if you do not want a DMG — the ZIP alone is enough.
create-dmg \
  --volname "TransPeek" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 160 \
  --icon "TransPeek.app" 180 170 \
  --app-drop-link 480 170 \
  --hide-extension "TransPeek.app" \
  "TransPeek-v0.1.1-macOS.dmg" \
  .

# Optional: PopClip / OpenClip extension zips (from the repo).
# Skip these if you do not want them in this release.
ditto -c -k --sequesterRsrc --keepParent \
  PopClipExtension/TransPeek.popclipext "TransPeek.popclipext.zip"
ditto -c -k --sequesterRsrc --keepParent \
  OpenClipExtension/TransPeek.openclipext "TransPeek.openclipext.zip"
```

## 3. Download the Sparkle CLI tools (version 2.8.1)

```bash
mkdir -p /tmp/sparkle
curl -sL "https://github.com/sparkle-project/Sparkle/releases/download/2.8.1/Sparkle-2.8.1.tar.xz" \
  | tar xJ -C /tmp/sparkle
ls /tmp/sparkle/bin/generate_appcast   # must exist
```

## 4. Generate `appcast.xml` (signed with your EdDSA key)

`generate_appcast` reads the ZIP(s) in `build/release/`, signs each one
with your private key, and writes `appcast.xml` with the correct
download URL, file size, version, build number and EdDSA signature.
Download the existing appcast first so older releases stay in the file
(newest first) — users on older versions still see their update path.

```bash
cd ~/Desktop/transpeek-release/

# Download the existing appcast to preserve history
# (skip / ignore the error if this is the first release).
curl -sfL "https://github.com/TranManhTuanLabs/TransPeek/releases/latest/download/appcast.xml" \
  -o appcast.xml || rm -f appcast.xml

# Generate the new appcast. Replace the key path with where you stored
# transpeek-sparkle-eddsa.key.
# The download URL prefix must end with a slash and point at the
# release tag you are about to publish (v0.1.1).
/tmp/sparkle/bin/generate_appcast \
  --ed-key-file /path/to/transpeek-sparkle-eddsa.key \
  --download-url-prefix "https://github.com/TranManhTuanLabs/TransPeek/releases/download/v0.1.1/" \
  -o appcast.xml \
  build/release/
```

## 5. Check the appcast before publishing

```bash
# The XML must parse.
python3 -c "import xml.etree.ElementTree as ET; ET.parse('appcast.xml'); print('XML OK')"

# Open appcast.xml and check the newest <item>:
#   <title>TransPeek 0.1.1</title>
#   <sparkle:version> must be the build number (the Tests run number, e.g. 144)
#   <sparkle:shortVersionString> must be 0.1.1
#   <enclosure url="https://github.com/TranManhTuanLabs/TransPeek/releases/download/v0.1.1/TransPeek-v0.1.1-macOS.zip"
#     ... length="<the ZIP byte size>" sparkle:edSignature="<base64 signature>" />
#   <pubDate> in RFC 2822 UTC.
# The enclosure URL must match the file name you are about to upload,
# exactly — otherwise Sparkle downloads a 404.
ls -l "TransPeek-v0.1.1-macOS.zip" appcast.xml
```

If the version, build number or enclosure URL is wrong, fix the inputs
(§1–§4) and regenerate — do not hand-edit the signature.

## 6. Publish the GitHub Release (browser)

1. GitHub → Releases → "Draft a new release" → "Choose a tag": create
   `v0.1.1` from the release commit (the final `main` commit, the one
   the green `[build-app]` run tested).
   **Create the tag first.** A release created as a web draft does not
   create its tag until it is published; pushing the tag first makes
   sure the tag points at the right commit.
2. Title `TransPeek 0.1.1`, release notes describing the version.
3. Attach `TransPeek-v0.1.1-macOS.zip` + `appcast.xml` (and the DMG /
   extension zips if you made them).
4. **NOT draft, NOT prerelease** — so it becomes the Latest release and
   the `releases/latest/download/appcast.xml` feed URL serves your new
   file.
5. Publish.

## 7. Verify after publishing

- Feed: `https://github.com/TranManhTuanLabs/TransPeek/releases/latest/download/appcast.xml`
  → HTTP 200, byte-identical to the signed file you uploaded (`diff`).
- ZIP link: `https://github.com/TranManhTuanLabs/TransPeek/releases/download/v0.1.1/TransPeek-v0.1.1-macOS.zip`
  → HTTP 200, full byte count.
- Release API / Releases page: tag `v0.1.1`, `draft=false`,
  `prerelease=false`, and it is the Latest release.
- In the app: Settings → About → "Check for Updates..." should now
  report the new version (or, on the old build, Sparkle should offer
  the update).

## Notes

- **Never re-sign the app.** The app in the artifact is already signed
  by CI. Only the appcast is signed here (with the EdDSA key).
- **Do not hand-edit `appcast.xml` after `generate_appcast` writes it.**
  If something is wrong, fix the inputs and regenerate — the signature
  covers the ZIP, and a hand edit breaks the match.
- **Version/build rule:** `<sparkle:version>` is the build number (CI
  run number) and must be greater than the previous release's build
  (v0.1.0 was build 126). If it is not greater, Sparkle treats the new
  release as older and never offers it.
- If the Release workflow is green, prefer it over these manual steps —
  it does §1–§6 automatically and creates a draft for you to review
  before publishing. These manual steps are the fallback.

## History

- **2026-11-13 — manual release guide written for Manh** (Sparkle
  2.8.1, `generate_appcast`, EdDSA key file). Replaces the older
  openssl hand-signing method in `RELEASE-PROCESS.md` §3 for manual
  releases — `generate_appcast` is the same tool the Release workflow
  uses, so the manual and automatic paths now produce the same appcast.
