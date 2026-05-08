import SwiftUI
import AVKit
import QuickLook

struct ScanDetailView: View {
    let scan: Scan
    @EnvironmentObject private var store: ScanStore
    @State private var renamedTitle: String
    @State private var showShare = false
    @State private var quickLookURL: URL?
    @State private var bundleShareURL: URL?
    @State private var bundleError: String?

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
                Button {
                    makeWebBundle()
                } label: {
                    Label("Export web bundle (.zip)", systemImage: "globe")
                }
                Button(role: .destructive) {
                    store.remove(scan)
                } label: {
                    Label("Delete scan", systemImage: "trash")
                }
            } footer: {
                Text("The web bundle is a zip with mesh.obj, mesh.usdz, video.mp4 and meta.json. Drop it into your repo's docs/scans/ folder, run the indexer, and push to publish on GitHub Pages.")
            }
        }
        .navigationTitle(renamedTitle.isEmpty ? scan.name : renamedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
        .sheet(item: Binding(
            get: { bundleShareURL.map(IdentifiableURL.init) },
            set: { bundleShareURL = $0?.url }
        )) { wrapper in
            ShareSheet(items: [wrapper.url])
        }
        .alert("Bundle failed", isPresented: Binding(
            get: { bundleError != nil },
            set: { if !$0 { bundleError = nil } }
        )) {
            Button("OK", role: .cancel) { bundleError = nil }
        } message: {
            Text(bundleError ?? "")
        }
        .quickLookPreview($quickLookURL)
    }

    private func makeWebBundle() {
        do {
            bundleShareURL = try BundleBuilder.makeBundle(for: scan)
        } catch {
            bundleError = error.localizedDescription
        }
    }

    private var shareItems: [Any] {
        [scan.meshURL, scan.usdzURL, scan.videoURL].compactMap { $0 }
    }

    private func durationString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
