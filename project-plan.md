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
- [x] Outer margin control in the config panel, persisted across launches
- [x] MIT `LICENSE` file — the README claimed MIT with no licence text present
- [x] `v0.4.0` released; gradients, margin, and the animated SVG verified running
- [x] PDF export on ⌘P — one page per slide, save panel, Finder reveal
- [x] Clickable links in the exported PDF — prose links and YouTube thumbnails
- [x] `v0.5.0` released — PDF export, signed, notarized, stapled, on GitHub
- [x] Image slideshows — `![alt](a.png, b.png)` cross-fades between images
- [x] `v0.6.0` released — slideshows, signed, notarized, stapled, on GitHub
- [x] `<!-- ... -->` works as a plain comment, not just a directive carrier
- [x] `v0.7.0` released — comments, signed, notarized, stapled, on GitHub
- [x] `lineSpacing` theme key — extra leading, set on the `## Theme` page
- [x] `v0.8.0` released — lineSpacing, signed, notarized, stapled, on GitHub
- [x] `<!-- skip -->` drops a slide from the deck entirely
- [x] `v0.9.0` released — skip directive, signed, notarized, stapled, on GitHub
- [x] `<!-- cursor -->` — blinking cursor, below the content or on the last line
- [x] `v0.10.0` released — cursor, signed, notarized, stapled, on GitHub
- [x] `v0.10.1` released — `cursor:lastline` sits flush against the last word
- [x] ⌘F toggles fullscreen — whole screen frame, no border, no corner radius
- [x] `v0.11.0` released — fullscreen, signed, notarized, stapled, on GitHub
- [x] `innerMargin` theme key — inset from the panel edge to the slide content
- [x] SVG backgrounds fade in instead of popping once the web view loads
- [x] `v0.12.0` released — innerMargin and the SVG fade, signed, notarized,
      stapled, on GitHub
- [x] Gradients export correctly to PDF — an alpha ramp was painting opaque
- [x] `v0.12.1` released — the gradient fix, signed, notarized, stapled, on
      GitHub
- [ ] Revoke the exposed app-specific password and regenerate it in `.env`
      (deferred by choice — never reached the repo, terminal output only)
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
- **2026-07-29** — The presenter panel has **no maximum size**. It was
  `min(1100, width * 0.75) × min(720, height * 0.75)`, and the first cut of
  the margin control kept that cap — which made the slider feel broken, since
  a cap already insets the panel by whatever slack it leaves (126pt
  horizontally on a 1352pt display), so every margin below that did nothing.
  A cap and a margin control cannot both own the panel's size. Do not
  reintroduce one as a "safety" limit; the 320×240 floors already cover the
  degenerate end.
- **2026-07-29** — Outer margin is the one config-panel control that
  **persists** (`outerMargin` in `UserDefaults`, clamped 0–400 on load). It
  describes the display rather than the deck, so it is also not reset by
  `loadDeck` — a new deck should not move the window. Font, size, and shade
  stay session-only.
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

- **2026-09-06** — PDF export renders through `SlideCanvas`, the slide view
  extracted out of `PresenterContent`, rather than a second layout written for
  export. One code path means the PDF cannot drift from the panel. Pages are
  the panel's *current* size rather than a paper size, because font sizes here
  are absolute — rescaling would re-flow the slide instead of preserving it.
- **2026-09-06** — ⌘P is caught by the local `NSEvent` monitor, not by
  `PresenterPanel.keyDown`. Command-modified keys go through the menu bar and
  `performKeyEquivalent`, and this app has no menu, so `keyDown` never sees
  them. The monitor (previously video-only, now `installKeyMonitor`) runs
  ahead of the responder chain and is the only place that reliably works.
- **2026-09-06** — SVG backgrounds are exported by snapshotting an offscreen
  `WKWebView`, not by `NSImage`. `NSImage` loads these files without error and
  renders them entirely black — its SVG support is for symbol-style art, not
  gradients and filters. The web view also has to belong to a window, and the
  wait for its callbacks has to `await Task.sleep`, not pump a `RunLoop`:
  export runs inside a main-actor task, where run-loop pumping delivers
  nothing and every snapshot silently times out.

