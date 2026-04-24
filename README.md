# Screen Presenter

A minimal markdown-driven slide overlay for macOS. Hover the top-right
corner of the screen to open a dialog-style presenter; slides render over
a dimmed backdrop with no menus, toolbars, or window chrome.

## Features

- Borderless dialog overlay, dismisses on Esc or click outside
- Per-slide **background images** with automatic darken-for-readability overlay
- Inline **images** and **two-column** layouts
- Syntax-highlighted **code blocks** (Highlightr, `atom-one-dark`, ~190 languages)
- Five bundled Google Fonts (Inter, Space Grotesk, Merriweather, Playfair Display, JetBrains Mono)
- **Shift-hover** opens a live-config panel: font family, font size, per-slide shade
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
| Shift while hovering corner | Open with config panel |
| ⌘Q (while config panel is focused) | Quit |

## Markdown syntax

Standard markdown plus a few presentation-specific directives.

````markdown
# Slide title

Regular paragraph with **bold**, *italic*, and `inline code`.

- Bullet one
- Bullet two

![caption](images/photo.png)

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
| `<!-- bg: path -->` | Per-slide background image |
| ` ```lang ` fenced block | Syntax-highlighted code |
| `![alt](path)` | Image — path relative to the `.md` file, absolute, or `~/...` |
| `![alt](https://youtu.be/ID?t=20)` | YouTube — shows the thumbnail; click to play inline. Accepts `youtu.be/ID`, `youtube.com/watch?v=ID`, `/shorts/ID`, with optional `t=`/`start=` |

## Config panel

Hover the top-right corner **while holding Shift** to open a second panel
below the presenter with live controls:

- **Font** — 5 bundled Google Fonts + System + common installed fonts
- **Size** — 14–40pt (scales headings proportionally; code blocks render at 0.75×)
- **Shade** — 0.0–1.0, applied per slide and persisted for the session

Settings are in-memory only and reset when the app quits.

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
  main.swift                entire app (~800 lines)
  Fonts/                    bundled Google Fonts (.ttf, variable)
Resources/
  Info.plist.template       placeholders substituted by make app
  entitlements.plist        minimal; enables hardened runtime
Makefile                    build/sign/notarize/dmg pipeline
VERSION                     semver, read by Makefile and Info.plist
icon.png                    1024×1024 source; make icon -> .icns
sample.md                   default deck demonstrating syntax
images/                     assets referenced by sample.md
.env.example                signing/notary credentials template
```

## Requirements

- macOS 13+
- Xcode command-line tools (`swift`, `codesign`, `sips`, `iconutil`, `xcrun notarytool`)
- Apple Developer ID certificate for signing + notarization

## License

MIT.
