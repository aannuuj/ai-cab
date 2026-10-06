// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AICabCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "AICabCore", targets: ["AICabCore"]),
        .library(name: "AICabDesign", targets: ["AICabDesign"]),
    ],
    targets: [
        // Pure domain layer: models, engines, persistence. Foundation only, so it is
        // shared by the app, the widget extension and the unit tests.
        .target(name: "AICabCore"),
        // SwiftUI design system: tokens + reusable components shared by app and widgets.
        .target(name: "AICabDesign", dependencies: ["AICabCore"]),
        .testTarget(name: "AICabCoreTests", dependencies: ["AICabCore"]),
    ],
    swiftLanguageModes: [.v5]
)
