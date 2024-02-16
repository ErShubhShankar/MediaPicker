// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MediaPicker",
    platforms: [
            .iOS(SupportedPlatform.IOSVersion.v16)
    ],
    products: [
        .library(
            name: "MediaPicker",
            targets: ["MediaPicker"]),
    ],
    targets: [
        .target(
            name: "MediaPicker"),
        .testTarget(
            name: "MediaPickerTests",
            dependencies: ["MediaPicker"]),
    ]
)
