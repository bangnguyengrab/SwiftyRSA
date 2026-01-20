// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SwiftyRSA",
    products: [
        .library(
            name: "SwiftyRSA",
            targets: ["SwiftyRSA"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SwiftyRSA",
            dependencies: [],
            path: "Source",
            buildSettings: [
                .init("BUILD_LIBRARY_FOR_DISTRIBUTION", to: "YES"),
                .init("OTHER_SWIFT_FLAGS", to: "$(inherited) -Xfrontend -enable-library-evolution")
            ])
    ]
)
