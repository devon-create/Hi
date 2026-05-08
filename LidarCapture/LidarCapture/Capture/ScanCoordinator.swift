import ARKit
import RealityKit
import Combine
import CoreVideo
import AVFoundation
import UIKit

enum ScanError: LocalizedError {
    case lidarNotAvailable
    case alreadyScanning
    case writerFailed(String)

    var errorDescription: String? {
        switch self {
        case .lidarNotAvailable:
            return "This device does not have a LiDAR scanner. LiDAR Capture requires an iPhone Pro / iPad Pro with LiDAR."
        case .alreadyScanning:
            return "A scan is already in progress."
        case .writerFailed(let reason):
            return "Could not start recording: \(reason)"
        }
    }
}

final class ScanCoordinator: NSObject, ObservableObject {
    @Published private(set) var isScanning = false
    @Published private(set) var meshAnchorCount = 0
    @Published private(set) var trackingDescription = "Initializing..."
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var lastError: String?
    let isLiDARAvailable: Bool

    let arView: ARView
    private let recorder = VideoRecorder()
    private var scanID: UUID?
    private var startDate: Date?
    private var elapsedTimer: Timer?
    private weak var store: ScanStore?

    override init() {
        self.isLiDARAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
        self.arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        super.init()
        configureView()
    }

    func attach(store: ScanStore) {
        self.store = store
    }

    private func configureView() {
        arView.session.delegate = self
        arView.environment.sceneUnderstanding.options = [.occlusion, .receivesLighting]
        arView.debugOptions = [.showSceneUnderstanding]
        arView.renderOptions = [.disableMotionBlur]
        arView.automaticallyConfigureSession = false
    }

    func prepareSession() {
        guard isLiDARAvailable else {
            trackingDescription = "LiDAR unavailable"
            return
        }
        let config = makeConfiguration()
        arView.session.run(config, options: [])
        trackingDescription = "Move slowly to map your space"
    }

    private func makeConfiguration() -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .meshWithClassification
        config.environmentTexturing = .automatic
        config.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        if let format = ARWorldTrackingConfiguration.recommendedVideoFormatForHighResolutionFrameCapturing {
            config.videoFormat = format
        }
        config.isAutoFocusEnabled = true
        return config
    }

    func startScan() throws {
        guard isLiDARAvailable else { throw ScanError.lidarNotAvailable }
        guard !isScanning else { throw ScanError.alreadyScanning }

        let id = UUID()
        let videoURL = ScanStore.scansDirectory.appendingPathComponent("\(id.uuidString).mp4")
        let resolution = arView.session.configuration.flatMap { ($0 as? ARWorldTrackingConfiguration)?.videoFormat.imageResolution } ?? CGSize(width: 1920, height: 1440)

        do {
            try recorder.start(to: videoURL, width: Int(resolution.width), height: Int(resolution.height))
        } catch {
            throw ScanError.writerFailed(error.localizedDescription)
        }

        let config = makeConfiguration()
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])

        scanID = id
        startDate = Date()
        elapsed = 0
        meshAnchorCount = 0
        isScanning = true
        startElapsedTimer()
    }

    func stopScan() async -> Scan? {
        guard isScanning, let id = scanID, let start = startDate else { return nil }
        isScanning = false
        stopElapsedTimer()

        let meshAnchors = currentMeshAnchors()
        let videoURL = await recorder.finish()

        let meshURL: URL?
        let vertexCount: Int
        let triangleCount: Int
        do {
            let exported = try MeshExporter.exportOBJ(meshAnchors: meshAnchors, scanID: id)
            meshURL = exported.url
            vertexCount = exported.vertexCount
            triangleCount = exported.triangleCount
        } catch {
            await MainActor.run { self.lastError = "Mesh export failed: \(error.localizedDescription)" }
            meshURL = nil
            vertexCount = 0
            triangleCount = 0
        }

        let scan = Scan(
            id: id,
            name: Self.defaultName(for: start),
            createdAt: start,
            durationSeconds: Date().timeIntervalSince(start),
            meshAnchorCount: meshAnchors.count,
            vertexCount: vertexCount,
            triangleCount: triangleCount,
            meshFileName: meshURL?.lastPathComponent,
            videoFileName: videoURL?.lastPathComponent
        )

        await MainActor.run {
            self.store?.add(scan)
            self.scanID = nil
            self.startDate = nil
            self.trackingDescription = "Scan saved"
        }
        return scan
    }

    func cancelScan() {
        guard isScanning else { return }
        isScanning = false
        stopElapsedTimer()
        recorder.cancel()
        scanID = nil
        startDate = nil
    }

    private func currentMeshAnchors() -> [ARMeshAnchor] {
        arView.session.currentFrame?.anchors.compactMap { $0 as? ARMeshAnchor } ?? []
    }

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, let start = self.startDate else { return }
            DispatchQueue.main.async {
                self.elapsed = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    static func defaultName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return "Scan • \(formatter.string(from: date))"
    }
}

extension ScanCoordinator: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if isScanning {
            let pixelBuffer = frame.capturedImage
            let pts = CMTimeMakeWithSeconds(frame.timestamp, preferredTimescale: 600)
            recorder.append(pixelBuffer: pixelBuffer, presentationTime: pts)
        }

        let description: String
        switch frame.camera.trackingState {
        case .normal: description = isScanning ? "Tracking — keep moving" : "Ready"
        case .notAvailable: description = "Tracking unavailable"
        case .limited(let reason):
            switch reason {
            case .excessiveMotion: description = "Slow down"
            case .insufficientFeatures: description = "Need more detail in view"
            case .initializing: description = "Initializing..."
            case .relocalizing: description = "Relocalizing..."
            @unknown default: description = "Limited tracking"
            }
        }
        DispatchQueue.main.async { self.trackingDescription = description }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        updateMeshCount()
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        updateMeshCount()
    }

    private func updateMeshCount() {
        let count = arView.session.currentFrame?.anchors.compactMap { $0 as? ARMeshAnchor }.count ?? 0
        DispatchQueue.main.async { self.meshAnchorCount = count }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { self.lastError = error.localizedDescription }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async { self.trackingDescription = "Session interrupted" }
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        prepareSession()
    }
}
