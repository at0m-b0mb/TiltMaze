import CoreMotion

/// Thin wrapper over `CMMotionManager` device-motion gravity. The engine reads
/// `gx`/`gy` every frame to tilt the maze. On the Simulator (no sensors)
/// `available` stays false and the game falls back to drag-to-steer.
@MainActor
final class MotionManager {
    private let manager = CMMotionManager()
    private(set) var gx: Double = 0
    private(set) var gy: Double = 0
    private(set) var available = false

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        available = true
        manager.deviceMotionUpdateInterval = 1.0 / 50.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let g = motion?.gravity else { return }
            self.gx = g.x
            self.gy = g.y
        }
    }

    func stop() {
        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }
    }
}
