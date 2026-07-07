// swift-tools-version: 5.9
// This Package.swift enables Swift Package Manager support alongside CocoaPods.
// Both build systems are supported and kept in sync.

import PackageDescription

let package = Package(
    name: "native_workmanager",
    platforms: [
        .iOS("14.0"),
    ],
    products: [
        .library(name: "native_workmanager", targets: ["native_workmanager"]),
    ],
    dependencies: [
        // No third-party dependencies. Uses Apple Archive for ZIP operations.
    ],
    targets: [
        // KMPWorkManager is bundled as a local XCFramework (kmpworkmanager v3.0.1)
        .binaryTarget(
            name: "KMPWorkManager",
            path: "../Frameworks/KMPWorkManager.xcframework"
        ),
        // Issue #36: ObjC target that registers BGTask launch handlers in +load,
        // before the app finishes launching. Required because on the Flutter 3.38+
        // UIScene template plugin registration happens too late for
        // BGTaskScheduler.register, and because only ObjC can catch the
        // NSExceptions it throws. Must stay a separate target: SPM targets are
        // single-language, so the .m/.h files cannot live in the Swift target.
        .target(
            name: "native_workmanager_objc",
            path: "Sources/native_workmanager_objc",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("BackgroundTasks"),
            ]
        ),
        .target(
            name: "native_workmanager",
            dependencies: [
                "KMPWorkManager",
                "native_workmanager_objc",
            ],
            path: "Sources/native_workmanager",
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
        .testTarget(
            name: "NativeWorkManagerTests",
            dependencies: ["native_workmanager"],
            path: "../Tests"
        ),
    ]
)
