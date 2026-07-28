# config-panel

The Shift-hover live-settings panel: what it controls, how long the settings last, and why it can break.

## Trigger

Move the mouse into the 40×40 corner target at the top-right of the screen
**while holding Shift**. `Controller` reads the modifier state at the moment
of entry and, if Shift is down, lazily builds a second `NSPanel` positioned
below the presenter. Hovering without Shift shows the presenter alone.

## Controls

| Control | Range | Effect |
|---|---|---|
| Font | 5 bundled Google Fonts + `System` + common installed fonts | Overrides the deck theme's font for this session |
| Size | 14–40 pt | Base font size; headings scale proportionally, code blocks render at 0.75× |
| Shade | 0.0–1.0 | Darkening overlay applied over the current slide's background image |

All three live on `PresenterSettings`, an `ObservableObject`, so edits
propagate to the SwiftUI tree immediately.

## The `"System"` sentinel

`PresenterSettings.fontName` defaults to the literal string `"System"`. That
value is not a font — it is a sentinel meaning "no explicit user choice", and
both `PresenterSettings.font(size:)` and `MarkdownSlide.font(size:)` fall back
to the active theme's font when they see it.

Consequence: **never assign a theme's font name to `settings.fontName`.**
Doing so on deck load looks harmless but permanently shadows the theme —
every subsequent deck renders in the stale font, and the user's only escape is
picking a font manually. `Controller.loadDeck` deliberately resets it back to
`"System"`.

## Lifetime

- **Per session, in memory only.** Nothing here is written to `UserDefaults`;
  quitting the app resets everything to defaults.
- **Reset on deck load.** `Controller.loadDeck` calls
  `settings.resetPerSlideSettings()` and restores `fontName` to `"System"`, so
  a dropped file does not inherit the previous deck's tweaks.
- **Shade is per slide index**, not global — adjusting it on slide 3 leaves
  slide 4 alone. Because it is keyed by index, loading a different deck without
  the reset would apply slide 3's shade to the new deck's slide 3.

## Quitting

⌘Q only quits while the config panel holds focus. The presenter panel itself
is a `.nonactivatingPanel` and does not take key focus, so there is no menu
bar and no other keyboard route to quit — the config panel is the intended
exit path for a dockless run.
