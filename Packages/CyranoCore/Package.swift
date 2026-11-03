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
  name: "CyranoCore",
  platforms: [.macOS("27.0")],
  products: [
    .library(name: "CyranoCore", targets: ["CyranoCore"]),
    .executable(name: "cyrano-eval", targets: ["CyranoEval"]),
  ],
  targets: [
    .target(name: "CyranoCore", swiftSettings: strictSettings),
    // Runs the prompts on eval cases with the app's code (docs/specs/04-prompts.md §5).
    .executableTarget(
      name: "CyranoEval", dependencies: ["CyranoCore"], swiftSettings: strictSettings),
    .testTarget(
      name: "CyranoCoreTests",
      dependencies: ["CyranoCore"],
      swiftSettings: strictSettings
    ),
    .testTarget(
      name: "CyranoEvalTests",
      dependencies: ["CyranoEval"],
      swiftSettings: strictSettings
    ),
  ]
)
