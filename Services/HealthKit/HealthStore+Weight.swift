//
//  HealthStore+Weight.swift
//  GluVibProbe
//
//  Weight-Logik ausgelagert aus HealthStore.swift
//

import Foundation
import HealthKit

extension HealthStore {

    // ============================================================
    // MARK: - WEIGHT (kg) – Body Domain
    // ============================================================

    /// Letztes bekanntes Gewicht in kg (unabhängig vom Tag)
    func fetchWeightToday() {
        if isPreview {
            // Im Preview setzen wir den Wert direkt im preview()-Factory
            return
        }

        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

        // ❗ Kein Start-of-day → wir wollen "letztes Gewicht insgesamt"
        let predicate = HKQuery.predicateForSamples(
            withStart: nil,
            end: Date(),
            options: []
        )

        // letzter Eintrag (neueste Messung)
        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        let query = HKSampleQuery(
            sampleType: weightType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard
                let self,
                let sample = samples?.first as? HKQuantitySample
            else { return }

            let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))

            DispatchQueue.main.async {
                self.todayWeightKg = Int(round(kg))
            }
        }

        healthStore.execute(query)
    }

    /// Tägliches Gewicht der letzten `days` Tage
    /// 👉 generisch als [DailyStepsEntry], `steps` = weightKg
    func fetchWeightDaily(
        last days: Int,
        completion: @escaping ([DailyStepsEntry]) -> Void
    ) {
        if isPreview {
            let slice = Array(previewDailyWeight.suffix(days))
            DispatchQueue.main.async { completion(slice) }
            return
        }

        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return
        }

        let calendar   = Calendar.current
        let now        = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: []
        )

        let interval = DateComponents(day: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: weightType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,   // Ø Gewicht pro Tag
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            var daily: [DailyStepsEntry] = []

            results?.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let valueKg = stats.averageQuantity()?.doubleValue(for: .gramUnit(with: .kilo)) ?? 0
                daily.append(
                    DailyStepsEntry(
                        date: stats.startDate,
                        steps: Int(round(valueKg))    // steps = weightKg
                    )
                )
            }

            DispatchQueue.main.async {
                completion(daily.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }

    /// Gewicht der letzten 90 Tage → für 90d-Chart
    func fetchLast90DaysWeight() {
        fetchWeightDaily(last: 90) { [weak self] entries in
            self?.last90DaysWeight = entries
        }
    }

    /// Monatliche Gewichtswerte (Ø Gewicht / Monat)
    func fetchMonthlyWeight() {
        fetchWeightDaily(last: 180) { [weak self] entries in
            guard let self else { return }

            let calendar = Calendar.current
            var perMonth: [DateComponents: (sum: Int, count: Int)] = [:]

            for e in entries {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                var bucket = perMonth[comps] ?? (0, 0)
                bucket.sum   += e.steps
                bucket.count += 1
                perMonth[comps] = bucket
            }

            let sortedKeys = perMonth.keys.sorted { lhs, rhs in
                let l = calendar.date(from: lhs) ?? .distantPast
                let r = calendar.date(from: rhs) ?? .distantPast
                return l < r
            }

            let result: [MonthlyMetricEntry] = sortedKeys.map { comps in
                let date       = calendar.date(from: comps) ?? Date()
                let monthShort = date.formatted(.dateTime.month(.abbreviated))
                let bucket     = perMonth[comps] ?? (0, 1)
                let avg        = bucket.count > 0 ? bucket.sum / bucket.count : 0
                return MonthlyMetricEntry(monthShort: monthShort, value: avg)
            }

            DispatchQueue.main.async {
                self.monthlyWeight = result
            }
        }
    }
}
