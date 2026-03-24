//
//  HealthStore+MetabolicDailyStatsV1.swift
//  GluVibProbe
//
//  Metabolic V1 — DailyStats90 (SSoT)
//
//  ✅ UPDATED (Single-writer rule):
//  - This file MUST NOT write glucoseReadAuthIssueV1.
//  - Auth/Badge is set ONLY by HealthStore+Bootstrap.swift (central read-probe).
//  - All queries here are data-only. If permission is missing, they simply return empty / nil.
//
//  ✅ UPDATED (Batch-style / performance):
//  - If glucoseReadAuthIssueV1 == true, ALL glucose HK queries short-circuit (return empty).
//  - awaitHybridGlucoseReadyV1() exits immediately when glucose permission is missing.
//

import Foundation
import HealthKit

extension HealthStore {

    // ============================================================
    // MARK: - Debug Gate (Therapy-only)
    // ============================================================

    @MainActor
    private func applyMetabolicTherapyDebugNoDataModeIfNeededV1() -> Bool { // 🟨 NEW
        guard isDebugSimulatingNoHealthDataV1 else { return false }

        dailyBolus90 = []
        dailyBasal90 = []
        dailyBolusBasalRatio90 = []
        dailyCarbs90 = []
        dailyCarbBolusRatio90 = []

        bolusEvents3Days = []
        basalEvents3Days = []

        bolusEventsHistoryWindowV1 = []
        basalEventsHistoryWindowV1 = []

        return true
    }

    // ============================================================
    // MARK: - Metabolic-Metrics (Detail) — Public API
    // ============================================================

    @MainActor
    func refreshMetabolicDailyStats90V1(refreshSource: String) async {
        if isPreview { return }

        await fetchDailyTIR90V1Async()
        recomputeCGMPeriodKPIsHybridV1()

        await fetchDailyGlucoseStats90V1Async()

        await refreshMetabolicTherapyDaily90LightV1(refreshSource: refreshSource)
    }

    // ============================================================
    // MARK: - Metabolic-Overview (Premium Overview) — Public API
    // ============================================================

    @MainActor
    func refreshMetabolicOverviewDaily7FullDaysV1(refreshSource: String) async {
        if isPreview { return }
        await fetchOverviewDailyTIR7FullDaysV1Async()
        await fetchOverviewDailyGlucoseStats7FullDaysV1Async()
    }

    // ============================================================
    // MARK: - Metabolic-Overview (Therapy Preload Light) — Public API
    // ============================================================

    @MainActor
    func refreshMetabolicTherapyDaily90LightV1(refreshSource: String) async {
        if isPreview { return }
        if applyMetabolicTherapyDebugNoDataModeIfNeededV1() { return } // 🟨 NEW

        await fetchLast90DaysCarbsV1Async()
        mirrorNutritionCarbs90IntoMetabolicV1()

        await fetchDailyBolus90V1Async()
        await fetchDailyBasal90V1Async()

        recomputeMetabolicDerivedDailyArraysV1()
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

    // ------------------------------------------------------------
    // MARK: - Overview GMI(90) Light — Mean mg/dL (90d) [SSoT publish]
    // ------------------------------------------------------------

    @MainActor
    func fetchGlucoseMean90dMgdlLightV1Async() async {
        if isPreview { return }

        let mean = await fetchGlucoseMean90dMgdlLightV1RawAsync()
        await MainActor.run {
            self.glucoseMean90dMgdl = (mean ?? 0) > 0 ? mean : nil
        }
    }

    private func fetchGlucoseMean90dMgdlLightV1RawAsync() async -> Double? {

        let authMissing = await MainActor.run(resultType: Bool.self) { self.glucoseReadAuthIssueV1 }
        if authMissing { return nil }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return nil }

        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)

        guard let startDate = cal.date(byAdding: .day, value: -(90 - 1), to: todayStart) else { return nil }

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

        guard !samples.isEmpty else { return nil }

        var byTimestamp: [TimeInterval: Double] = [:]
        byTimestamp.reserveCapacity(samples.count)

        for s in samples {
            let key = s.startDate.timeIntervalSince1970.rounded()
            byTimestamp[key] = s.quantity.doubleValue(for: unit)
        }