- **2026-09-06** — Links in the exported PDF are added in a PDFKit pass over
  the finished file, and prose links are located by **searching the page's own
  text** for the label rather than by measuring geometry — SwiftUI exposes no
  per-run rects for a `Text`. That makes "the pages are real text" load-bearing
  rather than merely nice: rasterized pages would have nothing to search.
  YouTube thumbnails have no text, so those rects come from a `GeometryReader`
  probe during the render pass instead.

- **2026-09-06** — `<!-- ... -->` is now a real comment. A closed comment that
  opens a line and that neither `bg:` nor `gradient:` claims is **dropped**
  instead of rendered as literal text — there had been no comment syntax at all.
  Two earlier rules still hold and are what keep this safe: only a line that
  *starts* with `<!--` is treated as a comment, so the decks' mid-sentence
  `` `<!-- bg: path -->` `` examples still render; and an *unterminated* comment
  is still restored to the body verbatim rather than swallowing the rest of the
  slide.

- **2026-09-07** — ⌘F fullscreen means the **whole `screen.frame`**, menu bar
  included, not "margin 0" — the margin slider already covers filling
  `visibleFrame`. Covering the menu bar requires the panel above `.mainMenu`,
  so it goes to `.screenSaver` with the backdrop one level below; both drop
  back to `.floating` on exit and in `hide()`. `settings.fullscreen` is
  session-only (a deck should open windowed) and is what zeroes the corner
  radius and drops the border. The outer margin is left untouched and restored
  on exit; `applyMargin` returns early while fullscreen. Esc leaves fullscreen
  before it dismisses, matching the macOS convention — a second Esc dismisses.

- **2026-09-07** — `innerMargin` is a **theme** key, not a config-panel
  control. The two margins are deliberately split: `outerMargin` describes the
  display, persists in `UserDefaults`, and is session-wide; `innerMargin`
  describes the deck and travels with the `.md` file. It replaces the
  hard-coded `.padding(48)` on `SlideCanvas`'s content, so it reaches the PDF
  export too, and is clamped to 0–200. The page-number label keeps its own
  fixed 16pt inset — it is chrome, not content.
- **2026-09-07** — `SVGBackgroundView` fades in rather than appearing at once.
  A `WKWebView` paints nothing until its load finishes, so an SVG background
  popped in a beat after the slide; the view now starts transparent and its
  coordinator, acting as the navigation delegate, animates alpha to 1 over
  0.4s on `didFinish` — dispatched to the next runloop pass, because
  `didFinish` precedes the first paint. Image backgrounds are left alone:
  `NSImage` decodes synchronously and is already there on frame one.

- **2026-09-07** — Gradients are drawn as a **bitmap** in the PDF export, not
  as a `LinearGradient`. CoreGraphics writes a PDF axial shading from the RGB
  stops only and drops their alpha, so every exported gradient painted fully
  opaque — hiding the theme background colour and every `bg:` photo behind a
  solid slab. A gradient whose two stops are identical collapses to a flat
  fill and was unaffected, which is exactly why this went unnoticed: the
  neutralised-gradient slides exported fine. `SlideGradient.image(size:)`
  redraws the ramp with `CGGradient` into a bitmap (alpha survives as an
  `SMask`) and `backgroundOverlay` uses it only when `staticBackgrounds` is
  set. The live panel is untouched.

- **2026-09-07** — `staple` now declares `notarize` as its prerequisite. It had
  none, so `make dist-zip` and `make dmg` stapled whatever bundle was sitting
  in `build/` — and *succeeded*, because an earlier release's ticket still
  matched that unmodified app. The first 0.12.1 zip and dmg were therefore a
  0.12.0 app under a 0.12.1 name, with no rebuild, no signing and no
  notarization run, and nothing in the output said so. Caught by checking
  `CFBundleShortVersionString` in the built bundle against `VERSION`, which is
  now the thing to check when a release "succeeds" suspiciously fast.

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

