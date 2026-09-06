import AppKit
import Combine
import CoreText
import Highlightr
import Network
import PDFKit
import SwiftUI
import WebKit

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

// MARK: - Gradient overlay

// Drawn above the slide background — image, SVG, or the theme's fill colour.
// `from`/`to` are normalized positions along the gradient axis: startColor
// holds from 0 to `from`, fades to endColor by `to`, then holds through 1.
// SwiftUI's stop handling gives the two plateaus for free.
struct SlideGradient {
    let angle: Double
    let from: Double
    let to: Double
    let startColor: Color
    let endColor: Color

    var linearGradient: LinearGradient {
        // 0 = top-to-bottom, increasing clockwise (CSS convention). Screen y
        // grows downward, so the direction vector is (sin, cos).
        let radians = angle * .pi / 180
        let dx = sin(radians) / 2
        let dy = cos(radians) / 2
        let lo = min(from, to)
        let hi = max(from, to)
        return LinearGradient(
            stops: [
                Gradient.Stop(color: startColor, location: lo),
                Gradient.Stop(color: endColor, location: hi),
            ],
            startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
            endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy)
        )
    }

    // "angle=180 from=0.35 to=1 start=#000000@0 end=#000000@0.85"
    static func parse(_ spec: String) -> SlideGradient? {
        var config: [String: String] = [:]
        for token in spec.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }) {
            guard let eq = token.firstIndex(of: "=") else { continue }
            let key = String(token[..<eq]).lowercased()
            let value = String(token[token.index(after: eq)...])
            if !key.isEmpty, !value.isEmpty { config[key] = value }
        }
        guard !config.isEmpty else { return nil }
        return SlideGradient(
            angle: config["angle"].flatMap(Double.init) ?? 0,
            from: clamp01(config["from"].flatMap(Double.init) ?? 0),
            to: clamp01(config["to"].flatMap(Double.init) ?? 1),
            startColor: config["start"].flatMap(color) ?? .clear,
            endColor: config["end"].flatMap(color) ?? Color(nsColor: NSColor(calibratedWhite: 0, alpha: 0.6))
        )
    }

    private static func clamp01(_ v: Double) -> Double { min(max(v, 0), 1) }

    // "#rrggbb" or "#rrggbb@a", where a is 0...1.
    private static func color(_ raw: String) -> Color? {
        let parts = raw.split(separator: "@", maxSplits: 1)
        let hex = parts[0].trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&rgb) else { return nil }
        let alpha = parts.count > 1 ? clamp01(Double(parts[1]) ?? 1) : 1
        return Color(nsColor: NSColor(
            calibratedRed: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: CGFloat(alpha)
        ))
    }
}

// MARK: - Theme system

struct DeckTheme {
    let textColor: Color
    let accentColor: Color
    let backgroundColor: Color
    let codeBackground: Color
    let fontName: String
    let defaultBackground: String?
    let templateName: String
    // Defaulted so the ten bundled entries below need no gradient argument.
    var defaultGradient: SlideGradient? = nil

    private static func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1.0) -> Color {
        Color(nsColor: NSColor(calibratedRed: r, green: g, blue: b, alpha: a))
    }

    private static func gray(_ w: Double, _ a: Double = 1.0) -> Color {
        Color(nsColor: NSColor(calibratedWhite: w, alpha: a))
    }

    static let bundled: [String: DeckTheme] = [
        "dark": DeckTheme(
            textColor: .white,
            accentColor: rgb(0.95, 0.75, 0.16),
            backgroundColor: gray(0.10),
            codeBackground: gray(0.0, 0.55),
            fontName: "Inter",
            defaultBackground: nil,
            templateName: "dark"
        ),
        "ocean": DeckTheme(
            textColor: .white,
            accentColor: rgb(0.12, 0.94, 0.99),
            backgroundColor: rgb(0.05, 0.25, 0.40),
            codeBackground: rgb(0.0, 0.35, 0.50, 0.6),
            fontName: "Playfair Display",
            defaultBackground: nil,
            templateName: "ocean"
        ),
        "sunset": DeckTheme(
            textColor: .white,
            accentColor: rgb(1.0, 0.85, 0.35),
            backgroundColor: rgb(0.25, 0.12, 0.10),
            codeBackground: rgb(0.40, 0.20, 0.15, 0.6),
            fontName: "Merriweather",
            defaultBackground: nil,
            templateName: "sunset"
        ),
        "forest": DeckTheme(
            textColor: .white,
            accentColor: rgb(0.70, 0.95, 0.35),
            backgroundColor: rgb(0.08, 0.20, 0.12),
            codeBackground: rgb(0.15, 0.35, 0.20, 0.6),
            fontName: "Space Grotesk",
            defaultBackground: nil,
            templateName: "forest"
        ),
        "minimal": DeckTheme(
            textColor: .black,
            accentColor: .black,
            backgroundColor: .white,
            codeBackground: gray(0.15),
            fontName: "JetBrains Mono",
            defaultBackground: nil,
            templateName: "minimal"
        ),
        "neon": DeckTheme(
            textColor: rgb(0.0, 1.0, 0.99),
            accentColor: rgb(1.0, 0.0, 0.75),
            backgroundColor: rgb(0.08, 0.08, 0.12),
            codeBackground: rgb(0.0, 0.20, 0.25, 0.7),
            fontName: "Space Grotesk",
            defaultBackground: nil,
            templateName: "neon"
        ),
        "warm": DeckTheme(
            textColor: rgb(0.98, 0.95, 0.90),
            accentColor: rgb(1.0, 0.75, 0.35),
            backgroundColor: rgb(0.20, 0.15, 0.10),
            codeBackground: rgb(0.35, 0.28, 0.20, 0.6),
            fontName: "Georgia",
            defaultBackground: nil,
            templateName: "warm"
        ),
        "cool": DeckTheme(
            textColor: .white,
            accentColor: rgb(0.70, 0.85, 1.0),
            backgroundColor: rgb(0.12, 0.12, 0.18),
            codeBackground: rgb(0.25, 0.18, 0.40, 0.6),
            fontName: "Inter",
            defaultBackground: nil,
            templateName: "cool"
        ),
        "candy": DeckTheme(
            textColor: rgb(0.30, 0.25, 0.35),
            accentColor: rgb(0.99, 0.50, 0.75),
            backgroundColor: rgb(0.98, 0.92, 0.95),
            codeBackground: rgb(0.25, 0.18, 0.25),
            fontName: "Space Grotesk",
            defaultBackground: nil,
            templateName: "candy"
        ),
        "ink": DeckTheme(
            textColor: rgb(0.98, 0.96, 0.92),
            accentColor: rgb(0.95, 0.70, 0.20),
            backgroundColor: rgb(0.12, 0.16, 0.40),
            codeBackground: rgb(0.18, 0.22, 0.45, 0.6),
            fontName: "Merriweather",
            defaultBackground: nil,
            templateName: "ink"
        ),
    ]

    static func `default`() -> DeckTheme {
        bundled["dark"]!
    }
}

