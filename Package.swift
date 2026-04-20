// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AdmitPathLogic",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AdmitPathLogic",
            targets: ["AdmitPathLogic"]
        )
    ],
    targets: [
        .target(
            name: "AdmitPathLogic",
            path: "AdmitPath",
            exclude: [
                "App/AdmitPathApp.swift",
                "Resources"
            ],
            sources: ["App", "Components", "Core", "Models", "Repositories", "Services", "Utilities", "ViewModels", "Views"],
            resources: [
                .process("SeedData"),
                .process("Support")
            ]
        ),
        .testTarget(
            name: "AdmitPathLogicTests",
            dependencies: ["AdmitPathLogic"],
            path: "Tests/AdmitPathLogicTests"
        )
    ]
)
