//
//  HealthStore.swift
//  GluVibProbe
//

import Foundation
import HealthKit
import Combine

final class HealthStore: ObservableObject {
    
    static let shared = HealthStore()

    private let healthStore = HKHealthStore()
    private let isPreview: Bool

    // Standard-Init für die App (HealthKit aktiv)
    init(isPreview: Bool = false) {
        self.isPreview = isPreview
    }

    // MARK: - Published Values für SwiftUI
    @Published var todaySteps: Int = 0
    @Published var last90Days: [DailyStepsEntry] = []
    @Published var monthlySteps: [MonthlyMetricEntry] = []

    // 🔥 Neu: Activity Energy (kcal)
    @Published var todayEnergy: Int = 0
    @Published var last90DaysEnergy: [DailyStepsEntry] = []
    @Published var monthlyEnergy: [MonthlyMetricEntry] = []

    // MARK: - Permission Request
    func requestAuthorization() {
        // ⚠️ Im Preview KEIN HealthKit-Aufruf → Demo-Daten bleiben erhalten
        if isPreview {
            return
        }

        guard
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        else {
            return
        }

        healthStore.requestAuthorization(
            toShare: [],
            read: [stepType, energyType]
        ) { success, error in
            if success {
                // Schritte
                self.fetchStepsToday()
                self.fetchLast90Days()
                self.fetchMonthlySteps()

                // 🔥 Activity Energy
                self.fetchEnergyToday()
                self.fetchLast90DaysEnergy()
                self.fetchMonthlyEnergy()
            } else {
                print("HealthKit Auth fehlgeschlagen:", error?.localizedDescription ?? "unbekannt")
            }
        }
    }

    // MARK: - Heute: Schritte
    func fetchStepsToday() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in

            let value = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0

            DispatchQueue.main.async {
                self.todaySteps = Int(value)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Helper: Letzte N Tage (tägliche Buckets)
    private func fetchLastNDays(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyStepsEntry]) -> Void
    ) {
        let calendar = Calendar.current
        
        // 🔹 Heute, 00:00 lokale Zeit
        let todayStart = calendar.startOfDay(for: Date())
        
        // 🔹 Start vor (days - 1) Tagen, ebenfalls 00:00
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            return
        }
        
        // 🔹 Alle Samples in diesem Zeitraum
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: todayStart,
            options: []
        )
        
        var daily: [DailyStepsEntry] = []
        let interval = DateComponents(day: 1)
        
        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { _, results, _ in
            results?.enumerateStatistics(from: startDate, to: todayStart) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                
                daily.append(
                    DailyStepsEntry(
                        date: stats.startDate,     // = 00:00 dieses Tages (lokal)
                        steps: Int(value)          // ⚠️ steps-Feld = Steps ODER kcal
                    )
                )
            }
            
            // 🔹 Auf dem Main-Thread Published-Werte aktualisieren
            DispatchQueue.main.async {
                assign(daily.sorted { $0.date < $1.date })
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Heute: Activity Energy (kcal)
    func fetchEnergyToday() {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: energyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in

            let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0

            DispatchQueue.main.async {
                self.todayEnergy = Int(value)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Letzte 90 Tage (täglich) – Schritte
    func fetchLast90Days() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return
        }

        // Helper verwenden
        fetchLastNDays(
            quantityType: stepType,
            unit: .count(),
            days: 90
        ) { entries in
            self.last90Days = entries
        }
    }

    // MARK: - Letzte 90 Tage (täglich) – Activity Energy
    func fetchLast90DaysEnergy() {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return
        }

        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -89, to: Date()) else {
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: Date(),
            options: []
        )

        var daily: [DailyStepsEntry] = []
        let interval = DateComponents(day: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: energyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            results?.enumerateStatistics(from: startDate, to: Date()) { stats, _ in
                let energy = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0

                daily.append(
                    DailyStepsEntry(
                        date: stats.startDate,
                        steps: Int(energy)   // steps-Feld enthält hier kcal
                    )
                )
            }

            DispatchQueue.main.async {
                self.last90DaysEnergy = daily.sorted { $0.date < $1.date }
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Monatliche Schritte (letzte 5 Monate inkl. aktuellem Monat)
    func fetchMonthlySteps() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return
        }

        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        // sauberer Monatsanfang
        guard let startOfCurrentMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: startOfToday)
        ) else { return }

        // Start vor 4 Monaten
        guard let startDate = calendar.date(
            byAdding: .month, value: -4, to: startOfCurrentMonth
        ) else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: startOfToday,
            options: .strictStartDate
        )

        let interval = DateComponents(month: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results else { return }

            var temp: [MonthlyMetricEntry] = []

            results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
                let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))

                temp.append(
                    MonthlyMetricEntry(
                        monthShort: monthShort,
                        value: Int(value)
                    )
                )
            }

            DispatchQueue.main.async {
                self.monthlySteps = temp
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Monatliche Activity Energy (letzte 5 Monate inkl. aktuellem Monat)
    func fetchMonthlyEnergy() {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return
        }

        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        // sauberer Monatsanfang
        guard let startOfCurrentMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: startOfToday)
        ) else { return }

        // Start vor 4 Monaten
        guard let startDate = calendar.date(
            byAdding: .month, value: -4, to: startOfCurrentMonth
        ) else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: startOfToday,
            options: .strictStartDate
        )

        let interval = DateComponents(month: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: energyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results else { return }

            var temp: [MonthlyMetricEntry] = []

            results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))

                temp.append(
                    MonthlyMetricEntry(
                        monthShort: monthShort,
                        value: Int(value)
                    )
                )
            }

            DispatchQueue.main.async {
                self.monthlyEnergy = temp
            }
        }

        healthStore.execute(query)
    }
}

// MARK: - Preview Store (Demo-Daten, KEIN HealthKit)
extension HealthStore {
    static func preview() -> HealthStore {
        let store = HealthStore(isPreview: true)

        // Schritte (Demo)
        store.todaySteps = 8_532

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Demo 90 days – Schritte
        store.last90Days = (0..<90).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            return DailyStepsEntry(date: d, steps: Int.random(in: 2_000...12_000))
        }.sorted { $0.date < $1.date }

        // Demo monthly data – Schritte
        store.monthlySteps = [
            MonthlyMetricEntry(monthShort: "Jul", value: 140_000),
            MonthlyMetricEntry(monthShort: "Aug", value: 152_000),
            MonthlyMetricEntry(monthShort: "Sep", value: 165_000),
            MonthlyMetricEntry(monthShort: "Okt", value: 158_000),
            MonthlyMetricEntry(monthShort: "Nov", value: 171_000),
        ]

        // 🔥 Demo-Daten für Activity Energy (kcal)
        store.todayEnergy = 567

        store.last90DaysEnergy = (0..<90).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            return DailyStepsEntry(date: d, steps: Int.random(in: 300...1_200)) // steps-Feld = kcal
        }.sorted { $0.date < $1.date }

        store.monthlyEnergy = [
            MonthlyMetricEntry(monthShort: "Jul", value: 22_500),
            MonthlyMetricEntry(monthShort: "Aug", value: 24_200),
            MonthlyMetricEntry(monthShort: "Sep", value: 23_800),
            MonthlyMetricEntry(monthShort: "Okt", value: 25_100),
            MonthlyMetricEntry(monthShort: "Nov", value: 24_900),
        ]

        return store
    }
}
