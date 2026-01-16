//
//  HealthStore+RangeV1.swift
//  GluVibProbe
//
//  Metabolic V1 — RANGE (Settings-based, HYBRID)
//
//  Was diese Datei macht:
//  - dailyRange90: tagesbasierte Range-Buckets (≤90 Tage) aus HealthKit Samples, thresholds-basiert
//  - HYBRID Period Summaries 7/14/30/90: (days-1) aus dailyRange90 + Today (00:00 → now) aus RAW (cgmSamples3Days)
//  - Last24h / Today sind minutenbasiert nur über RAW (keine Vermischung der Vergangenheit)
//

import Foundation
import HealthKit

// ============================================================
// MARK: - Models
// ============================================================

struct RangeThresholds: Equatable {
    let glucoseMin: Int
    let glucoseMax: Int
    let veryLowLimit: Int
    let veryHighLimit: Int

    func normalized() -> RangeThresholds {
        let vl = min(veryLowLimit, glucoseMin)
        let gh = max(glucoseMax, veryHighLimit)
        let gMin = max(vl, min(glucoseMin, gh))
        let gMax = max(gMin, min(glucoseMax, gh))
        let vHigh = max(gMax, veryHighLimit)
        return .init(glucoseMin: gMin, glucoseMax: gMax, veryLowLimit: vl, veryHighLimit: vHigh)
    }
}

struct DailyRangeEntry: Identifiable {
    let id: UUID
    let date: Date

    let veryLowMinutes: Int
    let lowMinutes: Int
    let inRangeMinutes: Int
    let highMinutes: Int
    let veryHighMinutes: Int

    let coverageMinutes: Int
    let expectedMinutes: Int
    let coverageRatio: Double
    let isPartial: Bool
}

struct RangePeriodSummaryEntry: Identifiable {
    let id: UUID
    let days: Int

    let veryLowMinutes: Int
    let lowMinutes: Int
    let inRangeMinutes: Int
    let highMinutes: Int
    let veryHighMinutes: Int

    let coverageMinutes: Int
    let expectedMinutes: Int
    let coverageRatio: Double
    let isPartial: Bool
}

// ============================================================
// MARK: - Public API (HealthStore)
// ============================================================

extension HealthStore {

    // ------------------------------------------------------------
    // MARK: - Published State (ADD THESE to HealthStore)
    //  @Published var dailyRange90: [DailyRangeEntry] = []
    //  @Published var rangeTodaySummary: RangePeriodSummaryEntry? = nil
    //  @Published var range7dSummary: RangePeriodSummaryEntry? = nil
    //  @Published var range14dSummary: RangePeriodSummaryEntry? = nil
    //  @Published var range30dSummary: RangePeriodSummaryEntry? = nil
    //  @Published var range90dSummary: RangePeriodSummaryEntry? = nil
    // ------------------------------------------------------------

    /// Refresh dailyRange90 (≤90d) thresholds-based:
    /// - Past days: daily-based from HealthKit samples
    /// - Today: overwritten from RAW (minute-based, 00:00 → now)
    @MainActor
    func refreshRangeDailyStats90V1Async(thresholds: RangeThresholds) async {
        if isPreview { return }

        let t = thresholds.normalized()
        let out = await fetchDailyRange90V1RawAsync(thresholds: t)

        // Only overwrite TODAY with RAW (hybrid rule)
        let rawToday = buildDailyRangeTodayFromRawV1(thresholds: t)

        var merged = out
        if let rawToday {
            let cal = Calendar.current
            let todayKey = cal.startOfDay(for: rawToday.date)

            merged = merged.map { e in
                let day = cal.startOfDay(for: e.date)
                return (day == todayKey) ? rawToday : e
            }
        }

        await MainActor.run {
            self.dailyRange90 = merged.sorted { $0.date < $1.date }
        }
    }

