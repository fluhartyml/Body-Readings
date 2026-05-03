//
//  MotionStore.swift
//  Body Readings
//
//  Created by Michael Fluharty on 5/3/26.
//

import Foundation
import CoreMotion
import Observation

@MainActor
@Observable
final class MotionStore {
    private let manager = CMMotionManager()

    var x: Double = 0
    var y: Double = 0
    var z: Double = 0
    var isStreaming = false
    var isAvailable: Bool { manager.isAccelerometerAvailable }

    func start() {
        guard manager.isAccelerometerAvailable, !isStreaming else { return }
        manager.accelerometerUpdateInterval = 1.0 / 30.0
        manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            self.x = data.acceleration.x
            self.y = data.acceleration.y
            self.z = data.acceleration.z
        }
        isStreaming = true
    }

    func stop() {
        guard isStreaming else { return }
        manager.stopAccelerometerUpdates()
        isStreaming = false
    }
}
