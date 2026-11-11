# Git, CI Test & Build Workflow Setup (TransPeek)

The complete setup and configuration of git, the CI test workflow, and the
app build workflow for this repo — plus the history of what was changed and
why, so a future maintainer (or another AI entering this repo) can
investigate a red run, fix a failure, or change the setup without
rediscovering everything.

Related docs:

- `docs/SELF-SIGNED-CERTIFICATE-GUIDE.md` — the A–Z signing guide (why
  signing, certificate anatomy, openssl + Keychain GUI methods, local
  signing, CI signing, the two `.p12` directions).
- `docs/BUILD-TEST-WORKFLOW-GITHUB-CI.md` — the CI workflow in detail (how
  to read a red run, caching, Swift/API gotchas).
- `docs/APP-SIGN-KEY-PERMISSIONS.md` — code signing and macOS permissions
  (why signing matters, how to create the certificate).
- `docs/SPEC-v0.1.md` — product spec.

## 1. Git setup

### Repo

- GitHub: `TranManhTuanLabs/TransPeek` (public).
- Default branch: `main`. Feature branch: `m2-m3-tts-ocr` (M2 TTS + M3
  Tesseract, not merged — see §5).
- Local clones:
  - Manh's Mac (primary): `/Users/manhtuan/Documents/AI-Agent-Workspace/AI_Workspace`
    (the workspace root; the TransPeek checkout lives under it).
  - This VM: `~/workspace/projects/moepeek-translator/transpeek/` (main
    checkout; sync with `git fetch origin` + `git reset --hard origin/main`
    before starting work).

### Authentication

- Manh's Mac: SSH with an ed25519 key. Verify with
  `ssh -T git@github.com` — it must print `Hi TranManhTuanLabs`. SSH is
  preferred over HTTPS.
- Commit author follows the machine's username/hostname (no forced author).
  On the VM the git config user is `Muse <muse@local>`; the VM has no SSH
  key authorised to push this repo, so pushes from the VM go through the
  GitHub connector (see below).
- The Muse GitHub App (connector) does NOT have Workflows permission: any
  call touching `.github/workflows/*` returns 403. Stop after the first
  403; do not retry the same call. Edit workflow files from Manh's Mac,
  or through the GitHub web editor (browser session) when Manh has
  explicitly allowed it.

### How pushes are done (and the rules)

- **Push related files in ONE commit.** Prepare everything locally first
  (all files written, diff re-read, names/parameters checked consistent),
  then push the whole change as one commit. Never push related files
  one-by-one through the browser web editor — each web edit is 1 commit,
  so the repo passes through intermediate states where the code does not
  fit together and CI goes red mid-batch.
- Push routes: (a) connector snapshot push (`push-files` with a paths
  file) — creates/edits UTF-8 text files only, cannot delete, rename, or
  push binary; (b) local git from Manh's Mac (SSH). Deleting a file needs
  a separate `delete_file` call (or `git rm` locally).
- Approval cards for connector pushes expire after 30 minutes. An
  expired/denied card only blocks that push — the code is not lost;
  re-push and a new card appears.
- **Branch strategy:** feature work on a branch, `main` stays clean and
  green. Before merging a branch into `main`, sync `main` INTO the branch
  first (merge main → branch), resolve conflicts ON the branch, rework the
  feature to the new main structure, get CI green on the branch, THEN
  merge via PR. Never merge a stale branch straight into main — it can
  downgrade or lose main's newer code.
- **"Foundation first, branch second":** if CI is red on both `main` and
  a branch, fix `main` FIRST.
- **Gate (milestone flow):** work locally → push one batch → CI green →
  Manh tests live on his Mac → ok / reports bugs → fix → only then move
  to the next milestone.
- **Commit message marker `[build-app]`:** the app artifact is only built
  when the commit message contains `[build-app]` (see §3). Only put
  `[build-app]` in a commit when Manh explicitly says "build-app". Do not
  decide it yourself, even if the change is visible in the app.

## 2. CI test workflow (`test.yml`)

### At a glance

- File: `.github/workflows/test.yml`. Runner: `macos-26`. One job
  (`test`), timeout 20 min.
- Triggers: push to `main`, PRs to `main`, `workflow_dispatch`.
- `paths-ignore`: `docs/**` and `**.md` (both push and PR) — a docs-only
  push runs NO CI at all.
