//
//  HealthStore.swift
//  Body Readings
//
//  Created by Michael Fluharty on 5/3/26.
//

import Foundation
import HealthKit
import Observation

@MainActor
@Observable
final class HealthStore {
    static let isAvailable = HKHealthStore.isHealthDataAvailable()

    private let store = HKHealthStore()

    private let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    private let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount)!

    var heartRate: Double? = nil
    var heartRateTimestamp: Date? = nil
    var todaysSteps: Int? = nil
    var didFinishInitialLoad = false
    var lastError: String? = nil
    var isAuthorized = false
    var hasRequestedAuth = false
    var heartRateAuthStatus: HKAuthorizationStatus = .notDetermined
    var stepsAuthStatus: HKAuthorizationStatus = .notDetermined

    func requestAuthorization() async {
        hasRequestedAuth = true
        lastError = nil
        guard Self.isAvailable else {
            lastError = "Health data isn't available on this device."
            didFinishInitialLoad = true
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: [heartRateType, stepCountType])
            heartRateAuthStatus = store.authorizationStatus(for: heartRateType)
            stepsAuthStatus = store.authorizationStatus(for: stepCountType)
            // Apple intentionally hides whether the user granted or denied READ access.
            // Both possibilities return .sharingDenied. The only way to know is to attempt the read.
            isAuthorized = true
            await refresh()
        } catch {
            lastError = error.localizedDescription
            didFinishInitialLoad = true
        }
    }

    func refresh() async {
        await loadLatestHeartRate()
        await loadTodaysSteps()
        didFinishInitialLoad = true
    }

    private func loadLatestHeartRate() async {
        await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, _ in
                Task { @MainActor in
                    guard let self else { continuation.resume(); return }
                    if let sample = samples?.first as? HKQuantitySample {
                        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
                        self.heartRate = sample.quantity.doubleValue(for: bpmUnit)
                        self.heartRateTimestamp = sample.endDate
                    } else {
                        self.heartRate = nil
                        self.heartRateTimestamp = nil
                    }
                    continuation.resume()
                }
            }
            store.execute(query)
        }
    }

    private func loadTodaysSteps() async {
        await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: nil, options: [])
            let query = HKStatisticsQuery(
                quantityType: stepCountType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { [weak self] _, statistics, _ in
                Task { @MainActor in
                    guard let self else { continuation.resume(); return }
                    if let sum = statistics?.sumQuantity() {
                        self.todaysSteps = Int(sum.doubleValue(for: HKUnit.count()))
                    } else {
                        self.todaysSteps = 0
                    }
                    continuation.resume()
                }
            }
            store.execute(query)
        }
    }
}