        let values = Array(byTimestamp.values)
        guard !values.isEmpty else { return nil }

        let sum = values.reduce(0.0, +)
        let mean = sum / Double(values.count)
        return mean > 0 ? mean : nil
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    @MainActor
    func mirrorNutritionCarbs90IntoMetabolicV1() {
        dailyCarbs90 = last90DaysCarbs
    }

    @MainActor
    func recomputeMetabolicDerivedDailyArraysV1() {
        if isPreview { return }
        recomputeBolusBasalRatio90V1()
        recomputeCarbBolusRatio90V1()
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

        overviewGlucoseDaily7FullDays = []
        overviewTIRDaily7FullDays = []
    }

    private func mgdlUnitV1() -> HKUnit {
        HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
    }

    // ------------------------------------------------------------
    // MARK: - Dexcom-like Rolling SD + CV (RAW window, end = last sample)
    // ------------------------------------------------------------

    private func fetchGlucoseRaw90DedupedV1Async() async -> [(ts: Date, mgdl: Double)] {

        let authMissing = await MainActor.run(resultType: Bool.self) { self.glucoseReadAuthIssueV1 }
        if authMissing { return [] }

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

        var byTimestamp: [TimeInterval: (Date, Double)] = [:]
        byTimestamp.reserveCapacity(samples.count)

        for s in samples {
            let key = s.startDate.timeIntervalSince1970.rounded()
            byTimestamp[key] = (s.startDate, s.quantity.doubleValue(for: unit))
        }

        return byTimestamp.values
            .map { (ts: $0.0, mgdl: $0.1) }
            .sorted { $0.ts < $1.ts }
    }

    private func computeRollingStatsDexcomLikeV1(
        values: [(ts: Date, mgdl: Double)],
        windowDays: Int
    ) -> (mean: Double, sd: Double, cv: Double)? {

        guard values.count >= 2 else { return nil }
        guard let end = values.last?.ts else { return nil }
        let start = end.addingTimeInterval(TimeInterval(-windowDays * 24 * 60 * 60))

        let window = values
            .filter { $0.ts >= start && $0.ts <= end }
            .map { $0.mgdl }

        guard window.count >= 2 else { return nil }

        let n = Double(window.count)
        let mean = window.reduce(0.0, +) / n

        let sumSq = window.reduce(0.0) { acc, x in
            let d = x - mean
            return acc + (d * d)
        }

        let variance = sumSq / max(1.0, (n - 1.0))
        let sd = sqrt(variance)

        guard mean > 0, sd > 0 else { return nil }

        let cv = max(0, (sd / mean) * 100.0)
        return (mean: mean, sd: sd, cv: cv)
    }

    @MainActor
    private func updateRollingStatsDexcomLikeFromRaw90V1() async {
        let raw = await fetchGlucoseRaw90DedupedV1Async()

        let s7  = computeRollingStatsDexcomLikeV1(values: raw, windowDays: 7)
        let s14 = computeRollingStatsDexcomLikeV1(values: raw, windowDays: 14)
        let s30 = computeRollingStatsDexcomLikeV1(values: raw, windowDays: 30)
        let s90 = computeRollingStatsDexcomLikeV1(values: raw, windowDays: 90)

        await MainActor.run {
            self.rollingGlucoseSdMgdl7  = s7?.sd
            self.rollingGlucoseSdMgdl14 = s14?.sd
            self.rollingGlucoseSdMgdl30 = s30?.sd
            self.rollingGlucoseSdMgdl90 = s90?.sd

            self.rollingGlucoseCvPercent7  = s7?.cv
            self.rollingGlucoseCvPercent14 = s14?.cv
            self.rollingGlucoseCvPercent30 = s30?.cv
            self.rollingGlucoseCvPercent90 = s90?.cv
        }
    }

    // ------------------------------------------------------------
    // MARK: - Daily TIR (90)
    // ------------------------------------------------------------

    @MainActor
    func fetchDailyTIR90V1Async() async {
        if isPreview { return }

        let out = await fetchDailyTIR90V1RawAsync()
        await MainActor.run {
            self.dailyTIR90 = out.sorted { $0.date < $1.date }
        }
    }

