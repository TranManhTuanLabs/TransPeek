# AppIcon — Draft Samples + Final Candidate

Temporary draft samples for choosing the TransPeek app icon direction.
These samples are **not** the final macOS iconset by themselves — the ready-to-use
iconset is in `AppIcon-main-using/` (made from the approved S3 sample, all
required macOS sizes, see below).

Design direction (approved 2026-11-08 / 2026-11-11):
- Finder-style split, blue left / white right.
- Eyes: **A** (English) on the left + **文** (Chinese) on the right.
- Smile: handwritten **Xin chào** curved like a smile. The two mouth corners are
  **not** separate marks and there is **no** line under the text — the left corner
  is the first stroke of the X curling up, the right corner is the tail of the
  final o curling up.
- Colour rule per side: left side **A + Xin** share one colour (white),
  right side **文 + chào** share one colour (dark blue). Each word contrasts
  with its own half of the background.

## Samples

- `X1.webp` — 3D glass, eyes A + 文, handwritten Xin chào as the smile.
- `X3.webp` — Round glass bubble, rainbow light, eyes A + 文, Xin chào script.
- `Z3.webp` — Round glass bubble, curved smile line + Xin chào.
- `Z4.webp` — Square glass split blue/white, Xin chào + 2 mouth corners (the
  design the Z4 style is based on).
- `S1.webp` — Z4 split-colour: Xin white on blue + chào dark blue on white,
  kept the rainbow glass.
- `S3.webp` — **Final candidate.** Z4 split-colour, Xin white + chào dark blue,
  clean version with less sparkle.
- `S4.webp` — Z4 split-colour: Xin light cyan + chào navy blue.
- `X3S1.webp` — X3 split-colour: A + Xin white, 文 + chào dark blue, script.
- `X3S2.webp` — X3 split-colour, bold 3D version of X3S1.
- `X3S3.webp` — X3 split-colour, clean version.
- `X3S4.webp` — X3 split-colour, bolder script version.
- `X3W1.webp` — X3 with Xin chào all white (same as A), soft shadow.
- `X3W2.webp` — X3 with Xin chào all white, bold 3D.
- `X3W3.webp` — X3 with Xin chào white + blue outline (font changed to round,
  no longer script).
- `X3W4.webp` — X3 with Xin chào all white, clean version.
- `X3-glass/` — X3 glass family in one folder: `X3S1.webp`, `X3S2.webp`,
  `X3S3.webp`, `X3W1.webp`, `X3W2.webp`, `X3W4.webp`.

## Final candidates (2026-11-11)

- **S3** — the iconset in `AppIcon-main-using/` is made from this sample.
- **X3** — runner-up, round glass bubble. Its split-colour versions are
  `X3S1`–`X3S4` above (A + Xin white, 文 + chào dark blue).

## AppIcon-main-using/

Ready to drop into the app source:

- `AppIcon.appiconset/` — classic macOS iconset made from **S3** (source
  1600×1600, resized with Lanczos): `16`, `32`, `64`, `128`, `256`, `512`,
  `1024` px, with `Contents.json` (`idiom: mac`). Copy this folder into
  `Assets.xcassets` and set it as the app icon.
- `TransPeek-S3-1024.png` — 1024×1024 master image of S3, for the newer
  Xcode `.icon` format or any other place that needs a single square master.

Note: the app currently ships the upstream icon via `Resources/AppIcon.icon`
(`MoePeek.png`, Xcode 26 `.icon` format). Replacing that icon with this S3
iconset is a separate integration step — see the build chat / `docs/`.
