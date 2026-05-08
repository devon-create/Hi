import SwiftUI
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    let coordinator: ScanCoordinator

    func makeUIView(context: Context) -> ARView {
        coordinator.prepareSession()
        return coordinator.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
