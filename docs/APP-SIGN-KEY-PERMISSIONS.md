# Signing TransPeek locally (self-signed certificate)

> **Full A–Z guide:** `docs/SELF-SIGNED-CERTIFICATE-GUIDE.md` covers
> everything in this file plus the Keychain GUI 100-year path, the
> `.p12` format problem (two directions, §7), CI signing on GitHub, and
> the full history. This file stays as the shorter local-signing
> reference — read the guide when you need the why, the GUI steps, or
> the CI side.

This guide is for anyone building and testing TransPeek from source — the
maintainer and community contributors alike. It covers why local signing is
needed, how to create your own signing certificate from scratch (no
dependency on a file someone else made for you), how to sign the app, and
how to fix the problems that actually came up while setting this up.

> **Scope:** this is for local development and testing only. A self-signed
> certificate does **not** replace an Apple Developer ID for distribution:
> there is no notarization, and Gatekeeper will warn on other machines.
> A public release still needs a Developer ID ($99/year). Each contributor
> creates their **own** certificate on their own Mac — do not share `.p12`
> files between people. The certificate name (`TransPeek Local` below) is
> just a label; any name works, what matters is that it stays the same on
> your machine.
>
> **What "Self-Signed" means in the certificate name.** The certificate used by
> CI is named **`TransPeek Self-Signed 100Years`**. "Self-Signed" means the certificate
> was created locally (with openssl, on a Mac) — it is **self-signed**,
> not issued by Apple. It is **not** a Developer ID: Developer ID is a
> specific Apple-issued certificate type (it requires the $99/year Apple
> Developer membership), and this certificate is not one. Do not call it
> a Developer ID — that would imply Apple issued it, which it did not.
> "100Years" is the validity period (100 years, so it effectively never
> expires). The name is only a label for the identity; what matters is
> that the same certificate signs every build, so macOS keeps the
> permissions attached to it. (The name was "TransPeek Local 100Years"
> until 2026-11-10 23:22; "Local" was ambiguous, "Self-Signed" says
> exactly what it is — same pattern as "Tinycast Self-Signed".)

## Why sign locally at all

macOS ties Accessibility and Screen Recording permissions to the app's
code-signing identity (TCC — Transparency, Consent, and Control).

- **Unsigned CI builds get a new identity on every rebuild.** An unsigned
  (ad-hoc) build's identity is its per-build code hash (cdhash). Every
  rebuild produces a new hash, so macOS treats it as a different app: a
  permission granted for build #70 does not apply to build #71, even
  though the toggle in System Settings still shows ON for the old entry.
  This is the root cause of "I granted permission but the app still says
  it has none" after every new build.
- **Upstream MoePeek does not have this problem** because its releases are
  signed with a real Apple Developer ID, so the identity is stable across
  releases. TransPeek CI builds are unsigned (`CODE_SIGNING_ALLOWED=NO`),
  so they hit the problem on every build.
- **A stable self-signed certificate fixes it for free.** Once the app is
  signed with the same certificate, its identity becomes
  bundle ID + certificate, which does not change across rebuilds. Grant the
  permissions once for the signed app and they keep working for later
  builds — you only re-run the one `codesign` command per new build, you
  do not re-grant permissions.
- **Without signing**, every new build needs its permissions granted again
  from scratch (remove the old entries, re-add the app, toggle on).

Related traps confirmed while debugging this (so you do not waste time on
them):

- `tccutil reset <service> <bundle-id>` does **not** clear entries for
  unsigned apps. Those entries are keyed by file path, while the reset
  looks them up by bundle ID, so it reports success and changes nothing.
  Remove stale entries with the **−** button in System Settings instead.
- `AXIsProcessTrusted()` can return a cached result inside a running
  process on recent macOS, so a grant may only be seen after a real
  relaunch. Use the in-app Relaunch button (or quit and reopen) after
  granting.

## Method 1 — Create the certificate yourself with openssl (recommended)

This is the exact method used to produce the working certificate. It gives
you full control over the extensions, and you can redo it any time without
depending on a file someone else made.

### The one detail that matters most: Key Usage

The certificate **must** have all three of these, or macOS refuses to use
it for code signing:

