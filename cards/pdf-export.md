# pdf-export

⌘P while the presenter is open writes the deck to a PDF, one page per slide.

## Trigger

`Controller.installKeyMonitor` — the same local `NSEvent` monitor that
intercepts keys during video playback. Command-modified keys never reach
`PresenterPanel.keyDown`, because AppKit routes them through the menu bar and
`performKeyEquivalent` first, and this app has no menu. The monitor runs ahead
of the responder chain, so it catches ⌘P whether or not a video is playing.

The handler dispatches into a `Task { @MainActor }` rather than calling
directly: `exportPDF` runs a modal save panel, which must not start on the
event's own stack.

## Flow

1. `Controller.exportPDF` closes any playing video, then runs an `NSSavePanel`
   through `withPanelsBelowModal`, which drops the presenter, backdrop, and
   config panel from `.floating` to `.normal` for the duration. Without that
   the panels sit *above* the save panel. The deck is not hidden — that would
   lose the current slide.
2. `PDFExporter.write` prefetches (below), then renders each slide with
   `ImageRenderer` into a `CGContext` PDF, one `beginPDFPage`/`endPDFPage` per
   slide.
3. On success, Finder is opened with the file selected. On failure, an
   `NSAlert` runs through the same level dance.

## Page size

The page is the panel's current frame size, rounded. Font sizes in this app
are absolute — `baseFontSize` does not scale with the panel — so rescaling the
page to a standard paper size would re-flow the slide instead of preserving
it. The export therefore matches what is on screen, outer margin included.

## SlideCanvas

`SlideCanvas` is the slide, with no dependency on `PresenterState`, so the
panel and the exporter render through one code path. `PresenterContent` is now
just `SlideCanvas` plus the video overlay. Export passes `cornerRadius: 0`,
`showsBorder: false` (a page is not a floating panel) and
`staticBackgrounds: true`.

## What ImageRenderer cannot see

`ImageRenderer` captures SwiftUI drawing only — anything backed by an
`NSViewRepresentable` renders as nothing. Two features are affected, and both
are handled by warming a cache *before* the render pass:

- **YouTube blocks** draw a thumbnail fetched asynchronously in `.onAppear`,
  which never fires under `ImageRenderer`. `PDFExporter.prefetchThumbnails`
  walks every slide's blocks, collects the video IDs, and fills
  `YouTubeThumbnails` on a detached task. Without it, every video slide
  exports as a black rectangle.
- **SVG backgrounds** are a live `WKWebView`. `SVGSnapshot.capture` loads the
  same HTML into an offscreen web view and calls `takeSnapshot`, caching the
  still; `SlideCanvas` reads that cache when `staticBackgrounds` is set.
  `NSImage` *does* load SVG files, but its renderer handles symbol-style art
  only — both bundled backgrounds come out solid black through it, which is
  why the web view is used instead.

## Gradients export as a bitmap

CoreGraphics builds a PDF axial shading from a gradient's RGB stops and
**drops their alpha**, so an exported gradient paints fully opaque — the
theme's background colour and any `bg:` photo disappear behind a solid slab
of the gradient's colour. A single-colour, single-alpha gradient collapses to
a flat fill and is unaffected, which is why the bug hid: neutralised
gradients (`start=#000@0 end=#000@0`) looked fine while every real one wiped
the slide.

`SlideGradient.image(size:)` draws the same ramp into a bitmap with
`CGGradient`, and `backgroundOverlay` uses it in place of the vector
`LinearGradient` when `staticBackgrounds` is set. Images with alpha go into
the PDF as an `SMask`, which CoreGraphics does honour. The live panel keeps
the vector gradient.

## Two non-obvious mechanics

- **The web view needs a window.** WebKit does not composite a view with no
  window, and `takeSnapshot` then returns an empty image. `capture` parks an
  offscreen borderless `NSWindow` at `(-30000, -30000)` for the duration.
- **`RunLoop.run` does not work here.** Export runs inside a main-actor task,
  and pumping the run loop from there never delivers the WebKit callbacks —
  the load and the snapshot both silently time out. `SVGSnapshot.settle`
  awaits `Task.sleep` in 20 ms slices instead, which yields the main actor so
  those callbacks can run. This was a real bug, found because the SVG slide
  exported as a flat rectangle.

## Links

The PDF carries two kinds of link annotation, both added in a PDFKit pass over
the finished file rather than during rendering:

- **Prose links.** `[label](url)` — and bare URLs, which
  `AttributedString(markdown:)` autolinks. SwiftUI hands out no per-run
  geometry for a `Text`, so the rect cannot be measured on the way out.
  Instead `annotateLinks` searches the rendered page's own text for the
  label and takes the bounds from the resulting `PDFSelection`. This is the
  concrete reason the pages must be real text: rasterized pages would have
  nothing to search. `selectionsByLine()` gives one annotation per line, so a
  label that wraps stays fully clickable.
- **YouTube thumbnails.** No text to search for, so `LinkProbe` records the
  block's frame during the render pass via `GeometryReader` and the rect is
  converted to PDF coordinates (`y = pageHeight - maxY`). The target is
  `YouTubeLink.watchURL`, which carries the start offset.

Two details that bite:

- The page is laid out **more than once**, so a probe reports itself several
  times. `LinkRectCollector.add` compares rects at whole points — repeat
  passes can differ in the last fractional digit.
- Repeated labels on one page are paired with their URLs **in order of
  appearance**, so two links both labelled "docs" stay distinct. The
  assumption is that the extracted page text runs in the same order as the
  parsed blocks; on a two-column slide the extraction may interleave the
  columns, so two identical labels in *different columns* of the same slide
  could swap targets. Distinct labels are unaffected.

## Invariants

- Page count equals slide count.
- Text is real text in the PDF (selectable, searchable), not rasterized.
- Per-slide shade, gradients, and theme overrides all carry through, because
  the exporter reads the same `PresenterSettings` the panel is using.
- Every markdown link on a slide becomes at least one annotation, unless its
  label wraps mid-word — the search is over the label's exact characters with
  line breaks flattened to spaces.
