import AppKit
import CoreText
import Highlightr
import SwiftUI

// MARK: - Font registration

enum FontLoader {
    // Register every .ttf/.otf in a bundled Fonts directory. Tries Bundle.main
    // first (inside the .app) then Bundle.module (SPM dev build).
    static func registerBundledFonts() {
        let candidates: [Bundle] = [.main, .module]
        for bundle in candidates {
            guard let dir = bundle.url(forResource: "Fonts", withExtension: nil) else { continue }
            let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for url in files where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
                var err: Unmanaged<CFError>?
                if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &err) {
                    NSLog("ScreenPresenter: failed to register font \(url.lastPathComponent): \(err?.takeRetainedValue().localizedDescription ?? "unknown")")
                }
            }
            return  // stop at the first bundle that had the Fonts dir
        }
    }
}

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

// MARK: - Settings (live-adjustable via the config panel)

final class PresenterSettings: ObservableObject {
    @Published var fontName: String = "System"
    @Published var baseFontSize: CGFloat = 24
    @Published private var shadeByIndex: [Int: Double] = [:]

    static let defaultShade: Double = 0.45
    static let fontOptions = [
        "System",
        // Bundled Google Fonts (loaded at launch from Resources/Fonts).
        "Inter", "Space Grotesk",
        "Merriweather", "Playfair Display",
        "JetBrains Mono",
        // System-installed fallbacks.
        "SF Mono", "Menlo", "Monaco",
        "Georgia", "Times New Roman",
        "Helvetica Neue", "Avenir Next", "Palatino",
    ]

    func shade(for index: Int) -> Double {
        shadeByIndex[index] ?? Self.defaultShade
    }

    func setShade(_ v: Double, for index: Int) {
        shadeByIndex[index] = v
    }

    func resetPerSlideSettings() {
        shadeByIndex.removeAll()
    }

    func font(size: CGFloat) -> Font {
        if fontName == "System" {
            return .system(size: size)
        }
        return .custom(fontName, size: size)
    }

    func nsFont(size: CGFloat, monospaced: Bool = false) -> NSFont {
        if monospaced {
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
        if fontName == "System" {
            return NSFont.systemFont(ofSize: size)
        }
        return NSFont(name: fontName, size: size) ?? NSFont.systemFont(ofSize: size)
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
    @EnvironmentObject var settings: PresenterSettings

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

    private var base: CGFloat { settings.baseFontSize }

    @ViewBuilder
    private func render(block: Block) -> some View {
        switch block {
        case .heading(1, let s):
            Text(inline(s)).font(settings.font(size: base * 2.33)).fontWeight(.bold)
        case .heading(2, let s):
            Text(inline(s)).font(settings.font(size: base * 1.67)).fontWeight(.semibold)
        case .heading(_, let s):
            Text(inline(s)).font(settings.font(size: base * 1.25)).fontWeight(.semibold)
        case .bullet(let s):
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("•").font(settings.font(size: base))
                Text(inline(s)).font(settings.font(size: base))
            }
        case .paragraph(let s):
            Text(inline(s)).font(settings.font(size: base))
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
    @EnvironmentObject var settings: PresenterSettings

    static let highlightr: Highlightr = {
        let h = Highlightr()!
        h.setTheme(to: "atom-one-dark")
        return h
    }()

    var body: some View {
        Text(highlighted(size: settings.baseFontSize * 0.75))
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.55))
            )
    }

    private func highlighted(size: CGFloat) -> AttributedString {
        Self.highlightr.theme.setCodeFont(
            NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        )
        let lang = language.isEmpty ? nil : language
        let ns = Self.highlightr.highlight(source, as: lang)
            ?? NSAttributedString(string: source)
        return AttributedString(ns)
    }
}

// MARK: - Presenter state

final class PresenterState: ObservableObject {
    @Published var index: Int = 0
    @Published var deck: Deck

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
    // Bool parameter: true if Shift was held when the mouse entered.
    var onEnter: ((Bool) -> Void)?

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
        let shift = event.modifierFlags.contains(.shift)
        NSLog("ScreenPresenter: mouseEntered corner shift=\(shift)")
        onEnter?(shift)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { self }
}

// MARK: - Presenter view (panel contents)

struct PresenterContent: View {
    @ObservedObject var state: PresenterState
    @EnvironmentObject var settings: PresenterSettings

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let bg = backgroundImage
        let shadeAmount = settings.shade(for: state.index)
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
                .overlay(bg != nil ? Color.black.opacity(shadeAmount) : Color.clear)
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

// MARK: - Config panel (opened when the corner is entered with Shift held)

struct ConfigPanelView: View {
    @ObservedObject var settings: PresenterSettings
    @ObservedObject var state: PresenterState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Settings").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("Slide \(state.index + 1) of \(state.deck.slides.count)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            row("Font") {
                Menu {
                    ForEach(PresenterSettings.fontOptions, id: \.self) { name in
                        Button(name) { settings.fontName = name }
                    }
                } label: {
                    HStack {
                        Text(settings.fontName)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .contentShape(Rectangle())
                }
                .menuIndicator(.hidden)
                .menuStyle(.button)
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }

            row("Size") {
                Slider(value: $settings.baseFontSize, in: 14...40, step: 1)
                Text("\(Int(settings.baseFontSize))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, alignment: .trailing)
            }

            row("Shade") {
                Slider(value: shadeBinding, in: 0...1, step: 0.05)
                Text(String(format: "%.2f", shadeBinding.wrappedValue))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, alignment: .trailing)
            }

            HStack {
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q", modifiers: [.command])
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(.white)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: NSColor(calibratedWhite: 0.12, alpha: 0.97)))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var shadeBinding: Binding<Double> {
        Binding(
            get: { settings.shade(for: state.index) },
            set: { settings.setShade($0, for: state.index) }
        )
    }

