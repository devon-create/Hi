import Foundation

enum BundleBuilder {
    enum BundleError: LocalizedError {
        case nothingToBundle
        case zipFailed(String)

        var errorDescription: String? {
            switch self {
            case .nothingToBundle: return "This scan has no exported files."
            case .zipFailed(let reason): return "Could not create bundle: \(reason)"
            }
        }
    }

    static func makeBundle(for scan: Scan) throws -> URL {
        let folderName = scan.id.uuidString
        let stagingRoot = FileManager.default.temporaryDirectory.appendingPathComponent("LidarCaptureBundles", isDirectory: true)
        let staging = stagingRoot.appendingPathComponent(folderName, isDirectory: true)

        try? FileManager.default.removeItem(at: staging)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)

        var copied = 0
        if let mesh = scan.meshURL, FileManager.default.fileExists(atPath: mesh.path) {
            try FileManager.default.copyItem(at: mesh, to: staging.appendingPathComponent("mesh.obj"))
            copied += 1
        }
        if let usdz = scan.usdzURL, FileManager.default.fileExists(atPath: usdz.path) {
            try FileManager.default.copyItem(at: usdz, to: staging.appendingPathComponent("mesh.usdz"))
            copied += 1
        }
        if let video = scan.videoURL, FileManager.default.fileExists(atPath: video.path) {
            try FileManager.default.copyItem(at: video, to: staging.appendingPathComponent("video.mp4"))
            copied += 1
        }
        guard copied > 0 else { throw BundleError.nothingToBundle }

        let meta = WebManifest(
            id: scan.id.uuidString,
            name: scan.name,
            createdAt: scan.createdAt,
            durationSeconds: scan.durationSeconds,
            meshAnchorCount: scan.meshAnchorCount,
            vertexCount: scan.vertexCount,
            triangleCount: scan.triangleCount
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(meta).write(to: staging.appendingPathComponent("meta.json"), options: .atomic)

        let destination = stagingRoot.appendingPathComponent("\(folderName).zip")
        try? FileManager.default.removeItem(at: destination)

        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        var copyError: Error?

        coordinator.coordinate(readingItemAt: staging, options: [.forUploading], error: &coordinatorError) { tempZipURL in
            do {
                try FileManager.default.copyItem(at: tempZipURL, to: destination)
            } catch {
                copyError = error
            }
        }

        if let coordinatorError {
            throw BundleError.zipFailed(coordinatorError.localizedDescription)
        }
        if let copyError {
            throw BundleError.zipFailed(copyError.localizedDescription)
        }
        return destination
    }

    private struct WebManifest: Encodable {
        let id: String
        let name: String
        let createdAt: Date
        let durationSeconds: Double
        let meshAnchorCount: Int
        let vertexCount: Int
        let triangleCount: Int
    }
}