    /// Recompute HYBRID period summaries (7/14/30/90):
    /// - days-1 from dailyRange90 (full past days)
    /// - today (00:00 → now) from RAW (cgmSamples3Days)
    @MainActor
    func recomputeRangePeriodSummariesHybridV1(thresholds: RangeThresholds) {
        if isPreview { return }

        let t = thresholds.normalized()

        let today = buildTodayRangeSummaryFromRawV1(thresholds: t)
        rangeTodaySummary = today

        range7dSummary  = buildHybridRangeSummaryV1(days: 7, today: today)
        range14dSummary = buildHybridRangeSummaryV1(days: 14, today: today)
        range30dSummary = buildHybridRangeSummaryV1(days: 30, today: today)
        range90dSummary = buildHybridRangeSummaryV1(days: 90, today: today)
    }

    @MainActor
    func recomputeRangeAllHybridV1(thresholds: RangeThresholds) {
        if isPreview { return }
        recomputeRangePeriodSummariesHybridV1(thresholds: thresholds)
    }

    /// One-shot HYBRID refresh (fills dailyRange90 + all summaries)
    @MainActor
    func refreshRangeHybridV1Async(thresholds: RangeThresholds) async {
        if isPreview { return }

        let t = thresholds.normalized()
        await refreshRangeDailyStats90V1Async(thresholds: t)
        recomputeRangeAllHybridV1(thresholds: t)
    }
}

// ============================================================
// MARK: - Hybrid Builders
// ============================================================

private extension HealthStore {

    @MainActor
    func buildHybridRangeSummaryV1(
        days: Int,
        today: RangePeriodSummaryEntry?
    ) -> RangePeriodSummaryEntry? {
        guard days >= 1 else { return nil }

        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)

        let pastDays = max(0, days - 1)
        let pastStart = cal.date(byAdding: .day, value: -pastDays, to: todayStart) ?? todayStart

        let pastEntries = dailyRange90
            .filter { $0.date >= pastStart && $0.date < todayStart }
            .sorted { $0.date < $1.date }

        var veryLow = 0
        var low = 0
        var inRange = 0
        var high = 0
        var veryHigh = 0
        var coverage = 0
        var expected = 0

        for e in pastEntries {
            veryLow += max(0, e.veryLowMinutes)
            low += max(0, e.lowMinutes)
            inRange += max(0, e.inRangeMinutes)
            high += max(0, e.highMinutes)
            veryHigh += max(0, e.veryHighMinutes)

            coverage += max(0, e.coverageMinutes)
            expected += max(0, e.expectedMinutes)
        }

        // Past days are full days (defensive)
        let expectedPastCalendar = pastDays * 1440
        if expected < expectedPastCalendar { expected = expectedPastCalendar }

        // Add TODAY (00:00 → now) from RAW
        if let today {
            veryLow += max(0, today.veryLowMinutes)
            low += max(0, today.lowMinutes)
            inRange += max(0, today.inRangeMinutes)
            high += max(0, today.highMinutes)
            veryHigh += max(0, today.veryHighMinutes)

            coverage += max(0, today.coverageMinutes)
            expected += max(0, today.expectedMinutes)
        }

        let denom = max(1, expected)
        let ratio = Double(coverage) / Double(denom)
        let isPartial = coverage < expected