- Concurrency group
  `tests-${{ github.event.pull_request.number || github.ref }}` with
  `cancel-in-progress: true` — a new push cancels the run still going.
  (This is why run #80 was Cancelled: run #81 superseded it.)
- Permissions: `contents: read`, `actions: write` (needed to delete old
  artifacts).
- Steps: Checkout → Cache mise tools (Tuist) → Install Tuist via mise →
  Cache SPM artifacts → Resolve dependencies + generate project (retries
  3 times, 30 s apart) → Install xcbeautify → Run tests → Build app
  (only `[build-app]`) → Sign app (only `[build-app]`) → Zip app (only
  `[build-app]`) → Upload app artifact (only `[build-app]`) → Delete older
  app artifacts (only `[build-app]`) → Upload test results (always).

### How tests run

- `xcodebuild test -workspace TransPeek.xcworkspace -scheme TransPeek
  -destination 'platform=macOS' -resultBundlePath build/Tests.xcresult
  ... CODE_SIGNING_ALLOWED=NO | xcbeautify`, with `set -o pipefail` so a
  failing `xcodebuild` still fails the step.
- The test bundle is uploaded as artifact `macOS-test-results` (14-day
  retention). The `.xcresult` is the source of truth for per-test detail.
- **Log policy: never errors-only.** A failing test shows as `recorded an
  issue` + a summary (`Test run with N tests ... failed with M issues`,
  `Failing tests:`), not as an `error:` line. Filtering to errors-only
  hides it. Keep the full log via xcbeautify (it drops the thousands of
  `SwiftCompile` lines so the log loads fast, but keeps test results).

### Diagnostics: what reaches the CI log and what does NOT

- **xcbeautify strips Swift Testing `#expect` messages** from the log. A
  red run shows only "Recorded an issue" — it does not say WHICH
  assertion failed.
- **xcbeautify also drops the result lines of parameterized Swift Testing
  tests** (e.g. the 12 cases of `longTextLayoutSettles` never appear as
  result lines in the log). The suite total time is the only indirect
  evidence they ran.
- **`print` (stdout) inside a Swift Testing test does NOT reach the
  console log** — it is captured into the `.xcresult`.
- **`FileHandle.standardError.write` (stderr) ALSO does NOT reach the
  console log** (verified in run #82) — `xcodebuild` captures the test
  process's stderr into the `.xcresult` too.
- **Consequence:** when a test goes red, the values that explain WHY are
  only in the uploaded `macOS-test-results` (`.xcresult`) artifact —
  download it and inspect the test's recorded issues there. Do not add
  more `print`/stderr diagnostics expecting them to show in the log.

### Caching (rule: keep caches under ~80 MB)

- SPM artifacts only (`~/Library/Caches/org.swift.swiftpm/artifacts`),
  key by `Package.resolved`, `-v2` suffix. (~9.9 MB.)
- mise tools only (`~/.local/share/mise/installs`), key by `.mise.toml` +
  `.tuist-version`, `-v2` suffix. (~54.2 MB.)
- Both were narrowed from the whole directories (SPM was ~143 MB, mise
  ~94 MB in run #53).

### GitHub limits and queue behaviour

- This repo is **public**, so GitHub Actions is **free and unlimited** —
  there is no monthly limit on the number of CI runs, and no per-run
  minute cap that matters here. (For private repos the free plan is
  2,000 min/month; that does not apply.)
- Real limits: one job max 6 hours (we set 20 min), max 20 concurrent
  jobs, 500 MB free artifact storage (we manage it by keeping only the
  newest app artifact + 7-day retention).
- **macOS runner capacity:** GitHub sometimes has no free macOS arm64
  runner, and a run can sit Queued for a long time. Run #81 was Queued
  for 26 minutes; GitHub shows the notice "Due to capacity constraints,
  jobs targeting macOS arm64 runners may experience longer queue times."
  A long queue is a capacity problem, NOT a failure and NOT a usage
  limit. Do not "fix" the code for a queued run — wait, or re-check later.
  Since 2026-11-10 the failure mode got worse: if no runner picks the
  job up within ~15 minutes, GitHub **cancels** it (0 steps run,
  annotation "The job was not acquired by Runner of type hosted even
  after multiple attempts" + "Internal server error"). Runs #89, #90
  and #91 all died this way. A cancelled-with-0-steps run says nothing
  about the code or the signing direction — re-run it (prefer off-peak
  US hours: late night VN is still US business hours; 08:00 +07 VN is
  US evening and quieter) and wait. Never switch direction on a
  capacity failure — only on a real failure at the step itself.

## 3. Build workflow (app artifact + CI signing)

### Build steps (all gated on `[build-app]`)

- **Build app:** `xcodebuild build ... -configuration Release
  -derivedDataPath build ... CURRENT_PROJECT_VERSION=${{ github.run_number }}
  CODE_SIGNING_ALLOWED=NO
  SPARKLE_ED_PUBLIC_KEY=+aGGc4fF2j3XJ3maoDbbwh/MmxP7BqDBdRs4A/r8f2M=`.
  The run number becomes the build number shown in About as "Build CI #<run>"
  (hidden when it is "1"). The EdDSA public key is passed here (it is a
  public key, so it is safe to hardcode in the workflow, same as the "Run
  tests" step) — without it the built app has an empty `SUPublicEDKey` and
  Sparkle's updater fails to start (see §4, 2026-11-10).
- **Sign app with self-signed certificate** (added 2026-11-09, commit
  `414e364`; PEM format since 2026-11-11, commit `48069b7`): decodes the
  secrets `MACOS_CODESIGN_CERT_PEM` + `MACOS_CODESIGN_KEY_PEM` (base64 of
  the PEM certificate and private key) to temp files → checks both
  against their known SHA-256 hashes → creates a temporary keychain →
  imports the certificate, then the key → signs the app with identity
  `TransPeek Self-Signed 100Years` (`codesign --force --deep --sign`) →
  verifies (`codesign --verify --verbose`) → deletes the temp files.
  Runs after Build app, before Zip app. **Verified working: run #99
  (2026-11-11).** Full A–Z guide (why, the five signing attempts, the
  winner): `docs/SELF-SIGNED-CERTIFICATE-GUIDE.md` §7.
- **Zip app:** `ditto -c -k --keepParent` (keeps the `.app` bundle;
  `upload-artifact` with a directory path would lose the directory
  itself).
- **Upload app:** artifact `TransPeek-macOS`, 7-day retention.
- **Delete older app artifacts:** keeps only the newest `TransPeek-macOS`
  artifact (older links die). `continue-on-error: true`.
- **Upload test results:** always runs, artifact `macOS-test-results`,
  14-day retention.

### CI signing — the secret and the certificate

- Secrets (repo Settings → Secrets and variables → Actions → Secrets):
  `MACOS_CODESIGN_CERT_PEM` (base64 of the PEM certificate, 1640 chars)
  and `MACOS_CODESIGN_KEY_PEM` (base64 of the PEM private key, 2272
  chars). The secrets and the `test.yml` on `main` are a set — always
  update them together. No longer used: `MACOS_CODESIGN_CERT_P12` and
  `MACOS_CODESIGN_CERT_PASSWORD` (every `.p12` format failed — see
  `docs/SELF-SIGNED-CERTIFICATE-GUIDE.md` §7).
- Certificate: self-signed **"TransPeek Self-Signed 100Years"**, SHA256
  fingerprint
  `28:7A:3E:21:62:A8:44:1E:47:94:1F:27:0D:0A:B6:F4:A1:29:E7:3F:BD:77:CA:BC:5C:D6:DF:93:D6:47:E6:40`,
  valid 10 Nov 2026 → 17 Oct 2126 (100 years, `-days 36500`).
  Extensions: `keyUsage=critical,digitalSignature,keyCertSign`,
  `extendedKeyUsage=codeSigning`. This REPLACES the "TransPeek Local
  100Years" certificate (fingerprint `A8:02:6E:B5…`, valid 10/11/2026 →
  17/10/2126 — renamed to "Self-Signed" on 2026-11-10 23:22 because
  "Local" was ambiguous), which replaced the "TransPeek Local 100Y"
  certificate (fingerprint `8C:02:CD:18…`, valid 9/11/2026 →
  16/10/2126), which replaced the old 10-year "TransPeek Local"
  certificate (fingerprint `B1AB87...`, valid to 2036). A new
  certificate is a NEW identity, so an app signed with it needs
  Accessibility + Screen Recording granted once.
- Source files (do not commit to the repo), kept in the local workspace
  `~/workspace/projects/moepeek-translator/signing/`:
  `transpeek-signing-selfsigned-100years.crt` + `.key`, and their base64
  forms `transpeek-signing-selfsigned-100years-cert-b64.txt` (1640
  chars) + `-key-b64.txt` (2272 chars). The `.p12` variants from the
  failed directions (direction 1 nocrypt, direction 2 legacy-pass2,
  direction 3 modern-pass2, direction 3b modern-nopass) are kept in the
  same directory for reference only — do not use them for CI. The old
  direction-2/3 password lives only in
  `signing/transpeek-signing-100years-password.txt` (mode 600) and in
  the GitHub secret — never in chat, memory, docs, or the repo. Keep a
  backup of the `.crt` + `.key` somewhere safe. If they are lost, a new
  certificate can be created and the secrets updated — macOS does not
  limit self-signed certificates and GitHub does not limit secrets; the
  cost is only re-creating the certificate and re-granting permissions
  once per machine.
- **Status (as of 2026-11-11 13:04 +07): CI signing WORKS — direction
  4b (PEM certificate + key, no `.p12`) verified by run #99 (commit
  `48069b7`): all steps green, artifact `TransPeek-macOS` produced.**
  Directions 1, 2, 3 and 3b all failed at the `security import` step
  (see the table in `docs/SELF-SIGNED-CERTIFICATE-GUIDE.md` §7.1).
  Runs #89, #90, #91 and the early attempts of #92/#93 never got a
  macOS runner (0 steps run, capacity) — those say nothing about any
  direction.

### Why signing matters (TCC / cdhash)

- macOS's permission system (TCC — Transparency, Consent, and Control)
  ties Accessibility + Screen Recording grants to the app's **cdhash**
  (code directory hash — the hash of the app's code). An unsigned build
  gets a new cdhash on every rebuild, so permissions granted for one
  build do not carry over — the toggles in System Settings can look ON
  while the app still has no access.
- Signing with a stable certificate gives the app a stable identity, so
  permissions granted once survive rebuilds. A self-signed certificate
  is enough for this; a real Developer ID ($99/year, Apple Developer) is
  only needed to skip Gatekeeper's first-run block and to prove the app
  is really from the developer.
- Signing does NOT grant permissions by itself — permissions live in each
  machine's TCC database and must still be granted once per machine.
  Gatekeeper still blocks a self-signed app on first launch (right-click
  → Open).
- Full guide: `docs/APP-SIGN-KEY-PERMISSIONS.md`.

### Artifact ≠ Release

- The `TransPeek-macOS` artifact is a CI build artefact (expires in 7
  days, only the newest is kept, no user notification). A real Release
  (tag + Sparkle appcast) is what makes "Check for Updates" notify
  users. Do not confuse the two.

## 4. Intervention log (what was changed, when, why)

Chronological, so a future investigator can see the cause and the fix for
each recurring problem.

- **2026-11-09 — `[build-app]` gating + docs `paths-ignore` (commits
  `d55fb13`, `504f14e`).** Problem: every push built the app (wasting
  runners) and docs-only pushes ran CI. Fix: build/zip/upload/delete
  steps gated on `[build-app]` in the commit message; `paths-ignore` for
  `docs/**` + `**.md` on push and PR. Verified by run #75 (SUCCESS).
  Rule going forward: only add `[build-app]` when Manh explicitly says
  so.
- **2026-11-09 — Sparkle 504 on dependency resolve.** The Sparkle
  binary zip download failed intermittently with HTTP 504. Fix: retry
  the resolve step 3 times (30 s apart) + narrow the SPM cache to
  artifacts only. A red "Resolve dependencies" step is usually this
  flake — re-run before touching code.
- **2026-11-09 — CI signing step added (commit `414e364`).** Added the
  "Sign app with self-signed certificate" step (secret
  `MACOS_CODESIGN_CERT_P12`, identity "TransPeek Self-Signed 100Years" —
  named "100Y" at the time, renamed 2026-11-10). See §3.
  Still untested as of 2026-11-10 (see above).
- **2026-11-09 — Run #81 queued 26 min, then failed.** Cause of the
  queue: GitHub macOS arm64 runner capacity (not a usage limit, not a
  code problem). Cause of the failure: the flaky test below. Run #80 was
  Cancelled because #81 superseded it under the concurrency group — that
  is expected behaviour, not a problem.
- **2026-11-09/10 — Flaky test `PopupPanelLayoutTests.longTextLayoutSettles`
  (fixed in commit `afa4d5b`, verified by run #82 SUCCESS, 3m45s).** The
  test (12 cases: height {200,350,500} × fontSize {12,13,16,20}) was red
  in runs #61, #66, #70, #74, #77, #81 and green in #62, #65, #67, #68,
  #71, #78, #79. Root cause: the test capped the total resize count at
  30 and hid the panel (`orderOut`) when exceeded. On a loaded CI runner
  the panel legitimately resizes more than 30 times, so ONE slow layout
  produced TWO failures (panel hidden → `isVisible` false, AND count >
  30) — that is the "2 issue(s)" seen in run #81. Earlier fixes did not
  address this: polling for 400 ms stability within 5 s still flaked
  (#74), and removing the `settled` assertion did not help (#77) because
  the failures were the count + visibility, not the assertion. Fix
  (`afa4d5b`): removed the count cap and the panel-hide side effect
  entirely; the test now asserts the layout SETTLES (two consecutive
  200 ms polls with no new resize, up to 10 s) via `stablePolls >= 2`.
  An unbounded resize loop never settles, so it is still caught (bounded
  at 10 s, no hang). How many resizes it takes to settle is
  load-dependent and is no longer asserted. If this test goes red again,
  do NOT just re-run — read the `.xcresult` (see §2 diagnostics) and
  check whether it is the settling assertion, the visibility, or the
  reentrancy check.
- **2026-11-10 — Diagnostics lesson.** `print` (stdout) and
  `FileHandle.standardError` (stderr) inside a Swift Testing test both
  end up in the `.xcresult`, NOT the console log; xcbeautify strips
  `#expect` messages and parameterized test result lines from the log.
  So a red run's "why" is only in the `macOS-test-results` artifact.
  (The stderr diagnostic added in `afa4d5b` is still useful — it is
  recorded in the `.xcresult` — but it does not appear in the log as
  originally expected.)
- **2026-11-10 — Updater "Unable to Check For Updates / updater failed to
  start" on every launch (fixed in commit `0048aa9`, untested).** Root
  cause: the built app had no Sparkle EdDSA public key. `Project.swift`
  sets `SUPublicEDKey` to `$(SPARKLE_ED_PUBLIC_KEY)`; the "Run tests" step
  passed the key, but the "Build app" step did not, and
  `Signing.xcconfig.example` leaves the key commented out — so the app
  artifact was built with an empty key (and unsigned), and Sparkle could
  not start the updater. Fix (`0048aa9`): pass
  `SPARKLE_ED_PUBLIC_KEY=11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo=` in
  the "Build app" step (same value as the test step; a public key, so it
  is fine to hardcode in the workflow). Still untested — needs one
  `[build-app]` run (app with the key + CI-signed) to confirm the updater
  starts. Note: the feed URL
  (`.../releases/latest/download/appcast.xml`) has no release behind it
  yet, so a successful start is the check here, not a found update.
- **2026-11-10 — Flaky test `PopupPanelLayoutTests.dismissAndReopenDiscardsPendingResize`
  (fixed in commit `56fef05`, verified by run #88's green Run tests step).**
  Run #86 failed with exactly one red test: after dismiss/reopen, the
  coordinator had not finished when the test asserted `allFinished`.
  Same flaky family as `longTextLayoutSettles`: a fixed 200 ms sleep
  after reopen is too short on a slow CI runner. Fix (`56fef05`):
  replace the fixed sleep with a poll (up to 2 s, 200 × 10 ms) waiting
  for `allFinished`; a real hang never finishes, so it still fails.
- **2026-11-10 — Certificate renamed 100Y → 100Years (commit `4d92dc2`,
  `[build-app]`).** "100Y" was unclear as an abbreviation; the new
  certificate is "TransPeek Local 100Years", fingerprint SHA256
  `A8:02:6E:B5:A1:09:B2:EC:EE:0F:04:11:01:4F:9F:A8:F6:DD:BF:D9:94:3D:79:F1:F4:F1:61:16:F8:63:10:CC`,
  valid 10/11/2026 → 17/10/2126. `test.yml` also gained comments
  explaining each step. Run #88 (this commit) failed at the Sign step —
  see next entry.
- **2026-11-10 — Run #88: legacy-without-password is NOT enough.**
  Run #88 (commit `4d92dc2`): Run tests green, Build app green, Sign
  step red after 0 s with the identical error as #85: `security
  import ... -P ""` → "MAC verification failed during PKCS12 import
  (wrong password?)". The `.p12` was verified good locally (openssl
  reads it, base64 round-trips, key matches certificate), so the file
  and the secret are not corrupt. Conclusion: on recent macOS a `.p12`
  with an empty password cannot be imported at all — changing only the
  format to legacy does not fix it. Two directions prepared from the
  same 100Years certificate (see `docs/SELF-SIGNED-CERTIFICATE-GUIDE.md`
  §7): direction 1, unencrypted `.p12` (`-legacy -keypbe NONE -certpbe
  NONE`, import `-P ""`); direction 2, legacy `.p12` with a non-empty
  password (`-legacy -macalg sha1`, secret
  `MACOS_CODESIGN_CERT_PASSWORD`).
- **2026-11-10 — Runs #89/#90/#91: capacity kills the run before it
  starts (0 steps).** Direction 1 pushed (commit `05cf520`, run #89)
  → job Queued 15 min, cancelled, 0 steps, twice (attempt 1 and re-run
  attempt 2). Direction 2 pushed too quickly (commit `95d2ccd`, run
  #90) → Manh corrected: a capacity failure is not a signing failure,
  direction 1 must be tested first. A revert task briefly left the
  secret and workflow mismatched (secret direction 1, workflow
  direction 2, 21:55) — fixed within minutes (21:58, secret restored
  to direction 2). Run #90 → 0 steps. Direction 1 restored (commit
  `8132d99`, run #91) → 0 steps again (22:22). **Rule learned: only
  switch direction when a direction has actually run and failed at the
  Sign step; a 0-step capacity failure only ever means re-run and wait.**
  Cause of the capacity crunch: 22:00 +07 VN is 10:00 US East Coast
  business hours — GitHub's macOS arm64 pool is shared and busy. This
  repo is public, so Actions is free and unlimited; there is no "free
  plan gets deprioritised" queue — the limit is the shared macOS pool
  (5 concurrent macOS jobs on Free/Pro/Team), and this repo runs one
  job, so the cap is not the cause. Re-run of #91 scheduled ~23:40 +07
  (cron `transpeek-rerun-91-late-night`); if capacity fails again,
  follow-up 2026-11-11 08:00 +07 (US evening, quieter).
- **2026-11-10 — A–Z signing guide written
  (`docs/SELF-SIGNED-CERTIFICATE-GUIDE.md`).** Synthesises the whole
  signing story from this chat: why signing, certificate anatomy, the
  openssl method (verified), the Keychain GUI method including the
  100-year path (UNVERIFIED screen-by-screen), local signing, CI
  signing, the two `.p12` directions and their status. CI signing is
  still unverified — after one direction works, update the guide §7 and
  §3–§4 here with the verified winner.
- **2026-11-10 23:22 — Certificate renamed to "TransPeek Self-Signed
  100Years".** No Apple standard governs self-signed names (free
  choice; only Developer ID names are Apple-imposed) — "Self-Signed"
  was chosen because it says exactly what the certificate is, following
  the "Tinycast Self-Signed" pattern. New certificate created with
  openssl (fingerprint SHA256
  `28:7A:3E:21:62:A8:44:1E:47:94:1F:27:0D:0A:B6:F4:A1:29:E7:3F:BD:77:CA:BC:5C:D6:DF:93:D6:47:E6:40`,
  valid 10/11/2026 → 17/10/2126); both `.p12` directions regenerated
  from it (direction 1 unencrypted 2362 bytes / base64 3152 chars,
  direction 2 legacy + same password 2469 bytes / base64 3292 chars).
  The old "TransPeek Local 100Years" certificate never signed a
  successful CI build, so the rename costs no machine a re-grant of
  permissions. Secret + `test.yml` updated together (direction 1) with
  a `[build-app]` commit; the 23:40 re-run plan moves from run #91 to
  the new run.

- **2026-11-11 — Direction 1 LOSES (run #92 attempt 4, commit
  `2f3e64f`).** Attempts 1–3 died of capacity (0 steps). Attempt 4
  (finished 01:48): Run tests green, Build app green, Sign red in ~1 s
  — `security import ... -P ""` → "MAC verification failed during
  PKCS12 import". Unencrypted legacy `.p12` is dead. (Capacity note:
  Manh re-ran attempt 2 himself at 23:46 on 2026-11-10.)
- **2026-11-11 — Direction 2 LOSES (run #93 attempt 3, commit
  `5530bb9`).** Attempts 1–2 died of capacity (0 steps). Attempt 3
  (finished 04:44): tests + build green, Sign red — `security import`
  → "Unknown format in import" (the RC2-40 certificate bag). Legacy
  `.p12` with password is dead. This was the only direction that got
  past the MAC check.
- **2026-11-11 — English UI + i18n (commits `9076c25`, `41e5124`,
  `fedbf93`; runs #94, #96, #97 — all SUCCESS).** Interface switched
  to English (Manh's decision: English first for mac + Windows,
  Vietnamese/Chinese/Korean only when the app is finished). The
  `Localizable.xcstrings` catalog went 319 → 331 → 416 keys, all
  extracted by script (verify with Xcode Export Localizations when a
  Mac with Xcode is available). See `docs/LOCALIZATION.md`.
- **2026-11-11 — Direction 3 LOSES (run #95, commit `596b5a4`,
  attempts 1 + 2).** Modern `.p12` (OpenSSL 3 default, PBES2/AES-256 +
  SHA-256 MAC) + password: both attempts failed at import with "MAC
  verification failed". Suspected cause: the password value in secret
  `MACOS_CODESIGN_CERT_PASSWORD` did not match the `.p12`. The local
  password file (17 chars) and the file itself were verified good, and
  the secret was re-created from the verified file at 06:06 (cron
  `transpeek-check-93-6am`) — attempt 2 still failed identically, so
  the file was exonerated. A background check the same morning wrongly
  claimed the legacy file "does not open with the saved password" and
  that a second 21-char password file existed — both false (the check
  had omitted the `-provider legacy` flag; no second file exists).
  Re-verified the same morning. Lesson: re-verify a surprising claim
  against the actual files before acting on it.
- **2026-11-11 — GitHub sudo-mode codes: authenticator app first.**
  Updating a secret triggered sudo-mode; the browser task clicked
  "send code by email", which made the input accept only 8-digit
  codes — two 6-digit authenticator codes were rejected as wrong
  format before the 8-digit email code worked. Rule (Manh, 02:22):
  default to the authenticator app (6 digits); use the email code (8
  digits) only when needed. Gmail is not connected to Muse, so email
  codes must come from Manh.
- **2026-11-11 — Direction 3b LOSES (run #98, commit `3726ade`).**
  Modern `.p12` with an EMPTY password, import `-P ""`: failed at
  import in 1 s with the same "MAC verification failed". This proved
  the password was NOT the cause. Web check afterwards confirmed
  macOS `security` only understands legacy PKCS12 (3DES/SHA-1) and
  rejects OpenSSL 3's modern format — and direction 2 had already
  shown RC2-40 is dead on macOS 26. So the remaining space was:
  legacy-3DES-only (direction 4a) or skip `.p12` entirely (4b).
- **2026-11-11 — Direction 4b WINS (run #99, commit `48069b7`).**
  Certificate + private key as separate PEM secrets
  (`MACOS_CODESIGN_CERT_PEM`, 1640 chars; `MACOS_CODESIGN_KEY_PEM`,
  2272 chars), SHA-256 checks of both decoded files at the start of
  the Sign step, `security import` of each file, then `codesign` —
  **all steps green, first successful CI signing, artifact
  `TransPeek-macOS` produced.** Manh approved trying both 4a and 4b
  (13:00); 4b ran first and won, so 4a (legacy `-descert`, both bags
  3DES, no RC2) was never run and is not needed. Full history and
  lessons: `docs/SELF-SIGNED-CERTIFICATE-GUIDE.md` §7.
- **2026-11-11 — Panel UI tweaks (commits `ce4befb`, `9e03b25`,
  `165bc0e9`; build requested by Manh 15:33).** From a screenshot of
  the signed 0.21.0 (CI #99) panel: source speak + Copy moved to the
  right, mirroring the result card (bordered mini buttons, speaker icon
  the same colour as the target side), shortcut hints on the left;
  GitHub cat icon + "GitHub" link centred as one group in the bottom
  bar (version stays right), link opens the mac repo. The US accent
  label was first removed (`9e03b25`) because it only shows for
  English and differs between input/output — then kept after all
  (`165bc0e9`), merged inside the speaker button, as decoration; per-
  language labels (US, VI, KO…) were judged not worth it because the
  language is already shown in the language bar and non-English has
  no accent choice. Speaker and Copy buttons share a 56pt minimum
  width so they sit evenly at the default font size. Decisions also
  recorded in `docs/SPEC-v0.1.md` §8.
- **2026-11-11 — Panel UI tweaks, round 2 (feedback from build
  0.21.0 (103); push 18:32, `[build-app]`).** New slogan "Translate
  anywhere, Peek instantly!" (capital P + !) in the panel top bar,
  About, and the catalog key (still 416 keys); README EN/ZH updated
  in the same push (icon image link fixed to
  `Resources/AppIcon.icon/Assets/TransPeek.png` — the old
  `MoePeek.png` link was dead after commit `0b28b5f` deleted that
  file). Shortcut hint aligned left. The 56pt minWidth on the four
  speaker/Copy buttons was dropped — it only added padding and pushed
  the two buttons apart — and the speaker icon itself was enlarged
  (+2pt, 14pt at the default size). The GitHub link in the bottom bar
  was not clickable: the panel treats any click without an
  `InteractiveMarker` as a window drag, and the GitHub group had none
  (the Copy button worked because it has one) — marker added; not
  verified live. About: link relabelled "Github/TranManhTuanLabs",
  copyright merged to one line "Copyright © 2025-2026 TransPeek
  Licensed under AGPL-3.0" (the "Fork of MoePeek by cosZone" line is
  gone from About; README still states the fork), Email link added
  (`mailto:tuanmanhtran.vn@gmail.com`). Local clone was reset to
  `cda67be` (newest main) before the push so no stale code went in.
  Decisions also recorded in `docs/SPEC-v0.1.md` §8.
- **2026-11-11 — Panel UI tweaks, round 3 (push 2026-11-11,
  `[build-app]`).** About GitHub link relabelled
  "Github.com/TranManhTuanLabs" and now points at the org page
  (https://github.com/TranManhTuanLabs) instead of the repo. The
  output row (ProviderResultCard) used the default 8pt HStack
  spacing, so its speaker + Copy buttons sat further apart than the
  input row's 4pt — changed to `HStack(spacing: 4)` to match. The
  version text was removed from the panel bottom bar entirely
  (version still shown in About); the unused
  `appVersion`/`buildNumber`/`versionText` helpers in PopupView were
  removed with it. Decisions also recorded in
  `docs/SPEC-v0.1.md` §8.
- **2026-11-11 — Panel UI tweaks, round 3b (push 2026-11-11,
  `[build-app]`).** The version text was restored to the panel
  bottom bar, dimmed instead of removed: `.foregroundStyle
  (.quaternary)` like the shortcut hint in the input row, so it
  reads as metadata while still identifying the running build when
  reporting a bug from the panel. The round-3 removal is reverted
  in `PopupView.swift` only; the About org link and the 4pt output
  spacing from round 3 are unchanged.
- **2026-11-11 — Version scheme unified: TransPeek's own line
  starts at 0.1.0 (push 2026-11-11, `[build-app]`).** The app had
  carried upstream MoePeek's `MARKETING_VERSION` 0.21.0; the first
  public release now starts TransPeek's own SemVer line at 0.1.0
  (`Project.swift`; tag `v0.1.0`). 1.0.0 was considered and rejected
  for the first release — it means stable and feature-complete, and
  M4/M5 (Keychain, retry, real Sparkle feed, notarize) are still
  open. Going forward: patch for bug fixes (0.1.1), minor for new
  features (0.2.0), major for the stable milestone (1.0.0). The
  build number is unchanged (CI run number as `CFBundleVersion`).
  Two comments citing 0.21.0 as an example were updated with it.
- **2026-11-11 — Sparkle EdDSA key rotated for the first release
  (commit `d84f0ff`, `[build-app]`).** The private key of the
  original EdDSA keypair (public key
  `11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo=`, added in
  `0048aa9`) could not be found anywhere in the workspace — only
  the public key was ever recorded. A fresh keypair was generated
  with OpenSSL Ed25519 and sign/verify-tested; the new public key
  `+aGGc4fF2j3XJ3maoDbbwh/MmxP7BqDBdRs4A/r8f2M=` replaced the old
  one in both `test.yml` steps. Safe because no release has ever
  shipped with the old key: the first release (v0.1.0) carries the
  new public key and its appcast is signed with the new private
  key. Private key: `signing/transpeek-sparkle-eddsa.key` (mode
  600, on the VM) — back it up like the code-signing key; if it is
  lost, rotate again the same way before the next release. The
  historical `0048aa9` entry above still quotes the old key — that
  was the value at the time.

## 5. Branch note — `m2-m3-tts-ocr`

- Branch `m2-m3-tts-ocr` (head `841ef9a1`) holds the finished M2 (EdgeTTS,
  TTSFallbackChain, TTSAutoswitch, DictionaryAudioService) and M3
  (Tesseract OCR fallback) code, with Draft PR #1 unmerged.
- M3 is POSTPONED by Manh's decision (2026-11-09): Vision is the Mac
  OCR; Tesseract stays on the branch, not merged into main.
- The branch is behind main (71 commits as of 2026-11-09) and its
  `SettingsView` body is the old `TabView`, while main now uses a custom
  tab-button bar — merging needs the "sync main into branch first"
  procedure (§1), keeping main's body + the branch's taller `tabHeight`
  (OCR 620 / audio 680).

## 6. Quick reference

- Repo: https://github.com/TranManhTuanLabs/TransPeek
- Actions: https://github.com/TranManhTuanLabs/TransPeek/actions
- Workflow file: `.github/workflows/test.yml`
- Test file: `Tests/PopupPanelLayoutTests.swift`
- Secrets: `MACOS_CODESIGN_CERT_PEM` (base64 PEM certificate, 1640
  chars) and `MACOS_CODESIGN_KEY_PEM` (base64 PEM private key, 2272
  chars) — direction 4b, verified by run #99. No longer used:
  `MACOS_CODESIGN_CERT_P12` + `MACOS_CODESIGN_CERT_PASSWORD` (every
  `.p12` format failed). Identity: "TransPeek Self-Signed 100Years"
  (fingerprint SHA256 `28:7A:3E:21…`, valid to 17/10/2126). Full
  signing guide: `docs/SELF-SIGNED-CERTIFICATE-GUIDE.md`.
- Local signing backup:
  `~/workspace/projects/moepeek-translator/signing/` — `.crt` + `.key`
  for `transpeek-signing-selfsigned-100years` and their base64 forms
  (`*-cert-b64.txt`, `*-key-b64.txt`). The `.p12` variants from the
  failed directions are kept in the same directory for reference only.
  The old direction-2/3 password is only in
  `signing/transpeek-signing-100years-password.txt` (mode 600) and in
  the GitHub secret — never in chat, memory, docs, or the repo.
- Check CI: open the Actions page, newest run first; the failure is at
  the END of the "Run tests" step log. If the log is huge, download the
  log archive. For per-test detail, download the `macOS-test-results`
  artifact.
