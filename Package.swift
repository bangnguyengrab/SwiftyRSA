// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "SwiftyRSA",
  platforms: [
    .iOS(.v11), .macOS(.v10_13), .tvOS(.v11), .watchOS(.v4)
  ],
  products: [
    .library(
      name: "SwiftyRSA",
      // removed 'type: .dynamic' because the XCFramework binary determines its own linking type.
      targets: ["SwiftyRSA"]
    ),
  ],
  dependencies: [],
  targets: [
    // Switch to Binary Target to enforce Library Evolution (LE) support
    .binaryTarget(
      name: "SwiftyRSA",
      url: "https://github.com/bangnguyengrab/SwiftyRSA/releases/download/1.8.8/SwiftyRSA.xcframework.zip",
      checksum: "ea395e1aceb383abab2cfcefcdc7e4cffad3dd72bc872262a3ca282e6d6e38c9"
    )
  ]
)
