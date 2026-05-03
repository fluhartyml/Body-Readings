//
//  Body_ReadingsApp.swift
//  Body Readings
//
//  Created by Michael Fluharty on 5/2/26.
//

import SwiftUI

@main
struct Body_ReadingsApp: App {
    @State private var health = HealthStore()
    @State private var motion = MotionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(health)
                .environment(motion)
                .task {
                    motion.start()
                }
        }
    }
}
