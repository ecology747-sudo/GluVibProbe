//
//  HealthStore.swift
//  GluVibProbe
//

import Foundation
import HealthKit
import Combine

final class HealthStore: ObservableObject {

    // Singleton-Instanz der App
    static let shared = HealthStore()

    private let healthStore = HKHealthStore()
    private let isPreview: Bool

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

    // MARK: - Preview Caches

    private var previewDailySteps: [DailyStepsEntry] = []
    private var previewDailyActiveEnergy: [ActivityEnergyEntry] = []
    private var previewDailySleep: [DailySleepEntry] = []

    // MARK: - Authorization

    func requestAuthorization() {
        if isPreview { return }

        guard
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
            let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        else { return }

        healthStore.requestAuthorization(
            toShare: [],
            read: [stepType, activeEnergyType, sleepType]
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

                // SLEEP
                self.fetchSleepToday()
                self.fetchLast90DaysSleep()
                self.fetchMonthlySleep()
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
    // MARK: - SLEEP (Minuten)
    // ============================================================

    // Heute
    func fetchSleepToday() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { [weak self] _, samples, _ in
            guard let self else { return }

            let all = samples as? [HKCategorySample] ?? []

            let seconds = all.reduce(0.0) { acc, sample in
                acc + sample.endDate.timeIntervalSince(sample.startDate)
            }

            DispatchQueue.main.async {
                self.todaySleepMinutes = Int(seconds / 60.0)
            }
        }

        healthStore.execute(query)
    }

    // Sleep N Tage
    func fetchSleepDaily(
        last days: Int,
        assign: @escaping ([DailySleepEntry]) -> Void
    ) {
        if isPreview {
            let slice = Array(previewDailySleep.suffix(days))
            DispatchQueue.main.async { assign(slice) }
            return
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { _, samples, _ in
            let all = samples as? [HKCategorySample] ?? []
            let calendar = Calendar.current

            var bucket: [Date: TimeInterval] = [:]

            for s in all {
                var current = s.startDate
                let end = s.endDate

                while current < end {
                    let dayStart = calendar.startOfDay(for: current)
                    guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }

                    let segmentEnd = min(end, nextDay)
                    let duration = segmentEnd.timeIntervalSince(current)

                    bucket[dayStart, default: 0] += duration
                    current = segmentEnd
                }
            }

            let entries: [DailySleepEntry] = bucket.map { (day, seconds) in
                DailySleepEntry(date: day, minutes: Int(seconds / 60.0))
            }
            .sorted { $0.date < $1.date }

            DispatchQueue.main.async { assign(entries) }
        }

        healthStore.execute(query)
    }

    func fetchLast90DaysSleep() {
        fetchSleepDaily(last: 90) { [weak self] entries in
            self?.last90DaysSleep = entries
        }
    }

    func fetchMonthlySleep() {
        fetchSleepDaily(last: 150) { [weak self] entries in
            guard let self else { return }

            let calendar = Calendar.current
            var perMonth: [DateComponents: Int] = [:]

            for day in entries {
                let comps = calendar.dateComponents([.year, .month], from: day.date)
                perMonth[comps, default: 0] += day.minutes
            }

            let sorted = perMonth.keys.sorted {
                let l = calendar.date(from: $0) ?? .distantPast
                let r = calendar.date(from: $1) ?? .distantPast
                return l < r
            }

            let result = sorted.map { comps in
                let date = calendar.date(from: comps) ?? Date()
                let monthShort = date.formatted(.dateTime.month(.abbreviated))
                return MonthlyMetricEntry(monthShort: monthShort, value: perMonth[comps] ?? 0)
            }

            DispatchQueue.main.async { self.monthlySleep = result }
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
            return DailyStepsEntry(date: d, steps: Int.random(in: 3000...12000))
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
            return ActivityEnergyEntry(date: d, activeEnergy: Int.random(in: 200...1200))
        }.sorted { $0.date < $1.date }
        store.last90DaysActiveEnergy = Array(store.previewDailyActiveEnergy.suffix(90))
        store.monthlyActiveEnergy = [
            .init(monthShort: "Jul", value: 18200),
            .init(monthShort: "Aug", value: 19500),
            .init(monthShort: "Sep", value: 20100),
            .init(monthShort: "Okt", value: 19800),
            .init(monthShort: "Nov", value: 21000)
        ]

        // SLEEP (Demo)
        store.todaySleepMinutes = 420   // 7h
        store.previewDailySleep = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            return DailySleepEntry(date: d, minutes: Int.random(in: 300...540))
        }.sorted { $0.date < $1.date }
        store.last90DaysSleep = Array(store.previewDailySleep.suffix(90))
        store.monthlySleep = [
            .init(monthShort: "Jul", value: 13200),
            .init(monthShort: "Aug", value: 12600),
            .init(monthShort: "Sep", value: 13800),
            .init(monthShort: "Okt", value: 12900),
            .init(monthShort: "Nov", value: 13500)
        ]

        return store
    }
}
