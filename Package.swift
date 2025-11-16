// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Pipeline",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        
        // PipelineCore (without the step macro):
        .library(
            name: "PipelineCore",
            targets: ["PipelineCore"]),
        
        // The step macro:
        .library(
            name: "StepMacro",
            targets: ["StepMacro"]
        ),
        
        // The actual library to use:
        .library(
            name: "Pipeline",
            targets: ["Pipeline"]
        ),
        
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/stefanspringer1/Localization.git", from: "0.0.4"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.1"),
    ],
    targets: [
        
        // PipelineCore (without the step macro):
        .target(
            name: "PipelineCore",
            dependencies: [
                "Localization",
            ]
        ),
        .testTarget(
            name: "PipelineCoreTests",
            dependencies: [
                "PipelineCore"
            ]
        ),
        
        // The step macro:
        .macro(
            name: "StepMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "PipelineCore",
            ]
        ),
        .target(
            name: "StepMacro",
            dependencies: ["StepMacros"]
        ),
        .testTarget(
            name: "MacroTests",
            dependencies: [
                "StepMacro",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                "PipelineCore",
            ],
            swiftSettings: [
                .enableExperimentalFeature("BodyMacros"),
            ]
        ),
        
        // The actual library to use:
        .target(
            name: "Pipeline",
            dependencies: [
                "PipelineCore",
                "StepMacro",
            ]
        ),
    ]
)
