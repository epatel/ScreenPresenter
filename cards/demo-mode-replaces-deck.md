# demo-mode-replaces-deck

Why `template: demo` throws away your slides instead of adding preview slides to them.

## The choice

When the effective template resolves to the string `demo` — from either a
`template: demo` line in the markdown's theme block or a `template=demo` CLI
argument — `Deck.load` returns a deck whose slides are entirely generated:
one preview slide per bundled template, sorted by name. The user's own slides
are discarded for that run.

A 30-slide deck launched with `template=demo` shows **10 slides, not 40**.

## Alternatives considered

- **Append** the 10 previews after the user's content.
- **Prepend** them before it.
- **A separate flag** (`--browse-themes`) that doesn't reuse the `template`
  key at all.
- **A dedicated demo deck file** shipped in the repo (which is roughly what
  `theme-demo.md` is, for a different purpose).

## Why this won

- The point of demo mode is *browsing themes to pick one*, not presenting.
  Nobody in that mode wants to arrow through 30 slides of real content first,
  or discover previews stranded at the end.
- Reusing the `template` key means demo mode works identically from the
  markdown and from the CLI, with no extra argument parsing.
- Being destructive is safe here: it only affects the in-memory deck for one
  run. No file is modified, and removing the `demo` value restores the deck.

## How the previews are built

`generateThemeDemo()` iterates `DeckTheme.bundled` sorted by key and emits a
two-column slide per template, each carrying that template as its
`themeOverride` so the slide renders in its own colors and font:

- **Left column** — the template name as an H1, its font name, a sample H3,
  a paragraph with bold and italic, three bullets, and the `template=NAME`
  string to copy.
- **Right column** — a Swift code block, so the template's `codeBackground`
  is visible against the fixed `atom-one-dark` syntax colors.

Because each slide carries a `themeOverride`, this is also the best available
regression check for per-slide theming: if overrides stop flowing through to
text, fonts, or code backgrounds, every demo slide renders identically in the
deck's theme instead of its own.

## Gotchas

- `demo` is a **sentinel, not a dictionary entry.** It is not in
  `DeckTheme.bundled`, so the deck's own theme resolves through the normal
  unknown-name fallback to the default. Adding a real template named `demo`
  would be shadowed by the sentinel check.
- The CLI override wins over the inline value, so `template=dark` on a deck
  declaring `template: demo` presents the real deck — and `template=demo` on
  any deck browses themes.

## When to revisit

If demo mode grows a second purpose — say, previewing a *specific* subset of
templates, or previewing a user's custom hex overrides against their own
content — the replacement behavior stops being obviously right and the flag
should split into something explicit.
