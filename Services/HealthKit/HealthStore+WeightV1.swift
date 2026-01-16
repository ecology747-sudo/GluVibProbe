//
//  HealthStore+WeightV1.swift
//  GluVibProbe
//
//  Weight V1 (parallel, neu aufgesetzt)
//  - Fetch-only (SSoT = HealthStore Published Properties)
//  - V1 kompatibel (Steps-V1 Pattern)
//  - TODAY: Double (kg) -> todayWeightKgRaw
//  - 90d: [DailyWeightEntry] -> last90DaysWeight
//  - Monthly: [MonthlyMetricEntry] (Ø kg pro Monat, Int gerundet) -> monthlyWeight
//  - 365d: [DailyWeightEntry] (measured days only) -> weightDaily365Raw
//

import Foundation
import HealthKit

// ============================================================
// MARK: - History Weight Sample Model (V1)
// ============================================================

struct WeightSamplePointV1: Identifiable, Hashable {          // ✅ NEW
    let id: UUID = UUID()
    let timestamp: Date
    let kg: Double
}

// ============================================================
// MARK: - HealthStore + Weight (V1 kompatibel)
// ============================================================

extension HealthStore {

   

    // ============================================================
    // MARK: - Public API (Entry Points) — V1 kompatibel
    // ============================================================

    /// TODAY KPI (latest measured weight) → writes `todayWeightKgRaw`
    func fetchWeightTodayV1() {
        if isPreview {
            let value = previewDailyWeight.sorted { $0.date < $1.date }.last?.kg ?? 0
            DispatchQueue.main.async {
                self.todayWeightKgRaw = max(0, value)
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

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

            let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))

            DispatchQueue.main.async {
                self.todayWeightKgRaw = max(0, kg)
            }
        }

        healthStore.execute(query)
    }

    /// 90d Serie (für Charts)
    func fetchLast90DaysWeightV1() {
        if isPreview {
            let slice = Array(previewDailyWeight.suffix(90)).sorted { $0.date < $1.date }
            DispatchQueue.main.async { self.last90DaysWeight = slice }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

        fetchDailySeriesAverageRawV1(
            quantityType: type,
            unit: .gramUnit(with: .kilo),
            days: 90
        ) { [weak self] entries in
            self?.last90DaysWeight = entries
        }
    }

    /// Monatswerte (Ø kg pro Monat; Int gerundet, weil MonthlyMetricEntry Int ist)
    func fetchMonthlyWeightV1() {
        if isPreview {
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var bucket: [DateComponents: (sum: Double, count: Int)] = [:]

            for e in previewDailyWeight where e.date >= startDate && e.date <= startOfToday && e.kg > 0 {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                var b = bucket[comps] ?? (0, 0)
                b.sum += e.kg
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

            DispatchQueue.main.async { self.monthlyWeight = result }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

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

            var daily: [DailyWeightEntry] = []
            results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                guard let q = stats.averageQuantity() else { return }
                let kg = q.doubleValue(for: .gramUnit(with: .kilo))
                guard kg > 0 else { return }
                daily.append(DailyWeightEntry(date: stats.startDate, kg: kg))
            }

            var perMonth: [DateComponents: (sum: Double, count: Int)] = [:]
            for e in daily {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                var b = perMonth[comps] ?? (0, 0)
                b.sum += e.kg
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
                self.monthlyWeight = result
            }
        }

        healthStore.execute(query)
    }

    /// 365d Basereihe (SSoT) — measured days only
    func fetchWeightDaily365RawV1() {
        if isPreview {
            let slice = Array(previewDailyWeight.suffix(365)).sorted { $0.date < $1.date }
            DispatchQueue.main.async { self.weightDaily365Raw = slice }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

        fetchDailySeriesAverageRawV1(
            quantityType: type,
            unit: .gramUnit(with: .kilo),
            days: 365
        ) { [weak self] entries in
            self?.weightDaily365Raw = entries
        }
    }

    // ============================================================
    // MARK: - History Window: recent weight samples (10 days)
    // ============================================================

    func fetchRecentWeightSamplesForHistoryWindowV1(days: Int = 10) {    // ✅ NEW
        if isPreview {
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) ?? todayStart

            // previewDailyWeight has day-level dates -> give it a plausible time (07:15)
            let points = previewDailyWeight
                .filter { $0.date >= start && $0.kg > 0 }
                .map { e in
                    WeightSamplePointV1(
                        timestamp: e.date.addingTimeInterval(7 * 3600 + 15 * 60),
                        kg: e.kg
                    )
                }
                .sorted { $0.timestamp > $1.timestamp }

            DispatchQueue.main.async {
                self.recentWeightSamplesForHistoryV1 = points
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) ?? todayStart

        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard let self else { return }

            let points: [WeightSamplePointV1] = (samples as? [HKQuantitySample] ?? [])
                .map { s in
                    let kg = s.quantity.doubleValue(for: .gramUnit(with: .kilo))
                    return WeightSamplePointV1(timestamp: s.endDate, kg: max(0, kg))
                }
                .filter { $0.kg > 0 }
                .sorted { $0.timestamp > $1.timestamp }

            DispatchQueue.main.async {
                self.recentWeightSamplesForHistoryV1 = points
            }
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - Private Helpers (Weight V1 only)
// ============================================================

private extension HealthStore {

    func fetchDailySeriesAverageRawV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyWeightEntry]) -> Void
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

        var measured: [DailyWeightEntry] = []

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            results?.enumerateStatistics(from: startDate, to: now) { stats, _ in
                guard let q = stats.averageQuantity() else { return }
                let kg = q.doubleValue(for: unit)
                guard kg > 0 else { return }
                measured.append(DailyWeightEntry(date: stats.startDate, kg: kg))
            }

            DispatchQueue.main.async {
                assign(measured.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }
}
