# Git, CI Test & Build Workflow Setup (TransPeek)

The complete setup and configuration of git, the CI test workflow, and the
app build workflow for this repo — plus the history of what was changed and
why, so a future maintainer (or another AI entering this repo) can
investigate a red run, fix a failure, or change the setup without
rediscovering everything.

Related docs:

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

## 3. Build workflow (app artifact + CI signing)

### Build steps (all gated on `[build-app]`)

- **Build app:** `xcodebuild build ... -configuration Release
  -derivedDataPath build ... CURRENT_PROJECT_VERSION=${{ github.run_number }}
  CODE_SIGNING_ALLOWED=NO`. The run number becomes the build number shown
  in About as "Build CI #<run>" (hidden when it is "1").
- **Sign app with self-signed certificate** (added 2026-11-09, commit
  `414e364`): decodes the secret `MACOS_CODESIGN_CERT_P12` (base64 of the
  `.p12`) to a temp file → creates a temporary keychain → imports the
  certificate (no password) → signs the app with identity `TransPeek
  Local 100Y` (`codesign --force --deep --sign`) → verifies (`codesign
  --verify --verbose`) → deletes the temp `.p12`. Runs after Build app,
  before Zip app.
- **Zip app:** `ditto -c -k --keepParent` (keeps the `.app` bundle;
  `upload-artifact` with a directory path would lose the directory
  itself).
- **Upload app:** artifact `TransPeek-macOS`, 7-day retention.
- **Delete older app artifacts:** keeps only the newest `TransPeek-macOS`
  artifact (older links die). `continue-on-error: true`.
- **Upload test results:** always runs, artifact `macOS-test-results`,
  14-day retention.

### CI signing — the secret and the certificate

- Secret: `MACOS_CODESIGN_CERT_P12` (repo Settings → Secrets and
  variables → Actions → Secrets). Value = base64 of the `.p12` file.
  Only ONE secret is needed (the `.p12` has no password, so no password
  secret).
- Certificate: self-signed **"TransPeek Local 100Y"**, SHA256 fingerprint
  `8C:02:CD:18:D7:FF:B8:C9:17:2B:5F:0E:45:1A:01:A4:01:D5:F1:78:B2:F1:7E:A3:CC:41:50:20:7D:BD:DD:AE`,
  valid 9 Nov 2026 → 16 Oct 2126 (100 years, `-days 36500`).
  Extensions: `keyUsage=critical,digitalSignature,keyCertSign`,
  `extendedKeyUsage=codeSigning`. This REPLACES the old 10-year
  "TransPeek Local" certificate (fingerprint `B1AB87...`, valid to 2036)
  — the new certificate is a NEW identity, so an app signed with it
  needs Accessibility + Screen Recording granted once.
- Source file (do not commit to the repo):
  `signing/transpeek-signing-100y.p12` (no password, 2595 bytes) + `.crt`
  + `.key`, kept in the local workspace
  `~/workspace/projects/moepeek-translator/signing/` and as a base64 text
  file `transpeek-cert-100y-b64.txt` (3460 chars). Keep a backup of the
  `.p12` somewhere safe. If it is lost, a new certificate can be created
  and the secret updated — macOS does not limit self-signed certificates
  and GitHub does not limit secrets; the cost is only re-creating the
  certificate and re-granting permissions once per machine.
- **Status (as of 2026-11-10): the CI signing step has NEVER run
  successfully yet.** Run #81 was the first `[build-app]` trigger after
  the step was added, but the test step failed first so Build/Sign/Zip/
  Upload were all skipped. Run #82 (the flaky-test fix) had no
  `[build-app]`, so it ran tests only. The signing step is still
  untested — trigger a `[build-app]` build and check that the "Sign app
  with self-signed certificate" step goes green and the artifact is a
  signed app.

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
  `MACOS_CODESIGN_CERT_P12`, identity "TransPeek Local 100Y"). See §3.
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
- Secret: `MACOS_CODESIGN_CERT_P12` (base64 `.p12`, identity "TransPeek
  Local 100Y")
- Local signing backup:
  `~/workspace/projects/moepeek-translator/signing/transpeek-signing-100y.p12`
- Check CI: open the Actions page, newest run first; the failure is at
  the END of the "Run tests" step log. If the log is huge, download the
  log archive. For per-test detail, download the `macOS-test-results`
  artifact.
