# How to publish a TransPeek release (manual steps)

A Release is a tag (e.g. `v0.1.0`) + a GitHub Release with the app ZIP +
`appcast.xml`. Only a real Release makes Sparkle ("Check for Updates")
notify users — the CI artifact alone never does (see
`GIT-CI-BUILD-SETUP.md` §3, "Artifact ≠ Release").

**Who does what:** Muse does every step below, on the VM and in the
browser. Manh does nothing — no Terminal, no signing on his Mac. He only
downloads the app from the Releases page afterwards (see §5).

## 0. Before you start

- **Version:** `MARKETING_VERSION` in `Project.swift` follows TransPeek's
  own SemVer line starting at 0.1.0 (patch for bug fixes, minor for new
  features, major 1.0.0 when the app is stable and feature-complete).
- **Green build:** a `[build-app]` run on main must be SUCCESS, carrying
  that version and the current Sparkle EdDSA public key. The app's build
  number (`CFBundleVersion`) is the CI run number (v0.1.0: run #126, app
  0.1.0 build 126).
- **EdDSA private key:** on the VM at
  `signing/transpeek-sparkle-eddsa.key` (mode 600). Never commit it, never
  paste it into chat or docs — back it up like the code-signing key. The
  matching public key is in `test.yml` (both build steps) and is public,
  safe to quote: `+aGGc4fF2j3XJ3maoDbbwh/MmxP7BqDBdRs4A/r8f2M=`.
- **If the private key is ever lost:** generate a new keypair and rotate
  the public key in `test.yml` *before* the release build (see
  `GIT-CI-BUILD-SETUP.md` §4, 2026-11-11 entry). A release shipped with
  the old key cannot be verified with a new one.

## 1. Download the CI artifact and check the app

1. GitHub → Actions → the green run → download the `TransPeek-macOS`
   artifact.
2. Verify size + SHA-256 against what GitHub reports for the artifact
   (v0.1.0: 14,279,201 bytes,
   SHA-256 `6f99850f4168f820cc2525774cacbb972a2d45018fe973aa243c8cd7c8e96548`).
3. Unzip and check the app inside (the VM has no macOS `defaults`, so
   read the plist with Python):
   ```bash
   python3 -c "import plistlib; d=plistlib.load(open('TransPeek.app/Contents/Info.plist','rb')); print(d.get('CFBundleShortVersionString'), d.get('CFBundleVersion'), d.get('SUPublicEDKey'), d.get('SUFeedURL'))"
   # must print: <version> <run number> <current EdDSA public key> https://github.com/TranManhTuanLabs/TransPeek/releases/latest/download/appcast.xml
   ```
   Also confirm `_CodeSignature/CodeResources` exists inside the app.
4. Re-zip the app as the release file users download:
   ```bash
   ditto -c -k --keepParent TransPeek.app TransPeek-<version>.zip
   ```
   (v0.1.0: `TransPeek-0.1.0.zip`, 14,408,228 bytes,
   SHA-256 `c5c2664a4c11a629721567c277b7cf65fa4b0635c28d6b6b3e30e4e5934da848`.)

## 2. Write `appcast.xml`

One `<item>` per release (keep older items in the file, newest first, so
users on older versions still see their update path). Fields that change
every release:

- `<title>TransPeek <version></title>`, link to the release tag page.
- `<sparkle:version>` = the build number (CI run number).
- `<sparkle:shortVersionString>` = the version.
- `<enclosure url="https://github.com/TranManhTuanLabs/TransPeek/releases/download/v<version>/TransPeek-<version>.zip" ... length="<zip byte size>" sparkle:edSignature="<base64 signature from §3>" />`
- `<pubDate>` in RFC 2822 UTC, e.g. `Tue, 11 Nov 2026 12:33:00 +0000`.

The v0.1.0 file (1,840 bytes) is the worked example: title, description
with the feature list, `sparkle:os="macos"`,
`type="application/octet-stream"`.

## 3. Sign the appcast (EdDSA) — this is NOT code signing

"Signing" here means two completely different things — this is the part
that causes confusion:

