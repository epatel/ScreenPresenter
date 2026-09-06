# Screen Presenter

A minimal markdown-driven slide overlay for macOS. Hover the top-right
corner of the screen to open a dialog-style presenter; slides render over
a dimmed backdrop with no menus, toolbars, or window chrome.

## Features

- Borderless dialog overlay, dismisses on Esc or click outside
- Per-slide **background images** with automatic darken-for-readability overlay
- **Gradient overlays** — angle, fade range, and two colours with alpha; over an
  image or as the background itself
- **SVG backgrounds** render live, so animated SVGs keep animating
- **Photo decks** — point the app at a folder and get one slide per image
- Inline **images** and **two-column** layouts
- **YouTube embeds** via `![alt](https://youtu.be/ID?t=20)` — shows the thumbnail, click to play full-panel
- Syntax-highlighted **code blocks** (Highlightr, `atom-one-dark`, ~190 languages)
- **10 bundled themes** (`## Theme` section in markdown, or `template=NAME` flag) plus per-key color/font overrides
- Five bundled Google Fonts (Inter, Space Grotesk, Merriweather, Playfair Display, JetBrains Mono)
- **Shift-hover** opens a live-config panel: font family, font size, per-slide shade, and outer margin
- **⌘P exports the deck as a PDF** — one page per slide, selectable text, clickable links
- **Drop a `.md` file** onto the app in Finder to load it
- Remembers the last viewed slide between opens

## Quick start

```sh
swift run                       # uses ./sample.md
swift run ScreenPresenter deck.md
```

After the first open, move the mouse to the top-right corner of the main screen
to show the presenter. A faint red 40×40 zone marks the trigger area (set its
alpha to 0 in `buildCornerTrigger` to hide it).

## Opening a deck

Three ways to point the app at a `.md` file:

```sh
# 1. CLI arg (dev build only):
swift run ScreenPresenter deck.md

# 2. Drop the .md onto ScreenPresenter.app in Finder, or right-click ->
#    "Open With" -> ScreenPresenter. When the app isn't running this launches
#    it with the file; when it is, the deck is swapped in place.

# 3. From the terminal, targeting the installed .app:
open -a ~/Applications/ScreenPresenter.app deck.md
```

A dropped file resets the slide index to 0 and clears any per-slide shade
settings from the previous deck.

### Photo decks

Any of those three routes also accepts a **folder** instead of a `.md` file:

```sh
swift run ScreenPresenter ~/Pictures/trip
open -a ~/Applications/ScreenPresenter.app ~/Pictures/trip
```

Every image directly inside the folder becomes one slide, ordered the way
Finder orders them (so `img2.png` precedes `img10.png`). Recognized
extensions are `jpg`, `jpeg`, `png`, `heic`, `heif`, `gif`, `webp`, `tiff`,
`tif`, and `bmp`; subdirectories and other files are skipped, and a folder
with no images shows a single "No images in folder" slide.

Each image is used as the slide background so it fills the panel, and the
darken-for-readability overlay is switched off — there is no text to keep
legible. Photo decks always use the default theme; a folder has nowhere to
declare one.

> **Note:** while the presenter is visible, the app temporarily elevates from
> `LSUIElement` (no dock icon) to a regular app so the window server actually
> renders the floating panel. A dock icon appears briefly; dismissing the
> panel (Esc / click outside) reverts to dockless.

## Controls

| Key | Action |
|---|---|
| Space, →, Return | Next slide |
| ← | Previous slide |
| Esc, click outside | Dismiss |
| Esc (while a video is playing) | Close the video, stay on the slide |
| Space / ← / → (while a video is playing) | Close the video and navigate |
| ⌘P | Export the deck as a PDF |
| Shift while hovering corner | Open with config panel |
| ⌘Q (while config panel is focused) | Quit |

## PDF export

Press **⌘P** while the presenter is open. A save panel appears, and the deck is
written as one page per slide at the panel's current size — so the exported
pages match what is on screen, outer margin and all.

Everything the panel draws is exported: backgrounds, gradients, per-slide
shade, columns, syntax-highlighted code, and images. Text stays real text in
the PDF rather than a picture of text. Two things are stills rather than live
views — a YouTube slide exports as its thumbnail with the play badge, and an
animated `.svg` background exports as a single frame.

Links stay clickable. A `[label](url)` is a link on the page it lands on, and
keeps working when the label wraps across two lines; a YouTube thumbnail
becomes a link to the video, start offset included.

## Markdown syntax

Standard markdown plus a few presentation-specific directives.

````markdown
# Slide title

Regular paragraph with **bold**, *italic*, and `inline code`.

- Bullet one
- Bullet two

![caption](images/photo.png)

![gallery](images/one.png, images/two.png)

