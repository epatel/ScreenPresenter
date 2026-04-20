import AppKit
import Highlightr
import SwiftUI

// MARK: - Slide model

struct Slide {
    let background: String?
    let columns: [String]

    static func parse(_ raw: String) -> Slide {
        var bg: String?
        var kept: [String] = []
        for line in raw.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("<!--"), t.hasSuffix("-->"), t.contains("bg:") {
                let inner = t.replacingOccurrences(of: "<!--", with: "")
                             .replacingOccurrences(of: "-->", with: "")
                             .trimmingCharacters(in: .whitespaces)
                if inner.hasPrefix("bg:") {
                    bg = String(inner.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    continue
                }
            }
            kept.append(line)
        }
        let body = kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let cols = body.components(separatedBy: "\n|||\n").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return Slide(background: bg, columns: cols)
    }
}

struct Deck {
    let baseDir: URL
    let slides: [Slide]

    static func load(from path: String) -> Deck {
        let url = URL(fileURLWithPath: path)
        let baseDir = url.deletingLastPathComponent()
        let fallback = """
        # Screen Presenter

        Move mouse to top-right corner to open.

        ---

        ## Controls

        - **Space** or **→** — next
        - **←** — previous
        - **Esc** — dismiss
        """
        let content = (try? String(contentsOfFile: path, encoding: .utf8)) ?? fallback
        let slides = content.components(separatedBy: "\n---\n").map { Slide.parse($0) }
        return Deck(baseDir: baseDir, slides: slides)
    }
}

// MARK: - Markdown rendering

enum Block {
    case heading(Int, String)
    case bullet(String)
    case paragraph(String)
    case image(alt: String, path: String)
    case code(language: String, source: String)
    case blank
}

struct MarkdownSlide: View {
    let text: String
    let baseDir: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                render(block: block)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var blocks: [Block] { Self.parse(text) }

    @ViewBuilder
    private func render(block: Block) -> some View {
        switch block {
        case .heading(1, let s):
            Text(inline(s)).font(.system(size: 56, weight: .bold))
        case .heading(2, let s):
            Text(inline(s)).font(.system(size: 40, weight: .semibold))
        case .heading(_, let s):
            Text(inline(s)).font(.system(size: 30, weight: .semibold))
        case .bullet(let s):
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("•").font(.system(size: 24))
                Text(inline(s)).font(.system(size: 24))
            }
        case .paragraph(let s):
            Text(inline(s)).font(.system(size: 24))
        case .blank:
            Spacer().frame(height: 8)
        case .image(_, let path):
            if let nsImg = loadImage(path) {
                Image(nsImage: nsImg)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .cornerRadius(8)
            } else {
                Text("[missing image: \(path)]")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.8))
            }
        case .code(let lang, let source):
            CodeBlockView(language: lang, source: source)
        }
    }

    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s)) ?? AttributedString(s)
    }

    private func loadImage(_ path: String) -> NSImage? {
        let expanded = (path as NSString).expandingTildeInPath
        let url: URL = expanded.hasPrefix("/")
            ? URL(fileURLWithPath: expanded)
            : baseDir.appendingPathComponent(expanded)
        return NSImage(contentsOf: url)
    }

    static func parse(_ text: String) -> [Block] {
        var blocks: [Block] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                i += 1
                while i < lines.count {
                    if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        i += 1
                        break
                    }
                    code.append(lines[i])
                    i += 1
                }
                blocks.append(.code(language: lang, source: code.joined(separator: "\n")))
                continue
            }
            if let img = parseImage(line) {
                blocks.append(.image(alt: img.alt, path: img.path))
            } else if line.hasPrefix("# ") {
                blocks.append(.heading(1, String(line.dropFirst(2))))
            } else if line.hasPrefix("## ") {
                blocks.append(.heading(2, String(line.dropFirst(3))))
            } else if line.hasPrefix("### ") {
                blocks.append(.heading(3, String(line.dropFirst(4))))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                blocks.append(.bullet(String(line.dropFirst(2))))
            } else if trimmed.isEmpty {
                blocks.append(.blank)
            } else {
                blocks.append(.paragraph(line))
            }
            i += 1
        }
        return blocks
    }

    static func parseImage(_ line: String) -> (alt: String, path: String)? {
        let pattern = #"^\s*!\[([^\]]*)\]\(([^)]+)\)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let m = regex.firstMatch(in: line, range: range),
              let altR = Range(m.range(at: 1), in: line),
              let pathR = Range(m.range(at: 2), in: line) else { return nil }
        return (String(line[altR]), String(line[pathR]))
    }
}

