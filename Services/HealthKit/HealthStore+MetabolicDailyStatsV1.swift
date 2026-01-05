//
//  HealthStore+MetabolicDailyStatsV1.swift
//  GluVibProbe
//
//  Metabolic V1 — DailyStats90 (≥90 Tage)
//
//  SSOT:
//  Apple Health → HealthStore → Published Arrays (DailyStats90)
//

import Foundation
import HealthKit

extension HealthStore {

    // ============================================================
    // MARK: - Metabolic V1 DailyStats90 — Public API
    // ============================================================

    @MainActor
    func refreshMetabolicDailyStats90V1(refreshSource: String) async {
        if isPreview { return }

        // --------------------------------------------------------
        // 1) CGM Daily TIR (90) — required for HYBRID period summaries
        // --------------------------------------------------------
        await fetchDailyTIR90V1Async()

        // --------------------------------------------------------
        // 2) Carbs Daily (90)
        // --------------------------------------------------------
        await fetchLast90DaysCarbsV1Async()
        mirrorNutritionCarbs90IntoMetabolicV1()

        // --------------------------------------------------------
        // 3) Insulin Daily (90)
        // --------------------------------------------------------
        await fetchDailyBolus90V1Async()
        await fetchDailyBasal90V1Async()

        // --------------------------------------------------------
        // 4) Derived Ratios (no refetch)
        // --------------------------------------------------------
        recomputeMetabolicDerivedDailyArraysV1()
    }

    @MainActor
    func recomputeMetabolicDailyStats90AfterThresholdChangeV1() {
        if isPreview { return }

        // Threshold change affects:
        // - todayTIR* (computed from RAW in HealthStore+CGMV1)
        // - dailyTIR90 (needs refetch / recompute)
        // - hybrid summaries
        Task { @MainActor in
            await fetchDailyTIR90V1Async()
            recomputeCGMPeriodKPIsHybridV1()
        }
    }

    @MainActor
    func recomputeMetabolicDerivedDailyArraysV1() {
        if isPreview { return }
        recomputeBolusBasalRatio90V1()
        recomputeCarbBolusRatio90V1()
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    @MainActor
    func mirrorNutritionCarbs90IntoMetabolicV1() {
        dailyCarbs90 = last90DaysCarbs
    }

    // ------------------------------------------------------------
    // MARK: - Derived Ratio Helpers
    // ------------------------------------------------------------

    @MainActor
    func recomputeBolusBasalRatio90V1() {
        let calendar = Calendar.current

        var basalByDay: [Date: Double] = [:]
        for b in dailyBasal90 {
            let day = calendar.startOfDay(for: b.date)
            basalByDay[day] = b.basalUnits
        }

        var out: [DailyBolusBasalRatioEntry] = []
        out.reserveCapacity(dailyBolus90.count)

        for bolus in dailyBolus90 {
            let day = calendar.startOfDay(for: bolus.date)
            let basal = basalByDay[day] ?? 0

            let ratio: Double = basal > 0 ? (bolus.bolusUnits / basal) : 0

            out.append(
                DailyBolusBasalRatioEntry(
                    id: UUID(),
                    date: day,
                    ratio: ratio
                )
            )
        }

        dailyBolusBasalRatio90 = out.sorted { $0.date < $1.date }
    }

    @MainActor
    func recomputeCarbBolusRatio90V1() {
        let calendar = Calendar.current

        var carbsByDay: [Date: Double] = [:]
        for c in dailyCarbs90 {
            let day = calendar.startOfDay(for: c.date)
            carbsByDay[day] = Double(max(0, c.grams))
        }

        var out: [DailyCarbBolusRatioEntry] = []
        out.reserveCapacity(dailyBolus90.count)

        for bolus in dailyBolus90 {
            let day = calendar.startOfDay(for: bolus.date)
            let carbs = carbsByDay[day] ?? 0

            let gramsPerUnit: Double = bolus.bolusUnits > 0 ? (carbs / bolus.bolusUnits) : 0

            out.append(
                DailyCarbBolusRatioEntry(
                    id: UUID(),
                    date: day,
                    gramsPerUnit: gramsPerUnit
                )
            )
        }

        dailyCarbBolusRatio90 = out.sorted { $0.date < $1.date }
    }

    @MainActor
    func clearMetabolicDailyStats90CacheV1() {
        dailyGlucoseStats90 = []
        dailyTIR90 = []
        dailyBolus90 = []
        dailyBasal90 = []
        dailyBolusBasalRatio90 = []
        dailyCarbs90 = []
        dailyCarbBolusRatio90 = []
    }
}

// ============================================================
// MARK: - CGM Daily TIR (90) — HealthKit Fetch (SSoT publish)
// ============================================================

private extension HealthStore {

    func mgdlUnitV1() -> HKUnit {
        HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
    }

    @MainActor
    func fetchDailyTIR90V1Async() async {
        if isPreview { return }

        let out = await fetchDailyTIR90V1RawAsync()
        await MainActor.run {
            self.dailyTIR90 = out.sorted { $0.date < $1.date }
        }
    }

    func fetchDailyTIR90V1RawAsync() async -> [DailyTIREntry] {
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

        // Dedup by rounded seconds (deterministic)
        var byTimestamp: [TimeInterval: (date: Date, mgdl: Double)] = [:]
        byTimestamp.reserveCapacity(samples.count)

        for s in samples {
            let key = s.startDate.timeIntervalSince1970.rounded()
            byTimestamp[key] = (s.startDate, s.quantity.doubleValue(for: unit))
        }

        // Group by day
        var byDay: [Date: [Double]] = [:]
        byDay.reserveCapacity(90)

        for v in byTimestamp.values {
            let day = cal.startOfDay(for: v.date)
            byDay[day, default: []].append(v.mgdl)
        }

        let minutesPerSample = 5

        // Build full 90-day series (including days with 0 samples)
        var out: [DailyTIREntry] = []
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
                    if mgdl < 54 {
                        veryLow += minutesPerSample
                    } else if mgdl < 70 {
                        low += minutesPerSample
                    } else if mgdl <= 180 {
                        inRange += minutesPerSample
                    } else if mgdl <= 250 {
                        high += minutesPerSample
                    } else {
                        veryHigh += minutesPerSample
                    }
                }

                // Clamp buckets to coverage (coverage is authoritative)
                let sum = veryLow + low + inRange + high + veryHigh
                if sum > coverage {
                    var overflow = sum - coverage

                    let takeVH = min(overflow, veryHigh)
                    veryHigh -= takeVH
                    overflow -= takeVH

                    if overflow > 0 {
                        let takeH = min(overflow, high)
                        high -= takeH
                        overflow -= takeH
                    }

                    if overflow > 0 {
                        let takeIR = min(overflow, inRange)
                        inRange -= takeIR
                        overflow -= takeIR
                    }

                    if overflow > 0 {
                        let takeL = min(overflow, low)
                        low -= takeL
                        overflow -= takeL
                    }

                    if overflow > 0 {
                        veryLow = max(0, veryLow - overflow)
                    }
                }
            }

            let ratio = expected > 0 ? (Double(coverage) / Double(expected)) : 0
            let isPartial = coverage < expected

            out.append(
                DailyTIREntry(
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

        return out
    }
}
