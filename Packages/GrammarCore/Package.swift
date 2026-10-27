// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "GrammarCore",
  platforms: [.macOS("27.0")],
  products: [
    .library(name: "GrammarCore", targets: ["GrammarCore"])
  ],
  targets: [
    .target(name: "GrammarCore"),
    .testTarget(name: "GrammarCoreTests", dependencies: ["GrammarCore"]),
  ]
)