// MARK: - Code block with syntax highlighting

struct CodeBlockView: View {
    let language: String
    let source: String

    static let highlightr: Highlightr = {
        let h = Highlightr()!
        h.setTheme(to: "atom-one-dark")
        h.theme.setCodeFont(NSFont.monospacedSystemFont(ofSize: 18, weight: .regular))
        return h
    }()

    var body: some View {
        Text(highlighted)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.55))
            )
    }

    private var highlighted: AttributedString {
        let lang = language.isEmpty ? nil : language
        let ns = Self.highlightr.highlight(source, as: lang)
            ?? NSAttributedString(string: source)
        return AttributedString(ns)
    }
}

// MARK: - Presenter state

final class PresenterState: ObservableObject {
    @Published var index: Int = 0
    let deck: Deck

    init(deck: Deck) { self.deck = deck }

    func next() { if index < deck.slides.count - 1 { index += 1 } }
    func prev() { if index > 0 { index -= 1 } }

    var currentSlide: Slide {
        guard !deck.slides.isEmpty else { return Slide(background: nil, columns: [""]) }
        return deck.slides[index]
    }

    var baseDir: URL { deck.baseDir }
}

// MARK: - Panel (borderless, focusable)

final class PresenterPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    var onKey: ((UInt16) -> Void)?

    override func keyDown(with event: NSEvent) {
        onKey?(event.keyCode)
    }
}

// MARK: - Corner trigger view

final class CornerView: NSView {
    var onEnter: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        NSLog("ScreenPresenter: mouseEntered corner")
        onEnter?()
    }

    // Ensure hit testing works on a fully transparent view.
    override func hitTest(_ point: NSPoint) -> NSView? { self }
}

// MARK: - Presenter view (panel contents)

struct PresenterContent: View {
    @ObservedObject var state: PresenterState

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let bg = backgroundImage
        ZStack(alignment: .bottomTrailing) {
            // Background fills the whole frame. Color.clear provides the sizing;
            // the image (if any) paints behind it via .background.
            Color.clear
                .background(
                    Group {
                        if let img = bg {
                            Image(nsImage: img).resizable().scaledToFill()
                        } else {
                            Color(nsColor: NSColor(calibratedWhite: 0.10, alpha: 1.0))
                        }
                    }
                )
                .overlay(bg != nil ? Color.black.opacity(0.45) : Color.clear)
                .clipShape(shape)

            shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1)