- Basic Constraints: `CA:TRUE` (it is a self-signed root)
- **Key Usage: `digitalSignature`** (plus `keyCertSign` for a root) —
  this is the one that is easy to get wrong. A first attempt that set only
  `extendedKeyUsage=codeSigning` and omitted Key Usage was rejected with
  `Invalid Key Usage for policy` and
  `this identity cannot be used for signing code`.
- Extended Key Usage: `codeSigning`

### Commands

```sh
# 1. Create the private key + self-signed certificate (10-year validity).
#    Replace "TransPeek Local" with any name you like; keep it stable.
openssl req -x509 -newkey rsa:2048 \
  -keyout transpeek-signing.key -out transpeek-signing.crt \
  -days 3650 -nodes -subj "/CN=TransPeek Local" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
  -addext "keyUsage=critical,digitalSignature,keyCertSign" \
  -addext "extendedKeyUsage=codeSigning"

# 2. Bundle key + certificate into a .p12 for import (no password, for
#    easy import; use -passout pass:YOURPASSWORD instead if you prefer one,
#    and remember it — you will need it at import time).
openssl pkcs12 -export \
  -out transpeek-signing.p12 \
  -inkey transpeek-signing.key -in transpeek-signing.crt \
  -passout pass:

# 3. Confirm the extensions are right before importing.
openssl x509 -in transpeek-signing.crt -noout -text | grep -A 2 -E "Key Usage|Extended|Basic Constraints"
#    Expect: CA:TRUE, Key Usage "Digital Signature, Certificate Sign",
#    Extended Key Usage "Code Signing".
```

### Import and trust

1. Double-click `transpeek-signing.p12` → Keychain Access opens → choose
   the **`login`** keychain → Add.
2. **Set trust (required — skipping this is the most common failure).**
   Double-click the certificate → expand the **Trust** section → set
   "When using this certificate:" to **Always Trust** → close the window
   and enter your Mac password to save. Without this, the certificate
   shows "This root certificate is not trusted" and `find-identity`
   reports 0 identities.
3. Verify:
   ```sh
   security find-identity -v -p codesigning
   ```
   Expect one line, `1 valid identities found`, with your certificate
   name and **no** `(Invalid Key Usage for policy)` suffix.

### Back up the .p12

Keep a safe backup of `transpeek-signing.p12` (and its password, if you
set one) somewhere only you can access. If you lose the certificate +
private key, you must create a new one — and because the identity changes,
you must re-grant Accessibility and Screen Recording for the newly
signed app. **Never commit the `.p12`, `.key`, or `.crt` private key to
the repo** — they are credentials.

## Method 2 — Create the certificate in Keychain Access (GUI)

If you prefer not to use the terminal for the certificate itself:

1. In Keychain Access, click **`login`** in the left sidebar first, so the
   certificate lands in the login keychain.
2. Menu: Keychain Access → Certificate Assistant → Create a Certificate.
3. Name: `TransPeek Local` (or any stable name). Identity Type:
   **Self Signed Root**. Certificate Type: **Code Signing**.
4. **Do not tick "Let me override defaults"** — leave it unchecked so the
   assistant creates the key pair with the correct defaults.
5. Create → Done.
6. Set trust to **Always Trust** as in Method 1, step 2, then verify with
   `security find-identity -v -p codesigning`.

Pitfalls seen in practice:

- Picking **S/MIME (Email)** instead of **Code Signing** creates a
  certificate for signing email, not code. `find-identity -p codesigning`
  will report 0 valid identities and there is no way to fix that
  certificate — delete it and create a new one with the right type.
- **Duplicate names confuse everything.** If a previous failed attempt
  left a certificate with the same name, delete the old one first. Two
  certificates named `TransPeek Local` (e.g. one expiring 2027, one
  expiring 2036) make it hard to tell which identity `codesign` will
  pick. Keep exactly one.
- A certificate with no private key underneath it (expand the triangle
  next to it in Keychain Access — there should be a key) is not an
  identity at all. Delete it and recreate it.

## Sign the app

After downloading a CI build (artifact `TransPeek-macOS`), unzip it and
put the app in `/Applications`, then sign it with your certificate:

```sh
codesign --force --deep --sign "TransPeek Local" /Applications/TransPeek.app
```

- The first time, macOS asks for permission to access the key — click
  **Always Allow**.
- On success it prints:
  `/Applications/TransPeek.app: replacing existing signature`.
- Verify:
  ```sh
  codesign --verify --verbose /Applications/TransPeek.app
  codesign -dv /Applications/TransPeek.app 2>&1 | grep -i authority
  # Authority should show TransPeek Local.
  ```
