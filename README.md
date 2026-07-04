# LiDAR Capture

> An iPhone / iPad app that uses the **LiDAR scanner** and **video camera** to capture 3D scans of physical spaces, plus a static viewer site you can deploy to GitHub Pages so anyone can browse, replay, and inspect the scans on the web.

<sub>Mercury Contracting brand colour `#0C3B1C` is used for the iOS app accent, the web viewer accent, and document headings.</sub>

---

## Two halves of the project

| Component | Where | Purpose |
|---|---|---|
| **iOS capture app** | [`LidarCapture/`](./LidarCapture) | Native SwiftUI + ARKit + RealityKit app that drives the LiDAR scanner, records walkthrough video, and exports OBJ + USDZ. |
| **Web viewer** | [`docs/`](./docs) | Static site (HTML + three.js, no backend) that lists every published scan, plays the video, and renders the mesh in WebGL. Designed for GitHub Pages. |
| **Indexer** | [`tools/build-scan-index.mjs`](./tools/build-scan-index.mjs) | Tiny Node script (no dependencies) that walks `docs/scans/` and rebuilds `docs/scans.json`. |

The capture half needs LiDAR hardware that no browser exposes, so scanning stays native. Everything downstream — viewing, sharing a link, embedding the model — happens in any modern browser.

## Hardware requirements (capture)

- iPhone Pro (12 Pro and newer) or iPad Pro (2020 and newer) — any LiDAR-equipped iOS device.
- iOS / iPadOS 17+, Xcode 15+ on macOS to build.

The app gracefully falls back to a "LiDAR not available" message on devices without a sensor.

## Project layout

```
.
├── LidarCapture/                  # iOS app
│   ├── project.yml                # XcodeGen spec
│   └── LidarCapture/
│       ├── LidarCaptureApp.swift
│       ├── Theme.swift            # #0C3B1C accent
│       ├── Info.plist
│       ├── Models/Scan.swift
│       ├── Storage/ScanStore.swift
│       ├── Capture/
│       │   ├── ScanCoordinator.swift   # ARSession + mesh + video
│       │   ├── VideoRecorder.swift     # AVAssetWriter wrapper
│       │   ├── MeshExporter.swift      # OBJ + USDZ export (ModelIO)
│       │   └── BundleBuilder.swift     # Zips a publishable scan bundle
│       └── Views/                      # SwiftUI screens
├── docs/                          # Static viewer site (GitHub Pages root)
│   ├── index.html                 # Library page
│   ├── scan.html                  # Detail page (three.js viewer + video + AR link)
│   ├── styles.css                 # Brand styling (#0C3B1C accent)
│   ├── app.js                     # Library logic
│   ├── scan.js                    # OBJ viewer + AR Quick Look
│   ├── scans.json                 # Auto-generated index
│   ├── vendor/three/              # Vendored three.js r161 (minified build + OBJLoader + OrbitControls)
│   └── scans/<id>/                # One folder per scan: mesh.obj, mesh.usdz, video.mp4, meta.json
├── tools/
│   └── build-scan-index.mjs       # Rebuilds docs/scans.json
└── README.md
```

## Building the iOS app

```sh
brew install xcodegen
cd LidarCapture
xcodegen generate
open LidarCapture.xcodeproj
```

In Xcode: `LidarCapture` target → **Signing & Capabilities** → set your team → connect a LiDAR-equipped device → Run. The simulator can't run ARKit's LiDAR.

## Capturing a scan

1. Launch the app on a LiDAR device.
2. Move slowly through the space. The mesh streams in coloured by classification and the camera feed is recorded.
3. Tap the stop button. The app saves three artefacts to its Documents folder:
   - `<id>.obj` — world-space mesh from every `ARMeshAnchor`
   - `<id>.usdz` — same mesh re-exported via ModelIO for AR Quick Look
   - `<id>.mp4` — H.264 walkthrough video
4. Open the scan in the library, tap **Export web bundle (.zip)**. The system share sheet appears with a single zip containing `mesh.obj`, `mesh.usdz`, `video.mp4`, and `meta.json`.

## Publishing scans to the web viewer

The web side is a plain static site under `docs/`. Each scan is a folder of files. The flow:

