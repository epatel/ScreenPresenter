# Screen Presenter — notes for Claude

A macOS-only SwiftUI/AppKit hybrid that renders markdown decks in a floating
borderless panel triggered by hovering the top-right corner of the screen.
The whole app lives in `Sources/ScreenPresenter/main.swift` — no other
source files. Keep it that way unless there's a strong reason to split.

## Build / run

```sh
swift build                              # debug build into .build/
swift run                                # default deck (./sample.md)
swift run ScreenPresenter <file>.md      # specific deck
swift run ScreenPresenter <file>.md template=NAME   # override theme
make app                                 # full .app bundle (signs with .env)
```

There are no tests — this is a UI app. Verify changes by running it. UI
changes need a screenshot or live check; type-checking only catches a
fraction of the regressions.

## House style

- **One file.** Keep new code adjacent to its peers in `main.swift` rather
  than appending to the bottom, and preserve the `// MARK:` sections.
- **No comments unless the *why* is non-obvious.** Most of `main.swift` is
  uncommented. Match that.
- **Never report a UI change as working on the strength of a clean build.**

## When asked to push

Don't push without explicit confirmation. The repo is `main`-only with
no protected branches but commits are user-reviewed before pushing.

## Project plan

@project-plan.md — read it before starting work and update the "Current
state / handoff" section before finishing. Pass it to any subagent or
worktree you spawn so they share the same objective.

## Cards

Reference cards under `cards/`. Open one when its trigger matches the
situation; they are self-contained and none references another.

### Architecture
- [architecture](cards/architecture.md) — onboarding, tracing data flow end to end, or working across more than one part of `main.swift`

### Domains
- [theme-system](cards/theme-system.md) — anything touching colors, fonts, templates, or a slide that should look different from its deck
- [markdown-parsing](cards/markdown-parsing.md) — a deck renders wrong, or you need to know exactly which markdown syntax is supported
- [panel-windows](cards/panel-windows.md) — the overlay doesn't appear, sits at the wrong level, ignores a key, or its corners/border look off
- [packaging](cards/packaging.md) — building the `.app`, signing, notarizing, bumping the version, or Finder not recognizing `.md` files

### Features
- [youtube-embeds](cards/youtube-embeds.md) — a video won't play, a YouTube URL isn't recognized, or you're touching the loopback server
- [photo-folder-decks](cards/photo-folder-decks.md) — someone points the app at a directory instead of a `.md` file
- [config-panel](cards/config-panel.md) — the Shift-hover controls, or a font/size/shade setting behaving unexpectedly across decks

### Decisions
- [single-file-main-swift](cards/single-file-main-swift.md) — you're tempted to add a source file or split `main.swift`
- [no-tests-visual-verification](cards/no-tests-visual-verification.md) — you're about to call a UI change done, or wondering where the tests are
- [demo-mode-replaces-deck](cards/demo-mode-replaces-deck.md) — `template=demo` shows fewer slides than expected, or you're changing theme previews

Keep this index and the cards current: new non-obvious logic gets a
feature card, a debated choice gets a decision card, a stale card gets
updated or deleted.
