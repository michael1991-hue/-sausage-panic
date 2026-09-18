// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SausagePanicCore",
    products: [.library(name: "SausagePanicCore", targets: ["SausagePanicCore"])],
    targets: [
        .target(name: "SausagePanicCore", path: "SausagePanic",
                exclude: ["SausagePanicApp.swift", "KitchenScene.swift", "GameScreen.swift", "GameStore.swift", "Info.plist", "Sounds", "PrivacyInfo.xcprivacy"],
                sources: ["GameCore.swift"]),
        .testTarget(name: "SausagePanicCoreTests", dependencies: ["SausagePanicCore"], path: "Tests")
    ]
)
