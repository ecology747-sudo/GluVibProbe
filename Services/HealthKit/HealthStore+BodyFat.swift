//
//  HealthStore+BodyFat.swift
//  GluVibProbe
//
//  Body-Fat-Logik (Body Domain)
//

import Foundation
import HealthKit

extension HealthStore {

    // ============================================================
    // MARK: - BODY FAT (%) – Body Domain
    // ============================================================

    func fetchBodyFatToday() {
        if isPreview {
            todayBodyFatPercent =
                previewDailyBodyFat.last?.bodyFatPercent ?? 0      // !!! FIX
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
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

            let unit = HKUnit.percent()
            let raw  = sample.quantity.doubleValue(for: unit)
            let pct  = raw * 100.0

            DispatchQueue.main.async {
                self.todayBodyFatPercent = pct
            }
        }

        healthStore.execute(query)
    }

    func fetchBodyFatDaily(
        last days: Int,
        completion: @escaping ([BodyFatEntry]) -> Void
    ) {
        if isPreview {
            let slice = Array(previewDailyBodyFat.suffix(days))
            DispatchQueue.main.async { completion(slice) }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
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
            var daily: [BodyFatEntry] = []

            results?.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let unit = HKUnit.percent()
                let raw  = stats.averageQuantity()?.doubleValue(for: unit) ?? 0
                let pct  = raw * 100.0

                daily.append(
                    BodyFatEntry(
                        date: stats.startDate,
                        bodyFatPercent: pct
                    )
                )
            }

            DispatchQueue.main.async {
                completion(daily.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }

    func fetchLast90DaysBodyFat() {
        fetchBodyFatDaily(last: 90) { [weak self] entries in
            self?.last90DaysBodyFat = entries
        }
    }

    func fetchMonthlyBodyFat() {
        fetchBodyFatDaily(last: 180) { [weak self] entries in
            guard let self else { return }

            let calendar = Calendar.current
            var perMonth: [DateComponents: (sum: Double, count: Int)] = [:]

            for e in entries {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                var bucket = perMonth[comps] ?? (0, 0)
                bucket.sum   += e.bodyFatPercent
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
                self.monthlyBodyFat = result
            }
        }
    }
}