    private func fetchDailyTIR90V1RawAsync() async -> [DailyTIREntry] {

        let authMissing = await MainActor.run(resultType: Bool.self) { self.glucoseReadAuthIssueV1 }
        if authMissing { return [] }

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

        let s = SettingsModel.shared
        let veryLow  = Double(s.veryLowLimit)
        let tMin     = Double(s.glucoseMin)
        let tMax     = Double(s.glucoseMax)
        let veryHigh = Double(s.veryHighLimit)

        var out: [DailyTIREntry] = []
        out.reserveCapacity(90)

        for offset in stride(from: (90 - 1), through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: todayStart) else { continue }

            let isToday = cal.isDate(day, inSameDayAs: now)
            let expected: Int = isToday ? max(0, Int(now.timeIntervalSince(todayStart) / 60.0)) : 1440

            let values = byDay[day] ?? []
            let coverageRaw = values.count * minutesPerSample
            let coverage = min(coverageRaw, expected)

            var veryLowMin = 0
            var lowMin = 0
            var inRangeMin = 0
            var highMin = 0
            var veryHighMin = 0

            if !values.isEmpty {
                for mgdl in values {
                    if mgdl <= veryLow {
                        veryLowMin += minutesPerSample
                    } else if mgdl < tMin {
                        lowMin += minutesPerSample
                    } else if mgdl <= tMax {
                        inRangeMin += minutesPerSample
                    } else if mgdl < veryHigh {
                        highMin += minutesPerSample
                    } else {
                        veryHighMin += minutesPerSample
                    }
                }

                let sum = veryLowMin + lowMin + inRangeMin + highMin + veryHighMin
                if sum > coverage {
                    var overflow = sum - coverage

                    let takeVH = min(overflow, veryHighMin)
                    veryHighMin -= takeVH
                    overflow -= takeVH

                    if overflow > 0 {
                        let takeH = min(overflow, highMin)
                        highMin -= takeH
                        overflow -= takeH
                    }

                    if overflow > 0 {
                        let takeIR = min(overflow, inRangeMin)
                        inRangeMin -= takeIR
                        overflow -= takeIR
                    }

                    if overflow > 0 {
                        let takeL = min(overflow, lowMin)
                        lowMin -= takeL
                        overflow -= takeL
                    }

                    if overflow > 0 {
                        veryLowMin = max(0, veryLowMin - overflow)
                    }
                }
            }

            let ratio = expected > 0 ? (Double(coverage) / Double(expected)) : 0
            let isPartial = coverage < expected

            out.append(
                DailyTIREntry(
                    id: UUID(),
                    date: day,
                    veryLowMinutes: max(0, veryLowMin),
                    lowMinutes: max(0, lowMin),
                    inRangeMinutes: max(0, inRangeMin),
                    highMinutes: max(0, highMin),
                    veryHighMinutes: max(0, veryHighMin),
                    coverageMinutes: max(0, coverage),
                    expectedMinutes: max(0, expected),
                    coverageRatio: min(1.0, max(0.0, ratio)),
                    isPartial: isPartial
                )
            )
        }