- Repeat this one command for every new build you download. The
  certificate stays the same, so permissions granted for the signed app
  carry over.

## Grant permissions for the signed app

Do this once (and again only if you ever create a brand-new certificate):

1. Quit TransPeek completely.
2. System Settings → Privacy & Security → **Accessibility**: click **−**
   to remove **every** TransPeek entry (including old ones), then **+**,
   select `/Applications/TransPeek.app`, toggle it ON.
3. **Screen Recording** (needed for OCR): in the app, use its
   "Open Settings" button for Screen Recording (it registers the app in
   the list first), then toggle it ON in System Settings.
4. Reopen TransPeek and select some text — the translate icon must
   appear. For OCR, use the capture shortcut and confirm text is
   recognized.

If permissions still are not recognized after granting, check that you are
running the signed copy at `/Applications/TransPeek.app` (not an older
unsigned copy in Downloads), remove the entries once more with **−**,
re-add, and relaunch — do not just toggle the old entry.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `security find-identity -v` → `0 valid identities found` | Certificate is not trusted, or it has no private key, or a duplicate name is confusing the lookup | Set Trust → Always Trust on the certificate; confirm a private key sits under it in Keychain Access; delete duplicate same-name certificates |
| `find-identity -v -p codesigning` shows the identity with `(Invalid Key Usage for policy)` | Certificate lacks Key Usage `digitalSignature` | Recreate the certificate with `keyUsage=critical,digitalSignature,keyCertSign` (Method 1) or via the GUI with type Code Signing (Method 2) |
| `codesign` → `this identity cannot be used for signing code` | Same as above | Same as above — the certificate itself is wrong, not the command |
| App still says permissions are missing after granting | Grant is attached to a different (unsigned/older) binary | Make sure the running app is the signed `/Applications/TransPeek.app`; remove all TransPeek entries with **−**, re-add, relaunch |
| `tccutil reset … <bundle-id>` reports success but nothing changes | Reset looks up by bundle ID; unsigned-app entries are keyed by path | Use the **−** button in System Settings to remove entries |

## History

- 2026-11-08/09: diagnosed the root cause (unsigned CI builds get a new
  TCC identity per build; upstream releases are Developer-ID signed).
  First GUI attempt picked S/MIME by mistake; first openssl certificate
  omitted Key Usage `digitalSignature` and was rejected; the working
  certificate was also initially "not trusted" until Trust was set to
  Always Trust, and a duplicate same-name certificate had to be removed.
  The signed build #71 was verified working (Accessibility + OCR).
- 2026-11-09/10: CI signing added (`.github/workflows/test.yml`, step
  "Sign app with self-signed certificate"). The `.p12` lives in the GitHub
  secret `MACOS_CODESIGN_CERT_P12`. The first `.p12` (OpenSSL 3.x default
  format, SHA-256 MAC + AES-256) was rejected by macOS `security import`
  with "MAC verification failed" (run #85). **Correction (2026-11-10,
  learned from run #88): switching only the format to legacy, still
  with an empty password, is NOT enough** — run #88 failed at import
  identically to #85. On recent macOS a `.p12` with an empty password
  cannot be imported at all. Two directions are now being tested (see
  `docs/SELF-SIGNED-CERTIFICATE-GUIDE.md` §7): direction 1, an
  unencrypted `.p12` (`-legacy -keypbe NONE -certpbe NONE`, no password),
  and direction 2, a legacy `.p12` with a non-empty password
  (`-legacy -macalg sha1`, secret `MACOS_CODESIGN_CERT_PASSWORD`).
  **Neither has been tested yet** — runs #89 (direction 1), #90
  (direction 2) and #91 (direction 1) all died with 0 steps run because
  GitHub had no free macOS runner (capacity). The certificate
  was renamed from "TransPeek Local 100Y" to **"TransPeek Self-Signed 100Years"**
  (2026-11-10) because "100Y" was unclear; fingerprint SHA256
  `A8:02:6E:B5:A1:09:B2:EC:EE:0F:04:11:01:4F:9F:A8:F6:DD:BF:D9:94:3D:79:F1:F4:F1:61:16:F8:63:10:CC`,
  valid 10/11/2026 → 17/10/2126. A new identity means every machine must
  grant the two permissions once for the newly signed app.
