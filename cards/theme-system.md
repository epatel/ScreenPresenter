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
}
```

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
   `font` and `defaultBackground` are plain strings. Anything omitted
   inherits from the base template.
3. A `template=NAME` CLI argument overrides the inline choice entirely — it
   replaces the theme struct, so inline hex overrides are discarded too.
4. If the effective template is `demo`, the deck is replaced wholesale.

`colorFromHex` requires exactly six hex digits after stripping `#`; anything
else silently falls back to the base template's swatch.

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

- **Light themes need a dark `codeBackground`.** The syntax theme is a fixed
  `atom-one-dark`, so a light code background makes highlighted text
  unreadable. Check this when adding a template.
- **Use `rgb`/`gray`, not `Color` literals.** Uncalibrated literals like
  `.white` and `.black` render inconsistently against the panel's transparent
  background; the helpers go through `NSColor(calibratedRed:...)`.
- **Border opacity.** The panel border uses `theme.textColor.opacity(0.35)`.
  Lowering it makes the border invisible on light templates — this has
  regressed before.
