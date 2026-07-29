# Project Plan — Screen Presenter

Every agent working on this repo reads this file first and updates it before
finishing. Decisions and open questions are append-only; status fields are
edited in place.

## Goal

A minimal, markdown-driven slide overlay for macOS that appears on a corner
hover and gets out of the way — no window chrome, no menus, no setup. Decks
are plain `.md` files that stay readable in any editor.

## Non-goals

- Cross-platform support. This is macOS-only, AppKit-coupled by design.
- A slide editor, WYSIWYG authoring, or a GUI for building decks.
- Full CommonMark compliance. The parser supports a deliberately small
  directive set; unsupported syntax renders as literal text.
- Presenter notes, speaker view, remote control, or multi-display output.
- A test suite. Verification is running the app — see the
  `no-tests-visual-verification` card.
- Splitting `main.swift`. See the `single-file-main-swift` card.

## Milestones

- [x] Core overlay: borderless panel, backdrop, corner-hover trigger
- [x] Markdown deck parsing: slides, columns, images, code blocks
- [x] Syntax highlighting via Highlightr (`atom-one-dark`)
- [x] YouTube embeds served over a loopback HTTP listener
- [x] Live config panel (font, size, per-slide shade)
- [x] Finder drop / "Open With" / `open -a` deck loading
- [x] Theme system: 10 bundled templates, per-key overrides, demo mode
- [x] SVG background support and a default-background fallback
- [x] Photo-folder decks (point at a directory of images)
- [x] Build/sign/notarize/dmg pipeline in the Makefile
- [x] Agentic documentation setup: `cards/`, `.claude/skills/`, this plan
- [x] Document photo-folder decks in the README
- [x] Audit both sample decks against the feature list and close the gaps
- [x] Gradient overlays — per-slide directive plus a `defaultGradient` theme key
- [x] First public release: `v0.3.0`, signed, notarized, stapled, on GitHub
- [ ] Revoke the exposed app-specific password and regenerate it in `.env`
- [ ] Confirm the release zip opens cleanly after a *browser* download

## Decisions

Append new entries; do not rewrite existing ones. Full rationale for the
larger ones lives in the decision cards under `cards/`.

- **2026-07-28** — Adopted the context-cards documentation pattern: `cards/`
  holds lazy-loaded reference cards indexed from `CLAUDE.md`, which stays the
  always-loaded overview.
- **2026-07-28** — Installed all ten skills from `epatel/agent-skills` under
  `.claude/skills/` as project-scoped, committed skills.
- **2026-07-28** — Adopted this shared project plan. Currently a solo,
  single-agent repo, so its practical value is as a durable goal/state record
  rather than as multi-agent coordination.
- **2026-07-28** — `theme-demo.md` stays a theme-browsing deck
  (`template: demo`). It had been locally repurposed as a scratch harness for
  the SVG background feature; those edits were discarded rather than
  committed. If SVG backgrounds need a permanent demo, it gets its own deck
  file instead of displacing this one.
- **2026-07-28** — Photo-folder decks are a supported, documented feature
  rather than an undocumented convenience; the README now covers them.
- **2026-07-28** — **Supersedes the `theme-demo.md` entry above.** The deck now
  presents its own slides (`template: ocean`) rather than declaring
  `template: demo`. A feature audit found that under demo mode its authored
  slides were replaced by the generated previews and had therefore never
  rendered — so its written guidance, including a `primaryColor` key that does
  not exist, was unreachable and unreviewed. Browsing themes is now a run-time
  flag (`template=demo`), which the deck explains on its last slide.
- **2026-07-28** — `images/abstract-bg.svg` stays static; animation lives in a
  separate `images/animated-bg.svg`, per the earlier decision that an SVG demo
  gets its own file. This makes the "SVG renders live" claim in `sample.md`
  demonstrated rather than asserted.
- **2026-07-28** — `images/jl1.jpg` was deleted and replaced by
  `images/boat.jpg` as the sample deck's background photo.
- **2026-07-29** — Gradient overlays added. Four choices worth not reopening:
  a gradient **replaces** the flat darken overlay rather than stacking with it
  (stacking double-darkens, and the Shade slider is inert on those slides); it
  applies **with or without** a background image, so a gradient can be the
  background; the angle convention is **CSS's** (`0` top-to-bottom, clockwise)
  rather than trigonometric; and the spec uses **named `key=value` pairs**
  rather than positional CSS-like syntax, so omitted keys take defaults and
  order does not matter.
