import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: ScanStore
    @State private var showLibrary = false

    var body: some View {
        ZStack {
            CaptureView(showLibrary: $showLibrary)
        }
        .sheet(isPresented: $showLibrary) {
            NavigationStack {
                ScanLibraryView()
                    .environmentObject(store)
            }
            .tint(Theme.brand)
        }
    }
}

#Preview {
    RootView().environmentObject(ScanStore())
}
