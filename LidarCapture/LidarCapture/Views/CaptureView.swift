import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var store: ScanStore
    @StateObject private var coordinator = ScanCoordinator()
    @Binding var showLibrary: Bool
    @State private var showUnsupportedAlert = false
    @State private var lastSavedScan: Scan?

    var body: some View {
        ZStack {
            if coordinator.isLiDARAvailable {
                ARViewContainer(coordinator: coordinator)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.yellow)
                    Text("LiDAR not available")
                        .font(.title2.bold())
                    Text("Run on an iPhone Pro or iPad Pro with a LiDAR scanner.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 40)
                }
                .foregroundStyle(.white)
            }

            VStack {
                topBar
                Spacer()
                if coordinator.isScanning {
                    statusPill
                }
                Spacer()
                bottomControls
            }
            .padding()
        }
        .onAppear { coordinator.attach(store: store) }
        .alert("Scan saved", isPresented: Binding(
            get: { lastSavedScan != nil },
            set: { if !$0 { lastSavedScan = nil } }
        )) {
            Button("View") {
                lastSavedScan = nil
                showLibrary = true
            }
            Button("OK", role: .cancel) { lastSavedScan = nil }
        } message: {
            if let scan = lastSavedScan {
                Text("\(scan.triangleCount.formatted()) triangles, \(durationString(scan.durationSeconds)).")
            }
        }
        .alert("Capture error", isPresented: Binding(
            get: { coordinator.lastError != nil },
            set: { presented in if !presented { coordinator.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { coordinator.lastError = nil }
        } message: {
            Text(coordinator.lastError ?? "")
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("LiDAR Capture")
                    .font(.headline)
                Text(coordinator.trackingDescription)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.surface, in: Capsule())

            Spacer()

            Button {
                showLibrary = true
            } label: {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.title3)
                    .padding(12)
                    .background(Theme.surface, in: Circle())
            }
        }
        .foregroundStyle(.white)
    }

    private var statusPill: some View {
        HStack(spacing: 18) {
            stat(label: "Time", value: durationString(coordinator.elapsed))
            Divider().frame(height: 24).background(Color.white.opacity(0.3))
            stat(label: "Mesh chunks", value: "\(coordinator.meshAnchorCount)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .foregroundStyle(.white)
    }

    private func stat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.monospacedDigit().bold())
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.75))
        }
    }

    private var bottomControls: some View {
        HStack(spacing: 32) {
            Spacer()
            captureButton
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private var captureButton: some View {
        Button(action: toggleScan) {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 84, height: 84)
                RoundedRectangle(cornerRadius: coordinator.isScanning ? 8 : 36)
                    .fill(Theme.brand)
                    .frame(
                        width: coordinator.isScanning ? 36 : 72,
                        height: coordinator.isScanning ? 36 : 72
                    )
                    .animation(.easeInOut(duration: 0.2), value: coordinator.isScanning)
            }
        }
        .accessibilityLabel(coordinator.isScanning ? "Stop scan" : "Start scan")
        .disabled(!coordinator.isLiDARAvailable)
    }

    private func toggleScan() {
        if coordinator.isScanning {
            Task {
                if let scan = await coordinator.stopScan() {
                    await MainActor.run { lastSavedScan = scan }
                }
            }
        } else {
            do {
                try coordinator.startScan()
            } catch {
                coordinator.lastError = error.localizedDescription
            }
        }
    }

    private func durationString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}
