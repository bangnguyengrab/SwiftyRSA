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
      // remove 'type: .dynamic' because the XCFramework binary determines its own linking type.
      targets: ["SwiftyRSA"]
    ),
  ],
  dependencies: [],
  targets: [
    // Switch to Binary Target to enforce Library Evolution (LE) support
    .binaryTarget(
      name: "SwiftyRSA",
      url: "https://github.com/bangnguyengrab/SwiftyRSA/releases/download/1.8.4/SwiftyRSA.xcframework.zip",
      checksum: "6f1a840bef0deebecb7b24767f54b75ddf650eb54f493289111b8eb213d0f749"
    )
  ]
)
