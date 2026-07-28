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
- [ ] Document photo-folder decks in the README — currently undocumented

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
the GitHub About description and topics. No application code was touched.

Next agent: nothing is mid-flight. The one unchecked milestone above is the
only open thread, and it is small.

## Open questions

- Should photo-folder decks be a documented feature or stay an undocumented
  convenience? It has no theme support and no way to add captions, which may
  be why it was never written up.
- Is the faint red corner-trigger tint (`systemRed` at 0.12 alpha) meant to
  ship, or is it a development aid that should default to invisible?
