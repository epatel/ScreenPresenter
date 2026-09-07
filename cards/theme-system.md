# theme-system

Colors, fonts, bundled templates, and how a per-slide theme override reaches every view that draws.

## Purpose

Let a deck pick a visual identity from a `## Theme` block in its markdown, a
`template=NAME` CLI flag, or per-key hex overrides — and let a single slide
override the whole deck's theme.

## The type

```swift
struct DeckTheme {
    let textColor: Color
    let accentColor: Color
    let backgroundColor: Color
    let codeBackground: Color
    let fontName: String
    let defaultBackground: String?
    let templateName: String
    var defaultGradient: SlideGradient? = nil
    var lineSpacing: CGFloat = 0
    var innerMargin: CGFloat = 48
}
```

`defaultGradient`, `lineSpacing` and `innerMargin` are the `var`s, and each
carries a default so the ten bundled entries need no argument for them. Declare any future optional
addition the same way rather than editing all ten. `lineSpacing` defaults to
`0` because that is SwiftUI's own default — an existing deck lays out
unchanged.

`DeckTheme.bundled` is a `[String: DeckTheme]` of 10 templates. Palette
entries are built with the private helpers `rgb(r, g, b, a = 1)` and
`gray(w, a = 1)`, which wrap `NSColor(calibratedRed:...)`.
`DeckTheme.default()` returns the `dark` template.

## Bundled templates

| Name | Font | Vibe |
|---|---|---|
| `dark` | Inter | Minimal dark, yellow accent (the default) |
| `ocean` | Playfair Display | Cool blues and cyan |
| `sunset` | Merriweather | Warm oranges and pinks |
| `forest` | Space Grotesk | Deep greens and lime |
| `minimal` | JetBrains Mono | High-contrast black and white |
| `neon` | Space Grotesk | Cyberpunk cyan/magenta on black |
| `warm` | Georgia | Earthy browns and golds |
| `cool` | Inter | Purples and cool grays |
| `candy` | Space Grotesk | Playful pastels |
| `ink` | Merriweather | Navy and cream, print-like |

Plus the pseudo-template `demo`, which is not in the dictionary — it is a
sentinel that swaps the deck for one preview slide per bundled template.

## Resolution order

1. `Deck.parseTheme` reads a leading `## Theme` (or `# Theme`) block from the
   first slide. Any following `#`/`##`/`###` heading ends the block; the rest
   of that slide is kept as real content.
2. Lines are parsed as `key: value`. `template` selects the base theme
   (unknown names fall back to `DeckTheme.default()`); `textColor`,
   `accentColor`, `backgroundColor`, `codeBackground` accept `#rrggbb`;
   `font` and `defaultBackground` are plain strings; `lineSpacing` and
   `innerMargin` are numbers of points (`innerMargin` clamped to 0–200);
   `defaultGradient` takes the same `key=value` spec as the per-slide
   directive. Anything omitted inherits from the base template.
3. A `template=NAME` CLI argument overrides the inline choice entirely — it
   replaces the theme struct, so inline hex overrides are discarded too.
4. If the effective template is `demo`, the deck is replaced wholesale.

`colorFromHex` requires exactly six hex digits after stripping `#`; anything
else silently falls back to the base template's swatch.

## Gradients

`SlideGradient` (angle, `from`, `to`, `startColor`, `endColor`) renders as a
`LinearGradient` above the slide background. Two design points that are easy
to break:

- **It replaces the flat darken overlay, not stacks with it.**
  `PresenterContent.backgroundOverlay` picks *one* of gradient / shade /
  nothing. Stacking them double-darkens the image, and the config panel's
  Shade slider is consequently inert on gradient slides.
- **It applies with no background image**, unlike the shade — that is what
  lets a gradient be the background.

Resolution is `slide.gradient ?? theme.defaultGradient`, mirroring how the
slide's own theme override beats the deck's.

The angle convention is CSS's: `0` is top-to-bottom and increases clockwise.
Since SwiftUI's y grows downward, the direction vector is `(sin θ, cos θ)`,
and the axis is that vector centred on `(0.5, 0.5)`. `from`/`to` become the
locations of two `Gradient.Stop`s, which is what produces the hold-fade-hold
shape for free — SwiftUI extends the first and last stops to the edges.

## Threading the theme through views

The deck theme lives on `PresenterSettings.theme` and is set in two places:
`Controller.init` and `Controller.loadDeck`. But `settings.theme` is the
**deck-level** theme — do not read it for content that a single slide can
override.

`PresenterContent.currentTheme` returns `slide.themeOverride ?? deck.theme`.
That value must be passed explicitly to:

- the slide background fill and `strokeBorder` in `PresenterContent`
- `MarkdownSlide` (drives both font and text color)
- `CodeBlockView` (drives the code background fill)

Any new view that draws themed content must take a `theme` parameter the same
way. `Slide.themeOverride` holds an actual `DeckTheme` struct, not a template
name to be looked up later.

## Font fallback

`MarkdownSlide.font(size:)` and `PresenterSettings.font(size:)` use the
theme's `fontName` only when the user's explicit choice is the literal string
`"System"`. This is why `Controller.loadDeck` resets `settings.fontName` to
`"System"` — writing a theme-specific font name there would permanently
shadow the user's ability to pick a font in the config panel.

Five fonts ship in the bundle (Inter, Space Grotesk, Merriweather, Playfair
Display, JetBrains Mono) and are registered at launch by `FontLoader`, which
scans `Fonts/` in both `Bundle.main` and `Bundle.module`. `warm` uses Georgia,
a system font, not a bundled one.

## Gotchas

- **`lineSpacing` is applied once, on `MarkdownSlide`'s `VStack`**, and reaches
  every `Text` under it — headings, bullets, and paragraphs. `CodeBlockView`
  resets it to `0`, since a syntax-highlighted listing has its own rhythm. It
  adds to the leading *within* a wrapped block; the 18pt gap *between* blocks is
  the stack's own `spacing` and is not configurable.

- **`innerMargin` is the deck-side counterpart of the config panel's Margin
  slider**, and the two are deliberately separate: the outer margin describes
  the display and persists in `UserDefaults`, while `innerMargin` describes the
  deck and travels with the file. It is applied on `SlideCanvas`'s
  `columnsView` and so also reaches the PDF export; the page-number label keeps
  its own fixed 16pt inset.

- **An SVG background fades in, an image background does not.** `NSImage`
  decodes synchronously, so a photo is there on the first frame; the web view
  behind an SVG paints only after its load finishes, so `SVGBackgroundView`
  holds it transparent and fades it up on `didFinish`. Slides therefore change
  their SVG backgrounds with a 0.4s cross-over against the theme color, not a
  snap.

- **Light themes need a dark `codeBackground`.** The syntax theme is a fixed
  `atom-one-dark`, so a light code background makes highlighted text
  unreadable. Check this when adding a template.
- **Use `rgb`/`gray`, not `Color` literals.** Uncalibrated literals like
  `.white` and `.black` render inconsistently against the panel's transparent
  background; the helpers go through `NSColor(calibratedRed:...)`.
- **Border opacity.** The panel border uses `theme.textColor.opacity(0.35)`.
  Lowering it makes the border invisible on light templates — this has
  regressed before.