            columnsView
                .foregroundStyle(.white)
                .padding(48)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text("\(state.index + 1) / \(state.deck.slides.count)")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .padding(16)
        }
        .clipShape(shape)
    }

    @ViewBuilder
    private var columnsView: some View {
        let cols = state.currentSlide.columns
        if cols.count > 1 {
            HStack(alignment: .top, spacing: 40) {
                ForEach(Array(cols.enumerated()), id: \.offset) { _, col in
                    MarkdownSlide(text: col, baseDir: state.baseDir)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        } else {
            MarkdownSlide(text: cols.first ?? "", baseDir: state.baseDir)
        }
    }

    private var backgroundImage: NSImage? {
        guard let path = state.currentSlide.background else { return nil }
        let expanded = (path as NSString).expandingTildeInPath
        let url: URL = expanded.hasPrefix("/")
            ? URL(fileURLWithPath: expanded)
            : state.baseDir.appendingPathComponent(expanded)
        return NSImage(contentsOf: url)
    }
}

// MARK: - App controller

final class Controller: NSObject, NSWindowDelegate {
    let state: PresenterState
    var panel: PresenterPanel!
    var backdrop: NSWindow!
    var corner: NSWindow!
    var mouseMonitor: Any?
    var isShown = false

    init(deck: Deck) {
        self.state = PresenterState(deck: deck)
    }

    func start() {
        buildBackdrop()
        buildPanel()
        buildCornerTrigger()
    }

    // Full-screen darkened window behind the panel.
    private func buildBackdrop() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.55)
        win.level = .floating
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.orderOut(nil)
        backdrop = win

        // Click on backdrop dismisses.
        let click = NSClickGestureRecognizer(target: self, action: #selector(dismiss))
        let container = NSView(frame: screen.frame)
        container.addGestureRecognizer(click)
        win.contentView = container
    }

    private func buildPanel() {
        guard let screen = NSScreen.main else { return }
        let w: CGFloat = min(1100, screen.frame.width * 0.75)
        let h: CGFloat = min(720, screen.frame.height * 0.75)
        let rect = NSRect(
            x: screen.frame.midX - w / 2,
            y: screen.frame.midY - h / 2,
            width: w, height: h
        )
        let p = PresenterPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.onKey = { [weak self] code in self?.handleKey(code) }

        let host = NSHostingView(rootView: PresenterContent(state: state))
        host.frame = p.contentView!.bounds
        host.autoresizingMask = [.width, .height]
        p.contentView?.addSubview(host)
        panel = p
    }

    // Small window at the top-right corner that triggers show on mouse enter.
    // Placed inside `visibleFrame` so the menu bar doesn't block hit-testing.
    private func buildCornerTrigger() {
        guard let screen = NSScreen.main else { return }
        let size: CGFloat = 40
        let vf = screen.visibleFrame
        let rect = NSRect(
            x: vf.maxX - size,
            y: vf.maxY - size,
            width: size, height: size
        )
        let win = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        // Very faint tint so the zone is discoverable. Set alpha to 0 to hide.
        win.backgroundColor = NSColor.systemRed.withAlphaComponent(0.12)
        win.level = .statusBar
        win.ignoresMouseEvents = false
        win.hasShadow = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let view = CornerView(frame: NSRect(origin: .zero, size: rect.size))
        view.onEnter = { [weak self] in self?.show() }
        win.contentView = view
        win.orderFrontRegardless()
        NSLog("ScreenPresenter: corner trigger at \(rect)")
        corner = win
    }

    @objc func dismiss() {
        hide()
    }

    private func show() {
        guard !isShown else { return }
        isShown = true
        // Resume by advancing from the last viewed slide, but stay on the first
        // slide if we never moved past it. next() clamps at the last slide.
        if state.index > 0 { state.next() }
        NSApp.activate(ignoringOtherApps: true)
        backdrop.orderFront(nil)
        panel.makeKeyAndOrderFront(nil)
    }

    private func hide() {
        guard isShown else { return }
        isShown = false
        panel.orderOut(nil)
        backdrop.orderOut(nil)
    }

    private func handleKey(_ code: UInt16) {
        switch code {
        case 49, 124, 36: state.next()   // space, right arrow, return
        case 123:         state.prev()   // left arrow
        case 53:          hide()         // escape
        default: break
        }
    }
}

// MARK: - Bootstrap

let args = CommandLine.arguments
let resolvedPath: String = {
    if args.count > 1 { return args[1] }
    // When running from the .app bundle, fall back to Resources/sample.md.
    if let bundled = Bundle.main.path(forResource: "sample", ofType: "md") {
        return bundled
    }
    return "sample.md"
}()
let deck = Deck.load(from: resolvedPath)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let controller = Controller(deck: deck)
let delegate = AppDelegateShim(controller: controller)
app.delegate = delegate
app.run()

final class AppDelegateShim: NSObject, NSApplicationDelegate {
    let controller: Controller
    init(controller: Controller) { self.controller = controller }
    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
    }
}