![talk](https://youtu.be/ID?t=20)

---                   <- slide separator

<!-- bg: images/hero.jpg -->

# Slide with a background

Left column.

|||                   <- column separator

Right column.

```swift
let greeting = "hello"
```
````

Supported directives:

| Syntax | Effect |
|---|---|
| `---` on its own line | New slide |
| <code>\|\|\|</code> on its own line | Split slide into two columns |
| `<!-- bg: path -->` | Per-slide background image (raster or `.svg`) |
| `<!-- gradient: ... -->` | Per-slide gradient overlay (see below) |
| `<!-- anything else -->` | Comment — not rendered |
| ` ```lang ` fenced block | Syntax-highlighted code |
| `![alt](path)` | Image — path relative to the `.md` file, absolute, or `~/...` |
| `![alt](a.png, b.png)` | Slideshow — cross-fades between the images in place |
| `![alt](<url>)` | YouTube — URL forms listed below |

### Block vs. inline syntax

Block structure is deliberately narrow — headings (`#`, `##`, `###`), bullets
(`-` or `*`), paragraphs, fenced code, images, and the directives above.
Tables, blockquotes, numbered lists, and nested bullets are **not** supported
and render as literal text.

Inline styling inside those blocks is full markdown, so `**bold**`,
`*italic*`, `` `code` ``, `[links](url)`, and `~~strikethrough~~` all work.

### Gradients

A gradient draws above the slide background — over a background image, or
straight over the theme's fill colour when there is no image. It is written
as space-separated `key=value` pairs, and may wrap across lines:

```markdown
<!-- bg: images/boat.jpg -->
<!-- gradient: angle=0 from=0.6 to=1 start=#000000@0.85 end=#000000@0.0 -->
```

| Key | Meaning | Default |
|---|---|---|
| `angle` | Degrees. `0` is top→bottom, increasing clockwise — `90` is left→right, `180` bottom→top, `270` right→left | `0` |
| `from` | Normalized position (`0`–`1`) where the fade begins | `0` |
| `to` | Normalized position where the fade completes | `1` |
| `start` | Colour before `from`, as `#rrggbb` or `#rrggbb@alpha` | transparent |
| `end` | Colour after `to` | black at 0.6 |

The start colour is held flat from `0` to `from`, interpolates to the end
colour between `from` and `to`, then holds flat through to `1`. With
`angle=0` position `0` is the top edge, so the example above holds 85% black
across the top 60% of the slide, then fades out over the remaining 40% to
reach fully clear at the bottom edge.

That flat plateau is the point of `from`: text sitting in the top 60% gets a
uniform backdrop rather than a gradient running through it, and the image
reads through along the bottom.

Omitted keys take their defaults, and unknown keys are ignored. `from` and
`to` are clamped into `0`–`1`, and are swapped if given out of order.

> **A gradient replaces the automatic darken overlay** rather than stacking
> with it — it *is* the readability treatment, and applying both muddies the
> image. The config panel's Shade slider therefore has no effect on a slide
> with a gradient.

Set `defaultGradient` in the theme block to apply one to every slide; a
slide's own `<!-- gradient: ... -->` overrides it.

### SVG backgrounds

`<!-- bg: ... -->` accepts an `.svg` path as well as a raster image. SVGs take
a different route: rather than being rasterized into a still frame, the file
is inlined into a minimal HTML document and rendered live in a `WKWebView`, so
SMIL and CSS animations inside the SVG keep playing behind the slide.

The same applies to a `defaultBackground` in the theme block.

### YouTube embeds

Any `![alt](<url>)` whose URL points at YouTube is rendered as a 16:9
thumbnail with a play badge. Clicking promotes the IFrame player to fill
the whole presenter panel; Esc closes it and returns to the slide
underneath, and Space / arrow keys close the video while navigating.

Accepted URL forms:

- `https://youtu.be/VIDEO_ID`
- `https://www.youtube.com/watch?v=VIDEO_ID`
- `https://www.youtube.com/shorts/VIDEO_ID`
- `https://www.youtube.com/embed/VIDEO_ID`

A start offset may be supplied via `?t=` or `?start=`; values are either
seconds (`20`) or a compound of `h`/`m`/`s` (`1m30s`, `1h2m3s`).

> **How it works.** YouTube's IFrame API rejects `file://` and the
> synthetic origin that `loadHTMLString` produces, so the app spins up a
> tiny `NWListener` on `127.0.0.1` and serves the embed page from
> `http://127.0.0.1:<port>/`. The bundle therefore ships with
> `NSAllowsLocalNetworking=true` in `Info.plist` — a narrow ATS
> exception that only permits cleartext http to loopback / `.local`
> hosts. No other http traffic is allowed.

## Themes

Define a `## Theme` section at the start of your markdown to configure colors, font, and a default background:

````markdown
## Theme

template: ocean
font: Playfair Display
textColor: #ffffff
accentColor: #00bfff
backgroundColor: #05204d
codeBackground: #001a33
defaultBackground: images/bg.jpg

---

# Your first slide
````

Theme properties (`key: value`):

| Property | Effect | Default |
|---|---|---|
| `template` | Bundled theme name (or `demo` to browse all) | `dark` |
| `font` | Font name (bundled or system) | template's |
| `textColor` | Text color (hex `#rrggbb`) | template's |
| `accentColor` | Highlight color (hex) | template's |
| `backgroundColor` | Slide background fill (hex) | template's |
| `codeBackground` | Code block background (hex) | template's |
| `defaultBackground` | Path to default background image | none |
| `defaultGradient` | Gradient overlay for every slide (same keys as the directive) | none |

Any property left out inherits from the named `template`. Hex colors override the template's individual swatches.

### Bundled templates (10)

| Template | Font | Vibe |
|---|---|---|
| `dark` | Inter | Minimal dark with yellow accent |
| `ocean` | Playfair Display | Cool blues and cyan |
| `sunset` | Merriweather | Warm oranges and pinks |
| `forest` | Space Grotesk | Deep greens and lime |
| `minimal` | JetBrains Mono | High contrast black and white |
| `neon` | Space Grotesk | Cyberpunk cyan and magenta on black |
| `warm` | Georgia | Earthy browns and golds |
| `cool` | Inter | Purples and cool grays |
| `candy` | Space Grotesk | Playful pastels |
| `ink` | Merriweather | Navy and cream, print-like |

### Applying a template

```sh
# 1. Inline in markdown (## Theme section)
template: ocean

# 2. CLI flag — overrides the inline choice for this run
swift run ScreenPresenter deck.md template=sunset
open -a ~/Applications/ScreenPresenter.app deck.md template=cool
```

The CLI flag only affects the deck it's launched with; subsequent file drops use whatever each dropped file declares.

### Demo mode

Set `template: demo` (or pass `template=demo`) to **replace** the deck with one preview slide per bundled template. Each preview shows that template's colors, font, and a sample code block — useful for picking a theme before committing.

## Config panel

Hover the top-right corner **while holding Shift** to open a second panel
below the presenter with live controls:

- **Font** — 5 bundled Google Fonts + System + common installed fonts (overrides the theme's font for this session)
- **Size** — 14–40pt (scales headings proportionally; code blocks render at 0.75×)
- **Shade** — 0.0–1.0, applied per slide and persisted for the session
- **Margin** — 0–400pt of space between the panel and the screen edges; resizes the presenter live

Font, Size, and Shade are in-memory only and reset when the app quits.
**Margin is remembered between launches** — it describes your display rather
than the deck.

The margin is the literal gap at each edge, so `0` fills the screen (below the
menu bar) and `200` leaves 200pt all round. The panel has no maximum size —
how large it gets is entirely yours to set.

A slide with a gradient ignores the **Shade** slider, since a gradient
replaces the automatic darken overlay rather than stacking with it.

## Building a distributable `.app`

All packaging is driven by the `Makefile`. Run `make` with no target to
list them.

```sh
make release       # swift build -c release
make icon          # build/AppIcon.icns from icon.png (1024×1024)
make app           # build/ScreenPresenter.app (also refreshes Launch Services)
make open          # launch the built .app
make register      # force-refresh Launch Services for the built .app
```

`make app` runs `lsregister -f` on the bundle automatically so Finder
picks up the document-type associations without a restart. `make register`
is available if you've moved the `.app` elsewhere and need a standalone
refresh.

### Signing and notarization

Copy `.env.example` to `.env` and fill in your Developer credentials:

```sh
SIGNING_IDENTITY = Developer ID Application: Your Name (TEAMID)
APPLE_ID         = you@example.com
TEAM_ID          = XXXXXXXXXX
APP_PASSWORD     = xxxx-xxxx-xxxx-xxxx   # app-specific password
```

Then:

```sh
make sign          # codesign with hardened runtime
make verify        # check signature + Gatekeeper assessment
make notarize      # submits .zip, waits for notary result
make staple        # staple the ticket to the .app
make dmg           # build/ScreenPresenter-<VERSION>.dmg
```

The Makefile also supports optional overrides in `.env` for
`APP_NAME`, `DISPLAY_NAME`, and `BUNDLE_ID`.

### Version management

Displayed version is `a.b.c (d)`:

- **`a.b.c`** — marketing version from `VERSION`, written to `CFBundleShortVersionString`.
- **`d`** — build number from `git rev-list --count HEAD`, written to `CFBundleVersion`.

Both are substituted into `Info.plist` at `make app` time.

```sh
make version       # e.g. "0.1.0 (12)"
make bump-patch    # 0.1.0 -> 0.1.1
make bump-minor    # 0.1.0 -> 0.2.0
make bump-major    # 0.1.0 -> 1.0.0
```

## Project layout

```
Package.swift               SwiftPM executable + Fonts as resources
Sources/ScreenPresenter/
  main.swift                entire app
  Fonts/                    bundled Google Fonts (.ttf, variable)
Resources/
  Info.plist.template       placeholders substituted by make app
  entitlements.plist        minimal; enables hardened runtime
Makefile                    build/sign/notarize/dmg pipeline
VERSION                     semver, read by Makefile and Info.plist
icon.png                    1024×1024 source; make icon -> .icns
sample.md                   default deck demonstrating syntax
theme-demo.md               example with a `## Theme` section
images/                     assets referenced by sample.md
.env.example                signing/notary credentials template
```

## Requirements

- macOS 13+
- Xcode command-line tools (`swift`, `codesign`, `sips`, `iconutil`, `xcrun notarytool`)
- Apple Developer ID certificate for signing + notarization

## License

MIT — see [LICENSE](LICENSE).