// MARK: - Slide model

struct Slide {
    let background: String?
    let columns: [String]
    let themeOverride: DeckTheme?
    var gradient: SlideGradient? = nil

    static func parse(_ raw: String) -> Slide {
        var bg: String?
        var gradient: SlideGradient?
        var kept: [String] = []
        var pending: [String] = []

        // Returns false for any comment that isn't a directive, so unknown
        // comments stay in the body exactly as before.
        func consume(_ inner: String) -> Bool {
            let t = inner.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.hasPrefix("bg:") {
                bg = String(t.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                return true
            }
            if t.hasPrefix("gradient:") {
                gradient = SlideGradient.parse(String(t.dropFirst(9)))
                return true
            }
            return false
        }

        func stripDelimiters(_ s: String) -> String {
            s.replacingOccurrences(of: "<!--", with: "")
             .replacingOccurrences(of: "-->", with: "")
        }

        for line in raw.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            // Continuing a comment opened on an earlier line — gradient specs
            // are long enough to want wrapping.
            if !pending.isEmpty {
                pending.append(line)
                if t.hasSuffix("-->") {
                    if !consume(stripDelimiters(pending.joined(separator: "\n"))) {
                        kept.append(contentsOf: pending)
                    }
                    pending.removeAll()
                }
                continue
            }
            // Only a line that *starts* with the delimiter is a directive, so
            // `<!-- bg: path -->` quoted mid-sentence in prose stays inert.
            if t.hasPrefix("<!--") {
                if t.hasSuffix("-->") {
                    if consume(stripDelimiters(t)) { continue }
                } else {
                    pending.append(line)
                    continue
                }
            }
            kept.append(line)
        }
        // An unterminated comment is left verbatim rather than swallowing the
        // rest of the slide.
        kept.append(contentsOf: pending)
        let body = kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let cols = body.components(separatedBy: "\n|||\n").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return Slide(background: bg, columns: cols, themeOverride: nil, gradient: gradient)
    }
}

struct Deck {
    let baseDir: URL
    let slides: [Slide]
    let theme: DeckTheme

    static func load(from path: String, templateOverride: String? = nil) -> Deck {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            return loadFolder(URL(fileURLWithPath: path))
        }
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
        let rawSlides = content.components(separatedBy: "\n---\n")

        var theme = DeckTheme.default()
        var filteredSlides: [Slide] = []
        var inlineTemplate: String?

        if !rawSlides.isEmpty {
            if let (parsedTheme, themeContent) = parseTheme(rawSlides[0]) {
                theme = parsedTheme
                inlineTemplate = parsedTheme.templateName
                let remaining = Array(rawSlides.dropFirst()).map { Slide.parse($0) }
                filteredSlides = themeContent.isEmpty
                    ? remaining
                    : [Slide.parse(themeContent)] + remaining
            } else {
                filteredSlides = rawSlides.map { Slide.parse($0) }
            }
        }

        // CLI override wins over inline template.
        if let override = templateOverride, let overrideTheme = DeckTheme.bundled[override] {
            theme = overrideTheme
        }

        // Demo mode if either CLI or inline template is "demo". Demo slides
        // replace the deck — point of demo is browsing themes, not appending
        // 10 previews after the user's content.
        let effectiveTemplate = templateOverride ?? inlineTemplate
        if effectiveTemplate == "demo" {
            return Deck(baseDir: baseDir, slides: generateThemeDemo(), theme: theme)
        }

        return Deck(baseDir: baseDir, slides: filteredSlides, theme: theme)
    }

    private static func parseTheme(_ firstSlide: String) -> (DeckTheme, String)? {
        let lines = firstSlide.components(separatedBy: "\n")
        var inTheme = false
        var themeFound = false
        var themeLines: [String] = []
        var contentLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "## Theme" || trimmed == "# Theme" {
                inTheme = true
                themeFound = true
                continue
            }
            // A new heading ends the Theme section.
            if inTheme && (trimmed.hasPrefix("# ") || trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ")) {
                inTheme = false
            }
            if inTheme {
                if !trimmed.isEmpty { themeLines.append(line) }
            } else {
                contentLines.append(line)
            }
        }

        guard themeFound && !themeLines.isEmpty else { return nil }

        var config: [String: String] = [:]
        for line in themeLines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if !key.isEmpty { config[key] = value }
        }

        let templateName = config["template"] ?? "dark"
        let base = DeckTheme.bundled[templateName] ?? DeckTheme.default()
        let theme = DeckTheme(
            textColor: config["textColor"].flatMap(colorFromHex) ?? base.textColor,
            accentColor: config["accentColor"].flatMap(colorFromHex) ?? base.accentColor,
            backgroundColor: config["backgroundColor"].flatMap(colorFromHex) ?? base.backgroundColor,
            codeBackground: config["codeBackground"].flatMap(colorFromHex) ?? base.codeBackground,
            fontName: config["font"] ?? base.fontName,
            defaultBackground: config["defaultBackground"] ?? base.defaultBackground,
            templateName: templateName,
            defaultGradient: config["defaultGradient"].flatMap(SlideGradient.parse)
                ?? base.defaultGradient
        )

        let contentStr = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (theme, contentStr)
    }

    private static func colorFromHex(_ hex: String) -> Color? {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6 else { return nil }
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        guard scanner.scanHexInt64(&rgb) else { return nil }
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        return Color(nsColor: NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0))
    }

    private static func generateThemeDemo() -> [Slide] {
        return DeckTheme.bundled.sorted { $0.key < $1.key }.map { name, theme in
            let left = """
            # \(name.uppercased())

            **Font:** \(theme.fontName)

            ### Sample Heading

            Regular paragraph with **bold** and *italic*.

            - First bullet point
            - Second bullet point
            - Third bullet point

            Try `template=\(name)`.
            """
            let right = """
            ```swift
            struct Theme {
                let name: String
                let font: String
                let bg: Color
                let fg: Color
            }

            let \(name) = Theme(
                name: "\(name)",
                font: "\(theme.fontName)",
                bg: .background,
                fg: .text
            )

            print("Active: \\(\(name).name)")
            ```
            """
            return Slide(background: nil, columns: [left, right], themeOverride: theme)
        }
    }

    // One slide per image file in the folder, ordered by filename (Finder-style).
    // The image is used as the slide background so it fills the panel.
    static func loadFolder(_ url: URL) -> Deck {
        let exts: Set<String> = [
            "jpg", "jpeg", "png", "heic", "heif", "gif",
            "webp", "tiff", "tif", "bmp",
        ]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil
        )) ?? []
        let images = files
            .filter { exts.contains($0.pathExtension.lowercased()) }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent)
                    == .orderedAscending
            }
        if images.isEmpty {
            return Deck(
                baseDir: url,
                slides: [Slide(background: nil, columns: ["# No images in folder"], themeOverride: nil)],
                theme: .default()
            )
        }
        let slides = images.map {
            Slide(background: $0.lastPathComponent, columns: [""], themeOverride: nil)
        }
        return Deck(baseDir: url, slides: slides, theme: .default())
    }
}

