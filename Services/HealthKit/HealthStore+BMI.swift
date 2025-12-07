//
//  HealthStore+BMI.swift
//  GluVibProbe
//
//  BMI-Logik (Body Domain)
//

import Foundation
import HealthKit

extension HealthStore {

    // ============================================================
    // MARK: - BMI – Body Domain
    // ============================================================

    func fetchBMIToday() {
        if isPreview {
            todayBMI = previewDailyBMI.last?.bmi ?? 0
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) else {
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: nil,
            end: Date(),
            options: []
        )

        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard
                let self,
                let sample = samples?.first as? HKQuantitySample
            else { return }

            let unit = HKUnit.count()
            let bmi  = sample.quantity.doubleValue(for: unit)

            DispatchQueue.main.async {
                self.todayBMI = bmi
            }
        }

        healthStore.execute(query)
    }

    /// Täglicher Ø-BMI der letzten `days` Tage
    func fetchBMIDaily(                                      // !!! FIX (Name korrigiert)
        last days: Int,
        completion: @escaping ([BMIEntry]) -> Void
    ) {
        if isPreview {
            let slice = Array(previewDailyBMI.suffix(days))
            DispatchQueue.main.async { completion(slice) }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) else {
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
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            var daily: [BMIEntry] = []

            results?.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let unit = HKUnit.count()
                let value = stats.averageQuantity()?.doubleValue(for: unit) ?? 0

                daily.append(
                    BMIEntry(
                        date: stats.startDate,
                        bmi: value
                    )
                )
            }

            DispatchQueue.main.async {
                completion(daily.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }

    func fetchLast90DaysBMI() {
        fetchBMIDaily(last: 90) { [weak self] entries in       // !!! FIX (Aufruf)
            self?.last90DaysBMI = entries
        }
    }

    func fetchMonthlyBMI() {
        fetchBMIDaily(last: 180) { [weak self] entries in      // !!! FIX (Aufruf)
            guard let self else { return }

            let calendar = Calendar.current
            var perMonth: [DateComponents: (sum: Double, count: Int)] = [:]

            for e in entries {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                var bucket = perMonth[comps] ?? (0, 0)
                bucket.sum   += e.bmi
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
                let avg        = bucket.count > 0
                    ? bucket.sum / Double(bucket.count)
                    : 0
                return MonthlyMetricEntry(
                    monthShort: monthShort,
                    value: Int(round(avg))
                )
            }

            DispatchQueue.main.async {
                self.monthlyBMI = result
            }
        }
    }
}