    @ViewBuilder
    private func row<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 60, alignment: .leading)
            content()
        }
    }
}

// MARK: - App controller

final class Controller: NSObject, NSWindowDelegate {
    let state: PresenterState
    let settings = PresenterSettings()
    var panel: PresenterPanel!
    var panelBaseSize: NSSize = .zero
    var configPanel: NSPanel?
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

    // Called when macOS hands us a file via Finder drop / "Open With" / `open -a`.
    func loadDeck(from url: URL) {
        let newDeck = Deck.load(from: url.path)
        state.deck = newDeck
        state.index = 0
        settings.resetPerSlideSettings()
        NSLog("ScreenPresenter: loaded deck \(url.lastPathComponent) with \(newDeck.slides.count) slides")
        // Show the presenter immediately so the user sees the result of the drop.
        if !isShown { show(withConfig: false) }
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
        p.canHide = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.onKey = { [weak self] code in self?.handleKey(code) }

        let host = NSHostingView(
            rootView: PresenterContent(state: state).environmentObject(settings)
        )
        host.frame = p.contentView!.bounds
        host.autoresizingMask = [.width, .height]
        p.contentView?.addSubview(host)
        panel = p
        panelBaseSize = rect.size
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
        view.onEnter = { [weak self] shift in self?.show(withConfig: shift) }
        win.contentView = view
        win.orderFrontRegardless()
        NSLog("ScreenPresenter: corner trigger at \(rect)")
        corner = win
    }

    @objc func dismiss() {
        hide()
    }

    private func show(withConfig: Bool) {
        guard !isShown else { return }
        isShown = true
        if state.index > 0 { state.next() }
        recenterPanel()
        // Promote to a regular app while visible so the window server actually
        // renders our floating panel; accessory-policy apps can have panels
        // silently not-display when orderFront is called from a non-active state.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        backdrop.orderFront(nil)
        panel.makeKeyAndOrderFront(nil)
        if withConfig { showConfigPanel() }
    }

    // Restore the panel to its original size and center it on visibleFrame.
    // showConfigPanel() may resize/reposition afterward if needed.
    private func recenterPanel() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let rect = NSRect(
            x: vf.midX - panelBaseSize.width / 2,
            y: vf.midY - panelBaseSize.height / 2,
            width: panelBaseSize.width,
            height: panelBaseSize.height
        )
        panel.setFrame(rect, display: true)
    }

    private func hide() {
        guard isShown else { return }
        isShown = false
        panel.orderOut(nil)
        backdrop.orderOut(nil)
        configPanel?.orderOut(nil)
        configPanel = nil
        // Go back to being a dockless utility.
        NSApp.setActivationPolicy(.accessory)
    }

    private func showConfigPanel() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let w: CGFloat = 540
        let h: CGFloat = 170
        let gap: CGFloat = 16
        let margin: CGFloat = 20

        // Fit the presenter+config pair inside visibleFrame: shrink the presenter
        // if needed, then center the whole group vertically.
        var pFrame = panel.frame
        let maxPanelH = vf.height - h - gap - margin * 2
        if pFrame.height > maxPanelH {
            pFrame.size.height = max(maxPanelH, 300)
        }
        let totalH = pFrame.height + gap + h
        pFrame.origin.x = vf.midX - pFrame.width / 2
        pFrame.origin.y = vf.midY + totalH / 2 - pFrame.height
        panel.setFrame(pFrame, display: true)

        let rect = NSRect(
            x: vf.midX - w / 2,
            y: pFrame.minY - gap - h,
            width: w, height: h
        )
        let cp = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        cp.isFloatingPanel = true
        cp.level = .floating
        cp.isOpaque = false
        cp.backgroundColor = .clear
        cp.hasShadow = true
        cp.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let host = NSHostingView(
            rootView: ConfigPanelView(settings: settings, state: state)
        )
        host.frame = cp.contentView!.bounds
        host.autoresizingMask = [.width, .height]
        cp.contentView?.addSubview(host)
        cp.orderFront(nil)
        configPanel = cp
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

FontLoader.registerBundledFonts()

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

    // Fires on: drop onto the .app in Finder, "Open With", or `open -a ... file.md`.
    // Covers both cold-launch and while-running cases.
    // Deferred to the next runloop tick because on cold launch this can fire
    // before the window server is fully ready for our floating panel.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        DispatchQueue.main.async { [controller] in
            controller.loadDeck(from: url)
        }
    }
}
