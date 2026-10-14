// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "MacGlint", platforms: [.macOS(.v14)],
    products: [.library(name: "MacGlintCore", targets: ["MacGlintCore"])],
    targets: [
        .target(name: "MacGlintCore"),
        .target(name: "CMacGlint", publicHeadersPath: "include", linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreFoundation")]),
        .target(name: "MacGlintSystem", dependencies: ["MacGlintCore", "CMacGlint"]),
        .testTarget(name: "MacGlintTests", dependencies: ["MacGlintCore", "MacGlintSystem"])
    ]
)
