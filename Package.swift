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
      checksum: "456efe912de830d5cb5d938cc4fdfc2837cba4fa79b86d61fcdf5c335c4f5a61"
    )
  ]
)
