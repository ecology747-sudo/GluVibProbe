///
//  HealthStore.swift
//  GluVibProbe
//

import Foundation
import HealthKit
import Combine          // wichtig für ObservableObject / @Published

@MainActor
final class HealthStore: ObservableObject {

    // Dummy-Publisher, damit ObservableObject eine Change-Source hat
    @Published private var heartbeat: Bool = false

    // Zentrale HealthKit-Schnittstelle
    let healthStore = HKHealthStore()

    // Prüfen, ob Health-Daten verfügbar sind
    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // Alle Datentypen, die GluVibProbe lesen will
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()

        if let glucose = HKObjectType.quantityType(forIdentifier: .bloodGlucose) {
            types.insert(glucose)
        }
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        if let height = HKObjectType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let carbs = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            types.insert(carbs)
        }
        if let protein = HKObjectType.quantityType(forIdentifier: .dietaryProtein) {
            types.insert(protein)
        }
        if let energyConsumed = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            types.insert(energyConsumed)
        }

        return types
    }

    // KEIN failable init mehr, HealthStore existiert immer
    init() { }

    // MARK: - Berechtigungen anfragen (lesen)
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard isHealthDataAvailable else {
            completion(false)
            return
        }

        healthStore.requestAuthorization(
            toShare: nil,
            read: readTypes
        ) { success, error in
            if let error {
                print("HealthKit Auth Error:", error.localizedDescription)
            }
            completion(success)
        }
    }

    // MARK: - Letztes Körpergewicht (in kg) lesen
    func fetchLatestBodyMass(completion: @escaping (Double?) -> Void) {
        guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion(nil)
            return
        }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: bodyMassType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sort]
        ) { _, samples, error in
            guard
                error == nil,
                let sample = samples?.first as? HKQuantitySample
            else {
                completion(nil)
                return
            }

            let kg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            completion(kg)
        }

        healthStore.execute(query)
    }

    // MARK: - Schritte von heute (Summe ab Mitternacht)
    func fetchTodayStepCount(completion: @escaping (Double?) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(nil)
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, statistics, error in
            guard
                error == nil,
                let sum = statistics?.sumQuantity()
            else {
                completion(nil)
                return
            }

            let steps = sum.doubleValue(for: HKUnit.count())
            completion(steps)
        }

        healthStore.execute(query)
    }

    // MARK: - Schritte der letzten N Tage (täglich aggregiert)
    func fetchStepsLastNDays(days: Int, completion: @escaping ([Int]) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion([])
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        // Startdatum = (N-1) Tage vor heute, ab 00:00 Uhr
        guard let startDate = calendar.date(
            byAdding: .day,
            value: -max(days - 1, 0),
            to: todayStart
        ) else {
            completion([])
            return
        }

        var interval = DateComponents()
        interval.day = 1

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: todayStart,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, collection, error in
            var result: [Int] = []

            if let collection, error == nil {
                collection.enumerateStatistics(from: startDate, to: now) { stats, _ in
                    if let sum = stats.sumQuantity() {
                        let steps = sum.doubleValue(for: HKUnit.count())
                        result.append(Int(steps.rounded()))
                    } else {
                        result.append(0)
                    }
                }
            }

            // zurück auf den Main-Thread (UI)
            DispatchQueue.main.async {
                completion(result)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Letzte Blutzucker-Messung
    func fetchLatestBloodGlucose(completion: @escaping (Double?, Date?) -> Void) {
        guard let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else {
            completion(nil, nil)
            return
        }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: glucoseType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sort]
        ) { _, samples, error in

            guard
                error == nil,
                let sample = samples?.first as? HKQuantitySample
            else {
                completion(nil, nil)
                return
            }

            let mgdlUnit = HKUnit(from: "mg/dL")
            let value = sample.quantity.doubleValue(for: mgdlUnit)
            let date = sample.endDate

            completion(value, date)
        }

        healthStore.execute(query)
    }
}
