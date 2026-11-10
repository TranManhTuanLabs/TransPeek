# Self-Signed Certificate Guide — A to Z (TransPeek)

The complete guide to code signing for TransPeek: why signing exists at
all, how to create your own self-signed certificate from scratch (terminal
or Keychain Access GUI), how to sign the app on your Mac, how CI signs the
app on GitHub, and everything that went wrong while setting this up — so
the next person does not repeat it.

Audience: anyone building TransPeek from source, and any future maintainer
(or another AI) who has to touch signing. No prior knowledge of
certificates is assumed; every term is explained where it first appears.

Related docs:

- `docs/APP-SIGN-KEY-PERMISSIONS.md` — the shorter local-signing guide
  (create a certificate, sign the app, grant permissions, troubleshooting
  table). Start there if you only want to sign a downloaded build.
- `docs/GIT-CI-BUILD-SETUP.md` — git / CI / build setup and the
  intervention log (including the signing history).
- `docs/BUILD-TEST-WORKFLOW-GITHUB-CI.md` — the CI workflow in detail.

> **Status note (2026-11-10, 22:28 +07):** local signing with a
> self-signed certificate is DONE and verified working (build #71, signed
> on Manh's Mac — Accessibility + OCR both work). CI signing is NOT yet
> verified: the signing step exists in `.github/workflows/test.yml`, but
> every `[build-app]` run since it was added has died before reaching it
> — runs #85/#88 failed at the `.p12` import, runs #89/#90/#91 never got
> a macOS runner at all (GitHub capacity, 0 steps run). Two `.p12`
> directions are being tested (§7); neither has run yet. This guide
> marks every claim that is still unverified as **UNVERIFIED**.

---

## 1. Why sign at all

### 1.1 The problem: permissions disappear after every new build

TransPeek needs two macOS permissions to work:

- **Accessibility** — to see what text you selected and show the
  translate icon.
- **Screen Recording** — to capture a screenshot for OCR.

macOS stores these grants in the TCC database (TCC = Transparency,
Consent, and Control, the macOS privacy system). A grant is attached to
the app's **code-signing identity**, not just to its name or bundle ID.

An **unsigned** build has no certificate, so its identity is its
**cdhash** — the code directory hash, a hash of the app's code. Every
rebuild produces different code, so every rebuild produces a **new
cdhash**, so macOS treats it as a **different app**. The result, seen
many times in this project:

- You grant Accessibility for build #70.
- You download build #71. The toggle in System Settings still shows ON
  for the old entry — but the app says it has no permission, because the
  grant belongs to build #70's cdhash, not #71's.

Upstream MoePeek does not have this problem: its releases are signed
with a real Apple Developer ID, so the identity is stable across
releases.

### 1.2 The fix: a stable self-signed certificate

Signing the app with the **same certificate every time** makes its
identity "bundle ID + certificate" instead of "bundle ID + cdhash of
this one build". The certificate does not change across rebuilds, so the
identity does not change, so the permissions granted once keep working
for later builds. You only re-run one `codesign` command per new build;
you do not re-grant permissions.

A **self-signed certificate** is a certificate you create yourself, on
your own Mac, with no Apple involvement. It costs nothing and takes
minutes. It is enough for this purpose because its job is only to give
the app a **stable identity**.

### 1.3 What signing does NOT do (do not expect these)

- **Signing does NOT grant permissions.** Permissions still live in each
  machine's TCC database and must be granted once per machine, by the
  user, in System Settings. A signed app on a new machine still asks.
- **Signing does NOT bypass Gatekeeper.** A self-signed app is still
  blocked on first launch on another machine (right-click → Open, or
  `xattr -cr` to clear the quarantine flag). Only a Developer ID
  certificate ($99/year Apple Developer membership) **plus notarization**
  removes that.
- **Signing does NOT prove the app is really from you.** Anyone can make
  a self-signed certificate with any name. Real protection against
  impersonation needs a Developer ID issued by Apple.
- **Signing does NOT stop the app from being modified.** It only makes
  modification detectable (the signature breaks).

### 1.4 Words used in this guide

| Term | Meaning |
|---|---|
| **Certificate** | A small file that binds a name (e.g. `TransPeek Self-Signed 100Years`) to a public key, with an expiry date and usage rules. |
| **Private key** | The secret half of the key pair. Whoever has it can sign as that identity. Never share it, never commit it. |
| **Identity** | A certificate **plus** its private key, together. `codesign` and `security find-identity` only count a certificate as an identity when the private key is present in the same keychain. A certificate with no private key underneath it is useless for signing. |
| **`.p12` file** | One file holding a certificate + its private key, optionally protected by a password. It is how a certificate moves between machines (local Mac → GitHub secret). Also called PKCS#12. |
| **Fingerprint (thumbprint)** | A hash of the **certificate**. It identifies *which certificate* signed something. Example: `A8:02:6E:B5:…` (§6). |
| **cdhash** | A hash of the **app's code**. It identifies *which build* was signed. Different from the fingerprint — do not confuse them. |
| **Key Usage** | A certificate extension that says what the key may be used for. For code signing it must include `digitalSignature` (and `keyCertSign` for a self-signed root). Missing it is the single most common failure (§2.3). |
| **Extended Key Usage (EKU)** | A finer extension: `codeSigning` says this certificate is for signing code. |
| **Trust (Always Trust)** | A Keychain setting that tells macOS "this self-signed root is acceptable". Without it, macOS reports the certificate as "not trusted" and refuses to use it. |
| **Keychain** | macOS's store for certificates, keys and passwords. The `login` keychain is the normal place for a signing identity. CI creates a temporary keychain instead (§8). |
| **TCC** | Transparency, Consent, and Control — the macOS privacy system that stores Accessibility / Screen Recording grants. |

---

## 2. The certificate itself — what a working one looks like

### 2.1 Requirements (all of them, or macOS refuses the certificate)

A certificate usable for code signing must have:

1. **Basic Constraints: `CA:TRUE`** — it is a self-signed root
   (it vouches for itself; there is no higher authority).
2. **Key Usage: `digitalSignature` + `keyCertSign`**, marked critical.
   This is the one that is easy to get wrong: a first attempt that set
   only Extended Key Usage and omitted Key Usage was rejected with
   `Invalid Key Usage for policy` and
   `this identity cannot be used for signing code`.
3. **Extended Key Usage: `codeSigning`**.
4. **A private key** in the same keychain (otherwise it is not an
   identity at all).
5. **Trust set to Always Trust** in Keychain Access (otherwise macOS
   reports it as not trusted and `find-identity` shows 0 identities).

### 2.2 How to check a certificate you already have

```sh
# Show subject, issuer, validity dates, fingerprint:
openssl x509 -in transpeek-signing.crt -noout -subject -issuer -dates -fingerprint -sha256

# Show the extensions (the part that matters most):
openssl x509 -in transpeek-signing.crt -noout -text | grep -A 3 -E "Basic Constraints|Key Usage|Extended"

# Expected output:
#   X509v3 Basic Constraints: critical
#       CA:TRUE
#   X509v3 Key Usage: critical
#       Digital Signature, Certificate Sign
#   X509v3 Extended Key Usage:
#       Code Signing

# Check that macOS sees it as a usable signing identity:
security find-identity -v -p codesigning
# Expected: "1 valid identities found" with your certificate name and NO
# "(Invalid Key Usage for policy)" suffix.
```

### 2.3 Mistakes already made (so you do not repeat them)

| Mistake | Symptom | Lesson |
|---|---|---|
| Picked **S/MIME (Email)** as the certificate type in the GUI | `find-identity -p codesigning` shows 0 valid identities | The type must be **Code Signing**. A wrong-type certificate cannot be fixed — delete it and create a new one. |
| openssl certificate with only `extendedKeyUsage=codeSigning`, no Key Usage | `Invalid Key Usage for policy`; `this identity cannot be used for signing code` | Always set `keyUsage=critical,digitalSignature,keyCertSign`. |
| Certificate created but Trust left at default | "This root certificate is not trusted"; `find-identity` shows 0 identities | Set Trust → **Always Trust** (§3.3 / §4.3). |
| Two certificates with the same name (old failed attempt + new one) | `codesign` picks the wrong one; confusing expiry dates | Delete the old one first. Keep exactly one certificate per name. |
| Certificate with no private key under it | Not an identity; signing fails | Expand the triangle next to the certificate in Keychain Access — a key must be underneath. If not, recreate it. |

---

## 3. Method A — Create the certificate with openssl (terminal, recommended)

This is the exact method used to produce the working certificates. It
gives full control over the extensions, it is scriptable, and you can
redo it any time without depending on a file someone else made.

**Verified:** this method produced the real certificates in use
(§6). Every command below was actually run.

### 3.1 Create the private key + self-signed certificate (100 years)

```sh
# Replace "TransPeek Self-Signed 100Years" with any name you like — but keep
# the name stable afterwards: changing the name means creating a NEW
# certificate, which is a NEW identity, which means re-granting
# permissions on every machine once.
# -days 36500 = 100 years, so the certificate effectively never expires.
# -nodes = do not encrypt the private key with a password (the .key file
#   itself must still be kept secret and backed up — see §3.4).
openssl req -x509 -newkey rsa:2048 \
  -keyout transpeek-signing.key -out transpeek-signing.crt \
  -days 36500 -nodes -subj "/CN=TransPeek Self-Signed 100Years" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
  -addext "keyUsage=critical,digitalSignature,keyCertSign" \
  -addext "extendedKeyUsage=codeSigning"
```

This creates two files in the current directory:

- `transpeek-signing.key` — the private key. **Secret. Never commit it.**
- `transpeek-signing.crt` — the certificate. Safe to inspect, not secret
  by itself — but keep it with the key.

### 3.2 Bundle key + certificate into a `.p12`

The `.p12` is the portable form: one file holding certificate + private
key. Which exact `.p12` format to make is the open question in §7 —
macOS's `security import` is picky about it. The two candidate formats:

```sh
# Direction 1 — UNENCRYPTED .p12, no password (see §7.1):
openssl pkcs12 -export -legacy -keypbe NONE -certpbe NONE -nomaciter \
  -out transpeek-signing-nocrypt.p12 \
  -inkey transpeek-signing.key -in transpeek-signing.crt \
  -passout pass:

# Direction 2 — LEGACY .p12 WITH a password (see §7.2):
# <PASSWORD> is a password you choose and remember. It is NOT written
# down in this repo, in chat, or in memory — it lives in the local file
# signing/transpeek-signing-100years-password.txt (mode 600) and in the
# GitHub secret MACOS_CODESIGN_CERT_PASSWORD.
openssl pkcs12 -export -legacy -macalg sha1 \
  -out transpeek-signing-selfsigned-100years-legacy-pass2.p12 \
  -inkey transpeek-signing.key -in transpeek-signing.crt \
  -passout pass:<PASSWORD>
```

Do NOT use the OpenSSL 3.x default format for a `.p12` that macOS must
import:

```sh
# WRONG for macOS import — OpenSSL 3.x default (SHA-256 MAC + AES-256).
# macOS `security import` rejects it with "MAC verification failed".
openssl pkcs12 -export \
  -out transpeek-signing.p12 \
  -inkey transpeek-signing.key -in transpeek-signing.crt \
  -passout pass:
```

Verify the `.p12` before using it:

```sh
# Unencrypted .p12 — should print MAC: sha1, Iteration 1, then the bags:
openssl pkcs12 -info -in transpeek-signing-nocrypt.p12 -passin pass: -nokeys -nocerts -provider legacy -provider default

# Legacy .p12 with password — use its real password instead of pass::
openssl pkcs12 -info -in transpeek-signing-selfsigned-100years-legacy-pass2.p12 -passin pass:<PASSWORD> -nokeys -nocerts -provider legacy -provider default
# (The -provider legacy flags are needed because this VM's OpenSSL 3.0
# cannot read RC2-40 encryption without the legacy provider. That is a
# limitation of the VM's openssl, not a problem with the file.)
```

### 3.3 Import into your login keychain and set trust

```sh
# Import (replace the password with "" for the unencrypted .p12,
# or with the real password for the legacy one):
security import transpeek-signing-nocrypt.p12 -k ~/Library/Keychains/login.keychain-db -P "" -T /usr/bin/codesign
```

Or double-click the `.p12` in Finder → Keychain Access opens → choose
the **`login`** keychain → Add.

Then **set trust (required — skipping this is the most common failure)**:

1. In Keychain Access, double-click the certificate.
2. Expand the **Trust** section.
3. Set "When using this certificate:" to **Always Trust**.
4. Close the window and enter your Mac password to save.

Without this, the certificate shows "This root certificate is not
trusted" and `find-identity` reports 0 identities.

Verify:

```sh
security find-identity -v -p codesigning
# Expect: 1 valid identities found, your certificate name, no
# "(Invalid Key Usage for policy)" suffix.
```

### 3.4 Back up the certificate (do this now, not later)

Keep a safe backup of the `.p12` (and its password, if it has one)
somewhere only you can access. If you lose the certificate + private
key, you must create a new one — and because the identity changes, you
must re-grant Accessibility and Screen Recording for the newly signed
app on every machine. That is the real cost of losing it; it is
recoverable, not catastrophic.

**Never commit `.p12`, `.key`, or `.crt` private-key files to the repo.**
They are credentials. The repo holds no signing files — only this
documentation and the GitHub secret (§8.1).

---

## 4. Method B — Create the certificate in Keychain Access (GUI)

If you prefer not to use the terminal for the certificate itself. The
screens below are the Certificate Assistant's screens in order.

> **UNVERIFIED (2026-11-10):** the GUI path below is reconstructed from
> how Certificate Assistant works; the individual screens were NOT
> re-verified one by one in this session (there is no Mac with Keychain
> Access on this VM to check against). The openssl path (§3) is the
> verified one. If a screen on your Mac looks different, follow the
> screen's own labels — the values to enter are the same. Please correct
> this section after doing it once on a real Mac.

### 4.1 The short path (default validity, ~1 year)

1. In Keychain Access, click **`login`** in the left sidebar first, so
   the certificate lands in the login keychain.
2. Menu: Keychain Access → Certificate Assistant → Create a Certificate.
3. Name: `TransPeek Local` (or any stable name). Identity Type:
   **Self Signed Root**. Certificate Type: **Code Signing**.
4. Leave **"Let me override defaults" UNCHECKED** — the assistant
   creates the key pair with its defaults.
5. Create → Done.
6. Set trust to **Always Trust** as in §3.3, then verify with
   `security find-identity -v -p codesigning`.

This is the path in `docs/APP-SIGN-KEY-PERMISSIONS.md` Method 2. Its
certificate is valid for about a year (the assistant's default) — fine
for trying things out, but you will have to redo it when it expires.

### 4.2 The 100-year path (tick "Let me override defaults")

To get a 100-year certificate from the GUI, you **must** tick
**"Let me override defaults"** — that is the tick that unlocks the
extra screens. (This is the opposite of the short path above: no tick =
no control over validity or extensions.)

1. Steps 1–3 as above, but **TICK "Let me override defaults"**, then
   Continue.
2. **Certificate Information** screen: Serial Number — any number
   (e.g. `1`); **Validity Period (days): `36500`** (= 100 years). If the
   assistant refuses that number, enter the largest it accepts.
   Continue.
3. **Key Pair Information** screen: Key Size **2048 bits**, Algorithm
   **RSA**. Continue.
4. **Key Usage Extension** screen: tick **"Include Key Usage
   Extension"**, then tick **Digital Signature** and **Certificate
   Signing**. (These two together are the `digitalSignature,keyCertSign`
   from §2.1 — leaving them out is the mistake that makes macOS reject
   the certificate.) Continue.
5. **Extended Key Usage Extension** screen: tick **"Include Extended Key
   Usage Extension"**, then tick **Code Signing**. Continue.
6. **Basic Constraints Extension** screen: tick **"Include Basic
   Constraints Extension"**, then tick **"Use this certificate as a
   Certificate Authority"** (this is the `CA:TRUE` from §2.1). Continue.
7. **Subject Alternate Name Extension** screen: leave empty, Continue.
8. Choose the **login** keychain when asked where to store it, then
   Create → Done.
9. Set trust to **Always Trust** (§3.3) and verify with
   `security find-identity -v -p codesigning`.

### 4.3 GUI pitfalls (seen in practice)

- Picking **S/MIME (Email)** instead of **Code Signing** creates a
  certificate for signing email, not code. There is no way to fix that
  certificate — delete it and create a new one with the right type.
- **Duplicate names confuse everything.** If a previous failed attempt
  left a certificate with the same name, delete the old one first. Two
  certificates named `TransPeek Local` (e.g. one expiring 2027, one
  expiring 2036) make it hard to tell which identity `codesign` picks.
  Keep exactly one.
- A certificate with no private key underneath it (expand the triangle
  next to it in Keychain Access — there should be a key) is not an
  identity at all. Delete it and recreate it.

---

## 5. Sign the app on your Mac (local signing, every build)

After downloading a CI build (artifact `TransPeek-macOS`), unzip it and
put the app in `/Applications`, then sign it with your certificate:

```sh
codesign --force --deep --sign "TransPeek Self-Signed 100Years" /Applications/TransPeek.app
```

- Use the **exact certificate name** as shown in Keychain Access
  (whatever you named it in §3/§4 — `TransPeek Self-Signed 100Years` is the
  CI certificate's name; your own certificate may be named differently).
- The first time, macOS asks for permission to access the key — click
  **Always Allow**.
- On success it prints:
  `/Applications/TransPeek.app: replacing existing signature`.
- Verify:
  ```sh
  codesign --verify --verbose /Applications/TransPeek.app
  codesign -dv /Applications/TransPeek.app 2>&1 | grep -i authority
  # Authority should show your certificate name.
  ```
- **Repeat this one command for every new build you download.** The
  certificate stays the same, so permissions granted for the signed app
  carry over.

### 5.1 Grant permissions for the signed app

Do this once — and again only if you ever create a brand-new
certificate (a new identity means new grants):

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

If permissions still are not recognized after granting, check that you
are running the signed copy at `/Applications/TransPeek.app` (not an
older unsigned copy in Downloads), remove the entries once more with
**−**, re-add, and relaunch — do not just toggle the old entry.

### 5.2 Traps confirmed while debugging permissions

- `tccutil reset <service> <bundle-id>` does **not** clear entries for
  unsigned apps. Those entries are keyed by file path, while the reset
  looks them up by bundle ID, so it reports success and changes nothing.
  Remove stale entries with the **−** button in System Settings instead.
- `AXIsProcessTrusted()` can return a cached result inside a running
  process on recent macOS, so a grant may only be seen after a real
  relaunch. Use the in-app Relaunch button (or quit and reopen) after
  granting.
- Granting a permission while the app is running has no effect until
  quit + reopen.

---

## 6. The certificates used by this project (history)

| Certificate | Created | Valid | Fingerprint (SHA256) | Files | Status |
|---|---|---|---|---|---|
| `TransPeek Local` (1st) | 2026-11-08/09 | 10 years (to 2036) | `B1AB8710A7BB806ACCBD8C1D46217EBED1CEE05F` | `signing/transpeek-signing2.p12` | Replaced |
| `TransPeek Local 100Y` | 2026-11-09 22:00 | 9/11/2026 → 16/10/2126 (100 y) | `8C:02:CD:18:D7:FF:B8:C9:17:2B:5F:0E:45:1A:01:A4:01:D5:F1:78:B2:F1:7E:A3:CC:41:50:20:7D:BD:DD:AE` | `signing/transpeek-signing-100y.p12` (2595 bytes, OpenSSL 3.x default format) | Replaced — its `.p12` format is rejected by macOS import (§7) |
| `TransPeek Local 100Years` | 2026-11-10 | 10/11/2026 → 17/10/2126 (100 y, `-days 36500`) | `A8:02:6E:B5:A1:09:B2:EC:EE:0F:04:11:01:4F:9F:A8:F6:DD:BF:D9:94:3D:79:F1:F4:F1:61:16:F8:63:10:CC` | `signing/transpeek-signing-100years.crt` + `.key`; `.p12` variants in §7 | Replaced 2026-11-10 23:22 by the rename below — never signed a successful CI build |
| **`TransPeek Self-Signed 100Years`** (current) | 2026-11-10 23:22 | 10/11/2026 → 17/10/2126 (100 y, `-days 36500`) | `28:7A:3E:21:62:A8:44:1E:47:94:1F:27:0D:0A:B6:F4:A1:29:E7:3F:BD:77:CA:BC:5C:D6:DF:93:D6:47:E6:40` | `signing/transpeek-signing-selfsigned-100years.crt` + `.key`; `.p12` variants in §7 | **Current CI identity** — a NEW identity, so every machine must grant the two permissions once for apps signed with it |

Name history: "TransPeek Local 100Y" → "TransPeek Local 100Years"
on 2026-11-10 (because "100Y" was unclear as an abbreviation), then →
**"TransPeek Self-Signed 100Years"** on 2026-11-10 23:22 (because
"Local" was ambiguous and "Self-Signed" says exactly what the
certificate is — self-signed, not Apple-issued — following the
"Tinycast Self-Signed" pattern). A self-signed certificate's name is
free choice — there is no Apple standard for it; only Developer ID
names are imposed by Apple (`Developer ID Application: <team>
(<TEAMID>)`). The name is only a label; what matters is that the same
certificate signs every build.

What "Self-Signed" means in the name: the certificate was created
locally (with openssl, on a Mac). It is **self-signed, not issued by
Apple, and NOT a Developer ID** — Developer ID is a specific
Apple-issued certificate type that requires the $99/year Apple
Developer membership. Do not call this certificate a Developer ID;
that would imply Apple issued it, which it did not.

The old "TransPeek Local" (2036) certificate and the "100Y"
certificate are both superseded. Their `.p12` files are kept in the
local `signing/` directory for reference only — do not use them for new
signing.

---

## 7. The `.p12` problem — two directions, one open question

### 7.1 What happened

The CI signing step (added 2026-11-09, commit `414e364`) imports a
`.p12` on the runner with:

```sh
security import /tmp/TransPeek-signing.p12 -k /tmp/ci-signing.keychain-db -P "<password>" -T /usr/bin/codesign
```

Runs #85 (commit `946b046`) and #88 (commit `4d92dc2`) both failed at
that exact command after ~1 second:

```text
security: SecKeychainItemImport: MAC verification failed during PKCS12 import (wrong password?)
```

The `.p12` file itself was verified good: openssl on the VM reads it
fine, the base64 round-trips exactly, and the key matches the
certificate. The file and the secret are not corrupt. The conclusion,
checked against macOS documentation and web reports: **on recent macOS,
a `.p12` with an empty password cannot be imported** — the import
rejects it no matter how the file was made. The first fix attempt
(changing only the format to legacy, still no password) was therefore
**not enough** — run #88 proved that, failing identically to #85.

### 7.2 Direction 1 — unencrypted `.p12`, no password

```sh
openssl pkcs12 -export -legacy -keypbe NONE -certpbe NONE -nomaciter \
  -out transpeek-signing-selfsigned-100years-nocrypt.p12 \
  -inkey transpeek-signing-100years.key -in transpeek-signing-100years.crt \
  -passout pass:
# File: 2362 bytes, base64 3152 chars, MAC SHA-1 iteration 1, key bag
# unencrypted. Import with -P "".
```

Idea: if nothing is encrypted, there is no password to verify, so the
empty-password rejection should not apply. This is the simplest
direction — no password to remember, no password secret.

### 7.3 Direction 2 — legacy `.p12` WITH a password

```sh
openssl pkcs12 -export -legacy -macalg sha1 \
  -out transpeek-signing-selfsigned-100years-legacy-pass2.p12 \
  -inkey transpeek-signing-100years.key -in transpeek-signing-100years.crt \
  -passout pass:<PASSWORD>
# File: 2469 bytes, base64 3292 chars, MAC SHA-1 + RC2-40 + 3DES key bag.
# Import with -P "$MACOS_CODESIGN_CERT_PASSWORD".
```

Idea: the documented working recipe for recent macOS is
`-legacy -macalg sha1` **plus a non-empty password**. The password is
stored in two places only: the local file
`signing/transpeek-signing-100years-password.txt` (mode 600) and the
GitHub secret `MACOS_CODESIGN_CERT_PASSWORD`. It is **never** written in
chat, in memory, in docs, or in the repo.

### 7.4 Status: NEITHER direction has been tested yet (UNVERIFIED)

| Run | Commit | Direction | Result |
|---|---|---|---|
| #85 | `946b046` | Old 100Y `.p12`, OpenSSL 3.x default, no password | Failed at import (MAC verification failed) |
| #86 | `f54825e` | Legacy, no password | Failed at **tests** (flaky test), signing step never reached |
| #88 | `4d92dc2` | Legacy, no password (100Years cert) | Failed at import, same error as #85 |
| #89 | `05cf520` | Direction 1 (unencrypted) | **0 steps run** — no macOS runner (capacity), job cancelled after 15 min |
| #90 | `95d2ccd` | Direction 2 (legacy + password) | **0 steps run** — no macOS runner (capacity), job cancelled after 15 min |
| #91 | `8132d99` | Direction 1 (unencrypted) | **0 steps run** — no macOS runner (capacity), job cancelled after 15 min |

Runs #89/#90/#91 say **nothing** about either direction — the workflow
never executed. A capacity failure (job cancelled, 0 steps, annotation
"The job was not acquired by Runner of type hosted even after multiple
attempts") must never be read as a signing failure, and must never
trigger a direction switch. Only switch direction when a direction has
**actually run and failed at the Sign step**.

Next step (scheduled 2026-11-10 ~23:40 +07, cron
`transpeek-rerun-91-late-night`): re-run #91 (direction 1). If that
also dies of capacity, retry again 2026-11-11 08:00 +07 (US evening,
quieter). **After one direction works, update this section and
`docs/GIT-CI-BUILD-SETUP.md` §3–§4 with the verified winner, and delete
the losing `.p12` variant from the active path (keep the file, remove it
from the secret/workflow).**

### 7.5 How to tell which direction won (for the person checking the run)

Open the run → job `test` → step "Sign app with self-signed
certificate":

- **Green + artifact `TransPeek-macOS` exists** → that direction works.
  Download the artifact and test it on a Mac (§5.1: grant the two
  permissions once for the new identity, quit + reopen, check
  Accessibility + OCR, and check the updater starts without the
  "Unable to Check For Updates" error).
- **Red at `security import` with "MAC verification failed"** → that
  direction is dead; switch to the other one (update the secret +
  `test.yml` together — they must always match; a mismatched pair is
  exactly what happened for a few minutes on 2026-11-10 21:55, and it
  would have failed the run).
- **Cancelled with 0 steps** → capacity, not signing. Re-run and wait.
  Do not change anything.

---

## 8. CI signing on GitHub (how the runner signs the app)

### 8.1 The secret

Repo → Settings → Secrets and variables → Actions → Secrets:

- **`MACOS_CODESIGN_CERT_P12`** — base64 of the `.p12` file. Create it
  with:
  ```sh
  base64 -w0 transpeek-signing-selfsigned-100years-nocrypt.p12 > transpeek-signing-selfsigned-100years-nocrypt-b64.txt
  # Paste the ENTIRE single line (3152 chars for direction 1,
  # 3292 chars for direction 2) as the secret value.
  ```
- **`MACOS_CODESIGN_CERT_PASSWORD`** — only for direction 2. Created
  2026-11-10 21:44. If direction 1 wins, consider deleting this secret
  (not yet decided).

Only ONE `.p12` secret is active at a time, and it must match the
`test.yml` on `main` — secret and workflow are a pair. Always update
both together, in one change, and verify after: the secret's "Last
updated" time should be just after the workflow commit.

### 8.2 The workflow step (`.github/workflows/test.yml`)

The step runs only when the commit message contains `[build-app]`
(see `docs/GIT-CI-BUILD-SETUP.md` §3). In order, it:

1. Decodes the secret from base64 into `/tmp/TransPeek-signing.p12`.
2. Creates a **temporary keychain** `/tmp/ci-signing.keychain-db` with
   a throwaway password (`ci-signing-temp`) — a fresh runner has no
   login keychain with the certificate, so CI makes its own.
3. Unlocks the keychain and sets it as default.
4. Imports the `.p12` (`-P ""` for direction 1,
   `-P "$MACOS_CODESIGN_CERT_PASSWORD"` for direction 2) with
   `-T /usr/bin/codesign` (allows `codesign` to use the key without
   prompting).
5. Sets the key partition list (`security set-key-partition-list`) so
   `codesign` can use the key non-interactively.
6. Signs the app:
   ```sh
   codesign --force --deep --sign "TransPeek Self-Signed 100Years" build/Build/Products/Release/TransPeek.app
   ```
7. Verifies (`codesign --verify --verbose`) and deletes the temp
   `.p12`.

The step was added 2026-11-09 (commit `414e364`). It has **never run
successfully yet** — see §7.4.

### 8.3 The rest of the build (context)

Build app (Release, `CURRENT_PROJECT_VERSION` = GitHub run number, so
About shows "Build CI #\<run\>") → Sign app → Zip app (`ditto -c -k
--keepParent`) → Upload artifact `TransPeek-macOS` (7-day retention) →
Delete older app artifacts (keep only the newest) → Upload test results
(always). The Build app step also passes the Sparkle EdDSA public key
(`SPARKLE_ED_PUBLIC_KEY=11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo=`),
without which the built app has an empty `SUPublicEDKey` and Sparkle's
updater fails to start ("Unable to Check For Updates") — fixed in
commit `0048aa9`, also still untested pending a successful signed build.

### 8.4 Rotating the certificate (when you must create a new one)

1. Create the new certificate (§3 or §4) with a **new name** (or the
   same name after deleting the old one — but a new name avoids
   confusion).
2. Export the `.p12` in the winning format (§7).
3. Update the secret `MACOS_CODESIGN_CERT_P12` (and the password secret
   if direction 2).
4. Update `test.yml` if the identity name changed
   (`codesign --sign "<new name>"`).
5. Push a `[build-app]` commit and check the Sign step goes green.
6. Every machine must grant Accessibility + Screen Recording **once**
   for the new identity (a new certificate = a new identity).
7. Keep the old `.p12` backed up until the new one is verified working.

If you lose the certificate + private key, the same procedure applies —
there is no recovery of the old identity, only replacement. The cost is
one re-grant of permissions per machine.

---

## 9. Troubleshooting (signing)

| Symptom | Cause | Fix |
|---|---|---|
| `security find-identity -v` → `0 valid identities found` | Certificate not trusted, or no private key, or duplicate name | Set Trust → Always Trust; confirm a private key sits under the certificate in Keychain Access; delete duplicate same-name certificates |
| `find-identity -v -p codesigning` shows `(Invalid Key Usage for policy)` | Certificate lacks Key Usage `digitalSignature` | Recreate with `keyUsage=critical,digitalSignature,keyCertSign` (§3) or via GUI with type Code Signing (§4) |
| `codesign` → `this identity cannot be used for signing code` | Same as above | Same as above — the certificate itself is wrong, not the command |
| CI `security import` → `MAC verification failed during PKCS12 import (wrong password?)` | `.p12` format macOS rejects: OpenSSL 3.x default, or legacy with empty password | Use direction 1 (§7.2) or direction 2 (§7.3); verify the `.p12` with `openssl pkcs12 -info` first |
| CI job cancelled, 0 steps, "job was not acquired by Runner" | GitHub has no free macOS arm64 runner (capacity), NOT a signing failure | Re-run and wait (prefer off-peak US hours); do NOT change direction or code |
| App still says permissions are missing after granting | Grant is attached to a different (unsigned/older) binary | Run the signed `/Applications/TransPeek.app`; remove all TransPeek entries with **−**, re-add, quit + reopen |
| `tccutil reset … <bundle-id>` reports success but nothing changes | Reset looks up by bundle ID; unsigned-app entries are keyed by path | Use the **−** button in System Settings |
| Updater: "Unable to Check For Updates / updater failed to start" | Built app has no Sparkle EdDSA public key (and/or is unsigned) | Needs a `[build-app]` build with the key + CI signing (§8.3) — UNVERIFIED, pending a successful signed build |

---

## 10. History (signing timeline)

- **2026-11-08/09 — Root cause diagnosed.** Unsigned CI builds get a
  new TCC identity (cdhash) per build; upstream releases are
  Developer-ID signed. First GUI attempt picked S/MIME by mistake;
  first openssl certificate omitted Key Usage `digitalSignature` and
  was rejected; the working certificate was "not trusted" until Trust
  was set to Always Trust; a duplicate same-name certificate had to be
  removed. Signed build #71 verified working (Accessibility + OCR).
- **2026-11-09 22:00 — 100-year certificate "TransPeek Local 100Y"**
  created (fingerprint `8C:02:CD:18…`, valid to 16/10/2126), replacing
  the 10-year "TransPeek Local" (2036). Secret `MACOS_CODESIGN_CERT_P12`
  created from its base64 (3460 chars).
- **2026-11-09 22:46 — CI signing step added** to `test.yml` (commit
  `414e364`), after Build app, before Zip app, gated on `[build-app]`.
- **2026-11-10 — Run #85 fails at import** (`MAC verification failed`),
  first time the signing step ever ran. Run #86 fails at tests (flaky
  test, fixed in `56fef05` by polling up to 2 s instead of a fixed
  200 ms sleep). Run #88 fails at import identically to #85 — proving
  legacy-without-password is not enough.
- **2026-11-10 — Certificate renamed 100Y → 100Years** (commit
  `4d92dc2`, fingerprint `A8:02:6E:B5…`, valid 10/11/2026 →
  17/10/2126). Two `.p12` directions prepared from it (§7).
- **2026-11-10 21:00–22:22 — Direction testing blocked by capacity.**
  Direction 1 pushed (commit `05cf520`, run #89) → 0 steps, twice.
  Switched to direction 2 too quickly (commit `95d2ccd`, run #90) →
  Manh corrected: a capacity failure is not a signing failure, wait
  for a real test of direction 1 first. A revert task briefly left the
  secret and workflow mismatched (secret direction 1, workflow
  direction 2) — fixed within minutes (21:58), secret restored to
  direction 2. Run #90 → 0 steps. Direction 1 restored (commit
  `8132d99`, run #91) → 0 steps. **Rule learned: only switch direction
  when a direction has actually run and failed at the Sign step;
  capacity failures only ever mean re-run and wait.**
- **2026-11-10 22:28 — This guide written.** CI signing still
  unverified; re-run of #91 scheduled ~23:40 +07, with a follow-up
  2026-11-11 08:00 +07 if capacity fails again.
- **2026-11-10 23:22 — Certificate renamed to "TransPeek Self-Signed
  100Years".** Self-signed names are free choice (no Apple standard;
  only Developer ID names are imposed by Apple). New certificate,
  fingerprint SHA256
  `28:7A:3E:21:62:A8:44:1E:47:94:1F:27:0D:0A:B6:F4:A1:29:E7:3F:BD:77:CA:BC:5C:D6:DF:93:D6:47:E6:40`,
  valid 10/11/2026 → 17/10/2126; both `.p12` directions regenerated
  from it. The old "TransPeek Local 100Years" certificate never signed
  a successful CI build, so the rename costs no re-grant. Secret +
  `test.yml` updated together (direction 1) with a `[build-app]`
  commit; the re-run plan moves from run #91 to the new run.
