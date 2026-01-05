//
//  HealthStore+FatV1.swift
//  GluVibProbe
//
//  Nutrition V1: Fat (g) aus Apple Health
//
//  HealthKit-Quelle: .dietaryFatTotal
//  - Fetch-only (SSoT = HealthStore Published Properties)
//  - KEINE Legacy-Aliasse
//  - V1 kompatibel
//

import Foundation
import HealthKit

// ============================================================
// MARK: - HealthStore + Fat (V1 kompatibel)
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - Public API (Entry Points) — V1 kompatibel
    // ============================================================

    /// TODAY KPI (Fat in g seit 00:00)
    func fetchFatTodayV1() {
        if isPreview {
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let value = previewDailyFat
                .first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
                .grams ?? 0

            DispatchQueue.main.async {
                self.todayFatGrams = max(0, value)
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) else { return }

        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: .gram()) ?? 0
            DispatchQueue.main.async {
                self?.todayFatGrams = max(0, Int(value.rounded()))
            }
        }

        healthStore.execute(query)
    }

    /// 90d Serie (für Charts)
    func fetchLast90DaysFatV1() {
        if isPreview {
            let slice = Array(previewDailyFat.suffix(90)).sorted { $0.date < $1.date }
            DispatchQueue.main.async { self.last90DaysFat = slice }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) else { return }

        fetchDailySeriesFatV1(
            quantityType: type,
            unit: .gram(),
            days: 90
        ) { [weak self] entries in
            self?.last90DaysFat = entries
        }
    }

    /// Monatswerte (cumulativeSum pro Monat; letzte ~5 Monate)
    func fetchMonthlyFatV1() {
        if isPreview {
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var bucket: [DateComponents: Int] = [:]
            for e in previewDailyFat where e.date >= startDate && e.date <= startOfToday {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                bucket[comps, default: 0] += max(0, e.grams)
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

            DispatchQueue.main.async { self.monthlyFat = result }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) else { return }

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
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self, let results else { return }

            var temp: [MonthlyMetricEntry] = []

            results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: .gram()) ?? 0
                let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))
                temp.append(
                    MonthlyMetricEntry(
                        monthShort: monthShort,
                        value: max(0, Int(value.rounded()))
                    )
                )
            }

            DispatchQueue.main.async {
                self.monthlyFat = temp
            }
        }

        healthStore.execute(query)
    }

    /// 365d Basereihe (SSoT) — heavy (Secondary)
    func fetchFatDaily365V1() {
        if isPreview {
            // !!! UPDATED: suffix + sort (Steps-V1 Pattern Konsistenz)
            let slice = Array(previewDailyFat.suffix(365)).sorted { $0.date < $1.date }   // !!! UPDATED
            DispatchQueue.main.async { self.fatDaily365 = slice }                          // !!! UPDATED
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) else { return }

        fetchDailySeriesFatV1(
            quantityType: type,
            unit: .gram(),
            days: 365
        ) { [weak self] entries in
            self?.fatDaily365 = entries
        }
    }
}

// ============================================================
// MARK: - Private Helpers (Fat V1 only)
// ============================================================

private extension HealthStore {

    func fetchDailySeriesFatV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyFatEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            DispatchQueue.main.async { assign([]) }
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let interval = DateComponents(day: 1)

        var daily: [DailyFatEntry] = []

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
                daily.append(
                    DailyFatEntry(
                        date: stats.startDate,
                        grams: max(0, Int(value.rounded()))
                    )
                )
            }

            DispatchQueue.main.async {
                assign(daily.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }
}
