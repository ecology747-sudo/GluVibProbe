//
//  HealthStore+NutritionEnergyV1.swift
//  GluVibProbe
//
//  Nutrition Energy V1 (kcal) — V1 kompatibel
//  - Fetch-only (SSoT = HealthStore Published Properties)
//  - KEINE Legacy-Aliasse
//  - KEINE neuen Published Properties
//

import Foundation
import HealthKit

// ============================================================
// MARK: - HealthStore + Nutrition Energy (V1 kompatibel)
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - Public API (Entry Points) — V1 kompatibel
    // ============================================================

    /// TODAY KPI (kcal seit 00:00)
    func fetchNutritionEnergyTodayV1() {
        if isPreview {
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())

            // !!! UPDATED: Preview aus Cache statt random (SSoT-Pattern)
            let value = previewDailyNutritionEnergy
                .first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
                .energyKcal ?? 0

            DispatchQueue.main.async {
                self.todayNutritionEnergyKcal = max(0, value)
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else { return }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            DispatchQueue.main.async {
                // !!! UPDATED: rounded (wie Carbs/Protein/Fat)
                self?.todayNutritionEnergyKcal = max(0, Int(value.rounded()))
            }
        }

        healthStore.execute(query)
    }

    /// 90d Serie (für Charts)
    func fetchLast90DaysNutritionEnergyV1() {
        if isPreview {
            // !!! UPDATED: Preview aus Cache (suffix + sort)
            let slice = Array(previewDailyNutritionEnergy.suffix(90)).sorted { $0.date < $1.date }  // !!! UPDATED
            DispatchQueue.main.async { self.last90DaysNutritionEnergy = slice }                      // !!! UPDATED
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else { return }

        fetchDailySeriesNutritionEnergyV1(
            quantityType: type,
            unit: .kilocalorie(),
            days: 90
        ) { [weak self] entries in
            self?.last90DaysNutritionEnergy = entries
        }
    }

    /// Monatswerte (cumulativeSum pro Monat; letzte ~5 Monate wie bisher)
    func fetchMonthlyNutritionEnergyV1() {
        if isPreview {
            // !!! UPDATED: Preview deterministisch aus Cache (daily -> month bucket)
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var bucket: [DateComponents: Int] = [:]
            for e in previewDailyNutritionEnergy where e.date >= startDate && e.date <= startOfToday {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                bucket[comps, default: 0] += max(0, e.energyKcal)
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

            DispatchQueue.main.async { self.monthlyNutritionEnergy = result }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else { return }

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
            temp.reserveCapacity(5)

            results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))
                // !!! UPDATED: rounded (wie Carbs/Protein/Fat)
                temp.append(MonthlyMetricEntry(monthShort: monthShort, value: max(0, Int(value.rounded()))))
            }

            DispatchQueue.main.async {
                self.monthlyNutritionEnergy = temp
            }
        }

        healthStore.execute(query)
    }

    /// 365d Basereihe (SSoT) — falls Property vorhanden (Nutrition V1 Standard)
    func fetchNutritionEnergyDaily365V1() {
        if isPreview {
            // !!! UPDATED: Preview aus Cache (suffix + sort)
            let slice = Array(previewDailyNutritionEnergy.suffix(365)).sorted { $0.date < $1.date } // !!! UPDATED
            DispatchQueue.main.async { self.nutritionEnergyDaily365 = slice }                        // !!! UPDATED
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else { return }

        fetchDailySeriesNutritionEnergyV1(
            quantityType: type,
            unit: .kilocalorie(),
            days: 365
        ) { [weak self] entries in
            self?.nutritionEnergyDaily365 = entries
        }
    }
}

// ============================================================
// MARK: - Private Helpers (Nutrition Energy V1 only) — V1 kompatibel
// ============================================================

private extension HealthStore {

    func fetchDailySeriesNutritionEnergyV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyNutritionEnergyEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let interval = DateComponents(day: 1)

        var daily: [DailyNutritionEnergyEntry] = []
        daily.reserveCapacity(days)

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
                    DailyNutritionEnergyEntry(
                        date: stats.startDate,
                        // !!! UPDATED: rounded (wie Carbs/Protein/Fat)
                        energyKcal: max(0, Int(value.rounded()))
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
