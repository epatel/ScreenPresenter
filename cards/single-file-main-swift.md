# single-file-main-swift

Why the entire app lives in one ~1500-line file, and what that means for edits.

## The choice

All of Screen Presenter — font loading, theming, markdown parsing, SwiftUI
views, an HTTP server, and the AppKit window controller — is in
`Sources/ScreenPresenter/main.swift`. Keep it that way unless something
genuinely belongs elsewhere.

## Alternatives considered

- **One file per type** (`DeckTheme.swift`, `Controller.swift`, …) — the
  conventional Swift layout.
- **Feature folders** with a module per concern.
- **A library target** plus a thin executable, which would also make the code
  unit-testable.

## Why this won

- The app is small and single-purpose. At this size, splitting adds import
  ceremony and file-hopping without reducing anything real.
- There are no tests, so the usual "extract a library target to make it
  testable" argument does not apply. Verification is running the app and
  looking at it.
- Everything is coupled to AppKit/SwiftUI interop anyway; the seams that look
  clean on paper (parser vs. renderer) don't survive contact with
  `EnvironmentObject` plumbing and theme threading.
- Reading the file top to bottom is a genuinely good introduction to the app —
  the declaration order follows the data flow.

## What follows from it

- **Keep new code adjacent to its peers** in the file rather than appending to
  the bottom. A new theme goes in the `DeckTheme.bundled` dictionary; a new
  block type goes next to the other block cases and their renderers.
- **`// MARK:` comments are the navigation structure.** Preserve them.
- **Comment density is low.** Most of the file is uncommented; comments exist
  only where the *why* is non-obvious (the demo-mode replacement, the
  `visibleFrame` corner placement, the activation-policy flip). Match that —
  do not add explanatory comments to code that reads plainly.
- **Edits should be surgical.** A 1500-line file makes wholesale rewrites both
  tempting and dangerous; the diff review surface is the whole file.

## When to revisit

Split when one of these becomes true:

- The file passes roughly 2500 lines and `// MARK:` sections stop being enough
  to navigate it.
- A genuinely independent subsystem appears — one with no AppKit/SwiftUI
  coupling and a narrow API — that would benefit from being tested in
  isolation.
- A second executable or an app extension needs to share code, forcing a
  library target regardless.

A new *resource* type (fonts, images, plists) is not a reason to split source;
those already live outside `main.swift`.