        return RangePeriodSummaryEntry(
            id: UUID(),
            days: days,
            veryLowMinutes: max(0, veryLow),
            lowMinutes: max(0, low),
            inRangeMinutes: max(0, inRange),
            highMinutes: max(0, high),
            veryHighMinutes: max(0, veryHigh),
            coverageMinutes: max(0, coverage),
            expectedMinutes: max(0, expected),
            coverageRatio: min(1.0, max(0.0, ratio)),
            isPartial: isPartial
        )
    }

    @MainActor
    func buildTodayRangeSummaryFromRawV1(thresholds: RangeThresholds) -> RangePeriodSummaryEntry? {
        let cal = Calendar.current
        let now = Date()
        let start = cal.startOfDay(for: now)

        let expected = max(0, Int(now.timeIntervalSince(start) / 60.0))
        guard expected > 0 else { return nil }

        let points = cgmSamples3Days.filter { $0.timestamp >= start && $0.timestamp <= now }
        let minutesPerSample = 5
        let coverage = min(points.count * minutesPerSample, expected)

        var veryLow = 0
        var low = 0
        var inRange = 0
        var high = 0
        var veryHigh = 0

        for p in points {
            let v = p.glucoseMgdl
            if v < Double(thresholds.veryLowLimit) {
                veryLow += minutesPerSample
            } else if v < Double(thresholds.glucoseMin) {
                low += minutesPerSample
            } else if v <= Double(thresholds.glucoseMax) {
                inRange += minutesPerSample
            } else if v <= Double(thresholds.veryHighLimit) {
                high += minutesPerSample
            } else {
                veryHigh += minutesPerSample
            }
        }

        // Clamp sum to coverage (coverage authoritative)
        let sum = veryLow + low + inRange + high + veryHigh
        if sum > coverage {
            var overflow = sum - coverage

            let takeVH = min(overflow, veryHigh); veryHigh -= takeVH; overflow -= takeVH
            if overflow > 0 {
                let takeH = min(overflow, high); high -= takeH; overflow -= takeH
            }
            if overflow > 0 {
                let takeIR = min(overflow, inRange); inRange -= takeIR; overflow -= takeIR
            }
            if overflow > 0 {
                let takeL = min(overflow, low); low -= takeL; overflow -= takeL
            }
            if overflow > 0 {
                veryLow = max(0, veryLow - overflow)
            }
        }

        let denom = max(1, expected)
        let ratio = Double(coverage) / Double(denom)
        let isPartial = coverage < expected

        return RangePeriodSummaryEntry(
            id: UUID(),
            days: 1,
            veryLowMinutes: max(0, veryLow),
            lowMinutes: max(0, low),
            inRangeMinutes: max(0, inRange),
            highMinutes: max(0, high),
            veryHighMinutes: max(0, veryHigh),
            coverageMinutes: max(0, coverage),
            expectedMinutes: max(0, expected),
            coverageRatio: min(1.0, max(0.0, ratio)),
            isPartial: isPartial
        )
    }

    /// DailyRangeEntry for TODAY from RAW (00:00 → now).
    @MainActor
    func buildDailyRangeTodayFromRawV1(thresholds: RangeThresholds) -> DailyRangeEntry? {
        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)

        let expected = max(0, Int(now.timeIntervalSince(todayStart) / 60.0))
        guard expected > 0 else { return nil }

        let points = cgmSamples3Days.filter { $0.timestamp >= todayStart && $0.timestamp <= now }
        let minutesPerSample = 5
        let coverage = min(points.count * minutesPerSample, expected)

        var veryLow = 0
        var low = 0
        var inRange = 0
        var high = 0
        var veryHigh = 0

        for p in points {
            let v = p.glucoseMgdl
            if v < Double(thresholds.veryLowLimit) {
                veryLow += minutesPerSample
            } else if v < Double(thresholds.glucoseMin) {
                low += minutesPerSample
            } else if v <= Double(thresholds.glucoseMax) {
                inRange += minutesPerSample
            } else if v <= Double(thresholds.veryHighLimit) {
                high += minutesPerSample
            } else {
                veryHigh += minutesPerSample
            }
        }

        // Clamp to coverage
        let sum = veryLow + low + inRange + high + veryHigh
        if sum > coverage {
            var overflow = sum - coverage

            let takeVH = min(overflow, veryHigh); veryHigh -= takeVH; overflow -= takeVH
            if overflow > 0 {
                let takeH = min(overflow, high); high -= takeH; overflow -= takeH
            }
            if overflow > 0 {
                let takeIR = min(overflow, inRange); inRange -= takeIR; overflow -= takeIR
            }
            if overflow > 0 {
                let takeL = min(overflow, low); low -= takeL; overflow -= takeL
            }
            if overflow > 0 {
                veryLow = max(0, veryLow - overflow)
            }
        }

        let denom = max(1, expected)
        let ratio = Double(coverage) / Double(denom)
        let isPartial = coverage < expected

        return DailyRangeEntry(
            id: UUID(),
            date: todayStart,
            veryLowMinutes: max(0, veryLow),
            lowMinutes: max(0, low),
            inRangeMinutes: max(0, inRange),
            highMinutes: max(0, high),
            veryHighMinutes: max(0, veryHigh),
            coverageMinutes: max(0, coverage),
            expectedMinutes: max(0, expected),
            coverageRatio: min(1.0, max(0.0, ratio)),
            isPartial: isPartial
        )
    }
}

