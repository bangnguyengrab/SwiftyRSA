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
      checksum: "9122380b2b0832a6d9d9ed890c910964d85bf87e0d0bda63cd9f2579eafcc5cc"
    )
  ]
)
