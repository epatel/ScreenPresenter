# panel-windows

The AppKit window layer — borderless panel, backdrop, corner trigger — and the interop rules that keep it rendering.

## Purpose

Present a floating, chromeless overlay on top of whatever the user is doing,
triggered by a hover target rather than by a dock icon or menu.

## The four windows

All owned by `Controller`, built in `Controller.start()`.

| Window | Type | Level | Role |
|---|---|---|---|
| backdrop | `NSWindow`, `.borderless` | `.floating` | Full-screen dim (`calibratedWhite: 0, alpha: 0.55`). A click gesture on its content view dismisses the presenter. |
| panel | `PresenterPanel` (`NSPanel` subclass), `[.borderless, .nonactivatingPanel]` | `.floating` | Hosts the SwiftUI tree. Clear background, `hasShadow = true`, `isFloatingPanel = true`, `hidesOnDeactivate = false`, `canHide = false`. |
| corner trigger | `NSWindow`, `.borderless` | `.statusBar` | 40×40 at the top-right of `screen.visibleFrame`, faintly red-tinted (`systemRed` at 0.12 alpha) so the zone is discoverable. Set the alpha to 0 to hide it. |
| config panel | `NSPanel`, created lazily | — | Live controls, shown below the presenter when the corner is entered with Shift held. |

The backdrop and panel both use `collectionBehavior = [.canJoinAllSpaces,
.fullScreenAuxiliary]` so they appear over full-screen apps and follow the
user across Spaces.

The corner trigger sits inside `visibleFrame`, not `frame` — the menu bar
would otherwise eat the hit-testing at the true screen corner.

## Panel sizing

Driven by the user's **outer margin** (`PresenterSettings.outerMargin`):

```swift
width  = max(320, visibleFrame.width  - margin * 2)
height = max(240, visibleFrame.height - margin * 2)
```

The margin is the literal gap at every edge — margin 0 is full-bleed within
`visibleFrame`. Default is 40.

`Controller.panelBaseSize` is a *computed* property over that formula, not a
stored size — so anything reading it picks up the current margin.
`centerPanel(size:)` centers an arbitrary size on `visibleFrame`;
`recenterPanel()` is the no-argument form using `panelBaseSize`.

**There is deliberately no maximum size, and reintroducing one is a trap.**
The panel was originally `min(1100, width * 0.75) × min(720, height * 0.75)`,
and the first version of the margin control kept that cap. It made the slider
feel broken: a cap already insets the panel by whatever slack it leaves — 126pt
horizontally on a 1352pt-wide display — so every margin below that value
changed nothing at all. A cap and a margin control cannot both own the panel's
size.

The 320×240 floors are a different thing: they only bite at the extreme end of
the slider, where the margin would otherwise leave no panel.

`Controller.marginObserver` is a Combine subscription that relays slider
changes to `applyMargin(_:)`. It reads the **emitted** value rather than
`settings.outerMargin`, because `@Published` fires in `willSet` and the
stored property is still stale inside the sink.

## SwiftUI interop

The panel's `contentView` gets an `NSHostingView` added as a subview, framed
to the content bounds with `autoresizingMask = [.width, .height]`. The hosting
view's root is `PresenterContent(state:)` with `PresenterSettings` and
`VideoPlayback` injected as environment objects.

**The rounded shape comes from SwiftUI, not AppKit.** Setting a corner radius
on the AppKit `contentView`'s layer does not take. The geometry is:

- `cornerRadius` 20, content padding 48
- structure is `Color.clear.background(theme.backgroundColor).clipShape(shape)`
  inside a `ZStack`, with `shape.strokeBorder(...)` as a **sibling**, not a
  modifier

Do not rewrite that to `shape.fill(...)` inside the `ZStack` without an
explicit frame — the rounded corners draw off-screen. This has regressed
before.

## Keyboard

`PresenterPanel` overrides `keyDown` and forwards the key code to an `onKey`
closure, which `Controller` sets to `handleKey`. A separate local event
monitor (`installKeyMonitor`) runs ahead of the responder chain: it is the
only place ⌘-modified keys (⌘P, ⌘F) arrive, since this app has no menu bar,
and while a video plays it also lets Esc close the video instead of the panel
and Space/arrows close the video while navigating.

| Key | Action |
|---|---|
| Space, →, Return | Next slide |
| ← | Previous slide |
| Esc, click outside | Dismiss |
| Esc while fullscreen | Leave fullscreen |
| Esc while a video plays | Close the video, stay on the slide |
| Space / ← / → while a video plays | Close the video and navigate |
| ⌘F | Toggle fullscreen |
| ⌘P | Export the deck as a PDF |
| Shift while entering the corner | Show with the config panel |
| ⌘Q while the config panel is focused | Quit |

## Fullscreen (⌘F)

`toggleFullscreen` sets the panel to the whole `screen.frame` — menu bar
included — which only works if it climbs above `.mainMenu`: the panel goes to
`.screenSaver` and the backdrop one level below it, both restored to
`.floating` on exit and in `hide()`. `settings.fullscreen` drives the view
side, zeroing the corner radius and dropping the border, and it makes the
Margin slider inert (`applyMargin` returns early) — the margin describes the
windowed size and is restored on exit. Entering fullscreen closes the config
panel, since nothing would be visible beside the deck.

## The activation-policy flip

The app normally runs as `.accessory` (`LSUIElement` — no dock icon). A panel
attached to an `.accessory` app sometimes refuses to render, so `Controller`
flips `NSApp.setActivationPolicy` to `.regular` when showing the panel and
back to `.accessory` when dismissing. A dock icon appears briefly during
presentation; that is intentional, not a bug.

**Do not remove or reorder that flip without testing the cold-launch path** —
the failure mode is a completely invisible panel on first show, which no
amount of type-checking catches.

## Mouse handling

`Controller.mouseMonitor` watches for entry into the corner window's
`CornerView`. Shift state at entry time decides whether the config panel opens
alongside the presenter.

## Verifying changes

There are no tests. If you touch padding, `cornerRadius`, `strokeBorder`, or
the `.clipShape` chain, compare against the original look: `git stash`,
`swift run`, capture, restore. Visual regressions are easy to introduce and
nearly invisible in a diff. Known past regressions are the `strokeBorder`
opacity (must stay around 0.35 to be visible on light backgrounds) and the
`Color.clear.background(...).clipShape(...)` chain described above.
