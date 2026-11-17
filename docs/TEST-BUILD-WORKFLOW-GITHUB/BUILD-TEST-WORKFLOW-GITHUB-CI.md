# CI Notes (TransPeek)

How the `Tests` workflow (`.github/workflows/test.yml`) is set up and how to
read a red run. Written so the next person (or future us) does not have to
rediscover any of this.

> **Rule (Manh, 2026-11-17 — applies to all repos):** this doc and
> `GIT-CI-BUILD-SETUP.md` must be updated AT THE SAME TIME as any
> workflow change — same round, same commit if possible, never deferred
> to later. A workflow change without its doc update is an incomplete
> change. (Full rule at the top of `GIT-CI-BUILD-SETUP.md`.)

## Workflow at a glance

- Trigger: push to `main`, PRs, `workflow_dispatch`.
- Runner: `macos-26`. One job (`test`).
- Concurrency group `tests-${{ github.event.pull_request.number || github.ref }}` with `cancel-in-progress`: a new
  push cancels the run that is still going. Push related files in ONE commit
  so CI only ever sees a complete version.
- Steps: Checkout → Cache mise tools (Tuist) → Install Tuist via mise →
  Cache Swift Package Manager artifacts → Resolve dependencies and generate
  project (retries 3 times) → Run tests → Build app (Release) → Zip app
  (`ditto`, keeps the `.app` bundle) → Upload artifact
  `TransPeek-macOS-<run number>` (7-day retention) + delete older app
  artifacts, keeping only the newest → Publish pre-release
  `v0.1.3.<run number>` (direct download link on the Releases page,
  keeps only the newest, same pattern as the Windows repo) → Upload test
  results (`macOS-test-results`). The artifact name carries the run number since
  2026-11-13 (commit `f617b7a`) so each download is distinct — before
  that every artifact was named the plain `TransPeek-macOS` and
  downloads collided. The pre-release was added 2026-11-16 (commit
  `04e5727`) so the app can be downloaded from a direct link instead of
  digging into the Actions run for the artifact; the artifact itself is
  still kept because `release.yml` (direction B) promotes the tested
  artifact, and the pre-release is only a convenience download.

## When CI runs, and when the app is built