// ============================================================
// MARK: - HealthKit Daily Aggregation (≤90d, thresholds-based)
// ============================================================

private extension HealthStore {

    func mgdlUnitV1() -> HKUnit {
        HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
    }

    func fetchDailyRange90V1RawAsync(thresholds: RangeThresholds) async -> [DailyRangeEntry] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return [] }

        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)

        guard let startDate = cal.date(byAdding: .day, value: -(90 - 1), to: todayStart) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let unit = mgdlUnitV1()

        let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, s, _ in
                continuation.resume(returning: (s as? [HKQuantitySample]) ?? [])
            }
            self.healthStore.execute(query)
        }

        if samples.isEmpty { return [] }

        var byTimestamp: [TimeInterval: (date: Date, mgdl: Double)] = [:]
        byTimestamp.reserveCapacity(samples.count)

        for s in samples {
            let key = s.startDate.timeIntervalSince1970.rounded()
            byTimestamp[key] = (s.startDate, s.quantity.doubleValue(for: unit))
        }

        var byDay: [Date: [Double]] = [:]
        byDay.reserveCapacity(90)

        for v in byTimestamp.values {
            let day = cal.startOfDay(for: v.date)
            byDay[day, default: []].append(v.mgdl)
        }

        let minutesPerSample = 5

        var out: [DailyRangeEntry] = []
        out.reserveCapacity(90)

        for offset in stride(from: (90 - 1), through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: todayStart) else { continue }

            let isToday = cal.isDate(day, inSameDayAs: now)
            let expected: Int = isToday ? max(0, Int(now.timeIntervalSince(todayStart) / 60.0)) : 1440

            let values = byDay[day] ?? []
            let coverageRaw = values.count * minutesPerSample
            let coverage = min(coverageRaw, expected)

            var veryLow = 0
            var low = 0
            var inRange = 0
            var high = 0
            var veryHigh = 0

            if !values.isEmpty {
                for mgdl in values {
                    if mgdl < Double(thresholds.veryLowLimit) {
                        veryLow += minutesPerSample
                    } else if mgdl < Double(thresholds.glucoseMin) {
                        low += minutesPerSample
                    } else if mgdl <= Double(thresholds.glucoseMax) {
                        inRange += minutesPerSample
                    } else if mgdl <= Double(thresholds.veryHighLimit) {
                        high += minutesPerSample
                    } else {
                        veryHigh += minutesPerSample
                    }
                }

                let sum = veryLow + low + inRange + high + veryHigh
                if sum > coverage {
                    var overflow = sum - coverage

                    let takeVH = min(overflow, veryHigh); veryHigh -= takeVH; overflow -= takeVH
                    if overflow > 0 {
                        let takeH = min(overflow, high); high -= takeH; overflow -= takeH
                    }
                    if overflow > 0 {
                        let takeIR = min(overflow, inRange); inRange -= takeIR; overflow -= takeIR
                    }
                    if overflow > 0 {
                        let takeL = min(overflow, low); low -= takeL; overflow -= takeL
                    }
                    if overflow > 0 {
                        veryLow = max(0, veryLow - overflow)
                    }
                }
            }

            let denom = max(1, expected)
            let ratio = Double(coverage) / Double(denom)
            let isPartial = coverage < expected

            out.append(
                DailyRangeEntry(
                    id: UUID(),
                    date: day,
                    veryLowMinutes: max(0, veryLow),
                    lowMinutes: max(0, low),
                    inRangeMinutes: max(0, inRange),
                    highMinutes: max(0, high),
                    veryHighMinutes: max(0, veryHigh),
                    coverageMinutes: max(0, coverage),
                    expectedMinutes: max(0, expected),
                    coverageRatio: min(1.0, max(0.0, ratio)),
                    isPartial: isPartial
                )
            )
        }

        return out.sorted { $0.date < $1.date }
    }
}
