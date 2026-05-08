import ARKit
import Foundation
import ModelIO
import simd

enum MeshExporter {
    struct Result {
        let objURL: URL
        let usdzURL: URL?
        let vertexCount: Int
        let triangleCount: Int
    }

    static func export(meshAnchors: [ARMeshAnchor], scanID: UUID) throws -> Result {
        let obj = try exportOBJ(meshAnchors: meshAnchors, scanID: scanID)
        let usdz = try? convertOBJToUSDZ(objURL: obj.url, scanID: scanID)
        return Result(
            objURL: obj.url,
            usdzURL: usdz,
            vertexCount: obj.vertexCount,
            triangleCount: obj.triangleCount
        )
    }

    static func convertOBJToUSDZ(objURL: URL, scanID: UUID) throws -> URL {
        let asset = MDLAsset(url: objURL)
        let usdzURL = ScanStore.scansDirectory.appendingPathComponent("\(scanID.uuidString).usdz")
        if FileManager.default.fileExists(atPath: usdzURL.path) {
            try FileManager.default.removeItem(at: usdzURL)
        }
        guard MDLAsset.canExportFileExtension("usdz") else {
            throw NSError(domain: "MeshExporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "USDZ export not supported on this OS"])
        }
        try asset.export(to: usdzURL)
        return usdzURL
    }

    private struct OBJResult {
        let url: URL
        let vertexCount: Int
        let triangleCount: Int
    }

    private static func exportOBJ(meshAnchors: [ARMeshAnchor], scanID: UUID) throws -> OBJResult {
        let url = ScanStore.scansDirectory.appendingPathComponent("\(scanID.uuidString).obj")
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        write(handle, "# LiDAR Capture mesh export\n")
        write(handle, "# scan: \(scanID.uuidString)\n")
        write(handle, "# generated: \(ISO8601DateFormatter().string(from: Date()))\n\n")

        var vertexOffset = 1
        var totalVertices = 0
        var totalTriangles = 0

        for (index, anchor) in meshAnchors.enumerated() {
            write(handle, "o mesh_\(index)\n")
            let geometry = anchor.geometry
            let transform = anchor.transform

            let vertexCount = geometry.vertices.count
            let normalCount = geometry.normals.count
            let faceCount = geometry.faces.count

            for i in 0..<vertexCount {
                let v = geometry.vertex(at: UInt32(i))
                let world = transform * SIMD4<Float>(v.x, v.y, v.z, 1)
                write(handle, String(format: "v %.6f %.6f %.6f\n", world.x, world.y, world.z))
            }

            for i in 0..<normalCount {
                let n = geometry.normal(at: UInt32(i))
                let rotated = (transform * SIMD4<Float>(n.x, n.y, n.z, 0))
                write(handle, String(format: "vn %.6f %.6f %.6f\n", rotated.x, rotated.y, rotated.z))
            }

            for i in 0..<faceCount {
                let face = geometry.vertexIndicesOf(faceWithIndex: i)
                let a = Int(face[0]) + vertexOffset
                let b = Int(face[1]) + vertexOffset
                let c = Int(face[2]) + vertexOffset
                if normalCount > 0 {
                    write(handle, "f \(a)//\(a) \(b)//\(b) \(c)//\(c)\n")
                } else {
                    write(handle, "f \(a) \(b) \(c)\n")
                }
            }

            vertexOffset += vertexCount
            totalVertices += vertexCount
            totalTriangles += faceCount
        }

        return OBJResult(url: url, vertexCount: totalVertices, triangleCount: totalTriangles)
    }

    private static func write(_ handle: FileHandle, _ string: String) {
        if let data = string.data(using: .utf8) {
            handle.write(data)
        }
    }
}

private extension ARMeshGeometry {
    func vertex(at index: UInt32) -> SIMD3<Float> {
        let buffer = vertices.buffer.contents().advanced(by: vertices.offset + vertices.stride * Int(index))
        return buffer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
    }

    func normal(at index: UInt32) -> SIMD3<Float> {
        let buffer = normals.buffer.contents().advanced(by: normals.offset + normals.stride * Int(index))
        return buffer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
    }

    func vertexIndicesOf(faceWithIndex index: Int) -> [UInt32] {
        let bytesPerIndex = faces.bytesPerIndex
        let pointer = faces.buffer.contents().advanced(by: index * faces.indexCountPerPrimitive * bytesPerIndex)
        var indices: [UInt32] = []
        for slot in 0..<faces.indexCountPerPrimitive {
            let raw = pointer.advanced(by: slot * bytesPerIndex)
            switch bytesPerIndex {
            case 2:
                indices.append(UInt32(raw.assumingMemoryBound(to: UInt16.self).pointee))
            case 4:
                indices.append(raw.assumingMemoryBound(to: UInt32.self).pointee)
            default:
                indices.append(0)
            }
        }
        return indices
    }
}
