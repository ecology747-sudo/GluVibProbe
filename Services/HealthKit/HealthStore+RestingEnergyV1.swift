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
import OSLog // 🟨 UPDATED

// ============================================================
// MARK: - Entry Types (V1)
// ============================================================

struct RestingEnergyEntry: Identifiable {
    let id = UUID()
    let date: Date
    let restingEnergyKcal: Int
}

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
                GluLog.restingEnergy.debug("fetchRestingEnergyTodayV1 preview applied | todayRestingEnergy=\(self.todayRestingEnergyKcal, privacy: .public)") // 🟨 UPDATED
            }
            return
        }

        GluLog.restingEnergy.notice("fetchRestingEnergyTodayV1 started") // 🟨 UPDATED

        guard let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else {
            GluLog.restingEnergy.error("fetchRestingEnergyTodayV1 failed | quantityTypeUnavailable=true") // 🟨 UPDATED
            return
        }

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
                guard let self else { return }
                self.todayRestingEnergyKcal = max(0, Int(value.rounded()))
                GluLog.restingEnergy.notice("fetchRestingEnergyTodayV1 finished | todayRestingEnergy=\(self.todayRestingEnergyKcal, privacy: .public)") // 🟨 UPDATED
            }
        }

        healthStore.execute(query)
    }

    /// 90d Serie (für Yesterday/DayBefore Mapping im Overview)
    func fetchLast90DaysRestingEnergyV1() {
        if isPreview {
            DispatchQueue.main.async {
                self.last90DaysRestingEnergy = []
                GluLog.restingEnergy.debug("fetchLast90DaysRestingEnergyV1 preview applied | entries=0") // 🟨 UPDATED
            }
            return
        }

        GluLog.restingEnergy.notice("fetchLast90DaysRestingEnergyV1 started") // 🟨 UPDATED

        guard let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else {
            GluLog.restingEnergy.error("fetchLast90DaysRestingEnergyV1 failed | quantityTypeUnavailable=true") // 🟨 UPDATED
            return
        }

        fetchDailySeriesRestingEnergyV1(
            quantityType: type,
            unit: .kilocalorie(),
            days: 90
        ) { [weak self] entries in
            guard let self else { return }
            self.last90DaysRestingEnergy = entries
            GluLog.restingEnergy.notice("fetchLast90DaysRestingEnergyV1 finished | entries=\(entries.count, privacy: .public)") // 🟨 UPDATED
        }
    }

    /// Monatswerte (cumulativeSum pro Monat; letzte ~5 Monate)
    func fetchMonthlyRestingEnergyV1() {
        if isPreview {
            DispatchQueue.main.async {
                self.monthlyRestingEnergy = []
                GluLog.restingEnergy.debug("fetchMonthlyRestingEnergyV1 preview applied | entries=0") // 🟨 UPDATED
            }
            return
        }

        GluLog.restingEnergy.notice("fetchMonthlyRestingEnergyV1 started") // 🟨 UPDATED

        guard let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else {
            GluLog.restingEnergy.error("fetchMonthlyRestingEnergyV1 failed | quantityTypeUnavailable=true") // 🟨 UPDATED
            return
        }

        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        guard
            let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
            let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
        else {
            GluLog.restingEnergy.error("fetchMonthlyRestingEnergyV1 failed | startDateUnavailable=true") // 🟨 UPDATED
            return
        }

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
            guard let self, let results else {
                GluLog.restingEnergy.notice("fetchMonthlyRestingEnergyV1 finished | resultsEmpty=true") // 🟨 UPDATED
                return
            }

            var temp: [MonthlyMetricEntry] = []
            temp.reserveCapacity(5)

            results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))
                temp.append(MonthlyMetricEntry(monthShort: monthShort, value: max(0, Int(value.rounded()))))
            }

            DispatchQueue.main.async {
                self.monthlyRestingEnergy = temp
                GluLog.restingEnergy.notice("fetchMonthlyRestingEnergyV1 finished | entries=\(temp.count, privacy: .public)") // 🟨 UPDATED
            }
        }

        healthStore.execute(query)
    }

    /// 365d Basereihe (für stabile Averages / spätere Erweiterungen)
    func fetchRestingEnergyDaily365V1() {
        if isPreview {
            DispatchQueue.main.async {
                self.restingEnergyDaily365 = []
                GluLog.restingEnergy.debug("fetchRestingEnergyDaily365V1 preview applied | entries=0") // 🟨 UPDATED
            }
            return
        }

        GluLog.restingEnergy.notice("fetchRestingEnergyDaily365V1 started") // 🟨 UPDATED

        guard let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else {
            GluLog.restingEnergy.error("fetchRestingEnergyDaily365V1 failed | quantityTypeUnavailable=true") // 🟨 UPDATED
            return
        }

        fetchDailySeriesRestingEnergyDaily365V1(
            quantityType: type,
            unit: .kilocalorie(),
            days: 365
        ) { [weak self] entries in
            guard let self else { return }
            self.restingEnergyDaily365 = entries
            GluLog.restingEnergy.notice("fetchRestingEnergyDaily365V1 finished | entries=\(entries.count, privacy: .public)") // 🟨 UPDATED
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

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            GluLog.restingEnergy.error("fetchDailySeriesRestingEnergyV1 failed | startDateUnavailable=true") // 🟨 UPDATED
            return
        }

        var daily: [RestingEnergyEntry] = []
        daily.reserveCapacity(days)

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
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
                daily.append(
                    RestingEnergyEntry(
                        date: stats.startDate,
                        restingEnergyKcal: max(0, Int(value.rounded()))
                    )
                )
            }

            let result = daily.sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                assign(result)
                GluLog.restingEnergy.debug("fetchDailySeriesRestingEnergyV1 finished | entries=\(result.count, privacy: .public)") // 🟨 UPDATED
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

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            GluLog.restingEnergy.error("fetchDailySeriesRestingEnergyDaily365V1 failed | startDateUnavailable=true") // 🟨 UPDATED
            return
        }

        var daily: [DailyRestingEnergyEntry] = []
        daily.reserveCapacity(days)

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
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
                daily.append(
                    DailyRestingEnergyEntry(
                        date: stats.startDate,
                        kcal: max(0, Int(value.rounded()))
                    )
                )
            }

            let result = daily.sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                assign(result)
                GluLog.restingEnergy.debug("fetchDailySeriesRestingEnergyDaily365V1 finished | entries=\(result.count, privacy: .public)") // 🟨 UPDATED
            }
        }

        healthStore.execute(query)
    }
}
