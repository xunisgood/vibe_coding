// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "PersonalLife",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "PersonalLife", targets: ["LifeApp"]),
    .library(name: "LifeCore", targets: ["LifeCore"]),
  ],
  targets: [
    .target(name: "LifeCore"),
    .executableTarget(name: "LifeApp", dependencies: ["LifeCore"]),
    .testTarget(name: "LifeCoreTests", dependencies: ["LifeCore"]),
    .testTarget(name: "LifeAppTests", dependencies: ["LifeApp", "LifeCore"]),
  ],
  swiftLanguageModes: [.v5]
)