- **Code signing (ký app): already done.** CI signed the app at build
  time with the self-signed certificate "TransPeek Self-Signed
  100Years". Nobody re-signs the app. No Mac, no Terminal on Manh's
  side, no key or keychain needed.
- **Appcast signing: the only signing in this step.** It stamps the
  *appcast file* (via a signature of the ZIP) with the EdDSA private
  key, so the app trusts that the update is genuine and not a forged
  file. One command, on the VM:

```bash
openssl pkeyutl -sign -rawin \
  -inkey signing/transpeek-sparkle-eddsa.key \
  -in TransPeek-<version>.zip \
  -out TransPeek-<version>.zip.sig
base64 -w0 TransPeek-<version>.zip.sig   # paste this value into sparkle:edSignature
```

Verify before publishing (the signature is 64 raw bytes; the base64 in
`appcast.xml` must match `base64 -w0` output exactly, and the XML must
parse):

```bash
openssl pkey -in signing/transpeek-sparkle-eddsa.key -pubout -out /tmp/sparkle-eddsa.pub
openssl pkeyutl -verify -rawin -pubin -inkey /tmp/sparkle-eddsa.pub \
  -sigfile TransPeek-<version>.zip.sig -in TransPeek-<version>.zip
# must print: Signature Verified Successfully
python3 -c "import xml.etree.ElementTree as ET; ET.parse('appcast.xml'); print('XML OK')"
```

(v0.1.0: signature
`+cIy8hyxa8X69Tc5ZiTgq6OVhKSXWh4DPc9R2M3FgGqlP0OLrvB1cAdDy6o3KU6xhXu/IwahUSt99O6glUkyDw==`,
verified against the new public key.)

## 4. Publish the GitHub Release (browser)

1. Releases → "Draft a new release" → "Choose a tag": create
   `v<version>` from the release commit (v0.1.0: from `3a5acf1`).
2. Title `TransPeek <version>`, release notes describing the version.
3. Attach `TransPeek-<version>.zip` + `appcast.xml`.
4. **NOT draft, NOT prerelease** — so it becomes the Latest release
   and the `releases/latest/download/appcast.xml` feed URL works.
5. Publish.

Note: pushing a tag also triggers the `Release` workflow
(`.github/workflows/release.yml`). As of 2026-11-11 that workflow fails
at "Import signing certificate" (it expects P12 secrets that do not
exist on the repo) — the manually published release is **not** affected
by that failure. The workflow is being fixed to use the same PEM
signing as `test.yml`.

Verify after publishing, independently of the publish step:

- Feed: `https://github.com/TranManhTuanLabs/TransPeek/releases/latest/download/appcast.xml`
  → HTTP 200, byte-identical to the signed file (`diff`).
- ZIP link: `https://github.com/TranManhTuanLabs/TransPeek/releases/download/v<version>/TransPeek-<version>.zip`
  → HTTP 200, full byte count.
- Release API: tag `v<version>`, `draft=false`, `prerelease=false`.

## 5. What Manh needs to do

Nothing. Download the app from the Releases page and use it like any
previous build. First launch: right-click → Open, grant Accessibility +
Screen Recording once. Quit the old app before opening the new build, so
permissions attach to the newly signed build. From the next version on,
Sparkle "Check for Updates" reports the new version automatically,
because the feed now exists.

## 6. Next release checklist (short)

1. Bump `MARKETING_VERSION`, commit + push with `[build-app]` only when
   Manh says so.
2. Wait for the run to go green; note the run number (= build number).
3. Repeat §1–§4 with the new version/build numbers.
4. If the EdDSA key or the code-signing certificate ever changes,
   rotate first (see `GIT-CI-BUILD-SETUP.md` §4) and rebuild before
   releasing.

## History

- **v0.1.0 — 2026-11-11 19:34, first public release.**
  Run #126 (commit `d84f0ff`) SUCCESS, app 0.1.0 (build 126) + new EdDSA
  key. Release: https://github.com/TranManhTuanLabs/TransPeek/releases/tag/v0.1.0 —
  tag `v0.1.0` from `3a5acf1`, 2 assets (`TransPeek-0.1.0.zip`,
  14,408,228 bytes + `appcast.xml`, 1,840 bytes). Feed URL and ZIP link
  verified 200 with matching bytes.
