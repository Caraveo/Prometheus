// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Prometheus",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Prometheus",
            targets: ["Prometheus"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Prometheus",
            dependencies: [],
            path: ".",
            exclude: [
                "env",
                "output",
                ".git",
                "requirements.txt",
                ".gitignore"
            ],
            sources: ["PrometheusApp.swift", "ContentView.swift"],
            resources: [
                .process("shap_e_generator.py")
            ]
        )
    ]
)