`v0.4.0` followed, adding the outer margin control and removing the panel's
maximum size, released the same way (submission
`cb581d94-0aeb-40a3-a33d-e0188b86f5e0`, checksum matched after re-download).
An MIT `LICENSE` was added — the README had claimed MIT since the start but no
licence text existed, so the terms had never actually been granted.

**Verified running (2026-07-29).** Everything from this session has now been
confirmed in the app, not just compiled:

- Gradient angles render as intended — `0` runs top-to-bottom, and the
  diagonal on the second gradient slide is correct.
- The margin slider resizes the panel live, with the config panel tracking
  below it.
- `images/animated-bg.svg` animates — WKWebView does play SMIL.
- Margin survives quit and relaunch, so the `UserDefaults` round-trip works.

Still unconfirmed, and minor: the release zip has only been opened after a
`gh` download, which sets no `com.apple.quarantine` attribute. Stapling should
make a browser download equivalent, but nobody has proven it.

**Security follow-up (accepted risk, 2026-07-29).** `make notarize` echoed its
recipe, printing the app-specific password in cleartext to the terminal and
into a session transcript. The recipe is silenced now and the `0.4.0` run
confirmed it no longer leaks. A full history scan — all 209 objects across
every ref *and* the reflog — found the credential in no commit, and it is
absent from `.env.example` and from the shipped `.app`, so this was never a
repo leak. Rotation is deferred by choice, not forgotten: revoke at
appleid.apple.com and regenerate in `.env` when convenient. It grants
notarization submission only, not account access.

**PDF export (2026-09-06).** ⌘P writes the deck to a PDF chosen through a save
panel. `SlideCanvas` was extracted from `PresenterContent` so the exporter and
the panel share one layout; `PDFExporter`, `SVGSnapshot`, and the
`YouTubeThumbnails` cache are new; the video key monitor became a general
`installKeyMonitor` that also catches ⌘P. README, `sample.md`, and a new
`cards/pdf-export.md` cover it.

Links in the PDF followed: `[label](url)` (and bare URLs, which
`AttributedString(markdown:)` autolinks) plus YouTube thumbnails, which link to
the video with its start offset.

The *rendering* is verified against `sample.md` — all 15 pages, including the
YouTube thumbnails, the animated SVG background, gradients, syntax
highlighting, and background photos, with the text landing as real selectable
text. That was done through a temporary env-var export hook in the bootstrap,
which has since been removed. What has **not** been exercised in the running
app is the ⌘P keystroke itself, the save panel appearing above the presenter
(the `withPanelsBelowModal` level dance), and the Finder reveal.

Link annotations are verified on a scratch deck covering headings, bullets,
two links in one paragraph, a repeated label pointing at two different URLs, a
label wrapping across two lines, and a bare URL — each lands on exactly its own
words, with the wrapped one getting an annotation per line. Not checked: how a
given PDF *viewer* renders the click target, and whether prose links are
clickable in the live panel (SwiftUI should handle it, but nobody has clicked
one).

`v0.5.0` was released the same way as its predecessors (`make app` → `sign` →
`notarize` → `staple` → `dist-zip` → `dmg`, tag on `main`, zip attached to a
GitHub release). Notarization `Accepted`, submission
`1d3e4ef1-21bf-4c7f-b8bf-5239a0739566`; the zip re-downloaded from GitHub is
byte-identical to the local build (`5bd377b1…b2de6`), staples cleanly, and
reports `source=Notarized Developer ID`. Note that it shipped with the ⌘P
keystroke itself still unexercised by a human — the export was verified through
code, not through the key.