// MARK: - Settings (live-adjustable via the config panel)

final class PresenterSettings: ObservableObject {
    @Published var fontName: String = "System"
    @Published var baseFontSize: CGFloat = 24
    @Published var theme: DeckTheme = .default()

    // Gap between the panel and the screen edges. Unlike the other controls
    // here this one persists — it is a property of the display, not the deck.
    @Published var outerMargin: CGFloat = PresenterSettings.loadMargin() {
        didSet { UserDefaults.standard.set(Double(outerMargin), forKey: "outerMargin") }
    }

    static let marginRange: ClosedRange<CGFloat> = 0...400
    static let defaultMargin: CGFloat = 40

    private static func loadMargin() -> CGFloat {
        guard UserDefaults.standard.object(forKey: "outerMargin") != nil else {
            return defaultMargin
        }
        let stored = CGFloat(UserDefaults.standard.double(forKey: "outerMargin"))
        return min(max(stored, marginRange.lowerBound), marginRange.upperBound)
    }
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
        let name = fontName == "System" ? theme.fontName : fontName
        if name == "System" {
            return .system(size: size)
        }
        return .custom(name, size: size)
    }

    func nsFont(size: CGFloat, monospaced: Bool = false) -> NSFont {
        if monospaced {
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
        let name = fontName == "System" ? theme.fontName : fontName
        if name == "System" {
            return NSFont.systemFont(ofSize: size)
        }
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
    }
}

// MARK: - Video playback (shared between YouTubeBlock and PresenterContent)

final class VideoPlayback: ObservableObject {
    struct Playing: Equatable {
        let videoId: String
        let start: Int
    }
    @Published var active: Playing?
}

// MARK: - Markdown rendering

enum Block {
    case heading(Int, String)
    case bullet(String)
    case paragraph(String)
    case image(alt: String, path: String)
    case slideshow(alt: String, paths: [String])
    case youtube(videoId: String, start: Int, alt: String)
    case code(language: String, source: String)
    case blank
}

// MARK: - YouTube link parsing

struct YouTubeLink {
    let videoId: String
    let start: Int

    static func from(_ urlString: String) -> YouTubeLink? {
        guard let url = URL(string: urlString), let host = url.host?.lowercased() else {
            return nil
        }
        var id: String?
        if host == "youtu.be" || host.hasSuffix(".youtu.be") {
            let p = url.path
            if p.count > 1 { id = String(p.dropFirst()) }
        } else if host.contains("youtube.com") || host.contains("youtube-nocookie.com") {
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let v = comps?.queryItems?.first(where: { $0.name == "v" })?.value {
                id = v
            } else {
                let parts = url.pathComponents.filter { $0 != "/" }
                if parts.count >= 2, ["embed", "shorts", "v", "live"].contains(parts[0]) {
                    id = parts[1]
                }
            }
        }
        guard let vid = id, !vid.isEmpty else { return nil }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let t = comps?.queryItems?.first(where: { $0.name == "t" || $0.name == "start" })?.value
        return YouTubeLink(videoId: vid, start: parseDuration(t ?? ""))
    }

    static func watchURL(videoId: String, start: Int) -> URL? {
        var comps = URLComponents(string: "https://www.youtube.com/watch")
        comps?.queryItems = [URLQueryItem(name: "v", value: videoId)]
            + (start > 0 ? [URLQueryItem(name: "t", value: "\(start)")] : [])
        return comps?.url
    }

    // Accepts "20", "20s", "1m30s", "1h2m3s".
    static func parseDuration(_ s: String) -> Int {
        if s.isEmpty { return 0 }
        if let i = Int(s) { return i }
        var total = 0
        var cur = 0
        for c in s {
            if let d = c.wholeNumberValue {
                cur = cur * 10 + d
            } else {
                switch c {
                case "h", "H": total += cur * 3600; cur = 0
                case "m", "M": total += cur * 60; cur = 0
                case "s", "S": total += cur; cur = 0
                default: break
                }
            }
        }
        return total + cur
    }
}

struct MarkdownSlide: View {
    let text: String
    let baseDir: URL
    let theme: DeckTheme
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

    private func font(size: CGFloat) -> Font {
        let name = settings.fontName == "System" ? theme.fontName : settings.fontName
        if name == "System" {
            return .system(size: size)
        }
        return .custom(name, size: size)
    }

    @ViewBuilder
    private func render(block: Block) -> some View {
        switch block {
        case .heading(1, let s):
            Text(inline(s)).font(font(size: base * 2.33)).fontWeight(.bold)
        case .heading(2, let s):
            Text(inline(s)).font(font(size: base * 1.67)).fontWeight(.semibold)
        case .heading(_, let s):
            Text(inline(s)).font(font(size: base * 1.25)).fontWeight(.semibold)
        case .bullet(let s):
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("•").font(font(size: base))
                Text(inline(s)).font(font(size: base))
            }
        case .paragraph(let s):
            Text(inline(s)).font(font(size: base))
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
        case .slideshow(_, let paths):
            let images = paths.compactMap { loadImage($0) }
            if images.isEmpty {
                Text("[missing images: \(paths.joined(separator: ", "))]")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.8))
            } else {
                SlideshowBlock(images: images)
            }
        case .youtube(let vid, let start, _):
            YouTubeBlock(videoId: vid, start: start)
        case .code(let lang, let source):
            CodeBlockView(language: lang, source: source, theme: theme)
        }
    }

    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s)) ?? AttributedString(s)
    }

    // Cached because the block list is rebuilt on every body pass, and a
    // slideshow would otherwise re-decode each of its images on every tick.
    private static var imageCache: [URL: NSImage] = [:]

    private func loadImage(_ path: String) -> NSImage? {
        let expanded = (path as NSString).expandingTildeInPath
        let url: URL = expanded.hasPrefix("/")
            ? URL(fileURLWithPath: expanded)
            : baseDir.appendingPathComponent(expanded)
        if let hit = Self.imageCache[url] { return hit }
        guard let img = NSImage(contentsOf: url) else { return nil }
        Self.imageCache[url] = img
        return img
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
                let paths = splitPaths(img.path)
                if paths.count > 1 {
                    blocks.append(.slideshow(alt: img.alt, paths: paths))
                } else if let yt = YouTubeLink.from(img.path) {
                    blocks.append(.youtube(videoId: yt.videoId, start: yt.start, alt: img.alt))
                } else {
                    blocks.append(.image(alt: img.alt, path: img.path))
                }
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

    // `![alt](a.png, b.png)` is a slideshow. Split only when every comma
    // separated piece is non-empty, so a lone path containing a comma stays one
    // path.
    static func splitPaths(_ spec: String) -> [String] {
        let parts = spec
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count > 1, !parts.contains(where: { $0.isEmpty }) else { return [spec] }
        return parts
    }
}

