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

## Architecture (top-down read of `main.swift`)

1. `FontLoader` registers `.ttf`/`.otf` from `Resources/Fonts/` at launch.
2. `DeckTheme` — palette + font + template name. 10 bundled themes in a
   static dict. Helpers `rgb(r,g,b,a)` / `gray(w,a)` keep the bundle
   readable. Fall back via `DeckTheme.default()` (= `dark`).
3. `Slide` — `background: String?`, `columns: [String]`, `themeOverride:
   DeckTheme?`. Override is the actual struct, **not** a name lookup.
4. `Deck.load(from:templateOverride:)` — splits markdown by `\n---\n`,
   pulls a leading `## Theme` block via `parseTheme`, then applies an
   optional CLI override. If the effective template is `"demo"`, the
   deck is **replaced** with `generateThemeDemo()` (one slide per
   bundled theme).
5. `PresenterSettings` — observable: font name, base size, per-slide
   shade, `theme`. The theme on settings tracks the deck's theme
   (set in `Controller.init` and `Controller.loadDeck`).
6. `MarkdownSlide` — line-by-line block parser (no Markdown library);
   takes a `theme` parameter so per-slide overrides actually flow
   through to text and code blocks.
7. `CodeBlockView` — Highlightr with `atom-one-dark`. Background fill
   uses the theme's `codeBackground` (must contrast with the dark
   syntax colors — light themes have to use a dark code bg).
8. `EmbedServer` — tiny `NWListener` on `127.0.0.1` that serves YouTube
   IFrame pages so the API gets a real http origin. See README for why.
9. `Controller` — owns the panel, backdrop, corner-trigger window,
   keyboard handling, config panel, and dock-icon activation policy.
10. `PresenterContent` — the SwiftUI view tree. `currentTheme` returns
    the slide's override or the deck's theme. Geometry: cornerRadius
    20, padding 48, structure is `Color.clear.background(...).clipShape`
    in a ZStack with `shape.strokeBorder` as a sibling.

## Conventions / gotchas

- **One file:** the whole app is in `main.swift`. Don't add files
  unless something genuinely belongs separately (e.g. a new resource
  type). Keep new code adjacent to its peers in the file.
- **No comments unless the *why* is non-obvious.** Most of `main.swift`
  is uncommented. Match that.
- **Panel rendering depends on AppKit + SwiftUI interop.** The panel is
  an `NSPanel` with a clear background hosting a SwiftUI view; the
  rounded shape comes from `.clipShape`, not from the AppKit window.
  Don't try to set `.contentView`'s corner radius — it doesn't take.
- **Per-slide theme overrides** flow through three places: the slide
  background/border in `PresenterContent`, the text rendering in
  `MarkdownSlide` (font + color), and the code block fill in
  `CodeBlockView`. If you add a new view that uses theme colors,
  thread the theme through the same way — don't read `settings.theme`
  for content that can be slide-specific (it's the deck-level theme).
- **Font fallback:** `MarkdownSlide.font(size:)` and
  `PresenterSettings.font(size:)` use the theme's font when the user's
  explicit choice is `"System"`. Setting `settings.fontName` to a
  theme-specific name on deck load *breaks* the user's ability to
  override via the config panel — keep it as `"System"` and let the
  theme drive the default.
- **Demo mode replaces the deck**, doesn't append. A 30-slide deck
  with `template: demo` shows 10 preview slides, not 40.
- **Light themes need dark code backgrounds** (the syntax theme is
  fixed `atom-one-dark`). When adding a new bundled theme, set
  `codeBackground` to a dark color or the highlighted text becomes
  unreadable.
- **`NSColor(calibratedRed:...)`** matters here — uncalibrated `Color`
  literals (`.white`, `.black`) sometimes render differently against
  the panel's transparent background. Stick with the `rgb`/`gray`
  helpers for theme palette entries.
- **CLI args:** the parser scans `CommandLine.arguments.dropFirst()`,
  picks the first positional as the path and `template=NAME` as the
  theme override. The override is *not* stored on the delegate; file
  drops onto the running app use whatever the dropped file declares.
- **macOS activation policy** flips between `.accessory` (dockless) and
  `.regular` (dock icon) when the panel is shown — a panel attached to
  an `.accessory` app sometimes refuses to render. Don't break that
  flip without testing the cold-launch path.

## When changing visuals

If you touch padding, cornerRadius, the `shape.strokeBorder`, or the
`.clipShape` chain, take a screenshot and compare against the original
look (`git stash` your changes, `swift run`, capture, restore). Visual
regressions are easy to introduce and hard to spot in a diff. Past
regressions:

- Border using `theme.textColor.opacity(...)` — invisible on light
  themes if opacity is too low. Current value `0.35` works on both.
- `Color.clear.background(theme.backgroundColor)` — gets clipped fine
  with `.clipShape(shape)`; don't rewrite to `shape.fill(...)` inside
  a ZStack without an explicit frame, or the rounded corners draw
  off-screen.

## When asked to push

Don't push without explicit confirmation. The repo is `main`-only with
no protected branches but commits are user-reviewed before pushing.
