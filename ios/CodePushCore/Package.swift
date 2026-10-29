// swift-tools-version:5.9
import PackageDescription

// This manifest exists so the pure-Swift core can be tested without `pod install` or a React Native
// app. `npm run test:unit:ios:core` runs the tests on an iOS simulator.
let package = Package(
    name: "CodePushCore",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "CodePushCore", targets: ["CodePushCore"]),
    ],
    targets: [
        .target(name: "CodePushCore"),
        .testTarget(name: "CodePushCoreTests", dependencies: ["CodePushCore"]),
    ]
)
