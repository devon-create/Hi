import Foundation

struct Scan: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var createdAt: Date
    var durationSeconds: Double
    var meshAnchorCount: Int
    var vertexCount: Int
    var triangleCount: Int
    var meshFileName: String?
    var usdzFileName: String?
    var videoFileName: String?

    var meshURL: URL? {
        meshFileName.map { ScanStore.scansDirectory.appendingPathComponent($0) }
    }

    var usdzURL: URL? {
        usdzFileName.map { ScanStore.scansDirectory.appendingPathComponent($0) }
    }

    var videoURL: URL? {
        videoFileName.map { ScanStore.scansDirectory.appendingPathComponent($0) }
    }
}
