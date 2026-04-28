// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "VoiceInput",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .executable(
            name: "VoiceInput",
            targets: ["VoiceInput"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/soniqo/speech-swift.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "VoiceInput",
            dependencies: [
                .product(name: "Qwen3ASR", package: "speech-swift"),
                .product(name: "SpeechVAD", package: "speech-swift"),
                .product(name: "AudioCommon", package: "speech-swift"),
            ],
            path: "Sources/VoiceInput"
        ),
        .testTarget(
            name: "VoiceInputTests",
            dependencies: ["VoiceInput"],
            path: "Tests/VoiceInputTests"
        ),
    ]
)
