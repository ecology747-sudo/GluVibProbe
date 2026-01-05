//
//  HealthStore+CarbsV1.swift
//  GluVibProbe
//
//  Nutrition V1: Carbs (g) aus Apple Health
//
//  HealthKit-Quelle: .dietaryCarbohydrates
//  - Fetch-only (SSoT = HealthStore Published Properties)
//  - KEINE Legacy-Aliasse
//  - V1 kompatibel (Steps-V1 Pattern)
//
//  !!! NEW (Metabolic V1 Integration):
//  - Zusätzlich Raw Events (3 Tage) für Metabolic DayProfile Overlay
//  - Single-File Pattern: Daily + Events bleiben in dieser Datei
//
//  !!! NEW (Race-Condition Fix):
//  - Async Wrapper fetchLast90DaysCarbsV1Async()
//  - ermöglicht deterministisches "await" im Metabolic DailyStats Flow
//

import Foundation
import HealthKit

// ============================================================
// MARK: - HealthStore + Carbs (V1 kompatibel)
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - Public API (Entry Points) — V1 kompatibel
    // ============================================================

    /// TODAY KPI (Carbs in g seit 00:00)
    func fetchCarbsTodayV1() {
        if isPreview {
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())

            let value = previewDailyCarbs
                .first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
                .grams ?? 0

            DispatchQueue.main.async {
                self.todayCarbsGrams = max(0, value)
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else { return }

        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: .gram()) ?? 0
            DispatchQueue.main.async {
                self?.todayCarbsGrams = max(0, Int(value.rounded()))
            }
        }

        healthStore.execute(query)
    }

    /// 90d Serie (für Charts)
    func fetchLast90DaysCarbsV1() {
        if isPreview {
            let slice = Array(previewDailyCarbs.suffix(90)).sorted { $0.date < $1.date }
            DispatchQueue.main.async { self.last90DaysCarbs = slice }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else { return }

        fetchDailySeriesCarbsV1(
            quantityType: type,
            unit: .gram(),
            days: 90
        ) { [weak self] entries in
            self?.last90DaysCarbs = entries
        }
    }

    // ============================================================
    // !!! NEW: Async Wrapper (Race-Condition Fix)
    // - Nutzt denselben Helper/Query
    // - Setzt weiterhin last90DaysCarbs (SSoT)
    // - Liefert nur "await fertig"
    // ============================================================

    @MainActor
    func fetchLast90DaysCarbsV1Async() async {                                           // !!! NEW
        if isPreview {
            let slice = Array(previewDailyCarbs.suffix(90)).sorted { $0.date < $1.date }
            self.last90DaysCarbs = slice
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            fetchDailySeriesCarbsV1(
                quantityType: type,
                unit: .gram(),
                days: 90
            ) { [weak self] entries in
                self?.last90DaysCarbs = entries
                continuation.resume(returning: ())
            }
        }
    }

    /// Monatswerte (cumulativeSum pro Monat; letzte ~5 Monate wie bisher)
    func fetchMonthlyCarbsV1() {
        if isPreview {
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var bucket: [DateComponents: Int] = [:]
            for e in previewDailyCarbs where e.date >= startDate && e.date <= startOfToday {
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

            DispatchQueue.main.async { self.monthlyCarbs = result }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else { return }

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
                self.monthlyCarbs = temp
            }
        }

        healthStore.execute(query)
    }

    /// 365d Basereihe (SSoT) — heavy (Secondary)
    func fetchCarbsDaily365V1() {
        if isPreview {
            let slice = Array(previewDailyCarbs.suffix(365)).sorted { $0.date < $1.date }
            DispatchQueue.main.async { self.carbsDaily365 = slice }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else { return }

        fetchDailySeriesCarbsV1(
            quantityType: type,
            unit: .gram(),
            days: 365
        ) { [weak self] entries in
            self?.carbsDaily365 = entries
        }
    }

    // ============================================================
    // MARK: - !!! NEW: Raw Events (3 Tage) — Metabolic DayProfile Overlay
    // ============================================================

    func fetchCarbEvents3DaysV1() {
        if isPreview {
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())

            var temp: [NutritionEvent] = []

            for dayOffset in stride(from: 2, through: 0, by: -1) {
                guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: todayStart) else { continue }
                let grams = previewDailyCarbs.first(where: { calendar.isDate($0.date, inSameDayAs: day) })?.grams ?? 0
                guard grams > 0 else { continue }

                let noon = calendar.date(byAdding: .hour, value: 12, to: day) ?? day
                temp.append(
                    NutritionEvent(
                        id: UUID(),
                        timestamp: noon,
                        grams: Double(grams),
                        kind: .carbs
                    )
                )
            }

            DispatchQueue.main.async {
                self.carbEvents3Days = temp.sorted { $0.timestamp < $1.timestamp }
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else { return }

        fetchRawCarbEvents3DaysV1(
            quantityType: type,
            unit: .gram()
        ) { [weak self] events in
            self?.carbEvents3Days = events
        }
    }
}

// ============================================================
// MARK: - Private Helpers (Carbs V1 only) — V1 kompatibel
// ============================================================

private extension HealthStore {

    func fetchDailySeriesCarbsV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyCarbsEntry]) -> Void
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

        var daily: [DailyCarbsEntry] = []

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
                    DailyCarbsEntry(
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

    func fetchRawCarbEvents3DaysV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        assign: @escaping ([NutritionEvent]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -2, to: todayStart) else {
            DispatchQueue.main.async { assign([]) }
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(
            sampleType: quantityType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { _, samples, _ in
            let quantitySamples = (samples as? [HKQuantitySample]) ?? []

            let events: [NutritionEvent] = quantitySamples.map { s in
                let grams = s.quantity.doubleValue(for: unit)
                return NutritionEvent(
                    id: UUID(),
                    timestamp: s.startDate,
                    grams: max(0, grams),
                    kind: .carbs
                )
            }

            DispatchQueue.main.async {
                assign(events)
            }
        }

        healthStore.execute(query)
    }
}
