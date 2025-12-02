//
//  HealthStore+Carbs.swift
//  GluVibProbe
//
//  Nutrition-Logik für Carbohydrates (Gramm)
//

import Foundation
import HealthKit

extension HealthStore {

    // ============================================================
    // MARK: - CARBS (dietaryCarbohydrates)
    // ============================================================

    /// Kohlenhydrate heute (Gramm, Summe ab Tagesbeginn)
    func fetchCarbsToday() {
        if isPreview {
            // Demo-Wert aus previewStore
            DispatchQueue.main.async {
                self.todayCarbsGrams = self.previewDailyCarbs.last?.grams ?? 0
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay,
                                                    end: Date(),
                                                    options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: .gram()) ?? 0
            DispatchQueue.main.async {
                self.todayCarbsGrams = Int(value)
            }
        }

        healthStore.execute(query)
    }

    // Helper: N Tage Carbs als daily-Einträge
    private func fetchLastNDaysCarbs(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyCarbsEntry]) -> Void
    ) {
        if isPreview {
            let slice = Array(previewDailyCarbs.suffix(days))
            DispatchQueue.main.async { assign(slice) }
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])

        var daily: [DailyCarbsEntry] = []
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
                    DailyCarbsEntry(
                        date: stats.startDate,
                        grams: Int(value)
                    )
                )
            }

            DispatchQueue.main.async {
                assign(daily.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }

    /// Tägliche Carbs für die letzten `days` Tage
    func fetchCarbsDaily(last days: Int, assign: @escaping ([DailyCarbsEntry]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else { return }

        fetchLastNDaysCarbs(
            quantityType: type,
            unit: .gram(),
            days: days,
            assign: assign
        )
    }

    /// Carbs der letzten 90 Tage (für 90d-Chart)
    func fetchLast90DaysCarbs() {
        fetchCarbsDaily(last: 90) { [weak self] entries in
            self?.last90DaysCarbs = entries
        }
    }

    /// Monatliche Carbs-Summen (letzte 5 Monate)
    func fetchMonthlyCarbs() {
        if isPreview {
            DispatchQueue.main.async {
                self.monthlyCarbs = self.monthlyCarbs   // im Preview schon gebaut
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else { return }

        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        guard let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth) else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: startOfToday,
            options: .strictStartDate
        )

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
                let value = stats.sumQuantity()?.doubleValue(for: .gram()) ?? 0
                let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))
                temp.append(
                    MonthlyMetricEntry(
                        monthShort: monthShort,
                        value: Int(value)
                    )
                )
            }

            DispatchQueue.main.async {
                self.monthlyCarbs = temp
            }
        }

        healthStore.execute(query)
    }
}
