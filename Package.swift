// swift-tools-version:5.9
import PackageDescription

// How this package finds React Native's header products (ReactHeaders etc.).
//
// `react-native spm scaffold` emits this same path, and react-native-screens, reanimated and
// Sentry ship this same pattern.
// RN generates these products in a local package inside each app, at
// <app>/ios/build/xcframeworks, and gives a hand-written manifest no way to locate the app. The
// path works because the autolinker loads this manifest through a symlink at
// <app>/ios/build/generated/autolinking/libs/CodePush, and SwiftPM resolves relative paths from
// that symlink, not from node_modules. Shipping no manifest is not an option: the autolinker
// rejects a dependency without one.
//
// It breaks in remote mode (RN_SPM_REMOTE_URL) and with a custom `--xcframeworks-path`.
// RN's documented contract for hand-written manifests is a remote package dependency instead,
// which RN doesn't publish as of 0.88:
// https://github.com/react/react-native/blob/v0.88.0/packages/react-native/scripts/spm/__docs__/spm-header-paths-contract.md#hand-authored-community-library-contract
let reactNativePackagePath = "../../../../xcframeworks"

let package = Package(
    name: "CodePush",
    platforms: [
        .iOS("15.5"),
        .tvOS("15.5"),
    ],
    products: [
        .library(name: "CodePush", targets: ["CodePush"]),
    ],
    dependencies: [
        .package(name: "ReactNative", path: reactNativePackagePath),
        .package(url: "https://github.com/ZipArchive/ZipArchive", .upToNextMinor(from: "2.5.5")),
    ],
    targets: [
        .target(
            name: "CodePush",
            dependencies: [
                "CodePushCore",
                "CodePushHDiffPatch",
                .product(name: "ZipArchive", package: "ZipArchive"),
                .product(name: "ReactHeaders", package: "ReactNative"),
                .product(name: "ReactNativeHeaders", package: "ReactNative"),
                .product(name: "ReactNativeDependenciesHeaders", package: "ReactNative"),
            ],
            path: "ios/CodePush",
            publicHeadersPath: "include"
        ),
        .target(
            name: "CodePushCore",
            path: "ios/CodePushCore/Sources/CodePushCore"
        ),
        .target(
            name: "CodePushHDiffPatch",
            path: "shared",
            sources: [
                "diffpatch/bspatch_bridge.c",
                "third_party/hdiffpatch/libHDiffPatch/HPatch/patch.c",
                "third_party/hdiffpatch/bsdiff_wrapper/bspatch_wrapper.c",
                "third_party/hdiffpatch/file_for_patch.c",
            ],
            publicHeadersPath: "diffpatch",
            cSettings: [
                // Keep in sync with CodePush.podspec and android/app/src/main/cpp/CMakeLists.txt.
                .define("_IS_NEED_BLOCK_DEV", to: "0"),
                .define("_IS_USED_MULTITHREAD", to: "0"),
                .define("_IS_NEED_DIR_DIFF_PATCH", to: "0"),
                .headerSearchPath("."),
                .headerSearchPath("third_party/hdiffpatch"),
                .headerSearchPath("third_party/hdiffpatch/libHDiffPatch/HPatch"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("bz2"),
            ]
        ),
    ]
)
