// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScreenPresenter",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/raspu/Highlightr", from: "2.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "ScreenPresenter",
            dependencies: ["Highlightr"],
            path: "Sources/ScreenPresenter",
            resources: [.copy("Fonts")]
        )
    ]
)
