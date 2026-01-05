//
//  HealthStore+RestingHeartRateV1.swift
//  GluVibProbe
//
//  Resting Heart Rate V1 (Body Domain) — Masterpattern wie StepsV1
//  - Fetch-only (SSoT = HealthStore Published Properties)
//  - KEINE Legacy-Aliasse
//  - Preview & Live: Assign immer sauber auf Main
//

import Foundation
import HealthKit

// ============================================================
// MARK: - HealthStore + Resting Heart Rate (V1 kompatibel)
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - TODAY KPI (latest sample)
    // ============================================================

    func fetchRestingHeartRateTodayV1() {
        if isPreview {
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())

            // !!! UPDATED: "Today" wirklich als Today filtern (nicht einfach .last)
            let value = previewDailyRestingHeartRate
                .last(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
                .restingHeartRate ?? 0

            DispatchQueue.main.async {
                self.todayRestingHeartRate = max(0, value)
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: nil, end: Date(), options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

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
                self.todayRestingHeartRate = max(0, Int(round(bpm)))
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - 90 DAYS (Ø pro Tag)
    // ============================================================

    func fetchLast90DaysRestingHeartRateV1() {
        if isPreview {
            let slice = Array(previewDailyRestingHeartRate.suffix(90)).sorted { $0.date < $1.date }
            DispatchQueue.main.async {
                self.last90DaysRestingHeartRate = slice
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }

        fetchDailySeriesRestingHRV1(
            quantityType: type,
            days: 90
        ) { [weak self] entries in
            // !!! UPDATED: Assign immer auf Main (StepsV1-Pattern)
            DispatchQueue.main.async {
                self?.last90DaysRestingHeartRate = entries
            }
        }
    }

    // ============================================================
    // MARK: - MONTHLY (Ø pro Monat; letzte ~5 Monate)
    // ============================================================

    func fetchMonthlyRestingHeartRateV1() {
        if isPreview {
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var bucket: [DateComponents: (sum: Int, count: Int)] = [:]
            for e in previewDailyRestingHeartRate where e.date >= startDate && e.date <= startOfToday {
                if e.restingHeartRate > 0 {
                    let comps = calendar.dateComponents([.year, .month], from: e.date)
                    var b = bucket[comps] ?? (0, 0)
                    b.sum += e.restingHeartRate
                    b.count += 1
                    bucket[comps] = b
                }
            }

            let keys = bucket.keys.sorted {
                (calendar.date(from: $0) ?? .distantPast) < (calendar.date(from: $1) ?? .distantPast)
            }

            let out: [MonthlyMetricEntry] = keys.map { comps in
                let d = calendar.date(from: comps) ?? Date()
                let b = bucket[comps] ?? (0, 0)
                let avg = b.count > 0 ? Int(round(Double(b.sum) / Double(b.count))) : 0
                return MonthlyMetricEntry(
                    monthShort: d.formatted(.dateTime.month(.abbreviated)),
                    value: max(0, avg)
                )
            }

            DispatchQueue.main.async {
                self.monthlyRestingHeartRate = out
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }

        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        guard
            let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
            let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
        else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: startOfToday, options: .strictStartDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,
            anchorDate: startDate,
            intervalComponents: DateComponents(month: 1)
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self, let results else { return }

            var temp: [MonthlyMetricEntry] = []

            results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = stats.averageQuantity()?.doubleValue(for: unit) ?? 0
                let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))
                temp.append(
                    MonthlyMetricEntry(
                        monthShort: monthShort,
                        value: max(0, Int(round(bpm)))
                    )
                )
            }

            DispatchQueue.main.async {
                self.monthlyRestingHeartRate = temp
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - 365 DAYS (Basereihe)
    // ============================================================

    func fetchRestingHeartRateDaily365V1() {
        if isPreview {
            let slice = Array(previewDailyRestingHeartRate.suffix(365)).sorted { $0.date < $1.date }
            DispatchQueue.main.async {
                self.restingHeartRateDaily365 = slice
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }

        fetchDailySeriesRestingHRV1(
            quantityType: type,
            days: 365
        ) { [weak self] entries in
            // !!! UPDATED: Assign immer auf Main (StepsV1-Pattern)
            DispatchQueue.main.async {
                self?.restingHeartRateDaily365 = entries
            }
        }
    }
}

// ============================================================
// MARK: - Private Helpers (Resting HR V1 only) — V1 kompatibel
// ============================================================

private extension HealthStore {

    func fetchDailySeriesRestingHRV1(
        quantityType: HKQuantityType,
        days: Int,
        assign: @escaping ([RestingHeartRateEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            // !!! UPDATED: consistent empty assign
            DispatchQueue.main.async { assign([]) }
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let interval = DateComponents(day: 1)

        var daily: [RestingHeartRateEntry] = []

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            results?.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = stats.averageQuantity()?.doubleValue(for: unit) ?? 0
                daily.append(
                    RestingHeartRateEntry(
                        date: stats.startDate,
                        restingHeartRate: max(0, Int(round(bpm)))
                    )
                )
            }

            // !!! UPDATED: assign in Helper auf Main (StepsV1-Pattern)
            DispatchQueue.main.async {
                assign(daily.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }
}
