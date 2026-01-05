//
//  HealthStore+ActivityEnergyV1.swift
//  GluVibProbe
//
//  Activity Energy V1
//  - vollständig isolierte V1-Linie
//  - KEINE Abhängigkeit zu alten Dateien
//  - KEINE Abhängigkeit zu anderen V1-Dateien
//

import Foundation
import HealthKit

// ============================================================
// MARK: - HealthStore + Activity Energy (V1)
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - TODAY KPI (V1)
    // ============================================================

    func fetchActiveEnergyTodayV1() {                                         // !!! UPDATED
        if isPreview {
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())

            let value = previewDailyActiveEnergy
                .first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
                .activeEnergy ?? 0

            DispatchQueue.main.async {
                self.todayActiveEnergy = max(0, value)
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: Date(),
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
            DispatchQueue.main.async {
                self?.todayActiveEnergy = max(0, Int(value))
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - 90 DAYS (Charts) (V1)
    // ============================================================

    func fetchLast90DaysActiveEnergyV1() {                                    // !!! UPDATED
        if isPreview {
            let slice = Array(previewDailyActiveEnergy.suffix(90))
                .sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                self.last90DaysActiveEnergy = slice
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        fetchDailySeriesActiveEnergyV1(                                       // !!! UPDATED
            quantityType: type,
            unit: HKUnit.kilocalorie(),
            days: 90
        ) { entries in
            DispatchQueue.main.async {
                self.last90DaysActiveEnergy = entries
            }
        }
    }

    // ============================================================
    // MARK: - MONTHLY (V1)
    // ============================================================

    func fetchMonthlyActiveEnergyV1() {                                       // !!! UPDATED
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        guard
            let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
            let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
        else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: startOfToday,
            options: .strictStartDate
        )

        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(month: 1)
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let results else { return }

            var temp: [MonthlyMetricEntry] = []

            results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                let month = stats.startDate.formatted(.dateTime.month(.abbreviated))
                temp.append(
                    MonthlyMetricEntry(
                        monthShort: month,
                        value: max(0, Int(value))
                    )
                )
            }

            DispatchQueue.main.async {
                self?.monthlyActiveEnergy = temp
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - 365 DAYS (SSoT) (V1)
    // ============================================================

    func fetchActiveEnergyDaily365V1() {                                      // (bleibt V1)
        if isPreview {
            let slice = Array(previewDailyActiveEnergy.suffix(365))
                .sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                self.activeEnergyDaily365 = slice
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        fetchDailySeriesActiveEnergyV1(                                       // !!! UPDATED
            quantityType: type,
            unit: HKUnit.kilocalorie(),
            days: 365
        ) { entries in
            DispatchQueue.main.async {
                self.activeEnergyDaily365 = entries
            }
        }
    }
}

// ============================================================
// MARK: - Private V1 Helper (NUR in dieser Datei)
// ============================================================

private extension HealthStore {

    func fetchDailySeriesActiveEnergyV1(                                      // !!! UPDATED
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([ActivityEnergyEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(
            byAdding: .day,
            value: -(days - 1),
            to: startOfToday
        ) else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: []
        )

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )

        var daily: [ActivityEnergyEntry] = []

        query.initialResultsHandler = { _, results, _ in
            results?.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                daily.append(
                    ActivityEnergyEntry(
                        date: stats.startDate,
                        activeEnergy: max(0, Int(value))
                    )
                )
            }

            assign(daily.sorted { $0.date < $1.date })
        }

        healthStore.execute(query)
    }
}