// Cross-fades between images in place. The frame is fixed to the aspect ratio
// of the largest image so the slide's layout does not jump as it cycles;
// smaller or differently shaped images fit inside it.
struct SlideshowBlock: View {
    let images: [NSImage]
    var interval: TimeInterval = 4
    var fade: TimeInterval = 1.2

    @State private var index = 0

    private var aspect: CGFloat {
        let largest = images.max {
            $0.size.width * $0.size.height < $1.size.width * $1.size.height
        }
        guard let size = largest?.size, size.width > 0, size.height > 0 else { return 16.0 / 9.0 }
        return size.width / size.height
    }

    var body: some View {
        ZStack {
            ForEach(Array(images.enumerated()), id: \.offset) { i, img in
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .opacity(i == index ? 1 : 0)
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .cornerRadius(8)
        .onReceive(Timer.publish(every: interval, on: .main, in: .common).autoconnect()) { _ in
            guard images.count > 1 else { return }
            withAnimation(.easeInOut(duration: fade)) {
                index = (index + 1) % images.count
            }
        }
    }
}

// MARK: - Code block with syntax highlighting

struct CodeBlockView: View {
    let language: String
    let source: String
    let theme: DeckTheme
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
                    .fill(theme.codeBackground)
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

// MARK: - YouTube block (thumbnail → inline player on click)

// Thumbnails are cached so a slide revisited mid-deck doesn't refetch, and so
// PDF export can render the same still the panel shows instead of a black box.
enum YouTubeThumbnails {
    private static let lock = NSLock()
    private static var cache: [String: NSImage] = [:]

    static func cached(_ videoId: String) -> NSImage? {
        lock.lock(); defer { lock.unlock() }
        return cache[videoId]
    }

    // Blocking. Called from a background queue by the panel, and from the
    // export prefetch — never from a render pass.
    static func fetch(_ videoId: String) -> NSImage? {
        if let hit = cached(videoId) { return hit }
        let candidates = [
            "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg",
            "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg",
        ]
        for s in candidates {
            guard let url = URL(string: s),
                  let data = try? Data(contentsOf: url),
                  let img = NSImage(data: data),
                  img.size.width > 50 else { continue }
            lock.lock(); cache[videoId] = img; lock.unlock()
            return img
        }
        return nil
    }
}

struct YouTubeBlock: View {
    let videoId: String
    let start: Int
    @State private var thumbnail: NSImage?
    @EnvironmentObject var videoPlayback: VideoPlayback
    @Environment(\.linkRectCollector) private var linkRectCollector

    var body: some View {
        ZStack {
            if let img = thumbnail ?? YouTubeThumbnails.cached(videoId) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(white: 0.12)
            }
            Image(systemName: "play.circle.fill")
                .font(.system(size: 72))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.red.opacity(0.9))
                .shadow(color: .black.opacity(0.5), radius: 10)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .overlay(exportLink)
        .onTapGesture {
            videoPlayback.active = .init(videoId: videoId, start: start)
        }
        .onAppear(perform: loadThumbnail)
    }

    // The thumbnail plays in-panel, so it is not a link on screen — but in a
    // PDF there is nothing to play, and the video's page is the useful target.
    @ViewBuilder
    private var exportLink: some View {
        if let collector = linkRectCollector,
           let url = YouTubeLink.watchURL(videoId: videoId, start: start) {
            LinkProbe(url: url, collector: collector)
        }
    }

    private func loadThumbnail() {
        guard thumbnail == nil, YouTubeThumbnails.cached(videoId) == nil else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let img = YouTubeThumbnails.fetch(videoId) else { return }
            DispatchQueue.main.async { self.thumbnail = img }
        }
    }
}

struct YouTubeWebView: NSViewRepresentable {
    let videoId: String
    let start: Int

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.underPageBackgroundColor = .black
        // YouTube's IFrame API rejects file:// and the synthetic origin that
        // loadHTMLString produces (errors 152/153). Serving the embed page
        // from a local HTTP loopback gives it a real http origin that the
        // API accepts.
        if let url = EmbedServer.shared.url(videoId: videoId, start: start) {
            wv.load(URLRequest(url: url))
        }
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: - SVG background (rendered live in WKWebView so animations play)

// Backgrounds shouldn't grab focus — refuse hit-testing so the presenter
// panel keeps first-responder status (otherwise WKWebView swallows Esc /
// arrow keys / space).
final class PassiveWebView: WKWebView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override var acceptsFirstResponder: Bool { false }
}

struct SVGBackgroundView: NSViewRepresentable {
    let url: URL

    final class Coordinator { var loadedURL: URL? }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PassiveWebView {
        let wv = PassiveWebView(frame: .zero, configuration: WKWebViewConfiguration())
        wv.underPageBackgroundColor = .clear
        wv.setValue(false, forKey: "drawsBackground")
        load(into: wv, context: context)
        return wv
    }

    func updateNSView(_ nsView: PassiveWebView, context: Context) {
        if context.coordinator.loadedURL != url {
            load(into: nsView, context: context)
        }
    }

    private func load(into wv: PassiveWebView, context: Context) {
        let svg = (try? String(contentsOf: url)) ?? ""
        let html = """
        <!doctype html><html><head><meta charset="utf-8"><style>
        html,body{margin:0;padding:0;background:transparent;width:100%;height:100%;overflow:hidden}
        svg{width:100vw;height:100vh;display:block}
        </style></head><body>\(svg)</body></html>
        """
        wv.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
        context.coordinator.loadedURL = url
    }
}

// ImageRenderer captures nothing from an NSViewRepresentable, and NSImage's
// own SVG support renders these files black (it handles symbol-style art, not
// gradients and filters). So PDF export snapshots the same web view the panel
// uses and caches the still. Blocking by design — it runs in the export's
// prefetch pass, never inside a render.
enum SVGSnapshot {
    private static var cache: [URL: NSImage] = [:]

    static func cached(_ url: URL) -> NSImage? { cache[url] }

    private final class LoadWaiter: NSObject, WKNavigationDelegate {
        var done = false
        func webView(_ w: WKWebView, didFinish n: WKNavigation!) { done = true }
        func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { done = true }
        func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { done = true }
    }

