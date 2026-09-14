// swift-tools-version: 6.2
import PackageDescription

// Portable verification of the app's real models, services and stores.
// SwiftUI navigation still requires the Xcode project and iOS simulator.
let package = Package(
    name: "CurtainCallVerification",
    platforms: [.macOS(.v14)],
    dependencies: [.package(url: "https://github.com/supabase/supabase-swift", exact: "2.55.2")],
    targets: [
        .target(name: "CurtainCall", dependencies: [.product(name: "Supabase", package: "supabase-swift")],
                path: ".", exclude: ["CurtainCall.xcodeproj", "CurtainCallUITests", "CurtainCallTests", "docs", "supabase", "README.md", "validation/README.md", "validation/test_database.py", "CurtainCall/Assets.xcassets", "CurtainCall/Info.plist", "CurtainCall/CurtainCallApp.swift", "CurtainCall/Supabase.swift", "CurtainCall/Views", "CurtainCall/Concerts/ConcertViews.swift", "CurtainCall/Rooms/RoomViews.swift", "CurtainCall/Rooms/RoomDetailView.swift", "CurtainCall/Rooms/MyRoomsView.swift"],
                sources: ["CurtainCall/AuthStore.swift", "CurtainCall/AuthValidation.swift", "CurtainCall/Concerts/ConcertModels.swift", "CurtainCall/Concerts/ConcertService.swift", "CurtainCall/Concerts/ConcertStore.swift", "CurtainCall/Rooms/RoomModels.swift", "CurtainCall/Rooms/RoomService.swift", "CurtainCall/Rooms/RoomStore.swift", "validation/SupabaseTestClient.swift"]),
        .testTarget(name: "CurtainCallTests", dependencies: ["CurtainCall"], path: "CurtainCallTests")
    ],
    swiftLanguageModes: [.v5]
)