**Image slideshows (2026-09-06).** `![alt](a.png, b.png)` — two or more
comma-separated paths in one image directive — becomes a `.slideshow` block that
cross-fades between the images every 4s over 1.2s. New `SlideshowBlock` view,
new `MarkdownSlide.splitPaths`, and `loadImage` now caches by URL (the block
list is rebuilt on every body pass, so a ticking slideshow would otherwise
re-decode its images constantly). The frame is pinned to the aspect ratio of the
largest image so the slide layout does not jump as it cycles. In a PDF export
the timer never fires, so page one of a slideshow is its first image — accepted,
not a bug. `sample.md` gained a "Slideshow" slide; README table and
`cards/markdown-parsing.md` updated.

**Verified running (2026-09-06).** The slideshow was watched in the app: the
images cross-fade, the frame stays put across the switch, and the 4s/1.2s
timing was accepted as-is.

`v0.6.0` was released the same way as its predecessors. Notarization `Accepted`,
submission `ad485a7e-90d7-4d5e-9865-694697963928`; the zip re-downloaded from
GitHub is byte-identical to the local build (`936e4573…a33280`), staples
cleanly, and reports `source=Notarized Developer ID`.

**Comments (2026-09-06).** Verified running: the comment above the Slideshow
slide in `sample.md` does not render, and the `bg:`/`gradient:` slides still
take their directives.

`v0.7.0` was released the same way as its predecessors. Notarization `Accepted`,
submission `5f16e729-0124-4f60-a8ea-6904f4ffc1d9`; the zip re-downloaded from
GitHub is byte-identical to the local build (`343c5f4c…449233`), staples
cleanly, and reports `source=Notarized Developer ID`.

**`lineSpacing` (2026-09-06).** A new `## Theme` key giving extra leading in
points, defaulting to `0` — SwiftUI's own default, so existing decks lay out
unchanged. Applied once on `MarkdownSlide`'s `VStack`, which reaches every
`Text` under it; `CodeBlockView` resets it to `0` so listings keep their own
rhythm. It is leading *within* a wrapped block — the 18pt gap *between* blocks
is the stack's `spacing` and stays fixed. `theme-demo.md` sets `lineSpacing: 4`
and documents the key. Verified running at 4pt.

`v0.8.0` was released the same way as its predecessors. Notarization `Accepted`,
submission `d2646527-fe43-485e-9e65-45942186e683`; the zip re-downloaded from
GitHub is byte-identical to the local build (`87825d6b…e87081`), staples
cleanly, and reports `source=Notarized Developer ID`.

**`<!-- skip -->` (2026-09-06).** A third slide directive, alongside `bg:` and
`gradient:`. `Slide.parse` sets `skipped: Bool` and `Deck.load` filters those
slides out before building the `Deck`, so page labels and PDF pages count only
what is shown — commenting a slide's body out would have left an empty slide
behind, since `---` defines the slides before any content is parsed. If every
slide is skipped the deck falls back to a single placeholder rather than being
empty. `sample.md` carries a skipped slide; a stale bullet in
`cards/markdown-parsing.md` (claiming unrecognized comments render as literal
paragraphs — untrue since `v0.7.0`) was corrected at the same time. Verified
running.

`v0.9.0` was released the same way as its predecessors. Notarization `Accepted`,
submission `f5c71dfe-bbff-4016-8e17-fec55ba31d7a`; the zip re-downloaded from
GitHub is byte-identical to the local build (`6fd80287…b53ec9`), staples
cleanly, and reports `source=Notarized Developer ID`.

**`<!-- cursor -->` (2026-09-06).** A blinking cursor, in two placements:
`cursor:last` (the default, and what the bare directive means) puts it on its
own line below the content; `cursor:lastline` appends it to the end of the last
line of text. Three choices worth not reopening:

- The blink is a `TimelineView(.periodic)` around **only the block carrying the
  cursor**. A `@State` + `Timer` on the slide would re-run `Slide.parse` twice a
  second for every deck, cursor or not.
- The cursor is an `AttributedString` run appended to that block's text, toggled
  between `theme.textColor` and `.clear`. Keeping it *inside* the text run is
  what puts `cursor:lastline` on the last **visual** line of a wrapped
  paragraph; an adjacent view in an `HStack` would sit beside the whole block.
