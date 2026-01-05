//
//  HealthStore+BMIV1.swift
//  GluVibProbe
//
//  BMI V1 (Body Domain) — EXACT WeightV1 / BodyFatV1 pattern
//  - Fetch-only (SSoT = HealthStore Published Properties)
//  - BMI ist dimensionslos -> HKUnit.count()
//  - TODAY: latest sample -> todayBMI
//  - 90d: measured days only (daily avg via HKStatisticsCollectionQuery) -> last90DaysBMI
//  - Monthly: avg BMI pro Monat (Int gerundet) -> monthlyBMI
//  - 365d: measured days only (daily avg via HKStatisticsCollectionQuery) -> bmiDaily365
//

import Foundation
import HealthKit

extension HealthStore {

    // ============================================================
    // MARK: - TODAY KPI (latest sample)
    // ============================================================

    func fetchBMITodayV1() {
        if isPreview {
            let value = previewDailyBMI.sorted { $0.date < $1.date }.last?.bmi ?? 0
            DispatchQueue.main.async {
                self.todayBMI = max(0, value)
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) else { return }

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

            let bmi = sample.quantity.doubleValue(for: .count())

            DispatchQueue.main.async {
                self.todayBMI = max(0, bmi)
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - 90 DAYS (measured days only)
    // ============================================================

    func fetchLast90DaysBMIV1() {
        if isPreview {
            let slice = Array(previewDailyBMI.suffix(90)).sorted { $0.date < $1.date }
            DispatchQueue.main.async { self.last90DaysBMI = slice }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) else { return }

        fetchDailySeriesAverageBMI_RawV1(
            quantityType: type,
            unit: .count(),
            days: 90
        ) { [weak self] entries in
            self?.last90DaysBMI = entries
        }
    }

    // ============================================================
    // MARK: - MONTHLY (Ø pro Monat; letzte ~5 Monate)
    // ============================================================

    func fetchMonthlyBMIV1() {
        if isPreview {
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var bucket: [DateComponents: (sum: Double, count: Int)] = [:]
            for e in previewDailyBMI where e.date >= startDate && e.date <= startOfToday && e.bmi > 0 {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                var b = bucket[comps] ?? (0, 0)
                b.sum += e.bmi
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

            DispatchQueue.main.async { self.monthlyBMI = result }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) else { return }

        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        guard
            let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
            let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
        else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: startOfToday, options: .strictStartDate)
        let interval = DateComponents(day: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self, let results else { return }

            var daily: [BMIEntry] = []
            results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                guard let q = stats.averageQuantity() else { return }          // ✅ measured days only
                let bmi = q.doubleValue(for: .count())
                guard bmi > 0 else { return }
                daily.append(BMIEntry(date: stats.startDate, bmi: bmi))
            }

            var perMonth: [DateComponents: (sum: Double, count: Int)] = [:]
            for e in daily {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                var b = perMonth[comps] ?? (0, 0)
                b.sum += e.bmi
                b.count += 1
                perMonth[comps] = b
            }

            let keys = perMonth.keys.sorted {
                (calendar.date(from: $0) ?? .distantPast) < (calendar.date(from: $1) ?? .distantPast)
            }

            let result: [MonthlyMetricEntry] = keys.map { comps in
                let d = calendar.date(from: comps) ?? Date()
                let b = perMonth[comps] ?? (0, 1)
                let avg = b.count > 0 ? (b.sum / Double(b.count)) : 0
                return MonthlyMetricEntry(
                    monthShort: d.formatted(.dateTime.month(.abbreviated)),
                    value: Int(round(max(0, avg)))
                )
            }

            DispatchQueue.main.async {
                self.monthlyBMI = result
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - 365 DAYS (measured days only) — SSoT series for Overview
    // ============================================================

    func fetchBMIDaily365V1() {
        if isPreview {
            let slice = Array(previewDailyBMI.suffix(365)).sorted { $0.date < $1.date }
            DispatchQueue.main.async { self.bmiDaily365 = slice }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) else { return }

        fetchDailySeriesAverageBMI_RawV1(
            quantityType: type,
            unit: .count(),
            days: 365
        ) { [weak self] entries in
            self?.bmiDaily365 = entries
        }
    }
}

// ============================================================
// MARK: - Private Helpers (BMI V1 only) — EXACT Weight helper
// ============================================================

private extension HealthStore {

    func fetchDailySeriesAverageBMI_RawV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([BMIEntry]) -> Void
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

        var measured: [BMIEntry] = []

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            results?.enumerateStatistics(from: startDate, to: now) { stats, _ in
                guard let q = stats.averageQuantity() else { return }          // ✅ measured days only
                let bmi = q.doubleValue(for: unit)
                guard bmi > 0 else { return }
                measured.append(BMIEntry(date: stats.startDate, bmi: bmi))
            }

            DispatchQueue.main.async {
                assign(measured.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }
}
