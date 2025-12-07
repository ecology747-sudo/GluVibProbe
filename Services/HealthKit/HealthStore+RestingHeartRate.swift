//
//  HealthStore+RestingHeartRate.swift                  // !!! NEW
//  GluVibProbe
//
//  Resting-Heart-Rate-Logik (Body Domain)
//

import Foundation
import HealthKit

extension HealthStore {

    // ============================================================
    // MARK: - RESTING HEART RATE (bpm) – Body Domain
    // ============================================================

    /// Letzter bekannter Resting Heart Rate in bpm
    func fetchRestingHeartRateToday() {
        if isPreview {
            todayRestingHeartRate =
                previewDailyRestingHeartRate.last?.restingHeartRate ?? 0   // !!! FIX
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
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

            let unit = HKUnit.count().unitDivided(by: .minute())
            let bpm = sample.quantity.doubleValue(for: unit)

            DispatchQueue.main.async {
                self.todayRestingHeartRate = Int(round(bpm))
            }
        }

        healthStore.execute(query)
    }

    /// Täglicher Ø-Resting-Heart-Rate der letzten `days` Tage
    func fetchRestingHeartRateDaily(
        last days: Int,
        completion: @escaping ([RestingHeartRateEntry]) -> Void
    ) {
        if isPreview {
            let slice = Array(previewDailyRestingHeartRate.suffix(days))
            DispatchQueue.main.async { completion(slice) }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
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
            var daily: [RestingHeartRateEntry] = []

            results?.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = stats.averageQuantity()?.doubleValue(for: unit) ?? 0

                daily.append(
                    RestingHeartRateEntry(
                        date: stats.startDate,
                        restingHeartRate: Int(round(bpm))
                    )
                )
            }

            DispatchQueue.main.async {
                completion(daily.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }

    func fetchLast90DaysRestingHeartRate() {
        fetchRestingHeartRateDaily(last: 90) { [weak self] entries in
            self?.last90DaysRestingHeartRate = entries
        }
    }

    func fetchMonthlyRestingHeartRate() {
        fetchRestingHeartRateDaily(last: 180) { [weak self] entries in
            guard let self else { return }

            let calendar = Calendar.current
            var perMonth: [DateComponents: (sum: Int, count: Int)] = [:]

            for e in entries {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                var bucket = perMonth[comps] ?? (0, 0)
                bucket.sum   += e.restingHeartRate
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
                self.monthlyRestingHeartRate = result
            }
        }
    }
}
