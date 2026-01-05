//
//  HealthStore+RestingEnergyV1.swift
//  GluVibProbe
//
//  Resting Energy V1 (kcal) — Basal Energy Burned
//  - Source: Apple Health (HK: basalEnergyBurned)
//  - Fetch-only (SSoT = HealthStore Published Properties)
//  - KEINE Legacy-Aliasse
//  - KEINE neuen Published Properties (die stehen in HealthStore.swift)
//

import Foundation
import HealthKit

// ============================================================
// MARK: - Entry Types (V1)
// ============================================================

// !!! NEW: Minimaler Entry für 90d (analog ActiveEnergy: date + value)
struct RestingEnergyEntry: Identifiable {
    let id = UUID()
    let date: Date
    let restingEnergyKcal: Int
}

// !!! NEW: Minimaler Entry für 365d Base-Series (Daily)
struct DailyRestingEnergyEntry: Identifiable {
    let id = UUID()
    let date: Date
    let kcal: Int
}

// ============================================================
// MARK: - HealthStore + Resting Energy (V1)
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - Public API (Entry Points)
    // ============================================================

    /// TODAY KPI (kcal seit 00:00)
    func fetchRestingEnergyTodayV1() {

        if isPreview {
            DispatchQueue.main.async {
                self.todayRestingEnergyKcal = 0
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else { return }

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
                self?.todayRestingEnergyKcal = max(0, Int(value.rounded()))
            }
        }

        healthStore.execute(query)
    }

    /// 90d Serie (für Yesterday/DayBefore Mapping im Overview)
    func fetchLast90DaysRestingEnergyV1() {
        if isPreview {
            DispatchQueue.main.async { self.last90DaysRestingEnergy = [] }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else { return }

        fetchDailySeriesRestingEnergyV1(
            quantityType: type,
            unit: .kilocalorie(),
            days: 90
        ) { [weak self] entries in
            self?.last90DaysRestingEnergy = entries
        }
    }

    /// Monatswerte (cumulativeSum pro Monat; letzte ~5 Monate)
    func fetchMonthlyRestingEnergyV1() {
        if isPreview {
            DispatchQueue.main.async { self.monthlyRestingEnergy = [] }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else { return }

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
                temp.append(MonthlyMetricEntry(monthShort: monthShort, value: max(0, Int(value.rounded()))))
            }

            DispatchQueue.main.async {
                self.monthlyRestingEnergy = temp
            }
        }

        healthStore.execute(query)
    }

    /// 365d Basereihe (für stabile Averages / spätere Erweiterungen)
    func fetchRestingEnergyDaily365V1() {
        if isPreview {
            DispatchQueue.main.async { self.restingEnergyDaily365 = [] }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else { return }

        fetchDailySeriesRestingEnergyDaily365V1(
            quantityType: type,
            unit: .kilocalorie(),
            days: 365
        ) { [weak self] entries in
            self?.restingEnergyDaily365 = entries
        }
    }
}

// ============================================================
// MARK: - Private Helpers (Resting Energy V1 only)
// ============================================================

private extension HealthStore {

    func fetchDailySeriesRestingEnergyV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([RestingEnergyEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let interval = DateComponents(day: 1)

        var daily: [RestingEnergyEntry] = []
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
                    RestingEnergyEntry(
                        date: stats.startDate,
                        restingEnergyKcal: max(0, Int(value.rounded()))
                    )
                )
            }

            DispatchQueue.main.async {
                assign(daily.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }

    func fetchDailySeriesRestingEnergyDaily365V1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyRestingEnergyEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let interval = DateComponents(day: 1)

        var daily: [DailyRestingEnergyEntry] = []
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
                    DailyRestingEnergyEntry(
                        date: stats.startDate,
                        kcal: max(0, Int(value.rounded()))
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
