# no-tests-visual-verification

Why this repo has no test target, and what "verified" means instead.

## The choice

There is no test target in `Package.swift` and no test files. Changes are
verified by building and running the app, and — for anything that draws — by
comparing the result against the previous look.

## Alternatives considered

- **A library target plus unit tests** for the parsing layer (theme block,
  slide splitting, block parsing, YouTube URL parsing) — the parts that are
  genuinely pure functions.
- **Snapshot tests** of the rendered SwiftUI tree.
- **XCUITest** driving the real overlay.

## Why this won

- The surface that actually breaks is visual and AppKit-interop-shaped: panel
  visibility under the activation-policy flip, corner-radius clipping, border
  contrast on light themes, hover hit-testing near the menu bar. None of that
  is reachable from a unit test.
- Snapshot tests of a floating borderless `NSPanel` hosted in an
  `NSHostingView` are fragile against macOS version differences, and the
  maintenance cost would exceed the defect cost for an app this size.
- The pure-function layer is small and its failure modes are visible
  immediately on the first slide.
- Adding a test target would force a library/executable split that the
  single-file layout is deliberately avoiding.

## What "verified" means here

- **Type-checking catches a fraction of regressions.** A clean `swift build`
  is necessary and nowhere near sufficient — the classic failure is a panel
  that compiles fine and renders as nothing at all.
- **Run it.** `swift run ScreenPresenter <deck>.md`, open the overlay, arrow
  through the slides.
- **For visual changes, compare.** If you touch padding, `cornerRadius`,
  `strokeBorder`, or the `.clipShape` chain: `git stash`, `swift run`,
  capture, restore, capture, diff by eye. Visual regressions are easy to
  introduce and nearly invisible in a code diff.
- **Test the cold-launch path** for anything touching window creation or the
  `.accessory` ↔ `.regular` activation-policy flip. A warm relaunch can hide
  a first-show failure.
- **Exercise both a light and a dark template.** Several past regressions —
  border opacity, code-block contrast — only showed up on one side.
- **`theme-demo.md` and a `template=demo` run** are the closest thing to a
  regression suite: 10 slides, each with its own theme override, exercising
  headings, bullets, inline formatting, two columns, and code blocks.

Do not report a UI change as working on the strength of a successful build.

## When to revisit

- A pure-logic subsystem grows enough to have non-obvious edge cases worth
  pinning — the YouTube duration parser and the theme-block parser are the
  most likely first candidates.
- A regression ships twice in the same place. That is the signal that the cost
  of a library split has been paid in bugs already.
