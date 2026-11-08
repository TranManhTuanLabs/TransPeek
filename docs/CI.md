# CI Notes (TransPeek)

How the `Tests` workflow (`.github/workflows/test.yml`) is set up and how to
read a red run. Written so the next person (or future us) does not have to
rediscover any of this.

## Workflow at a glance

- Trigger: push to `main`, PRs, `workflow_dispatch`.
- Runner: `macos-26`. One job (`test`).
- Concurrency group `tests-refs/heads/main` with `cancel-in-progress`: a new
  push cancels the run that is still going. Push related files in ONE commit
  so CI only ever sees a complete version.
- Steps: Checkout → Cache mise tools (Tuist) → Install Tuist via mise →
  Cache Swift Package Manager artifacts → Resolve dependencies and generate
  project (retries 3 times) → Run tests → Build app (Release) → Zip app
  (`ditto`, keeps the `.app` bundle) → Upload artifact `TransPeek-macOS`
  (7-day retention) + delete older app artifacts, keeping only the newest →
  Upload test results (`macOS-test-results`).

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