- **2026-07-29** — Shipped `v0.3.0`, the first tagged release. Tags are
  `vMAJOR.MINOR.PATCH` on `main`, cut from the commit carrying the matching
  `VERSION`, with the notarized zip attached to a GitHub release.
- **2026-07-29** — Distribution zips are built by `make dist-zip`, never
  `make zip`. `zip` runs before notarization and exists only to feed
  `notarytool`; the app it contains has no stapled ticket, so a machine
  without network access would refuse it. `dist-zip` re-zips after `staple`.
  `make dmg` was always correct — only the zip path had the gap.
- **2026-07-29** — Notarization registers a ticket with Apple keyed to the
  code hash and returns no artifact. Stapling is the separate step that
  embeds that ticket locally, and it is what makes offline launch work. A
  `.zip` cannot itself be stapled; staple the `.app`, then re-zip.
- **2026-07-29** — `Slide.parse` now accepts multi-line HTML comments, so a
  five-key gradient can wrap. Only a line whose trimmed form *starts* with
  `<!--` opens a directive — the sample decks quote `<!-- bg: path -->` inside
  prose and rely on staying inert — and an unterminated comment is restored to
  the body rather than swallowing the rest of the slide.
- **Earlier** — The whole app stays in one file (`single-file-main-swift`).
- **Earlier** — No test target; verification is visual
  (`no-tests-visual-verification`).
- **Earlier** — `template: demo` replaces the deck rather than appending
  preview slides (`demo-mode-replaces-deck`).
- **Earlier** — YouTube embeds are served from a loopback `NWListener` because
  the IFrame API rejects `file://` and synthetic origins; this is why
  `NSAllowsLocalNetworking` is in `Info.plist`.

## Current state / handoff

Version 0.2.0, branch `main`, working tree clean and in sync with
`origin/main`. The app is feature-complete for its stated goal; recent work
was the theme system (10 templates, `a405100`) and SVG background support
(`67d0c5d`).

This session added the agentic documentation layer: eleven cards under
`cards/`, ten project-scoped skills under `.claude/skills/`, this plan, and a
trimmed `CLAUDE.md` carrying the card index (`b718903`, pushed). It also set
the GitHub About description and topics.

It then audited both sample decks against the full feature list and closed the
gaps: `theme-demo.md` rewritten so its slides actually render, `sample.md`
grown from 8 to 13 slides (text formatting, more YouTube URL forms, SVG
backgrounds, photo decks), README sections for photo decks / SVG backgrounds /
block-vs-inline syntax, and a new animated `images/animated-bg.svg`.

It then added gradient overlays — the session's only application-code change,
touching `SlideGradient` (new), `DeckTheme`, `Slide.parse`, and
`PresenterContent.backgroundOverlay`.

`v0.3.0` was then tagged and released. The artifact was verified end to end:
notarization `Accepted` (submission `fa6406ef-e805-450f-8c0b-7cabbd7d3d4a`),
and the zip *re-downloaded from GitHub* is byte-identical to the local build
(`b4fc7bed…f7faa5`), staples cleanly, and reports
`source=Notarized Developer ID` under `spctl`. Two Makefile bugs were fixed
along the way — see the decisions above.

**Unverified — start here.** The release is sound as a *package*, but nothing
in it has been watched running. `swift build` is clean, which in this codebase
proves very little. Three items:

- **Gradient rendering.** The angle convention has only been confirmed
  analytically (`0` should run top-to-bottom, `90` left-to-right). Check the
  two new gradient slides in `sample.md`. This shipped in `v0.3.0` unseen.
- **The animated SVG.** WKWebView is expected to play SMIL, but nobody has
  watched `images/animated-bg.svg` move.
- **Browser download.** The artifact was validated after a `gh` download,
  which sets no `com.apple.quarantine` attribute. Stapling should make that
  moot, but one Safari download and double-click would prove it.

**Security follow-up.** `make notarize` echoed its recipe, printing the
app-specific password in cleartext to the terminal and into the session
transcript. The recipe is silenced now, but the exposed credential still needs
revoking at appleid.apple.com and regenerating in `.env`. It grants
notarization submission only, not account access.

Next agent: nothing is mid-flight. The milestone list is clear; the two open
questions below are the only threads.

## Open questions

- Is the faint red corner-trigger tint (`systemRed` at 0.12 alpha) meant to
  ship, or is it a development aid that should default to invisible?
