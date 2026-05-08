import SwiftUI
import AVKit
import QuickLook

struct ScanDetailView: View {
    let scan: Scan
    @EnvironmentObject private var store: ScanStore
    @State private var renamedTitle: String
    @State private var showShare = false
    @State private var quickLookURL: URL?

    init(scan: Scan) {
        self.scan = scan
        _renamedTitle = State(initialValue: scan.name)
    }

    var body: some View {
        Form {
            Section("Video") {
                if let url = scan.videoURL, FileManager.default.fileExists(atPath: url.path) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 6)
                } else {
                    Text("No video recorded").foregroundStyle(.secondary)
                }
            }

            Section("Mesh") {
                LabeledContent("Vertices", value: scan.vertexCount.formatted())
                LabeledContent("Triangles", value: scan.triangleCount.formatted())
                LabeledContent("Mesh chunks", value: "\(scan.meshAnchorCount)")
                LabeledContent("Duration", value: durationString(scan.durationSeconds))
                if let url = scan.meshURL, FileManager.default.fileExists(atPath: url.path) {
                    Button {
                        quickLookURL = url
                    } label: {
                        Label("Preview 3D mesh", systemImage: "cube.transparent")
                    }
                }
            }

            Section("Name") {
                TextField("Scan name", text: $renamedTitle)
                    .onSubmit { store.rename(scan, to: renamedTitle) }
            }

            Section {
                Button {
                    showShare = true
                } label: {
                    Label("Export files", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    store.remove(scan)
                } label: {
                    Label("Delete scan", systemImage: "trash")
                }
            }
        }
        .navigationTitle(renamedTitle.isEmpty ? scan.name : renamedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
        .quickLookPreview($quickLookURL)
    }

    private var shareItems: [Any] {
        [scan.meshURL, scan.videoURL].compactMap { $0 }
    }

    private func durationString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
