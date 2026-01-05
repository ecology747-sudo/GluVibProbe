//
//  HealthStore+BodyFatV1.swift
//  GluVibProbe
//
//  Body Fat V1 — EXACT WeightV1 pattern (HKStatisticsCollectionQuery, measured days only)
//  - Unit percent: HKUnit.percent() liefert 0...1 -> speichern 0...100
//  - TODAY: latest sample -> todayBodyFatPercent
//  - 90d: measured days only (daily avg) -> last90DaysBodyFat
//  - Monthly: avg % pro Monat (Int gerundet) -> monthlyBodyFat
//  - 365d: measured days only (daily avg) -> bodyFatDaily365
//

import Foundation
import HealthKit

extension HealthStore {

    // ============================================================
    // MARK: - TODAY KPI (latest sample)
    // ============================================================

    func fetchBodyFatTodayV1() {
        if isPreview {
            let value = previewDailyBodyFat.sorted { $0.date < $1.date }.last?.bodyFatPercent ?? 0
            DispatchQueue.main.async {
                self.todayBodyFatPercent = max(0, value)
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else { return }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(withStart: nil, end: Date(), options: [])

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

            let raw01 = sample.quantity.doubleValue(for: .percent()) // 0...1
            let pct100 = raw01 * 100.0

            DispatchQueue.main.async {
                self.todayBodyFatPercent = max(0, pct100)
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - 90 DAYS (measured days only)
    // ============================================================

    func fetchLast90DaysBodyFatV1() {
        if isPreview {
            let slice = Array(previewDailyBodyFat.suffix(90)).sorted { $0.date < $1.date }
            DispatchQueue.main.async { self.last90DaysBodyFat = slice }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else { return }

        fetchDailySeriesAverageBodyFat_RawV1(
            quantityType: type,
            days: 90
        ) { [weak self] entries in
            self?.last90DaysBodyFat = entries
        }
    }

    // ============================================================
    // MARK: - MONTHLY (Ø pro Monat; letzte ~5 Monate)
    // ============================================================

    func fetchMonthlyBodyFatV1() {
        if isPreview {
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var bucket: [DateComponents: (sum: Double, count: Int)] = [:]
            for e in previewDailyBodyFat where e.date >= startDate && e.date <= startOfToday && e.bodyFatPercent > 0 {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                var b = bucket[comps] ?? (0, 0)
                b.sum += e.bodyFatPercent
                b.count += 1
                bucket[comps] = b
            }

            let keys = bucket.keys.sorted {
                (calendar.date(from: $0) ?? .distantPast) < (calendar.date(from: $1) ?? .distantPast)
            }

            let result: [MonthlyMetricEntry] = keys.map { comps in
                let d = calendar.date(from: comps) ?? Date()
                let b = bucket[comps] ?? (0, 1)
                let avg = b.count > 0 ? (b.sum / Double(b.count)) : 0
                return MonthlyMetricEntry(
                    monthShort: d.formatted(.dateTime.month(.abbreviated)),
                    value: Int(round(max(0, avg)))
                )
            }

            DispatchQueue.main.async { self.monthlyBodyFat = result }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else { return }

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
                let raw01 = stats.averageQuantity()?.doubleValue(for: .percent()) ?? 0 // 0...1
                let pct100 = raw01 * 100.0                                           // ✅ FIX
                let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))
                temp.append(
                    MonthlyMetricEntry(
                        monthShort: monthShort,
                        value: max(0, Int(round(pct100)))
                    )
                )
            }

            DispatchQueue.main.async {
                self.monthlyBodyFat = temp
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - 365 DAYS (measured days only) — SSoT series for Overview
    // ============================================================

    func fetchBodyFatDaily365V1() {
        if isPreview {
            let slice = Array(previewDailyBodyFat.suffix(365)).sorted { $0.date < $1.date }
            DispatchQueue.main.async { self.bodyFatDaily365 = slice }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else { return }

        fetchDailySeriesAverageBodyFat_RawV1(
            quantityType: type,
            days: 365
        ) { [weak self] entries in
            self?.bodyFatDaily365 = entries
        }
    }
}

// ============================================================
// MARK: - Private Helpers (BodyFat V1 only) — EXACT Weight helper
// ============================================================

private extension HealthStore {

    func fetchDailySeriesAverageBodyFat_RawV1(
        quantityType: HKQuantityType,
        days: Int,
        assign: @escaping ([BodyFatEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            DispatchQueue.main.async { assign([]) }
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let interval = DateComponents(day: 1)

        var measured: [BodyFatEntry] = []

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            results?.enumerateStatistics(from: startDate, to: now) { stats, _ in
                guard let q = stats.averageQuantity() else { return }   // ✅ measured days only
                let raw01 = q.doubleValue(for: .percent())             // 0...1
                let pct100 = raw01 * 100.0                             // ✅ store 0...100
                guard pct100 > 0 else { return }
                measured.append(BodyFatEntry(date: stats.startDate, bodyFatPercent: pct100))
            }

            DispatchQueue.main.async {
                assign(measured.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }
}
