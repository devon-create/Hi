import SwiftUI

struct ScanLibraryView: View {
    @EnvironmentObject private var store: ScanStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if store.scans.isEmpty {
                ContentUnavailableView(
                    "No scans yet",
                    systemImage: "cube.transparent",
                    description: Text("Tap the capture button to record your first 3D scan.")
                )
            } else {
                List {
                    ForEach(store.scans) { scan in
                        NavigationLink(value: scan) {
                            ScanRow(scan: scan)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { store.scans[$0] }.forEach(store.remove)
                    }
                }
            }
        }
        .navigationTitle("Scan Library")
        .navigationDestination(for: Scan.self) { scan in
            ScanDetailView(scan: scan)
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private struct ScanRow: View {
    let scan: Scan

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.brand.opacity(0.85))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "cube.transparent.fill")
                        .foregroundStyle(.white)
                        .font(.title3)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(scan.name).font(.headline)
                HStack(spacing: 8) {
                    Label("\(scan.triangleCount.formatted())", systemImage: "triangle")
                    Label(durationString(scan.durationSeconds), systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func durationString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
