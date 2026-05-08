import SwiftUI

@main
struct LidarCaptureApp: App {
    @StateObject private var scanStore = ScanStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(scanStore)
                .tint(Theme.brand)
                .preferredColorScheme(.dark)
        }
    }
}