To avoid wasting CI runs (and other people's runners):

- **Docs-only and workflow-only changes do not trigger CI at all.** The
  `push` and `pull_request` triggers have `paths-ignore` for `docs/**`,
  `*.md` and `.github/workflows/**`. Renaming a doc, editing docs, or
  editing a workflow file costs zero CI runs. (Workflows added 2026-11-11:
  editing `release.yml` used to start a pointless Tests run, e.g. #127/#128.)
- **Tests run on every code commit**, but the app artifact is only built
  when the commit message contains `[build-app]`. The Build app / Zip app
  / Upload app / Delete older artifacts / Publish pre-release steps have
  `if: contains(github.event.head_commit.message, '[build-app]')`.
  A plain code commit runs tests only; add `[build-app]` to the message
  when a testable app build is actually needed. (Same pattern as SeekZip.)

## The artifact is signed by CI — verified working since run #99

The CI build used to be unsigned (`CODE_SIGNING_ALLOWED=NO`). An unsigned
build gets a new TCC identity (code hash) on every rebuild, so Accessibility
and Screen Recording permissions granted for one build do not carry over to
the next — the app will keep saying permissions are missing even though
the toggles in System Settings look ON.

Since 2026-11-09 (commit `414e364`) the workflow has a "Sign app with
self-signed certificate" step (after Build app, before Zip app, gated on
`[build-app]`). It decodes the PEM secrets `MACOS_CODESIGN_CERT_PEM` +
`MACOS_CODESIGN_KEY_PEM` into a temp keychain on the runner and signs
the app with the identity `TransPeek Self-Signed 100Years`
(`codesign --force --deep --sign`, then `codesign --verify --verbose`).
**Verified working: run #99 (2026-11-11), and every `[build-app]`
artifact since, including run #126 (v0.1.0), run #129 and run #144
(2026-11-13).** The earlier `.p12` directions all failed at import —
see [SELF-SIGNED-CERTIFICATE-GUIDE.md](../SELF-SIGNED-CERTIFICATE-GUIDE.md)
§7 for the full story (five attempts, one winner), and
[APP-SIGN-KEY-PERMISSIONS.md](../APP-SIGN-KEY-PERMISSIONS.md)
for how to sign a downloaded build locally yourself (one `codesign`
command per build, grant the two permissions once for the signed app),
including how to create the certificate yourself with the correct Key
Usage (`digitalSignature` + `codeSigning`). The Release workflow
(`release.yml`) does NOT sign the app: since direction B (2026-11-13)
it downloads the already-built, already-signed artifact from this
workflow and ships it — see `GIT-CI-BUILD-SETUP.md` §3–§4. (The old
archive flow, where `release.yml` archived unsigned and signed by
hand, was superseded by direction B; it stamped the Release run
number as the build number, so Sparkle would have seen a new release
as older than the installed build.)

## Log policy: xcbeautify, never errors-only

Do NOT configure the build to output only error lines. A failing test does
not show up as an `error:` line — it shows up as `recorded an issue` plus a
summary at the end of the log (`Test run with N tests ... failed with M
issues`, `Failing tests:`). Warnings can also be the clue (for example, the
compiler's `@MainActor` notes). Filtering to errors-only would hide all of
that context.

Instead, the `Run tests` step pipes `xcodebuild` through **xcbeautify**
(`brew install xcbeautify`, then `xcodebuild test ... | xcbeautify` with
`set -o pipefail` so a failing `xcodebuild` still fails the step). The log
stays complete for test results but drops the thousands of `SwiftCompile`
lines, so it loads fast in the GitHub web viewer. The raw log archive and the
`.xcresult` bundle are still uploaded, so nothing is lost.

## Caching (rule: cache needed dependencies under ~80 MB)

- SPM artifacts: `~/Library/Caches/org.swift.swiftpm/artifacts`, key by
  `Package.resolved` (+ `spm-<os>-` restore key). Narrowed from the whole
  `org.swift.swiftpm` dir (measured ~143 MB in run #53) — only the
  downloaded artifact zips are cached, which is what the Sparkle 504
  was about; checkouts re-clone fast and resolve already retries 3 times.
- mise tools (Tuist): `~/.local/share/mise/installs`, key by `.mise.toml` +
  `.tuist-version` (+ `mise-<os>-` restore key). Narrowed from the whole
  `~/.local/share/mise` dir (measured ~94 MB in run #53).
- Both keys carry a `-v2` suffix so the narrowed cache is stored under a
  new key; the restore-keys fall back to the old cache on the first run.
- The resolve step retries 3 times with 30 s between tries: the Sparkle
  binary zip download used to fail intermittently with HTTP 504 from GitHub,
  and the retry + cache made that go away. A red run at "Resolve
  dependencies" is usually that flake — re-run before touching code.

## Reading a red run

1. Open the run, job `test`, step `Run tests`.
2. The failure is at the END of the step log: a compile error lists
   `file:line: error: ...`, a test failure lists `recorded an issue` and the
   final summary names the failing tests.
3. Check the step BEFORE blaming the last change: a red "Resolve
   dependencies" is usually the Sparkle 504 flake, not the code.
4. If the web viewer hangs on the huge log, download the log archive
   ("Download log archive") instead of fighting the viewer.

## Known gotchas (learned the hard way)

- `NSAttributedString.MarkdownOptions` does not exist. The Markdown options
  type is `AttributedString.MarkdownParsingOptions` (Swift value type).
- `NSInlinePresentationIntent` was renamed to `InlinePresentationIntent` in
  Swift 3 (no `NS` prefix). The attribute key is still
  `.inlinePresentationIntent`.
- The Foundation Markdown parser marks bold/italic/code in each
  `AttributedString` run's `inlinePresentationIntent` and assigns NO font
  at all — and the `NSAttributedString` bridge does not reliably carry that
  intent (runs #51 and #53 both found no traits when reading the bridged
  `.font` / `.inlinePresentationIntent` attributes). So
  `SelectableResultTextView` parses with the Swift `AttributedString` value
  type and reads the intent from its runs directly instead of bridging.
- `upload-artifact` with a directory path loses the directory itself — zip
  the `.app` first (`ditto -c -k --keepParent`).
- Do not inline a whole `Button` (with a nested ternary in `.background`)
  inside a `.toolbar` builder: the type checker gives up with "unable to
  type-check this expression in reasonable time" (run #57). Extract the tab
  button into a helper function (and a helper for the background tint) so
  the toolbar builder only sees small expressions.
- Do not put a `ForEach` of `ToolbarItem`s directly inside `.toolbar { }`:
  the toolbar builder treats the `ForEach` as a `View` and demands
  `ToolbarItem` conform to `View` ("static method 'buildExpression'
  requires that 'ToolbarItem<...>' conform to 'View'", run #58). Put the
  `ForEach` inside a `ToolbarItemGroup(placement: .navigation)`, whose
  content is a plain `@ViewBuilder`.
- `NSAttributedString` HTML import needs a generous timeout on a cold
  system: it spins up WebKit, and on a cold CI runner WebKit may not start
  within 5 s — `RichTextImporterTests.importsHTMLFormatting()` timed out at
  exactly 5.027 s on Tests #163 (2026-11-13) and fell back to plain text,
  losing bold/list formatting. Raising the import timeout from 5 s to 10 s
  in `RichTextImporter.swift` fixed it (commit `2eee420`, Tests #164
  green). If this test flakes again, raise the timeout before assuming the
  importer is broken; the Swift 6 warnings in the same log are warnings
  only and do not fail the test.
- `PopupPanelLayoutTests` hardcodes panel heights that are coupled to the
  panel's chrome: adding one row to `PopupView` breaks two tests at once.
  The Actions row (Pin + Settings, added 2026-11-15 to match Windows)
  added 18pt of chrome — `streamingResultsRespectManualResize` failed
  238 vs 220 (Tests #165, fixed by updating the manual height to 238) and
  `dismissAndReopenDiscardsPendingResize` failed 358 vs 350 (Tests #166,
  fixed by updating the expected height to 358), both in the same commit
  range (Tests #167 green). But 358 is NOT a stable value: the height
  flips between the 350 baseline and the 358 fitted height across runs
  (#168/#169 read 350), because the async layout resize sometimes
  includes the Actions row's 8pt vertical padding in the chrome
  measurement and sometimes doesn't — and polling for 358 does not help
  (#169 waited 2s and the height stayed 350). So that test now asserts a
  range (350...358) instead of one exact height. Lesson: when a panel
  height is only 8pt above the baseline, do NOT assert one exact number —
  assert the range between the baseline and the fitted height. Verified:
  Tests #170 went green with the range assertion — the flaky test stopped
  flipping. When you add, remove or resize a row in the popup panel,
  update the hardcoded heights in that test file in the same commit.
- `PopupPanelLayoutTests.streamingResultsRespectManualResize` (CI #196,
  2026-11-16/17): `isUserResizing = true` alone does NOT block auto-fit
  in a test. `resizeForResultContent()` clears a "stale" `isUserResizing`
  flag when no mouse button is held, and a test sets the flag
  programmatically with no mouse press, so it looks stale and auto-fit
  runs — the panel grew to 467 (chrome 207 + output cap 260) instead of
  staying at the manual 450. A real drag always holds the button, so
  this only bites tests. Fix (commit `67c470e`): the test sets
  `manualResizeGeneration` BEFORE streaming, so the generation guard
  (the durable mechanism) blocks auto-fit. When a test simulates a
  manual resize, set the generation too, not just the flag.
- A run whose job is cancelled after ~15 minutes with 0 steps and the
  annotations "The job was not acquired by Runner of type hosted even
  after multiple attempts" + "Internal server error" + macOS arm64
  capacity notices is a GitHub infrastructure failure, NOT a code or
  test failure — no test step ever ran (CI #197, 2026-11-17, three
  attempts in a row). Re-run and wait; never change code or direction
  for it. See `GIT-CI-BUILD-SETUP.md` §4 for the full history of this
  pattern (runs #89/#90/#91, #140–#143, #197).

## Liên kết

- [Setup + intervention log](GIT-CI-BUILD-SETUP.md)
- [Quy tắc làm việc](../AGENTS.md)
- [Bản đồ docs](../STRUCTURE_MAP.md)