        return out
    }

    // ------------------------------------------------------------
    // MARK: - Daily Glucose Stats (90) — mean/SD/CV
    // ------------------------------------------------------------

    @MainActor
    func fetchDailyGlucoseStats90V1Async() async {
        if isPreview { return }

        let out = await fetchDailyGlucoseStats90V1RawAsync()
        await MainActor.run {
            self.dailyGlucoseStats90 = out.sorted { $0.date < $1.date }
        }

        await updateRollingStatsDexcomLikeFromRaw90V1()
    }

    private func fetchDailyGlucoseStats90V1RawAsync() async -> [DailyGlucoseStatsEntry] {

        let authMissing = await MainActor.run(resultType: Bool.self) { self.glucoseReadAuthIssueV1 }
        if authMissing { return [] }

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

        var out: [DailyGlucoseStatsEntry] = []
        out.reserveCapacity(90)

        for offset in stride(from: (90 - 1), through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: todayStart) else { continue }

            let isToday = cal.isDate(day, inSameDayAs: now)
            let expected: Int = isToday ? max(0, Int(now.timeIntervalSince(todayStart) / 60.0)) : 1440

            let values = byDay[day] ?? []
            let coverageRaw = values.count * minutesPerSample
            let coverage = min(coverageRaw, expected)
            let isPartial = coverage < expected

            let mean: Double
            let sd: Double
            let cv: Double

            if values.isEmpty {
                mean = 0
                sd = 0
                cv = 0
            } else {
                mean = values.reduce(0.0, +) / Double(values.count)

                if values.count >= 2 {
                    let n = Double(values.count)
                    let sumSq = values.reduce(0.0) { acc, x in
                        let d = x - mean
                        return acc + (d * d)
                    }
                    let variance = sumSq / max(1.0, (n - 1.0))
                    sd = sqrt(variance)
                } else {
                    sd = 0
                }

                cv = (mean > 0) ? max(0, (sd / mean) * 100.0) : 0
            }

            out.append(
                DailyGlucoseStatsEntry(
                    id: UUID(),
                    date: day,
                    meanMgdl: mean,
                    standardDeviationMgdl: sd,
                    coefficientOfVariationPercent: cv,
                    coverageMinutes: max(0, coverage),
                    expectedMinutes: max(0, expected),
                    isPartial: isPartial
                )
            )
        }

        return out
    }

    // ------------------------------------------------------------
    // MARK: - Overview Daily Series (7 full days: yesterday + 6 before)
    // ------------------------------------------------------------

    @MainActor
    func fetchOverviewDailyTIR7FullDaysV1Async() async {
        if isPreview { return }

        let out = await fetchOverviewDailyTIR7FullDaysV1RawAsync()
        await MainActor.run {
            self.overviewTIRDaily7FullDays = out.sorted { $0.date < $1.date }
        }
    }

    private func fetchOverviewDailyTIR7FullDaysV1RawAsync() async -> [DailyTIREntry] {

        let authMissing = await MainActor.run(resultType: Bool.self) { self.glucoseReadAuthIssueV1 }
        if authMissing { return [] }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return [] }

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())

        guard let startDate = cal.date(byAdding: .day, value: -7, to: todayStart) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: todayStart, options: .strictStartDate)
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
        byDay.reserveCapacity(7)

        for v in byTimestamp.values {
            let day = cal.startOfDay(for: v.date)
            byDay[day, default: []].append(v.mgdl)
        }

        let minutesPerSample = 5

        let s = SettingsModel.shared
        let veryLow  = Double(s.veryLowLimit)
        let tMin     = Double(s.glucoseMin)
        let tMax     = Double(s.glucoseMax)
        let veryHigh = Double(s.veryHighLimit)

        var out: [DailyTIREntry] = []
        out.reserveCapacity(7)

        for offset in stride(from: 7, through: 1, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: todayStart) else { continue }

            let expected = 1440
            let values = byDay[day] ?? []
            let coverageRaw = values.count * minutesPerSample
            let coverage = min(coverageRaw, expected)

            var veryLowMin = 0
            var lowMin = 0
            var inRangeMin = 0
            var highMin = 0
            var veryHighMin = 0

            if !values.isEmpty {
                for mgdl in values {
                    if mgdl <= veryLow {
                        veryLowMin += minutesPerSample
                    } else if mgdl < tMin {
                        lowMin += minutesPerSample
                    } else if mgdl <= tMax {
                        inRangeMin += minutesPerSample
                    } else if mgdl < veryHigh {
                        highMin += minutesPerSample
                    } else {
                        veryHighMin += minutesPerSample
                    }
                }

                let sum = veryLowMin + lowMin + inRangeMin + highMin + veryHighMin
                if sum > coverage {
                    var overflow = sum - coverage

                    let takeVH = min(overflow, veryHighMin)
                    veryHighMin -= takeVH
                    overflow -= takeVH

                    if overflow > 0 {
                        let takeH = min(overflow, highMin)
                        highMin -= takeH
                        overflow -= takeH
                    }

                    if overflow > 0 {
                        let takeIR = min(overflow, inRangeMin)
                        inRangeMin -= takeIR
                        overflow -= takeIR
                    }

                    if overflow > 0 {
                        let takeL = min(overflow, lowMin)
                        lowMin -= takeL
                        overflow -= takeL
                    }

                    if overflow > 0 {
                        veryLowMin = max(0, veryLowMin - overflow)
                    }
                }
            }

            let ratio = expected > 0 ? (Double(coverage) / Double(expected)) : 0
            let isPartial = coverage < expected

            out.append(
                DailyTIREntry(
                    id: UUID(),
                    date: day,
                    veryLowMinutes: max(0, veryLowMin),
                    lowMinutes: max(0, lowMin),
                    inRangeMinutes: max(0, inRangeMin),
                    highMinutes: max(0, highMin),
                    veryHighMinutes: max(0, veryHighMin),
                    coverageMinutes: max(0, coverage),
                    expectedMinutes: expected,
                    coverageRatio: min(1.0, max(0.0, ratio)),
                    isPartial: isPartial
                )
            )
        }

        return out
    }

    @MainActor
    func fetchOverviewDailyGlucoseStats7FullDaysV1Async() async {
        if isPreview { return }

        let out = await fetchOverviewDailyGlucoseStats7FullDaysV1RawAsync()
        await MainActor.run {
            self.overviewGlucoseDaily7FullDays = out.sorted { $0.date < $1.date }
        }
    }

    private func fetchOverviewDailyGlucoseStats7FullDaysV1RawAsync() async -> [DailyGlucoseStatsEntry] {

        let authMissing = await MainActor.run(resultType: Bool.self) { self.glucoseReadAuthIssueV1 }
        if authMissing { return [] }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return [] }

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())

        guard let startDate = cal.date(byAdding: .day, value: -7, to: todayStart) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: todayStart, options: .strictStartDate)
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
        byDay.reserveCapacity(7)

        for v in byTimestamp.values {
            let day = cal.startOfDay(for: v.date)
            byDay[day, default: []].append(v.mgdl)
        }

        let minutesPerSample = 5

        var out: [DailyGlucoseStatsEntry] = []
        out.reserveCapacity(7)

        for offset in stride(from: 7, through: 1, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: todayStart) else { continue }

            let expected = 1440
            let values = byDay[day] ?? []
            let coverageRaw = values.count * minutesPerSample
            let coverage = min(coverageRaw, expected)
            let isPartial = coverage < expected

            let mean: Double
            let sd: Double
            let cv: Double

            if values.isEmpty {
                mean = 0
                sd = 0
                cv = 0
            } else {
                mean = values.reduce(0.0, +) / Double(values.count)

                if values.count >= 2 {
                    let n = Double(values.count)
                    let sumSq = values.reduce(0.0) { acc, x in
                        let d = x - mean
                        return acc + (d * d)
                    }
                    let variance = sumSq / max(1.0, (n - 1.0))
                    sd = sqrt(variance)
                } else {
                    sd = 0
                }

                cv = (mean > 0) ? max(0, (sd / mean) * 100.0) : 0
            }

            out.append(
                DailyGlucoseStatsEntry(
                    id: UUID(),
                    date: day,
                    meanMgdl: mean,
                    standardDeviationMgdl: sd,
                    coefficientOfVariationPercent: cv,
                    coverageMinutes: max(0, coverage),
                    expectedMinutes: expected,
                    isPartial: isPartial
                )
            )
        }

        return out
    }

    // ============================================================
    // MARK: - HYBRID Snapshot Gate (Report / GMI consistency)
    // ============================================================

    @MainActor
    func awaitHybridGlucoseReadyV1() async {

        if glucoseReadAuthIssueV1 { return }

        while true {

            if glucoseReadAuthIssueV1 { return }

            let hasDailyStats = !dailyGlucoseStats90.isEmpty
            let hasTodayMean  = todayGlucoseMeanMgdl != nil
            let hasCoverage   = todayGlucoseCoverageMinutes > 0

            if hasDailyStats && hasTodayMean && hasCoverage {
                return
            }

            try? await Task.sleep(nanoseconds: 30_000_000)
        }
    }
}
