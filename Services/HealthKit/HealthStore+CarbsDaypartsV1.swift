//
//  HealthStore+CarbsDaypartsV1.swift
//  GluVibProbe
//
//  Nutrition V1: Carbs Split (timestamped → dayparts → period averages)
//  - Source: HKQuantityTypeIdentifier.dietaryCarbohydrates
//  - Purpose: Chart-only metric (no KPI)
//  - Loaded ONLY via Bootstrap -> refreshNutritionSecondaryDeferredV1 (deferred)
//  - Averages exclude 0-days from denominator (project rule)
//

import Foundation
import HealthKit

extension HealthStore {

    // ============================================================
    // MARK: - Public API (Bootstrap-only)
    // ============================================================

    @MainActor
    func refreshCarbsDayparts90V1Async(force: Bool) async {
        if isPreview {
            carbsDaypartsDaily90V1 = makePreviewDailyDayparts90()
            carbsDaypartsPeriodAveragesV1 = computePeriodAverages(from: carbsDaypartsDaily90V1)
            return
        }

        let key = ObjectIdentifier(self)

        if !force {
            let hasAnyPeriodAverages = !carbsDaypartsPeriodAveragesV1.isEmpty
            let hasTodayDaypartData = hasTodayCarbsDaypartDataV1() // 🟨 UPDATED

            guard CarbsDaypartsDeferredGateV1.shouldRun(
                for: key,
                hasAny: hasAnyPeriodAverages,
                hasTodayData: hasTodayDaypartData
            ) else { return } // 🟨 UPDATED
            guard CarbsDaypartsDeferredGateV1.begin(for: key) else { return }
        } else {
            _ = CarbsDaypartsDeferredGateV1.begin(for: key)
        }

        defer { CarbsDaypartsDeferredGateV1.finish(for: key) }

        let authIssue = await probeCarbsReadAuthIssueV1Async()
        if authIssue {
            carbsDaypartsDaily90V1 = []
            carbsDaypartsPeriodAveragesV1 = []
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else { return }

        let events90 = await fetchRawCarbSamples90V1(quantityType: type, unit: .gram(), days: 90)
        if carbsReadAuthIssueV1 {
            carbsDaypartsDaily90V1 = []
            carbsDaypartsPeriodAveragesV1 = []
            return
        }

        let daily = bucketSamplesIntoDailyDayparts(events90)
        carbsDaypartsDaily90V1 = daily

        carbsDaypartsPeriodAveragesV1 = computePeriodAverages(from: daily)
    }
}

// MARK: - Private helpers

private extension HealthStore {

    struct _CarbSampleV1: Hashable {
        let timestamp: Date
        let grams: Double
    }

    func fetchRawCarbSamples90V1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int
    ) async -> [_CarbSampleV1] {

        await withCheckedContinuation { (continuation: CheckedContinuation<[_CarbSampleV1], Never>) in

            let calendar = Calendar.current
            let now = Date()
            let todayStart = calendar.startOfDay(for: now)

            let spanDays = max(1, days)
            let startDate = calendar.date(byAdding: .day, value: -(spanDays - 1), to: todayStart) ?? todayStart

            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { [weak self] _, samples, _ in
                guard let self else {
                    continuation.resume(returning: [])
                    return
                }

                if self.carbsReadAuthIssueV1 {
                    continuation.resume(returning: [])
                    return
                }

                let quantitySamples = (samples as? [HKQuantitySample]) ?? []
                let mapped: [_CarbSampleV1] = quantitySamples.map { s in
                    let grams = s.quantity.doubleValue(for: unit)
                    return _CarbSampleV1(timestamp: s.startDate, grams: max(0, grams))
                }

                continuation.resume(returning: mapped)
            }

            self.healthStore.execute(query)
        }
    }

    func daypart(for timestamp: Date) -> CarbsDaypartV1 {
        let hour = Calendar.current.component(.hour, from: timestamp)

        if hour >= 6 && hour <= 11 { return .morning }
        if hour >= 12 && hour <= 17 { return .afternoon }
        return .night
    }