- `staticCursor`, threaded from `SlideCanvas.staticBackgrounds`, draws it solid
  in a PDF export rather than catching whichever half of the cycle the render
  lands in.

Two fallbacks: `cursor:lastline` on a slide ending in an image or code block has
no line to follow and reverts to `.last`; on a two-column slide the cursor goes
to the last column. Verified running.

`cursor:lastline` first shipped with a separating space before the block, on the
terminal reasoning that a cursor occupies the *next* cell. In the panel that
read as a gap, so `v0.10.1` removed it — the cursor now butts against the last
character. Notarization `Accepted`, submission
`ffe67c8f-d753-4661-b800-6b8a49f51d1b`; the zip re-downloaded from GitHub is
byte-identical to the local build (`1e4b2754…dc9e45`), staples cleanly, and
reports `source=Notarized Developer ID`.

`v0.10.0` was released the same way as its predecessors. Notarization
`Accepted`, submission `c44e85d4-2a95-49ba-8394-f50ac9eb8690`; the zip
re-downloaded from GitHub is byte-identical to the local build
(`c8c7c207…8eb058`), staples cleanly, and reports
`source=Notarized Developer ID`.

**Fullscreen (2026-09-07).** ⌘F added to `installKeyMonitor` alongside ⌘P, plus
`Controller.toggleFullscreen`, `PresenterSettings.fullscreen`, an early return in
`applyMargin`, a reset in `hide()`, and an Esc branch in `handleKey`.
`PresenterContent` passes `cornerRadius: 0` / `showsBorder: false` down to
`SlideCanvas` while fullscreen. README and `cards/panel-windows.md` updated.
Verified running: ⌘F covers the menu bar edge to edge and the exit path
restores the windowed size.

`v0.11.0` was released the same way as its predecessors. Notarization
`Accepted`, submission `2173cf92-40a9-4cd0-b453-32456b892a5a`; the zip
re-downloaded from GitHub is byte-identical to the local build
(`b38f819f…58316c`), staples cleanly, and reports
`source=Notarized Developer ID`.

**`innerMargin` and the SVG fade (2026-09-07).** Two small changes, both
verified running: the `## Theme` key `innerMargin` (default `48`, the old
hard-coded padding) now drives the inset from the panel edge to the slide
content, and `SVGBackgroundView` fades up over 0.4s on `didFinish` instead of
snapping in. README, `cards/theme-system.md`, `cards/architecture.md`, and
`theme-demo.md` (now `innerMargin: 64`) updated.

`v0.12.0` was released the same way as its predecessors. Notarization
`Accepted`, submission `516a0752-c182-421d-a073-07f40c6ff779`; the zip
re-downloaded from GitHub is byte-identical to the local build
(`ffb62bf3…fdf611`), staples cleanly, and reports
`source=Notarized Developer ID`.

**PDF gradient fix (2026-09-07).** A user-exported deck (`CH137.md`) came
out with black backgrounds on every slide — no theme colour, no `bg:` photos. Cause and fix are in the decision
above and in `cards/pdf-export.md`. Verified by re-exporting that deck through
a temporary env-var hook in `AppDelegateShim` (removed again) and rasterizing
the pages: the theme colour, the background photos, and the gradient ramps all
render, and the neutralised-gradient slides are unchanged. The ⌘P path itself
was not re-exercised by hand.

`v0.12.1` was released the same way as its predecessors. Notarization
`Accepted`, submission `ac1141ba-b569-43f9-8705-b98787b662a7`; the zip
re-downloaded from GitHub is byte-identical to the local build
(`36a6e614…503500`), staples cleanly, reports
`source=Notarized Developer ID`, and its `Info.plist` reads `0.12.1` — the
last check being new, and the reason the stale-bundle bug above was found.

Next agent: nothing is mid-flight, and nothing is blocked.

## Open questions

- Is the faint red corner-trigger tint (`systemRed` at 0.12 alpha) meant to
  ship, or is it a development aid that should default to invisible?
