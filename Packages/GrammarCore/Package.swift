// swift-tools-version: 6.2
import PackageDescription

// Strict compiler settings for every target; see docs/quality.md.
let strictSettings: [SwiftSetting] = [
  .treatAllWarnings(as: .error),
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("MemberImportVisibility"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .unsafeFlags([
    "-Xfrontend", "-warn-long-function-bodies=200",
    "-Xfrontend", "-warn-long-expression-type-checking=200",
  ]),
]

let package = Package(
  name: "GrammarCore",
  platforms: [.macOS("27.0")],
  products: [
    .library(name: "GrammarCore", targets: ["GrammarCore"])
  ],
  targets: [
    .target(name: "GrammarCore", swiftSettings: strictSettings),
    .testTarget(
      name: "GrammarCoreTests",
      dependencies: ["GrammarCore"],
      swiftSettings: strictSettings
    ),
  ]
)