    @MainActor
    static func capture(_ url: URL, size: CGSize) async -> NSImage? {
        if let hit = cache[url] { return hit }

        let frame = CGRect(origin: .zero, size: size)
        let wv = WKWebView(frame: frame, configuration: WKWebViewConfiguration())
        let waiter = LoadWaiter()
        wv.navigationDelegate = waiter
        // WebKit only composites a web view that belongs to a window, so park
        // one far off any screen for the duration of the snapshot.
        let host = NSWindow(
            contentRect: CGRect(x: -30000, y: -30000, width: size.width, height: size.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        host.contentView = wv
        host.orderFrontRegardless()
        defer { host.orderOut(nil) }

        let svg = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        wv.loadHTMLString("""
        <!doctype html><html><head><meta charset="utf-8"><style>
        html,body{margin:0;padding:0;background:transparent;width:100%;height:100%;overflow:hidden}
        svg{width:100vw;height:100vh;display:block}
        </style></head><body>\(svg)</body></html>
        """, baseURL: url.deletingLastPathComponent())

        await settle(while: { !waiter.done }, timeout: 5)
        // One settle beat so the first animation frame and any filter passes
        // have actually been composited.
        await settle(while: { true }, timeout: 0.4)

        var shot: NSImage?
        var finished = false
        let config = WKSnapshotConfiguration()
        config.rect = frame
        wv.takeSnapshot(with: config) { img, _ in
            shot = img
            finished = true
        }
        await settle(while: { !finished }, timeout: 5)

        if let shot { cache[url] = shot }
        return shot
    }

    // Yields the main actor in small slices so WebKit's delegate callbacks and
    // compositing get to run — a RunLoop pump would not, since export already
    // runs inside a main-actor task.
    private static func settle(while condition: () -> Bool, timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        while condition() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}

// MARK: - Tiny localhost HTTP server (serves YouTube embed pages)
//
// The IFrame API wants a real http(s) parent origin. We stand up one
// NWListener bound to 127.0.0.1 on an OS-assigned port and serve a
// template page that boots the API for a given ?id=&start=.

final class EmbedServer {
    static let shared = EmbedServer()

    private let queue = DispatchQueue(label: "EmbedServer")
    private var listener: NWListener?
    private var port: UInt16 = 0
    private let ready = DispatchSemaphore(value: 0)
    private var didSignal = false

    private init() { startListener() }

    func url(videoId: String, start: Int) -> URL? {
        if port == 0 { _ = ready.wait(timeout: .now() + 2.0) }
        guard port > 0 else { return nil }
        var comps = URLComponents()
        comps.scheme = "http"
        comps.host = "127.0.0.1"
        comps.port = Int(port)
        comps.path = "/"
        comps.queryItems = [
            URLQueryItem(name: "id", value: videoId),
            URLQueryItem(name: "start", value: String(start)),
        ]
        return comps.url
    }

    private func startListener() {
        do {
            let params = NWParameters.tcp
            params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: .any)
            let l = try NWListener(using: params)
            l.stateUpdateHandler = { [weak self, weak l] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    if let p = l?.port?.rawValue { self.port = p }
                    self.signalReady()
                case .failed, .cancelled:
                    self.signalReady()
                default: break
                }
            }
            l.newConnectionHandler = { [weak self] c in self?.accept(c) }
            l.start(queue: queue)
            listener = l
        } catch {
            NSLog("EmbedServer failed to start: \(error)")
            signalReady()
        }
    }

    private func signalReady() {
        queue.async {
            if !self.didSignal { self.didSignal = true; self.ready.signal() }
        }
    }

    private func accept(_ conn: NWConnection) {
        conn.start(queue: queue)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
            let req = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let target = Self.requestTarget(req)
            let body = Self.page(for: target).data(using: .utf8) ?? Data()
            var header = "HTTP/1.1 200 OK\r\n"
            header += "Content-Type: text/html; charset=utf-8\r\n"
            header += "Content-Length: \(body.count)\r\n"
            header += "Cache-Control: no-store\r\n"
            header += "Connection: close\r\n\r\n"
            var out = Data(header.utf8)
            out.append(body)
            conn.send(content: out, completion: .contentProcessed { _ in conn.cancel() })
        }
    }

    private static func requestTarget(_ req: String) -> String {
        guard let firstLine = req.split(separator: "\r\n", maxSplits: 1).first else { return "/" }
        let parts = firstLine.split(separator: " ")
        return parts.count >= 2 ? String(parts[1]) : "/"
    }

