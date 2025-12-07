//
//  HealthStore+NutritionEnergy.swift
//  GluVibProbe
//
//  Nutrition-Domain: Nutrition Energy (kcal) aus Apple Health
//
//  HealthKit-Quelle: .dietaryEnergyConsumed
//  → intern immer in kcal speichern, Umrechnung (kcal/kJ) macht später das ViewModel.
//

import Foundation
import HealthKit

extension HealthStore {

    // MARK: - NUTRITION ENERGY – Today

    /// Summiert Nutrition Energy (kcal) für HEUTE.
    /// Kann später für das KPI "Nutrition Energy Today" genutzt werden.
    // MARK: - NUTRITION ENERGY – Today (über Daily-Logik)

    /// Heutige Nutrition-Energy (kcal) über dieselbe Daily-Logik wie die Dashboards.
    func fetchNutritionEnergyToday(assign: @escaping (Int) -> Void) {
        fetchNutritionEnergyDailyInternal(last: 1) { entries in
            let value = entries.last?.energyKcal ?? 0
            assign(value)
        }
    }

    // MARK: - NUTRITION ENERGY – Daily helper (N Tage)

    private func fetchNutritionEnergyDailyInternal(
        last days: Int,
        assign: @escaping ([DailyNutritionEnergyEntry]) -> Void
    ) {
        if isPreview {
            // 🔸 Demo-Daten für Preview: "days" Tage Nutrition Energy (kcal)
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            let demo: [DailyNutritionEnergyEntry] = (0..<days).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                    return nil
                }
                // z. B. 1 400 – 3 000 kcal pro Tag
                let kcal = Int.random(in: 1_400...3_000)
                return DailyNutritionEnergyEntry(date: date, energyKcal: kcal)
            }
            .sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                assign(demo)
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(
            byAdding: .day,
            value: -(days - 1),
            to: todayStart
        ) else {
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )

        var daily: [DailyNutritionEnergyEntry] = []
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
                let value = stats
                    .sumQuantity()?
                    .doubleValue(for: .kilocalorie()) ?? 0

                let kcal = Int(value)

                daily.append(
                    DailyNutritionEnergyEntry(
                        date: stats.startDate,
                        energyKcal: kcal
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

    /// Öffentliche API: tägliche Nutrition Energy (kcal) für die letzten `days` Tage.
    func fetchNutritionEnergyDaily(
        last days: Int,
        assign: @escaping ([DailyNutritionEnergyEntry]) -> Void
    ) {
        fetchNutritionEnergyDailyInternal(last: days, assign: assign)
    }

    // MARK: - NUTRITION ENERGY – Monthly helper

    /// Monats-Summen Nutrition Energy (kcal) für die letzten 5 Monate.
    func fetchNutritionEnergyMonthly(assign: @escaping ([MonthlyMetricEntry]) -> Void) {
        if isPreview {
            // 🔸 Demo-Daten: 5 Monate mit Gesamtsumme Nutrition Energy in kcal
            let calendar = Calendar.current
            let today = Date()
            var result: [MonthlyMetricEntry] = []

            for monthOffset in (0..<5).reversed() {
                if let date = calendar.date(byAdding: .month, value: -monthOffset, to: today) {
                    let monthShort = date.formatted(.dateTime.month(.abbreviated))
                    // z. B. 45 000 – 80 000 kcal pro Monat
                    let total = Int.random(in: 45_000...80_000)
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

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            return
        }

        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        // Letzte 5 Monate inkl. aktuellem
        guard
            let currentMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: today)
            ),
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
                let value = stats
                    .sumQuantity()?
                    .doubleValue(for: .kilocalorie()) ?? 0

                let kcal = Int(value)
                let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))

                temp.append(
                    MonthlyMetricEntry(
                        monthShort: monthShort,
                        value: kcal
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
