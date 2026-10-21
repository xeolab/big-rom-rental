// swift-tools-version:5.9
import PackageDescription

// Pure business logic for the XEO rental demo. No UI, no networking:
// it builds and self-checks on a Mac with only the Command Line Tools (`swift run RentalKitChecks`).
let package = Package(
    name: "RentalKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "RentalKit", targets: ["RentalKit"])],
    targets: [
        .target(name: "RentalKit"),
        .executableTarget(name: "RentalKitChecks", dependencies: ["RentalKit"]),
    ]
)
