//
//  HealthStore+Protein.swift
//  GluVibProbe
//
//  Nutrition-Domain: Protein (g) aus Apple Health
//

import Foundation
import HealthKit

extension HealthStore {

    // MARK: - PROTEIN – Today (optional Helper)

    /// Summiert Protein (g) für HEUTE.
    /// Kann später fürs KPI-„Today Protein“ genutzt werden.
    func fetchProteinToday(assign: @escaping (Int) -> Void) {
        if isPreview {
            // z.B. 120 g als Demo
            DispatchQueue.main.async {
                assign(120)
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: .gram()) ?? 0
            DispatchQueue.main.async {
                assign(Int(value))
            }
        }

        healthStore.execute(query)
    }

    // MARK: - PROTEIN – Daily helper (N Tage)

    private func fetchProteinDailyInternal(
        last days: Int,
        assign: @escaping ([DailyProteinEntry]) -> Void
    ) {
        if isPreview {
            // 🔸 Demo-Daten für Preview: N Tage Protein in g
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            let demo: [DailyProteinEntry] = (0..<days).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
                // z.B. 60–180 g Protein
                let grams = Int.random(in: 60...180)
                return DailyProteinEntry(date: date, grams: grams)
            }
            .sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                assign(demo)
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) else { return }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )

        var daily: [DailyProteinEntry] = []
        let interval = DateComponents(day: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            results?.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: .gram()) ?? 0
                let grams = Int(value)
                daily.append(
                    DailyProteinEntry(
                        date: stats.startDate,
                        grams: grams
                    )
                )
            }

            let sorted = daily.sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                assign(sorted)
            }
        }

        healthStore.execute(query)
    }

    /// Öffentliche API: tägliches Protein für die letzten `days` Tage.
    func fetchProteinDaily(
        last days: Int,
        assign: @escaping ([DailyProteinEntry]) -> Void
    ) {
        fetchProteinDailyInternal(last: days, assign: assign)
    }

    // MARK: - PROTEIN – Monthly helper

    func fetchProteinMonthly(assign: @escaping ([MonthlyMetricEntry]) -> Void) {
        if isPreview {
            // 🔸 Demo-Daten: 5 Monate mit Gesamtsumme Protein in g
            let calendar = Calendar.current
            let today = Date()
            var result: [MonthlyMetricEntry] = []

            for monthOffset in (0..<5).reversed() {
                if let date = calendar.date(byAdding: .month, value: -monthOffset, to: today) {
                    let monthShort = date.formatted(.dateTime.month(.abbreviated))
                    // z.B. 8 000–15 000 g pro Monat
                    let total = Int.random(in: 8_000...15_000)
                    result.append(
                        MonthlyMetricEntry(
                            monthShort: monthShort,
                            value: total
                        )
                    )
                }
            }

            DispatchQueue.main.async {
                assign(result)
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) else { return }

        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        // Letzte 5 Monate inkl. aktuellem
        guard
            let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
            let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
        else {
            return
        }

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
                let grams = Int(value)
                let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))

                temp.append(
                    MonthlyMetricEntry(
                        monthShort: monthShort,
                        value: grams
                    )
                )
            }

            DispatchQueue.main.async {
                assign(temp)
            }
        }

        healthStore.execute(query)
    }
}
