import Foundation
import Combine

@MainActor
final class ScanStore: ObservableObject {
    @Published private(set) var scans: [Scan] = []

    static let scansDirectory: URL = {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Scans", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    private var indexURL: URL {
        Self.scansDirectory.appendingPathComponent("index.json")
    }

    init() {
        load()
    }

    func add(_ scan: Scan) {
        scans.insert(scan, at: 0)
        save()
    }

    func remove(_ scan: Scan) {
        scans.removeAll { $0.id == scan.id }
        if let mesh = scan.meshURL { try? FileManager.default.removeItem(at: mesh) }
        if let video = scan.videoURL { try? FileManager.default.removeItem(at: video) }
        save()
    }

    func rename(_ scan: Scan, to name: String) {
        guard let index = scans.firstIndex(where: { $0.id == scan.id }) else { return }
        scans[index].name = name
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        scans = (try? decoder.decode([Scan].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(scans) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
