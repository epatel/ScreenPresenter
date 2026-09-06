## Theme

template: ocean
lineSpacing: 4

---

# Theme Demo

Hover the top-right corner to show the presenter.

This deck explains the theme system. To *browse* all ten bundled themes
instead, run it with `template=demo`.

---

## Customize your theme

Add a `## Theme` section at the very start of your markdown:

```
## Theme

template: ocean
font: Playfair Display
textColor: #ffffff
accentColor: #00bfff
lineSpacing: 4
```

`lineSpacing` is extra leading between lines of text, in points. This deck
uses `4`.

Available templates:

- dark, ocean, sunset, forest
- minimal, neon, warm, cool
- candy, ink

Anything you leave out inherits from the named `template`.

---

## Every theme key

- `template` — bundled theme to start from
- `font` — font name, bundled or installed
- `textColor` — body and heading text
- `accentColor` — highlights
- `backgroundColor` — slide fill
- `codeBackground` — code block fill
- `defaultBackground` — image behind every slide
- `defaultGradient` — gradient overlay on every slide

Those eight are the *only* keys read. Anything else is ignored silently.

|||

```
## Theme

template: dark
font: JetBrains Mono
textColor: #00ff88
accentColor: #ffcc00
backgroundColor: #000000
codeBackground: #101014
```

Colors are `#rrggbb`. A malformed value falls back to the template's own,
silently — check your slide if a color seems ignored.

---

### Careful with codeBackground

Syntax highlighting is fixed to `atom-one-dark`, which assumes a **dark**
background.

On a light template like `minimal` or `ink`, leaving `codeBackground` light
makes highlighted code nearly unreadable. Set it to a dark color explicitly:

```
## Theme

template: minimal
codeBackground: #1b1f24
```

---

## Use template=NAME

Override the deck's own choice for a single run:

```bash
swift run ScreenPresenter deck.md template=ocean
open -a ScreenPresenter.app deck.md template=sunset
```

The flag beats the `## Theme` block, and it applies *only* to the deck it
launched with — a file dropped on the running app uses whatever that file
declares.

---

<!-- bg: images/abstract-bg.svg -->

## Default background

Set one image behind every slide:

```
## Theme

template: minimal
defaultBackground: images/abstract-bg.svg
```

Individual slides still override it with `<!-- bg: path -->`.

Raster or vector both work — this slide's is an SVG.

---

<!-- gradient: angle=180 from=0.0 to=0.75 start=#0f1733@0.9 end=#3a1d52@0.35 -->

## Default gradient

`defaultGradient` puts a gradient on every slide, with the same keys the
per-slide directive takes:

```
## Theme

template: ink
defaultGradient: angle=0 from=0.2 to=1 start=#000000@0.0 end=#000000@0.7
```

A slide's own `<!-- gradient: ... -->` overrides it. A gradient replaces the
automatic darken overlay rather than stacking with it, so the Shade slider
has no effect on these slides.

---

# Browse every theme

Run with `template=demo` to replace the deck with one preview slide per
bundled theme:

```bash
swift run ScreenPresenter theme-demo.md template=demo
```

It *replaces* the deck rather than adding to it — the point is picking a
theme, not presenting.
