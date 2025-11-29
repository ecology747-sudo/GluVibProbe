//
//  HealthStore_Archive.swift
//  GluVibProbe
//

import Foundation
import HealthKit
import Combine

final class HealthStore_Archive: ObservableObject {

    // Singleton-Instanz der App
    static let shared = HealthStore()

    let healthStore = HKHealthStore()   // ⚠️ internal für Extensions
    let isPreview: Bool

    // Standard-Init
    init(isPreview: Bool = false) {
        self.isPreview = isPreview
    }

    // MARK: - Published Values für SwiftUI

    // -------------------------
    // 🔶 STEPS
    // -------------------------

    /// Schritte heute
    @Published var todaySteps: Int = 0

    /// Schritte der letzten 90 Tage
    @Published var last90Days: [DailyStepsEntry] = []

    /// Monatliche Schritte (letzte 5 Monate)
    @Published var monthlySteps: [MonthlyMetricEntry] = []

    // -------------------------
    // 🔶 ACTIVITY ENERGY (kcal)
    // -------------------------

    /// Aktivitätsenergie heute
    @Published var todayActiveEnergy: Int = 0

    /// Aktivitätsenergie der letzten 90 Tage
    @Published var last90DaysActiveEnergy: [ActivityEnergyEntry] = []

    /// Monatliche Aktivitätsenergie (letzte 5 Monate)
    @Published var monthlyActiveEnergy: [MonthlyMetricEntry] = []

    // -------------------------
    // 🔵 SLEEP (Minuten)
    // -------------------------

    /// Schlaf heute in Minuten
    @Published var todaySleepMinutes: Int = 0

    /// Schlaf der letzten 90 Tage
    @Published var last90DaysSleep: [DailySleepEntry] = []

    /// Monatlicher Schlaf (Summen)
    @Published var monthlySleep: [MonthlyMetricEntry] = []

    // -------------------------
    // 🟠 WEIGHT (kg)
    // -------------------------

    /// Heutiges Gewicht in kg
    @Published var todayWeightKg: Int = 0

    /// Gewicht der letzten 90 Tage (für 90d-Chart),
    /// `steps`-Feld wird hier als "weightKg" verwendet
    @Published var last90DaysWeight: [DailyStepsEntry] = []

    /// Monatliche Gewichtswerte (z. B. Ø Gewicht / Monat)
    @Published var monthlyWeight: [MonthlyMetricEntry] = []

    // MARK: - Preview Caches

    var previewDailySteps: [DailyStepsEntry] = []
    var previewDailyActiveEnergy: [ActivityEnergyEntry] = []
    var previewDailySleep: [DailySleepEntry] = []
    var previewDailyWeight: [DailyStepsEntry] = []      // Weight-Preview wie Steps/Sleep

    // MARK: - Authorization

    func requestAuthorization() {
        if isPreview { return }

        guard
            let stepType         = HKQuantityType.quantityType(forIdentifier: .stepCount),
            let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            let sleepType        = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            let weightType       = HKQuantityType.quantityType(forIdentifier: .bodyMass)   // Gewicht
        else { return }

        healthStore.requestAuthorization(
            toShare: [],
            read: [stepType, activeEnergyType, sleepType, weightType]
        ) { success, error in
            if success {
                // STEPS
                self.fetchStepsToday()
                self.fetchLast90Days()
                self.fetchMonthlySteps()

                // ACTIVITY ENERGY
                self.fetchActiveEnergyToday()
                self.fetchLast90DaysActiveEnergy()
                self.fetchMonthlyActiveEnergy()

                // SLEEP  👉 Implementierung jetzt in HealthStore+Sleep.swift
                self.fetchSleepToday()
                self.fetchLast90DaysSleep()
                self.fetchMonthlySleep()

                // WEIGHT
                self.fetchWeightToday()
                self.fetchLast90DaysWeight()
                self.fetchMonthlyWeight()
            } else {
                print("HealthKit Auth fehlgeschlagen:", error?.localizedDescription ?? "unbekannt")
            }
        }
    }

    // ============================================================
    // MARK: - STEPS
    // ============================================================

