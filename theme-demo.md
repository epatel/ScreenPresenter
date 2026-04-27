## Theme

template: demo
font: Inter

---

# Welcome to Theme Demo

Hover top-right corner to show the presenter.

---

## Customize Your Theme

Add a `## Theme` section at the start of your markdown:

```
## Theme
template: ocean
font: Playfair Display
primaryColor: #0078a6
textColor: #ffffff
```

Available templates:
- dark, ocean, sunset, forest
- minimal, neon, warm, cool
- candy, ink

---

## Use template=NAME

Run with any template:

```bash
swift run ScreenPresenter deck.md template=ocean
open -a ScreenPresenter.app deck.md template=sunset
```

Or embed in markdown Theme section.

---

## Custom Colors

Override individual colors:

```
## Theme
template: dark
primaryColor: #ff00ff
textColor: #00ff00
accentColor: #ffff00
backgroundColor: #000000
font: JetBrains Mono
```

---

## Default Background

Set a default background for all slides:

```
## Theme
template: minimal
defaultBackground: images/bg.jpg
```

Slides can still override with `<!-- bg: path -->`.

---

# Try template: demo

Set `template: demo` in your Theme section to see all bundled themes as slides!