1. **Bundle.** From the iOS app's scan detail view, tap **Export web bundle (.zip)**. Save it somewhere you can get at on a desktop (AirDrop, iCloud Drive, Files, the Working Copy iOS app, anything).
2. **Extract.** Unzip into `docs/scans/`. The folder name is the scan UUID; keep it. You should end up with:
   ```
   docs/scans/2A35F0B1-…/
       mesh.obj
       mesh.usdz
       video.mp4
       meta.json
   ```
3. **Re-index.** From the repo root:
   ```sh
   node tools/build-scan-index.mjs
   ```
   This rewrites `docs/scans.json` so the library page knows about the new scan.
4. **Commit + push.**
   ```sh
   git add docs/scans docs/scans.json
   git commit -m "Add scan: kitchen walkthrough"
   git push
   ```
5. **Open the site.** Once GitHub Pages rebuilds, the new card appears on the library page; the detail page shows the three.js mesh viewer, the video, and a **View in AR** button on iOS.

### Enabling GitHub Pages (one-time)

In the repository settings on GitHub:

1. **Settings → Pages**
2. **Source:** Deploy from a branch
3. **Branch:** `main`, folder: `/docs`
4. Save. Within a minute the site is live at `https://<owner>.github.io/<repo>/`.

The viewer fetches `scans.json` and the per-scan files relatively, so it works on any host (or `python3 -m http.server` from `docs/` for local preview).

## How the web viewer renders

- **Library page (`index.html` / `app.js`)** — fetches `scans.json` and renders a card grid.
- **Detail page (`scan.html` / `scan.js`)** —
  - Loads the OBJ via three.js's `OBJLoader`, frames the camera to its bounding box, and drives it with `OrbitControls`.
  - Lights it with one ambient + one white key light + one Mercury-green rim light, sitting on a faint grid floor.
  - Plays the walkthrough as an HTML5 `<video>`.
  - On iOS, surfaces a **View in AR** button using the USDZ via `<a rel="ar">` (Apple's AR Quick Look).
- **No backend, no build step.** three.js (r161, minified build + the two addons the viewer uses) is vendored under `docs/vendor/three/` and wired up via an import map, so the page is just static same-origin files with no CDN dependency. three.js itself is lazy-loaded only when a scan has a mesh, so the page metadata renders immediately. To upgrade three.js, download the new `three-<version>.tgz` from `registry.npmjs.org` and replace `three.module.min.js`, `addons/loaders/OBJLoader.js`, and `addons/controls/OrbitControls.js`.

## How a scan is built (iOS)

1. `CaptureView` mounts `ARViewContainer`, which hands the `ARView` to `ScanCoordinator`.
2. `ScanCoordinator.prepareSession()` runs an `ARWorldTrackingConfiguration` with `sceneReconstruction = .meshWithClassification` and `frameSemantics = .smoothedSceneDepth` (falls back to `.sceneDepth`).
3. Tap record → `startScan()` begins an `AVAssetWriter` (H.264, recommended high-resolution AR video format) and resets reconstruction.
4. `ARSessionDelegate.session(_:didUpdate:)` appends each frame's `capturedImage` (BGRA `CVPixelBuffer`) to the writer with relative PTS.
5. `ARMeshAnchor`s arrive via `didAdd` / `didUpdate` and are visualised with `showSceneUnderstanding`.
6. Stop → the writer finalises the MP4. `MeshExporter.export` walks every `ARMeshAnchor`, transforms vertices into world space, writes a single OBJ, then re-reads it via `MDLAsset` to also export USDZ.
7. `ScanStore` persists the metadata as JSON in the app's Documents directory.
8. `BundleBuilder.makeBundle` stages the three files plus a `meta.json` into a temp folder and zips it via `NSFileCoordinator(.forUploading)`.

## Permissions

`Info.plist` declares:

- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSPhotoLibraryAddUsageDescription`
- `arkit` in `UIRequiredDeviceCapabilities`

## Limitations / future work

- OBJ + USDZ export is geometry only — no texture atlas. A future pass could project the recorded video back onto the mesh to produce a textured USDZ.
- The publish flow is currently file-drop. A small GitHub-API uploader inside the iOS app could do push-button publishing from the phone directly, at the cost of a personal access token.
- The viewer assumes one scene per scan and one OBJ file. Multi-room captures could split mesh anchors per room.

---

© Mercury Contracting · accent `#0C3B1C`
