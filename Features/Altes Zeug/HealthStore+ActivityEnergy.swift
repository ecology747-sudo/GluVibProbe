//
//  HealthStore+ActivityEnergy.swift
//  GluVibProbe
//
//  Activity-Energy-Logik ausgelagert aus HealthStore.swift
//

import Foundation
import HealthKit

extension HealthStore {

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
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else { return }

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
}