    func fetchStepsToday() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            DispatchQueue.main.async { self.todaySteps = Int(value) }
        }

        healthStore.execute(query)
    }

    // Helper Steps
    private func fetchLastNDays(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyStepsEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -(days-1), to: todayStart) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])

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
            results?.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                daily.append(DailyStepsEntry(date: stats.startDate, steps: Int(value)))
            }
            DispatchQueue.main.async { assign(daily.sorted { $0.date < $1.date }) }
        }

        healthStore.execute(query)
    }

    func fetchStepsDaily(last days: Int, assign: @escaping ([DailyStepsEntry]) -> Void) {
        if isPreview {
            let slice = Array(previewDailySteps.suffix(days))
            DispatchQueue.main.async { assign(slice) }
            return
        }

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        fetchLastNDays(quantityType: stepType, unit: .count(), days: days, assign: assign)
    }

    func fetchLast90Days() {
        fetchStepsDaily(last: 90) { [weak self] entries in self?.last90Days = entries }
    }

    func fetchMonthlySteps() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)
        guard let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: startOfToday)),
              let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: startOfToday, options: .strictStartDate)
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
                temp.append(MonthlyMetricEntry(monthShort: monthShort, value: Int(value)))
            }

            DispatchQueue.main.async { self.monthlySteps = temp }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - ACTIVITY ENERGY
    // ============================================================

    func fetchActiveEnergyToday() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            DispatchQueue.main.async { self.todayActiveEnergy = Int(value) }
        }

        healthStore.execute(query)
    }

    private func fetchLastNDaysActiveEnergy(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([ActivityEnergyEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -(days-1), to: todayStart) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])

        var daily: [ActivityEnergyEntry] = []
        let interval = DateComponents(day: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            results?.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                daily.append(ActivityEnergyEntry(date: stats.startDate, activeEnergy: Int(value)))
            }

            DispatchQueue.main.async {
                assign(daily.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }

    func fetchActiveEnergyDaily(last days: Int, assign: @escaping ([ActivityEnergyEntry]) -> Void) {
        if isPreview {
            let slice = Array(previewDailyActiveEnergy.suffix(days))
            DispatchQueue.main.async { assign(slice) }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        fetchLastNDaysActiveEnergy(
            quantityType: type,
            unit: .kilocalorie(),
            days: days,
            assign: assign
        )
    }

    func fetchLast90DaysActiveEnergy() {
        fetchActiveEnergyDaily(last: 90) { [weak self] entries in
            self?.last90DaysActiveEnergy = entries
        }
    }

    func fetchMonthlyActiveEnergy() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)
        guard let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: startOfToday, options: .strictStartDate)
        let interval = DateComponents(month: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: type,
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
                temp.append(MonthlyMetricEntry(monthShort: monthShort, value: Int(value)))
            }

            DispatchQueue.main.async { self.monthlyActiveEnergy = temp }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - WEIGHT (kg) – Body Domain
    // ============================================================

    /// Heutiges Gewicht in kg
    func fetchWeightToday() {
        if isPreview {
            // Im Preview setzen wir den Wert direkt im preview()-Factory
            return
        }

        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

        // letzter Wert insgesamt
        let predicate = HKQuery.predicateForSamples(
            withStart: nil,
            end: Date(),
            options: []
        )

        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        let query = HKSampleQuery(
            sampleType: weightType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard
                let self,
                let sample = samples?.first as? HKQuantitySample
            else { return }

            let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))

            DispatchQueue.main.async {
                self.todayWeightKg = Int(round(kg))
            }
        }

        healthStore.execute(query)
    }

    /// Tägliches Gewicht der letzten `days` Tage
    /// 👉 generisch als [DailyStepsEntry], `steps` = weightKg
    func fetchWeightDaily(
        last days: Int,
        completion: @escaping ([DailyStepsEntry]) -> Void
    ) {
        if isPreview {
            let slice = Array(previewDailyWeight.suffix(days))
            DispatchQueue.main.async { completion(slice) }
            return
        }

        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return
        }

        let calendar   = Calendar.current
        let now        = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: []
        )

        let interval = DateComponents(day: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: weightType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,   // Ø Gewicht pro Tag
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            var daily: [DailyStepsEntry] = []

            results?.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let valueKg = stats.averageQuantity()?.doubleValue(for: .gramUnit(with: .kilo)) ?? 0
                daily.append(
                    DailyStepsEntry(
                        date: stats.startDate,
                        steps: Int(round(valueKg))    // steps = weightKg
                    )
                )
            }

            DispatchQueue.main.async {
                completion(daily.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }

    /// Gewicht der letzten 90 Tage → für 90d-Chart
    func fetchLast90DaysWeight() {
        fetchWeightDaily(last: 90) { [weak self] entries in
            self?.last90DaysWeight = entries
        }
    }

    /// Monatliche Gewichtswerte (Ø Gewicht / Monat)
    func fetchMonthlyWeight() {
        fetchWeightDaily(last: 180) { [weak self] entries in
            guard let self else { return }

            let calendar = Calendar.current
            var perMonth: [DateComponents: (sum: Int, count: Int)] = [:]

            for e in entries {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                var bucket = perMonth[comps] ?? (0, 0)
                bucket.sum   += e.steps
                bucket.count += 1
                perMonth[comps] = bucket
            }

            let sortedKeys = perMonth.keys.sorted { lhs, rhs in
                let l = calendar.date(from: lhs) ?? .distantPast
                let r = calendar.date(from: rhs) ?? .distantPast
                return l < r
            }

            let result: [MonthlyMetricEntry] = sortedKeys.map { comps in
                let date       = calendar.date(from: comps) ?? Date()
                let monthShort = date.formatted(.dateTime.month(.abbreviated))
                let bucket     = perMonth[comps] ?? (0, 1)
                let avg        = bucket.count > 0 ? bucket.sum / bucket.count : 0
                return MonthlyMetricEntry(monthShort: monthShort, value: avg)
            }

            DispatchQueue.main.async {
                self.monthlyWeight = result
            }
        }
    }
}