    private static func page(for target: String) -> String {
        let comps = URLComponents(string: "http://x\(target)")
        let items = comps?.queryItems ?? []
        let rawId = items.first(where: { $0.name == "id" })?.value ?? ""
        let start = Int(items.first(where: { $0.name == "start" })?.value ?? "0") ?? 0
        // YouTube IDs are [A-Za-z0-9_-]+; strip anything else so we can't be
        // tricked into injecting JS via the markdown URL.
        let safeId = rawId.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <style>html,body{margin:0;padding:0;background:#000;height:100%;overflow:hidden}
        #player{width:100%;height:100%}</style></head>
        <body><div id="player"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
        function onYouTubeIframeAPIReady() {
          new YT.Player('player', {
            videoId: '\(safeId)',
            width: '100%', height: '100%',
            playerVars: { autoplay: 1, playsinline: 1, rel: 0, start: \(start) },
            events: { onReady: function(e){ e.target.playVideo(); } }
          });
        }
        </script></body></html>
        """
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
        guard !deck.slides.isEmpty else { return Slide(background: nil, columns: [""], themeOverride: nil) }
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

// The slide itself, with no dependency on PresenterState, so the PDF exporter
// can render any slide off-screen through the same code path the panel uses.
// `staticBackgrounds` swaps the live WKWebView for a still NSImage — SwiftUI's
// ImageRenderer captures nothing from an NSViewRepresentable.
struct SlideCanvas: View {
    static let pageSpace = "slidePage"

    let slide: Slide
    let deckTheme: DeckTheme
    let baseDir: URL
    let shade: Double
    let pageLabel: String
    var cornerRadius: CGFloat = 20
    var showsBorder: Bool = true
    var staticBackgrounds: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let bg = backgroundSource
        let theme = currentTheme
        ZStack(alignment: .bottomTrailing) {
            // Background fills the whole frame. Color.clear provides the sizing;
            // SVG -> live WKWebView (so animations play); image -> NSImage;
            // otherwise the theme's background color.
            Color.clear
                .background(backgroundFill(bg, theme: theme))
                .overlay(backgroundOverlay(theme: theme, shade: shade, hasContent: bg.hasContent))
                .clipShape(shape)

            if showsBorder {
                shape.strokeBorder(theme.textColor.opacity(0.35), lineWidth: 1.5)
            }

            columnsView
                .foregroundStyle(theme.textColor)
                .padding(48)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(pageLabel)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(theme.textColor.opacity(0.6))
                .padding(16)
        }
        .clipShape(shape)
        .coordinateSpace(name: Self.pageSpace)
    }

    @ViewBuilder
    private var columnsView: some View {
        let cols = slide.columns
        if cols.count > 1 {
            HStack(alignment: .top, spacing: 40) {
                ForEach(Array(cols.enumerated()), id: \.offset) { _, col in
                    MarkdownSlide(text: col, baseDir: baseDir, theme: currentTheme)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        } else {
            MarkdownSlide(text: cols.first ?? "", baseDir: baseDir, theme: currentTheme)
        }
    }

    private var currentTheme: DeckTheme {
        slide.themeOverride ?? deckTheme
    }

    // A gradient stands in for the flat darken overlay rather than stacking
    // with it — it is the readability treatment, and doubling them muddies
    // the image. Unlike the shade it also applies with no background image,
    // so a gradient can be the background.
    @ViewBuilder
    private func backgroundOverlay(theme: DeckTheme, shade: Double, hasContent: Bool) -> some View {
        if let gradient = slide.gradient ?? theme.defaultGradient {
            gradient.linearGradient
        } else if hasContent {
            Color.black.opacity(shade)
        } else {
            Color.clear
        }
    }

    private enum BackgroundSource {
        case none
        case image(NSImage)
        case svg(URL)

        var hasContent: Bool {
            if case .none = self { return false }
            return true
        }
    }

    private var backgroundSource: BackgroundSource {
        let path = slide.background ?? currentTheme.defaultBackground
        guard let path else { return .none }
        let expanded = (path as NSString).expandingTildeInPath
        let url: URL = expanded.hasPrefix("/")
            ? URL(fileURLWithPath: expanded)
            : baseDir.appendingPathComponent(expanded)
        if url.pathExtension.lowercased() == "svg" {
            if !staticBackgrounds { return .svg(url) }
            return SVGSnapshot.cached(url).map { .image($0) } ?? .none
        }
        return NSImage(contentsOf: url).map { .image($0) } ?? .none
    }

    @ViewBuilder
    private func backgroundFill(_ source: BackgroundSource, theme: DeckTheme) -> some View {
        switch source {
        case .none:
            theme.backgroundColor
        case .image(let img):
            Image(nsImage: img).resizable().scaledToFill()
        case .svg(let url):
            SVGBackgroundView(url: url)
        }
    }
}

struct PresenterContent: View {
    @ObservedObject var state: PresenterState
    @EnvironmentObject var settings: PresenterSettings
    @EnvironmentObject var videoPlayback: VideoPlayback

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        ZStack {
            SlideCanvas(
                slide: state.currentSlide,
                deckTheme: state.deck.theme,
                baseDir: state.baseDir,
                shade: settings.shade(for: state.index),
                pageLabel: "\(state.index + 1) / \(state.deck.slides.count)"
            )

            if let p = videoPlayback.active {
                YouTubeWebView(videoId: p.videoId, start: p.start)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .clipShape(shape)
            }
        }
        .clipShape(shape)
    }
}

// MARK: - PDF export (Cmd-P)

// Rects of things that should become clickable in the exported PDF but carry
// no text to search for — currently just YouTube thumbnails. Filled during the
// render pass, in the page's coordinate space with y measured from the top.
final class LinkRectCollector {
    private(set) var links: [(rect: CGRect, url: URL)] = []

    // ImageRenderer lays a page out more than once, so the same probe reports
    // itself repeatedly; one annotation per rect is enough.
    func add(_ rect: CGRect, _ url: URL) {
        // Compared at whole points: repeat passes can differ in the last
        // fractional digit, which is not a second link.
        guard !links.contains(where: { $0.rect.integral == rect.integral && $0.url == url })
        else { return }
        links.append((rect, url))
    }
    func reset() { links.removeAll() }
}

private struct LinkRectCollectorKey: EnvironmentKey {
    static let defaultValue: LinkRectCollector? = nil
}

extension EnvironmentValues {
    var linkRectCollector: LinkRectCollector? {
        get { self[LinkRectCollectorKey.self] }
        set { self[LinkRectCollectorKey.self] = newValue }
    }
}

// Records its own frame as a side effect of layout. onAppear and preference
// callbacks never fire under ImageRenderer, but GeometryReader's closure is
// evaluated during the layout it does perform.
struct LinkProbe: View {
    let url: URL
    let collector: LinkRectCollector

    var body: some View {
        GeometryReader { geo in
            record(geo.frame(in: .named(SlideCanvas.pageSpace)))
        }
    }

    private func record(_ rect: CGRect) -> Color {
        collector.add(rect, url)
        return .clear
    }
}



enum PDFExporter {
    enum Failure: LocalizedError {
        case cannotWrite(URL)

        var errorDescription: String? {
            switch self {
            case .cannotWrite(let url):
                return "Could not create a PDF at \(url.path)."
            }
        }
    }

    // One page per slide, at the panel's current size. Font sizes are absolute,
    // so rescaling the page would change the layout instead of preserving it —
    // the export matches whatever is on screen, margin included.
    @MainActor
    static func write(deck: Deck, settings: PresenterSettings, pageSize: CGSize, to url: URL) async throws {
        await prefetchThumbnails(deck)
        await prefetchSVGBackgrounds(deck, pageSize: pageSize)

        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let pdf = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { throw Failure.cannotWrite(url) }

        let collector = LinkRectCollector()
        var probedLinks: [[(rect: CGRect, url: URL)]] = []

        let total = deck.slides.count
        for (i, slide) in deck.slides.enumerated() {
            collector.reset()
            let page = SlideCanvas(
                slide: slide,
                deckTheme: deck.theme,
                baseDir: deck.baseDir,
                shade: settings.shade(for: i),
                pageLabel: "\(i + 1) / \(total)",
                cornerRadius: 0,
                showsBorder: false,
                staticBackgrounds: true
            )
            .frame(width: pageSize.width, height: pageSize.height)
            .environmentObject(settings)
            .environmentObject(VideoPlayback())
            .environment(\.linkRectCollector, collector)

            let renderer = ImageRenderer(content: page)
            renderer.proposedSize = ProposedViewSize(pageSize)
            renderer.render { _, draw in
                pdf.beginPDFPage(nil)
                draw(pdf)
                pdf.endPDFPage()
            }
            // The probes only fire once draw() has run the layout.
            probedLinks.append(collector.links)
        }
        pdf.closePDF()

        annotateLinks(
            in: url,
            probed: probedLinks,
            text: deck.slides.map(textLinks(in:)),
            pageHeight: pageSize.height
        )
    }

    // Two kinds of link, both applied after the pages exist. Probed rects come
    // from LinkProbe during the render; text links are located by searching the
    // finished PDF, which is why the pages are written as real text rather than
    // rasterized — SwiftUI hands out no per-run geometry for a Text.
    private static func annotateLinks(
        in url: URL,
        probed: [[(rect: CGRect, url: URL)]],
        text: [[(text: String, url: URL)]],
        pageHeight: CGFloat
    ) {
        guard let doc = PDFDocument(url: url) else { return }
        var added = false

        for index in 0..<doc.pageCount {
            guard let page = doc.page(at: index) else { continue }

            for link in probed.indices.contains(index) ? probed[index] : [] {
                // Probe rects measure y from the top of the page; PDF is y-up.
                let bounds = CGRect(
                    x: link.rect.minX,
                    y: pageHeight - link.rect.maxY,
                    width: link.rect.width,
                    height: link.rect.height
                )
                annotate(page, bounds: bounds, url: link.url)
                added = true
            }

            // Line breaks are flattened to spaces so a label that wraps is still
            // found; the substitution is one character for one, which keeps the
            // offsets usable as a range on the page itself.
            let haystack = (page.string ?? "")
                .replacingOccurrences(of: "\n", with: " ") as NSString
            // Repeated link text on one page is paired with its URLs in reading
            // order, so two different links sharing a label stay distinct.
            var consumed: [String: Int] = [:]
            for link in text.indices.contains(index) ? text[index] : [] {
                let needle = link.text.replacingOccurrences(of: "\n", with: " ")
                let nth = consumed[link.text, default: 0]
                consumed[link.text] = nth + 1
                guard let range = haystack.range(of: needle, occurrence: nth),
                      let selection = page.selection(for: range) else { continue }
                // A wrapped link needs one annotation per line it occupies.
                for line in selection.selectionsByLine() {
                    annotate(page, bounds: line.bounds(for: page), url: link.url)
                    added = true
                }
            }
        }

        if added { doc.write(to: url) }
    }

    private static func annotate(_ page: PDFPage, bounds: CGRect, url: URL) {
        let annotation = PDFAnnotation(bounds: bounds, forType: .link, withProperties: nil)
        annotation.action = PDFActionURL(url: url)
        // Some viewers outline a link annotation unless the border is empty.
        let border = PDFBorder()
        border.lineWidth = 0
        annotation.border = border
        page.addAnnotation(annotation)
    }

    // Every markdown link in a slide's prose, in reading order.
    private static func textLinks(in slide: Slide) -> [(text: String, url: URL)] {
        slide.columns
            .flatMap { MarkdownSlide.parse($0) }
            .flatMap { block -> [(text: String, url: URL)] in
                let source: String
                switch block {
                case .heading(_, let s), .bullet(let s), .paragraph(let s):
                    source = s
                default:
                    return []
                }
                guard let attributed = try? AttributedString(markdown: source) else { return [] }
                return attributed.runs.compactMap { run in
                    guard let link = run.link else { return nil }
                    let label = String(attributed[run.range].characters)
                    return label.isEmpty ? nil : (label, link)
                }
            }
    }

    @MainActor
    private static func prefetchSVGBackgrounds(_ deck: Deck, pageSize: CGSize) async {
        let paths = deck.slides.map { $0.background ?? $0.themeOverride?.defaultBackground ?? deck.theme.defaultBackground }
        for path in paths.compactMap({ $0 }) {
            let expanded = (path as NSString).expandingTildeInPath
            let url = expanded.hasPrefix("/")
                ? URL(fileURLWithPath: expanded)
                : deck.baseDir.appendingPathComponent(expanded)
            guard url.pathExtension.lowercased() == "svg" else { continue }
            _ = await SVGSnapshot.capture(url, size: pageSize)
        }
    }

    // A YouTube block draws whatever thumbnail is cached, and the panel's async
    // loader never runs under ImageRenderer — so warm the cache first or every
    // video slide exports as a black rectangle.
    private static func prefetchThumbnails(_ deck: Deck) async {
        let ids = deck.slides
            .flatMap { $0.columns }
            .flatMap { MarkdownSlide.parse($0) }
            .compactMap { block -> String? in
                if case .youtube(let videoId, _, _) = block { return videoId }
                return nil
            }
        let unique = Array(Set(ids))
        await Task.detached {
            for id in unique { _ = YouTubeThumbnails.fetch(id) }
        }.value
    }
}

private extension NSString {
    func range(of needle: String, occurrence: Int) -> NSRange? {
        var start = 0
        var remaining = occurrence
        while start <= length {
            let found = range(
                of: needle,
                options: [.literal],
                range: NSRange(location: start, length: length - start)
            )
            guard found.location != NSNotFound else { return nil }
            if remaining == 0 { return found }
            remaining -= 1
            start = found.location + max(found.length, 1)
        }
        return nil
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

            row("Margin") {
                Slider(value: $settings.outerMargin, in: PresenterSettings.marginRange, step: 10)
                Text("\(Int(settings.outerMargin))")
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
    let videoPlayback = VideoPlayback()
    var panel: PresenterPanel!
    var marginObserver: AnyCancellable?

    // Panel is the visible screen inset by the user's margin, so the margin is
    // the literal gap at every edge. There is deliberately no maximum size: a
    // cap makes small margins inert, since the panel is already inset by the
    // slack the cap leaves. The floors only bite at the extreme end.
    private func panelSize(margin: CGFloat) -> NSSize {
        guard let screen = NSScreen.main else { return NSSize(width: 1100, height: 720) }
        let vf = screen.visibleFrame
        return NSSize(
            width: max(320, vf.width - margin * 2),
            height: max(240, vf.height - margin * 2)
        )
    }

    var panelBaseSize: NSSize { panelSize(margin: settings.outerMargin) }

    private let configPanelSize = NSSize(width: 540, height: 210)
    var configPanel: NSPanel?
    var backdrop: NSWindow!
    var corner: NSWindow!
    var mouseMonitor: Any?
    var keyMonitor: Any?
    var isShown = false
    private var deckPath: String

    init(deck: Deck, path: String) {
        self.state = PresenterState(deck: deck)
        self.settings.theme = deck.theme
        self.deckPath = path
    }

    func start() {
        buildBackdrop()
        buildPanel()
        buildCornerTrigger()
        // @Published fires in willSet, so settings.outerMargin is still the old
        // value inside the sink — lay out from the emitted one.
        marginObserver = settings.$outerMargin
            .dropFirst()
            .sink { [weak self] newMargin in self?.applyMargin(newMargin) }
    }

    private func applyMargin(_ margin: CGFloat) {
        guard isShown else { return }
        let size = panelSize(margin: margin)
        if configPanel != nil {
            layoutWithConfig(panelSize: size)
        } else {
            centerPanel(size: size)
        }
    }

    // Called when macOS hands us a file or folder via Finder drop / "Open With"
    // / `open -a`. A folder becomes a photo deck (one image per slide).
    func loadDeck(from url: URL, templateOverride: String? = nil) {
        let newDeck = Deck.load(from: url.path, templateOverride: templateOverride)
        state.deck = newDeck
        state.index = 0
        videoPlayback.active = nil
        settings.theme = newDeck.theme
        settings.fontName = "System"
        settings.resetPerSlideSettings()
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
           isDir.boolValue {
            for i in 0..<newDeck.slides.count {
                settings.setShade(0, for: i)
            }
        }
        deckPath = url.path
        UserDefaults.standard.set(url.path, forKey: "lastDeckPath")
        NSLog("ScreenPresenter: loaded deck \(url.lastPathComponent) with \(newDeck.slides.count) slides (theme: \(newDeck.theme.templateName))")
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
        let size = panelBaseSize
        let rect = NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2,
            width: size.width, height: size.height
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
            rootView: PresenterContent(state: state)
                .environmentObject(settings)
                .environmentObject(videoPlayback)
        )
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
        installKeyMonitor()
        if withConfig { showConfigPanel() }
    }

    // WKWebView captures keyDown when it's first responder, so PresenterPanel's
    // keyDown override doesn't fire while a video is playing; and command-key
    // events never reach it at all without a menu. A local event monitor runs
    // ahead of the responder chain and covers both.
    private func installKeyMonitor() {
        if keyMonitor != nil { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "p" {
                // Off this event's stack — exportPDF runs a modal save panel.
                Task { @MainActor in await self.exportPDF() }
                return nil
            }
            guard self.videoPlayback.active != nil else { return event }
            switch event.keyCode {
            case 53:  // escape — close the video, keep the slide
                self.videoPlayback.active = nil
                return nil
            case 49, 124, 36:  // space, right arrow, return — advance slide
                self.videoPlayback.active = nil
                self.state.next()
                return nil
            case 123:  // left arrow — previous slide
                self.videoPlayback.active = nil
                self.state.prev()
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }
    }

    // Restore the panel to its margin-derived size and center it on
    // visibleFrame. showConfigPanel() may resize/reposition afterward.
    private func recenterPanel() {
        centerPanel(size: panelBaseSize)
    }

    private func centerPanel(size: NSSize) {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let rect = NSRect(
            x: vf.midX - size.width / 2,
            y: vf.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        panel.setFrame(rect, display: true)
    }

    private func hide() {
        guard isShown else { return }
        isShown = false
        videoPlayback.active = nil
        removeKeyMonitor()
        panel.orderOut(nil)
        backdrop.orderOut(nil)
        configPanel?.orderOut(nil)
        configPanel = nil
        // Go back to being a dockless utility.
        NSApp.setActivationPolicy(.accessory)
    }

    // Fit the presenter+config pair inside visibleFrame: shrink the presenter
    // if needed, then center the whole group vertically. Re-runnable, so the
    // Margin slider can relayout without rebuilding the config panel.
    private func layoutWithConfig(panelSize size: NSSize) {
        guard let screen = NSScreen.main, let cp = configPanel else { return }
        let vf = screen.visibleFrame
        let gap: CGFloat = 16
        let screenInset: CGFloat = 20

        var pFrame = NSRect(origin: .zero, size: size)
        let maxPanelH = vf.height - configPanelSize.height - gap - screenInset * 2
        if pFrame.height > maxPanelH {
            pFrame.size.height = max(maxPanelH, 300)
        }
        let totalH = pFrame.height + gap + configPanelSize.height
        pFrame.origin.x = vf.midX - pFrame.width / 2
        pFrame.origin.y = vf.midY + totalH / 2 - pFrame.height
        panel.setFrame(pFrame, display: true)

        cp.setFrame(
            NSRect(
                x: vf.midX - configPanelSize.width / 2,
                y: pFrame.minY - gap - configPanelSize.height,
                width: configPanelSize.width,
                height: configPanelSize.height
            ),
            display: true
        )
    }

    private func showConfigPanel() {
        guard configPanel == nil, let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let rect = NSRect(
            x: vf.midX - configPanelSize.width / 2,
            y: vf.midY,
            width: configPanelSize.width,
            height: configPanelSize.height
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
        layoutWithConfig(panelSize: panelBaseSize)
    }

    // Cmd-P. The panels sit at .floating, which is above the save panel, so
    // they're dropped to .normal for the duration of the modal and restored
    // after — hiding the deck instead would lose the current slide.
    @MainActor
    private func exportPDF() async {
        guard isShown else { return }
        videoPlayback.active = nil

        let save = NSSavePanel()
        save.allowedContentTypes = [.pdf]
        save.nameFieldStringValue = URL(fileURLWithPath: deckPath)
            .deletingPathExtension()
            .lastPathComponent + ".pdf"
        save.canCreateDirectories = true

        let response = withPanelsBelowModal { save.runModal() }
        guard response == .OK, let url = save.url else { return }

        let size = panel.frame.size
        do {
            try await PDFExporter.write(
                deck: state.deck,
                settings: settings,
                pageSize: CGSize(width: round(size.width), height: round(size.height)),
                to: url
            )
            NSLog("ScreenPresenter: exported \(state.deck.slides.count) slides to \(url.path)")
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            let alert = NSAlert()
            alert.messageText = "PDF export failed"
            alert.informativeText = error.localizedDescription
            _ = withPanelsBelowModal { alert.runModal() }
        }
    }

    private func withPanelsBelowModal<T>(_ body: () -> T) -> T {
        let windows = [panel, backdrop, configPanel].compactMap { $0 }
        let levels = windows.map { $0.level }
        windows.forEach { $0.level = .normal }
        defer { zip(windows, levels).forEach { $0.level = $1 } }
        return body()
    }

    private func handleKey(_ code: UInt16) {
        switch code {
        case 49, 124, 36:                            // space, right arrow, return
            videoPlayback.active = nil
            state.next()
        case 123:                                    // left arrow
            videoPlayback.active = nil
            state.prev()
        case 53:                                     // escape
            if videoPlayback.active != nil {
                videoPlayback.active = nil
            } else {
                hide()
            }
        default: break
        }
    }
}

// MARK: - Bootstrap

// Parse CLI args. First non-flag positional becomes the path; `template=NAME`
// sets the initial theme override.
var cliTemplate: String?
var cliPath: String?
for arg in CommandLine.arguments.dropFirst() {
    if arg.hasPrefix("template=") {
        cliTemplate = String(arg.dropFirst("template=".count))
    } else if cliPath == nil && !arg.hasPrefix("-") {
        cliPath = arg
    }
}

let resolvedPath: String = {
    if let p = cliPath { return p }
    // Remember the last file opened via drop / "Open With" / `open -a`.
    if let last = UserDefaults.standard.string(forKey: "lastDeckPath"),
       FileManager.default.fileExists(atPath: last) {
        return last
    }
    // When running from the .app bundle, fall back to Resources/sample.md.
    if let bundled = Bundle.main.path(forResource: "sample", ofType: "md") {
        return bundled
    }
    return "sample.md"
}()
let deck = Deck.load(from: resolvedPath, templateOverride: cliTemplate)

FontLoader.registerBundledFonts()

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let controller = Controller(deck: deck, path: resolvedPath)
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
    // The CLI template= flag intentionally does not propagate to dropped
    // files — those use whatever theme the dropped file declares.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        DispatchQueue.main.async { [controller] in
            controller.loadDeck(from: url)
        }
    }
}
