# LiDAR Capture

> An iPhone / iPad app that uses the **LiDAR scanner** and **video camera** to capture 3D scans of physical spaces, with a video recording of the walkthrough alongside the geometry.

<sub>Mercury Contracting brand colour `#0C3B1C` is used for the app accent and document headings.</sub>

---

## What it does

- Streams a real-time mesh of the surrounding environment, classified by surface type, using ARKit's LiDAR `meshWithClassification` reconstruction.
- Records the rear camera as H.264 MP4 in parallel with the scan, so you have an RGB walkthrough that matches the geometry.
- Saves every scan to a local library — mesh as `.obj`, video as `.mp4`, metadata as JSON.
- Lets you preview the captured mesh in QuickLook, replay the video inline, rename the scan, share both files via the system share sheet, or delete the scan.

## Hardware requirements

- iPhone 12 Pro / 13 Pro / 14 Pro / 15 Pro / 16 Pro (any Pro model) **or** iPad Pro (2020 or later) — every LiDAR-equipped iOS device works.
- iOS / iPadOS 17 or later.
- Xcode 15+ on macOS to build.

The app gracefully tells the user if it is run on a device without a LiDAR sensor.

## Project layout

```
LidarCapture/
├── project.yml                 # XcodeGen spec (generates .xcodeproj)
└── LidarCapture/
    ├── LidarCaptureApp.swift   # SwiftUI app entry point
    ├── Theme.swift             # Mercury Contracting #0C3B1C accent
    ├── Info.plist              # camera + mic permissions, ARKit capability
    ├── Models/
    │   └── Scan.swift          # Codable scan metadata
    ├── Storage/
    │   └── ScanStore.swift     # On-disk scan index + file management
    ├── Capture/
    │   ├── ScanCoordinator.swift   # ARSession + delegate, mesh + video pipeline
    │   ├── VideoRecorder.swift     # AVAssetWriter wrapper for AR video frames
    │   └── MeshExporter.swift      # ARMeshAnchor -> world-space OBJ writer
    ├── Views/
    │   ├── RootView.swift
    │   ├── CaptureView.swift       # Live AR view + capture button
    │   ├── ARViewContainer.swift   # SwiftUI bridge for RealityKit ARView
    │   ├── ScanLibraryView.swift   # List of saved scans
    │   └── ScanDetailView.swift    # Player + mesh QuickLook + share/delete
    └── Assets.xcassets/        # AppIcon + AccentColor (#0C3B1C)
```

## Generating the Xcode project

The repository ships with an [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec at `LidarCapture/project.yml`. Generate the `.xcodeproj` once on macOS:

```sh
brew install xcodegen
cd LidarCapture
xcodegen generate
open LidarCapture.xcodeproj
```

Then in Xcode:

1. Select the `LidarCapture` target → **Signing & Capabilities** → set your team.
2. Connect a LiDAR-equipped iPhone or iPad (the simulator does not expose ARKit / LiDAR).
3. Run.

## How a scan works

1. `CaptureView` mounts `ARViewContainer`, which hands the `ARView` to `ScanCoordinator`.
2. `ScanCoordinator.prepareSession()` runs an `ARWorldTrackingConfiguration` with `sceneReconstruction = .meshWithClassification` and `frameSemantics = .smoothedSceneDepth` (falls back to `.sceneDepth`).
3. Tap the capture button → `startScan()` begins an `AVAssetWriter` (H.264, recommended high-resolution AR video format) and resets reconstruction.
4. `ARSessionDelegate.session(_:didUpdate:)` is called every frame:
   - The frame's `capturedImage` (BGRA `CVPixelBuffer`) is appended to the writer with relative PTS.
   - Tracking quality is published to the UI.
5. New `ARMeshAnchor`s appear via `didAdd` / `didUpdate` and are visualised with `showSceneUnderstanding`.
6. Stop → the writer finalises the MP4, then `MeshExporter.exportOBJ` walks every `ARMeshAnchor`, transforms each vertex into world space, and writes a single `.obj` file with normals.
7. Metadata + filenames are persisted by `ScanStore` as JSON in the app's Documents directory.

## Permissions

`Info.plist` declares:

- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSPhotoLibraryAddUsageDescription`
- `arkit` in `UIRequiredDeviceCapabilities`

The user is prompted on first launch when the AR session starts.

## Limitations / future work

- The OBJ export is geometry only — no texture atlas. A future pass could project the recorded video back onto the mesh to produce a textured USDZ.
- Scans are stored locally; iCloud sync and direct USDZ export would be natural follow-ups.
- The capture button is disabled gracefully on non-LiDAR devices, but ARKit still runs the camera preview.

---

© Mercury Contracting · accent `#0C3B1C`