// ============================================================
// MARK: - PREVIEW STORE
// ============================================================

extension HealthStore {
    static func preview() -> HealthStore {
        let store = HealthStore(isPreview: true)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // STEPS (Demo)
        store.todaySteps = 8_532
        store.previewDailySteps = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            return DailyStepsEntry(date: d, steps: Int.random(in: 3_000...12_000))
        }.sorted { $0.date < $1.date }
        store.last90Days = Array(store.previewDailySteps.suffix(90))
        store.monthlySteps = [
            .init(monthShort: "Jul", value: 140_000),
            .init(monthShort: "Aug", value: 152_000),
            .init(monthShort: "Sep", value: 165_000),
            .init(monthShort: "Okt", value: 158_000),
            .init(monthShort: "Nov", value: 171_000)
        ]

        // ACTIVITY ENERGY (Demo)
        store.todayActiveEnergy = 650
        store.previewDailyActiveEnergy = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            return ActivityEnergyEntry(date: d, activeEnergy: Int.random(in: 200...1_200))
        }.sorted { $0.date < $1.date }
        store.last90DaysActiveEnergy = Array(store.previewDailyActiveEnergy.suffix(90))
        store.monthlyActiveEnergy = [
            .init(monthShort: "Jul", value: 18_200),
            .init(monthShort: "Aug", value: 19_500),
            .init(monthShort: "Sep", value: 20_100),
            .init(monthShort: "Okt", value: 19_800),
            .init(monthShort: "Nov", value: 21_000)
        ]

        // SLEEP (Demo)
        store.todaySleepMinutes = 420   // 7h
        store.previewDailySleep = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            return DailySleepEntry(date: d, minutes: Int.random(in: 300...540))
        }.sorted { $0.date < $1.date }
        store.last90DaysSleep = Array(store.previewDailySleep.suffix(90))
        store.monthlySleep = [
            .init(monthShort: "Jul", value: 13_200),
            .init(monthShort: "Aug", value: 12_600),
            .init(monthShort: "Sep", value: 13_800),
            .init(monthShort: "Okt", value: 12_900),
            .init(monthShort: "Nov", value: 13_500)
        ]

        // WEIGHT (Demo – wie Steps/Sleep über Preview-Array)
        store.previewDailyWeight = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            let w = Int.random(in: 92...100)
            return DailyStepsEntry(date: d, steps: w)
        }.sorted { $0.date < $1.date }

        store.last90DaysWeight = Array(store.previewDailyWeight.suffix(90))

        // Monatsdurchschnitt Gewicht aus previewDailyWeight
        let calendarComponents = Set<Calendar.Component>([.year, .month])
        var perMonth: [DateComponents: (sum: Int, count: Int)] = [:]

        for e in store.previewDailyWeight {
            let comps = calendar.dateComponents(calendarComponents, from: e.date)
            var bucket = perMonth[comps] ?? (0, 0)
            bucket.sum   += e.steps
            bucket.count += 1
            perMonth[comps] = bucket
        }

        let sortedKeys = perMonth.keys.sorted { lhs, rhs in
            let l = calendar.date(from: lhs) ?? .distantPast
            let r = calendar.date(from: rhs) ?? .distantPast
            return l < r
        }

        store.monthlyWeight = sortedKeys.map { comps in
            let date       = calendar.date(from: comps) ?? Date()
            let monthShort = date.formatted(.dateTime.month(.abbreviated))
            let bucket     = perMonth[comps] ?? (0, 1)
            let avg        = bucket.count > 0 ? bucket.sum / bucket.count : 0
            return MonthlyMetricEntry(monthShort: monthShort, value: avg)
        }

        // KPI im Preview = letzter Weight-Wert
        store.todayWeightKg = store.previewDailyWeight.last?.steps ?? 0

        return store
    }
}
