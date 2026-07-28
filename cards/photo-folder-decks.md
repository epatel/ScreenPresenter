# photo-folder-decks

Pointing the app at a directory instead of a `.md` file turns it into a photo slideshow.

## Trigger

Any deck path that `FileManager` reports as a directory — from the CLI, a
Finder drop, "Open With", or `open -a`. `Deck.load` checks `isDirectory` first
and delegates to `Deck.loadFolder`.

This mode is not mentioned in the README; it only exists in `loadFolder`.

## Steps

1. List the directory's immediate contents (non-recursive — subdirectories are
   ignored).
2. Keep files whose lowercased extension is one of: `jpg`, `jpeg`, `png`,
   `heic`, `heif`, `gif`, `webp`, `tiff`, `tif`, `bmp`.
3. Sort by filename using `localizedStandardCompare`, which gives Finder-style
   natural ordering — `img2.png` sorts before `img10.png`.
4. Emit one `Slide` per image with the filename as the slide **background**
   and an empty text column, so the image fills the panel rather than being
   laid out as inline content.
5. `baseDir` is the folder itself, and the theme is `DeckTheme.default()`
   (the `dark` template). A folder cannot declare a theme.

## Shade reset

`Controller.loadDeck` detects that the loaded path was a directory and
explicitly sets the per-slide shade to `0` for every slide. Markdown decks get
the usual darken-for-readability overlay on background images so text stays
legible; a photo deck has no text, so the overlay would just dim the photos
for no reason.

## Invariants

- Exactly one slide per matching image file, in sorted order.
- No text is ever rendered over a photo slide.
- Reloading the same folder re-reads the directory — files added since the
  last load appear.

## Failure modes

- **No matching images** → a single slide reading `# No images in folder`.
  Not an error, and not an empty deck.
- **Unreadable directory** → `contentsOfDirectory` throws, is swallowed, and
  the result is the same "no images" slide.
- **Mixed content** → non-image files are silently skipped; a folder of
  markdown files loads as "no images", not as a deck.
- Extension matching is by filename only, so a mislabeled file produces a
  slide with a broken background.
