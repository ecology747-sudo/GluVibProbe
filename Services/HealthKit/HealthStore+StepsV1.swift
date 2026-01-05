//
//  HealthStore+StepsV1.swift
//  GluVibProbe
//
//  Steps V1 (parallel, neu aufgesetzt)
//  - Fetch-only (SSoT = HealthStore Published Properties)
//  - KEINE Legacy-Aliasse
//  - V1 kompatibel
//

import Foundation
import HealthKit

// ============================================================
// MARK: - HealthStore + Steps (V1 kompatibel)
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - Public API (Entry Points) — V1 kompatibel
    // ============================================================

    /// TODAY KPI (Steps seit 00:00)
    func fetchStepsTodayV1() {
        if isPreview {
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let value = previewDailySteps
                .first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
                .steps ?? 0

            DispatchQueue.main.async {
                self.todaySteps = max(0, value)
            }
            return
        }

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            DispatchQueue.main.async {
                self?.todaySteps = max(0, Int(value))
            }
        }

        healthStore.execute(query)
    }

    /// 90d Serie (für Charts)
    func fetchLast90DaysStepsV1() {
        if isPreview {
            let slice = Array(previewDailySteps.suffix(90)).sorted { $0.date < $1.date }
            DispatchQueue.main.async { self.last90Days = slice }
            return
        }

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        fetchDailySeriesStepsV1(
            quantityType: stepType,
            unit: .count(),
            days: 90
        ) { [weak self] entries in
            self?.last90Days = entries
        }
    }

    /// Monatswerte (cumulativeSum pro Monat; letzte ~5 Monate wie bisher)
    func fetchMonthlyStepsV1() {
        if isPreview {
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var bucket: [DateComponents: Int] = [:]
            for e in previewDailySteps where e.date >= startDate && e.date <= startOfToday {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                bucket[comps, default: 0] += max(0, e.steps)
            }

            let keys = bucket.keys.sorted {
                (calendar.date(from: $0) ?? .distantPast) < (calendar.date(from: $1) ?? .distantPast)
            }

            let result: [MonthlyMetricEntry] = keys.map { comps in
                let d = calendar.date(from: comps) ?? Date()
                return MonthlyMetricEntry(
                    monthShort: d.formatted(.dateTime.month(.abbreviated)),
                    value: bucket[comps] ?? 0
                )
            }

            DispatchQueue.main.async { self.monthlySteps = result }
            return
        }

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        guard
            let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
            let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
        else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: startOfToday, options: .strictStartDate)
        let interval = DateComponents(month: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self, let results else { return }

            var temp: [MonthlyMetricEntry] = []

            results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
                let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))
                temp.append(
                    MonthlyMetricEntry(
                        monthShort: monthShort,
                        value: max(0, Int(value))
                    )
                )
            }

            DispatchQueue.main.async {
                self.monthlySteps = temp
            }
        }

        healthStore.execute(query)
    }

    /// 365d Basereihe (SSoT) — für Mini-Trend + 7d Avg etc.
    func fetchStepsDaily365V1() {
        if isPreview {
            let slice = Array(previewDailySteps.suffix(365))
            DispatchQueue.main.async { self.stepsDaily365 = slice }
            return
        }

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        fetchDailySeriesStepsV1(
            quantityType: stepType,
            unit: .count(),
            days: 365
        ) { [weak self] entries in
            self?.stepsDaily365 = entries
        }
    }
}

// ============================================================
// MARK: - Private Helpers (Steps V1 only) — V1 kompatibel
// ============================================================

private extension HealthStore {

    func fetchDailySeriesStepsV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyStepsEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let interval = DateComponents(day: 1)

        var daily: [DailyStepsEntry] = []

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
                daily.append(DailyStepsEntry(date: stats.startDate, steps: max(0, Int(value))))
            }

            DispatchQueue.main.async {
                assign(daily.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }
}