    func bucketSamplesIntoDailyDayparts(_ samples: [_CarbSampleV1]) -> [DailyCarbsByDaypartEntryV1] {
        let calendar = Calendar.current

        var bucket: [Date: (m: Double, a: Double, n: Double)] = [:]

        for s in samples {
            let day = calendar.startOfDay(for: s.timestamp)
            let dp = daypart(for: s.timestamp)

            var current = bucket[day] ?? (0, 0, 0)

            switch dp {
            case .morning: current.m += s.grams
            case .afternoon: current.a += s.grams
            case .night: current.n += s.grams
            }

            bucket[day] = current
        }

        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let start90 = calendar.date(byAdding: .day, value: -89, to: todayStart) ?? todayStart

        var daily: [DailyCarbsByDaypartEntryV1] = []
        daily.reserveCapacity(90)

        for i in 0..<90 {
            guard let d = calendar.date(byAdding: .day, value: i, to: start90) else { continue }
            let v = bucket[d] ?? (0, 0, 0)

            daily.append(
                DailyCarbsByDaypartEntryV1(
                    date: d,
                    morningGrams: max(0, Int(v.m.rounded())),
                    afternoonGrams: max(0, Int(v.a.rounded())),
                    nightGrams: max(0, Int(v.n.rounded()))
                )
            )
        }

        return daily
    }

    func computePeriodAverages(from daily: [DailyCarbsByDaypartEntryV1]) -> [CarbsDaypartPeriodAverageEntryV1] {
        let windows = [7, 14, 30, 90]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let endDate = calendar.date(byAdding: .day, value: -1, to: today) else { return [] }

        func avg(windowDays: Int) -> CarbsDaypartPeriodAverageEntryV1 {
            let startDate = calendar.date(byAdding: .day, value: -windowDays, to: today) ?? today

            let slice = daily.filter { e in
                let d = calendar.startOfDay(for: e.date)
                return d >= startDate && d <= endDate
            }

            let nonZero = slice.filter { $0.totalGrams > 0 }

            guard !nonZero.isEmpty else {
                return CarbsDaypartPeriodAverageEntryV1(
                    windowDays: windowDays,
                    morningAvg: 0,
                    afternoonAvg: 0,
                    nightAvg: 0
                )
            }

            let sumM = nonZero.reduce(0) { $0 + $1.morningGrams }
            let sumA = nonZero.reduce(0) { $0 + $1.afternoonGrams }
            let sumN = nonZero.reduce(0) { $0 + $1.nightGrams }

            let denom = nonZero.count
            return CarbsDaypartPeriodAverageEntryV1(
                windowDays: windowDays,
                morningAvg: sumM / denom,
                afternoonAvg: sumA / denom,
                nightAvg: sumN / denom
            )
        }

        return windows.map { avg(windowDays: $0) }
    }

    func makePreviewDailyDayparts90() -> [DailyCarbsByDaypartEntryV1] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start90 = calendar.date(byAdding: .day, value: -89, to: today) ?? today

        var daily: [DailyCarbsByDaypartEntryV1] = []
        daily.reserveCapacity(90)

        for i in 0..<90 {
            guard let d = calendar.date(byAdding: .day, value: i, to: start90) else { continue }

            let total = previewDailyCarbs.first(where: { calendar.isDate($0.date, inSameDayAs: d) })?.grams ?? 0
            let m = Int(Double(total) * 0.30)
            let a = Int(Double(total) * 0.30)
            let n = max(0, total - m - a)

            daily.append(
                DailyCarbsByDaypartEntryV1(date: d, morningGrams: m, afternoonGrams: a, nightGrams: n)
            )
        }

        return daily
    }

    func hasTodayCarbsDaypartDataV1() -> Bool { // 🟨 UPDATED
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let entry = carbsDaypartsDaily90V1.first(where: {
            calendar.isDate($0.date, inSameDayAs: today)
        }) else {
            return false
        }

        return entry.totalGrams > 0
    }
}

// ============================================================
// MARK: - File-local Deferred Gate (independent, TTL + inFlight)
// ============================================================

private enum CarbsDaypartsDeferredGateV1 {

    private static let ttl: TimeInterval = 60 * 60 * 12

    private static var lastRun: [ObjectIdentifier: Date] = [:]
    private static var inFlight: Set<ObjectIdentifier> = []

    static func shouldRun(for key: ObjectIdentifier, hasAny: Bool, hasTodayData: Bool) -> Bool { // 🟨 UPDATED
        let now = Date()
        if !hasAny { return true }
        if !hasTodayData { return true }
        guard let last = lastRun[key] else { return true }
        return now.timeIntervalSince(last) > ttl
    }

    static func begin(for key: ObjectIdentifier) -> Bool {
        if inFlight.contains(key) { return false }
        inFlight.insert(key)
        return true
    }

    static func finish(for key: ObjectIdentifier) {
        inFlight.remove(key)
        lastRun[key] = Date()
    }
}
