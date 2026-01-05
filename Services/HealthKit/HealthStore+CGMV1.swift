//
//  HealthStore+CGMV1.swift
//  GluVibProbe
//
//  Metabolic V1 — CGM (RAW + Quick KPIs)
//
//  Berechnet in dieser Datei (SSoT = HealthStore Published State):
//
//  1) RAW INPUT (DayProfile / MainChart Backbone)
//     - RAW3DAYS: CGM Samples für Today/Yesterday/DayBefore → cgmSamples3Days
//     - Trigger: rebuildMainChartCacheFromRaw3DaysV1() (MainChart Cache wird nach RAW-Publish rebuilt)
//
//  2) HOME QUICK KPI TILES (minute-based, RAW-derived; Last 24h)
//     - Ø Glucose (Last 24h): last24hGlucoseMeanMgdl + Coverage/Expected/Ratio/isPartial
//     - TIR (Last 24h): last24hTIR* Minuten + Coverage/Expected/Ratio/isPartial
//     - SD  (Last 24h): last24hGlucoseSdMgdl
//     - CV  (Last 24h): last24hGlucoseCvPercent                         // NEW
//
//  3) TODAY KPIs (minute-based, RAW-derived; 00:00 → now)
//     - Ø Glucose (Today): todayGlucoseMeanMgdl + Coverage/Expected/Ratio/isPartial
//     - TIR Buckets (Today): todayTIR* Minuten + Coverage/Expected/Ratio/isPartial
//     - Optional Mirror: tirTodaySummary (nur Wrapper der TODAY Published Werte)
//
//  4) PERIOD KPIs (RAW-derived, keine DailyStats; HealthKit Queries pro Zeitraum)
//     - Mean: glucoseMean7dMgdl / glucoseMean14dMgdl / glucoseMean30dMgdl / glucoseMean90dMgdl      // NEW: 30/90
//     - SD:   glucoseSd7dMgdl / glucoseSd14dMgdl / glucoseSd30dMgdl / glucoseSd90dMgdl
//     - CV:   glucoseCv7dPercent / glucoseCv14dPercent / glucoseCv30dPercent / glucoseCv90dPercent // NEW
//     - TIR Summaries: tir7dSummary / tir14dSummary / tir30dSummary / tir90dSummary
//
//  Hinweis:
//  - Perioden-HYBRID-Builder (DailyTIR90 + Today RAW) liegt NICHT hier,
//    sondern in HealthStore+CGMTIRV1.swift (recomputeCGMPeriodKPIsHybridV1()).
//

import Foundation
import HealthKit

extension HealthStore {

    // ============================================================
    // MARK: - RAW3DAYS (DayProfile) — CGM Samples
    // ============================================================

    @MainActor
    func fetchCGMSamples3DaysV1() {
        if isPreview { return }

        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -2, to: todayStart) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        // HealthKit Glucose Unit: mg/dL
        let mgdlUnit = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard let self else { return }

            let quantitySamples = (samples as? [HKQuantitySample]) ?? []

            // -----------------------------------------------------
            // Dedup by timestamp (deterministic)
            // NOTE: we round to full seconds to avoid sub-second dupes
            // -----------------------------------------------------
            var byTimestamp: [TimeInterval: CGMSamplePoint] = [:]
            byTimestamp.reserveCapacity(quantitySamples.count)

            for s in quantitySamples {
                let key = s.startDate.timeIntervalSince1970.rounded()
                byTimestamp[key] = CGMSamplePoint(
                    id: UUID(),
                    timestamp: s.startDate,
                    glucoseMgdl: s.quantity.doubleValue(for: mgdlUnit)
                )
            }

            let points = byTimestamp.values.sorted { $0.timestamp < $1.timestamp }

            // -----------------------------------------------------
            // MainActor publish (SSoT)
            // -----------------------------------------------------
            Task { @MainActor in
                self.cgmSamples3Days = points

                // Rebuild MainChart cache right after CGM RAW is published (Chart backbone)
                self.rebuildMainChartCacheFromRaw3DaysV1()

                // TODAY KPIs (Mean + TIR + Coverage) — 00:00 → now
                self.updateTodayGlucoseAndTIRFromRawV1()

                // LAST 24H KPI (Mean + Coverage)
                self.updateLast24hGlucoseFromRawV1()

                // LAST 24H KPI (TIR Minuten + Coverage)
                self.updateLast24hTIRFromRawV1()

                // LAST 24H KPI (SD / Standard Deviation) + CV
                self.updateLast24hGlucoseSdFromRawV1()

                // PERIOD KPIs (7d/14d/30d/90d) — RAW-derived, no DailyStats
                await self.refreshCGMPeriodKPIsV1()
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - TODAY KPIs (Mean + TIR + coverage) — RAW only
    // ============================================================

    @MainActor
    private func updateTodayGlucoseAndTIRFromRawV1() {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.startOfDay(for: now)

        // Expected minutes: 00:00 → now
        let expected = max(0, Int(now.timeIntervalSince(start) / 60.0))
        todayGlucoseExpectedMinutes = expected
        todayTIRExpectedMinutes = expected

        // Today samples (from RAW3DAYS)
        let today = cgmSamples3Days
            .filter { $0.timestamp >= start && $0.timestamp <= now }

        // Coverage: minutes based only on existing samples (no upscaling)
        let minutesPerSample = 5
        let coverage = today.count * minutesPerSample
        let cappedCoverage = min(coverage, expected)

        todayGlucoseCoverageMinutes = cappedCoverage
        todayTIRCoverageMinutes = cappedCoverage

        let denom = max(1, expected)
        let ratio = Double(cappedCoverage) / Double(denom)

        todayGlucoseCoverageRatio = min(1.0, max(0.0, ratio))
        todayGlucoseIsPartial = cappedCoverage < expected

        todayTIRCoverageRatio = min(1.0, max(0.0, ratio))
        todayTIRIsPartial = cappedCoverage < expected

        // Reset TIR buckets (deterministic)
        todayTIRVeryLowMinutes = 0
        todayTIRLowMinutes = 0
        todayTIRInRangeMinutes = 0
        todayTIRHighMinutes = 0
        todayTIRVeryHighMinutes = 0

        guard !today.isEmpty else {
            todayGlucoseMeanMgdl = nil
            tirTodaySummary = nil
            return
        }

        // Mean glucose (only existing samples)
        let sum = today.reduce(0.0) { $0 + $1.glucoseMgdl }
        todayGlucoseMeanMgdl = sum / Double(today.count)

        // Today TIR buckets (minutes based)
        for p in today {
            let v = p.glucoseMgdl
            if v < 54 {
                todayTIRVeryLowMinutes += minutesPerSample
            } else if v < 70 {
                todayTIRLowMinutes += minutesPerSample
            } else if v <= 180 {
                todayTIRInRangeMinutes += minutesPerSample
            } else if v <= 250 {
                todayTIRHighMinutes += minutesPerSample
            } else {
                todayTIRVeryHighMinutes += minutesPerSample
            }
        }

        // Safety clamp: keep coverage authoritative
        let tirSum =
            todayTIRVeryLowMinutes
            + todayTIRLowMinutes
            + todayTIRInRangeMinutes
            + todayTIRHighMinutes
            + todayTIRVeryHighMinutes

        if tirSum > cappedCoverage {
            let overflow = tirSum - cappedCoverage
            var remaining = overflow

            let takeVH = min(remaining, todayTIRVeryHighMinutes)
            todayTIRVeryHighMinutes -= takeVH
            remaining -= takeVH

            if remaining > 0 {
                let takeH = min(remaining, todayTIRHighMinutes)
                todayTIRHighMinutes -= takeH
                remaining -= takeH
            }

            if remaining > 0 {
                let takeIR = min(remaining, todayTIRInRangeMinutes)
                todayTIRInRangeMinutes -= takeIR
                remaining -= takeIR
            }

            if remaining > 0 {
                let takeL = min(remaining, todayTIRLowMinutes)
                todayTIRLowMinutes -= takeL
                remaining -= takeL
            }

            if remaining > 0 {
                todayTIRVeryLowMinutes = max(0, todayTIRVeryLowMinutes - remaining)
            }
        }

        // Period Summary (Today) — reuse today buckets + coverage
        tirTodaySummary = TIRPeriodSummaryEntry(
            id: UUID(),
            days: 1,
            veryLowMinutes: todayTIRVeryLowMinutes,
            lowMinutes: todayTIRLowMinutes,
            inRangeMinutes: todayTIRInRangeMinutes,
            highMinutes: todayTIRHighMinutes,
            veryHighMinutes: todayTIRVeryHighMinutes,
            coverageMinutes: todayTIRCoverageMinutes,
            expectedMinutes: todayTIRExpectedMinutes,
            coverageRatio: todayTIRCoverageRatio,
            isPartial: todayTIRIsPartial
        )
    }

    // ============================================================
    // MARK: - LAST 24H KPI (Mean + Coverage) — RAW only
    // ============================================================

    @MainActor
    private func updateLast24hGlucoseFromRawV1() {
        let now = Date()
        let start = now.addingTimeInterval(-24 * 60 * 60)

        // Expected minutes: last 24h window is always 1440
        let expected = 1440
        last24hGlucoseExpectedMinutes = expected

        // Last-24h samples (from RAW3DAYS)
        let points = cgmSamples3Days
            .filter { $0.timestamp >= start && $0.timestamp <= now }

        // Coverage: minutes based only on existing samples (no upscaling)
        let minutesPerSample = 5
        let coverage = points.count * minutesPerSample
        let cappedCoverage = min(coverage, expected)

        last24hGlucoseCoverageMinutes = cappedCoverage

        let denom = max(1, expected)
        let ratio = Double(cappedCoverage) / Double(denom)

        last24hGlucoseCoverageRatio = min(1.0, max(0.0, ratio))
        last24hGlucoseIsPartial = cappedCoverage < expected

        guard !points.isEmpty else {
            last24hGlucoseMeanMgdl = nil
            return
        }

        let sum = points.reduce(0.0) { $0 + $1.glucoseMgdl }
        last24hGlucoseMeanMgdl = sum / Double(points.count)
    }

    // ============================================================
    // MARK: - LAST 24H KPI (TIR) — RAW only
    // ============================================================

    @MainActor
    private func updateLast24hTIRFromRawV1() {
        let now = Date()
        let start = now.addingTimeInterval(-24 * 60 * 60)

        // Expected minutes: last 24h window is always 1440
        let expected = 1440
        last24hTIRExpectedMinutes = expected

        // Last-24h samples (from RAW3DAYS)
        let points = cgmSamples3Days
            .filter { $0.timestamp >= start && $0.timestamp <= now }

        // Coverage: minutes based only on existing samples (no upscaling)
        let minutesPerSample = 5
        let coverage = points.count * minutesPerSample
        let cappedCoverage = min(coverage, expected)

        last24hTIRCoverageMinutes = cappedCoverage

        let denom = max(1, expected)
        let ratio = Double(cappedCoverage) / Double(denom)

        last24hTIRCoverageRatio = min(1.0, max(0.0, ratio))
        last24hTIRIsPartial = cappedCoverage < expected

        // Reset buckets (deterministic)
        last24hTIRVeryLowMinutes = 0
        last24hTIRLowMinutes = 0
        last24hTIRInRangeMinutes = 0
        last24hTIRHighMinutes = 0
        last24hTIRVeryHighMinutes = 0

        guard !points.isEmpty else { return }

        for p in points {
            let v = p.glucoseMgdl
            if v < 54 {
                last24hTIRVeryLowMinutes += minutesPerSample
            } else if v < 70 {
                last24hTIRLowMinutes += minutesPerSample
            } else if v <= 180 {
                last24hTIRInRangeMinutes += minutesPerSample
            } else if v <= 250 {
                last24hTIRHighMinutes += minutesPerSample
            } else {
                last24hTIRVeryHighMinutes += minutesPerSample
            }
        }

        // Clamp to cappedCoverage
        let tirSum =
            last24hTIRVeryLowMinutes
            + last24hTIRLowMinutes
            + last24hTIRInRangeMinutes
            + last24hTIRHighMinutes
            + last24hTIRVeryHighMinutes

        if tirSum > cappedCoverage {
            var remaining = tirSum - cappedCoverage

            let takeVH = min(remaining, last24hTIRVeryHighMinutes)
            last24hTIRVeryHighMinutes -= takeVH
            remaining -= takeVH

            if remaining > 0 {
                let takeH = min(remaining, last24hTIRHighMinutes)
                last24hTIRHighMinutes -= takeH
                remaining -= takeH
            }

            if remaining > 0 {
                let takeIR = min(remaining, last24hTIRInRangeMinutes)
                last24hTIRInRangeMinutes -= takeIR
                remaining -= takeIR
            }

            if remaining > 0 {
                let takeL = min(remaining, last24hTIRLowMinutes)
                last24hTIRLowMinutes -= takeL
                remaining -= takeL
            }

            if remaining > 0 {
                last24hTIRVeryLowMinutes = max(0, last24hTIRVeryLowMinutes - remaining)
            }
        }
    }

    // ============================================================
    // MARK: - LAST 24H KPI (SD + CV) — RAW only
    // ============================================================
    //
    // Regel:
    // - SD wird NUR aus vorhandenen RAW Samples berechnet (keine Hochrechnung).
    // - Guard: Coverage muss sinnvoll sein (>= 2 Samples).
    // - SD = sqrt( average((x - mean)^2) )  // Population SD (stabil & deterministisch)
    // - CV% = (SD / Mean) * 100
    //
    // ============================================================

    @MainActor
    private func updateLast24hGlucoseSdFromRawV1() {
        let now = Date()
        let start = now.addingTimeInterval(-24 * 60 * 60)

        let points = cgmSamples3Days
            .filter { $0.timestamp >= start && $0.timestamp <= now }

        guard points.count >= 2 else {
            last24hGlucoseSdMgdl = nil
            last24hGlucoseCvPercent = nil        // NEW
            return
        }

        let mean = points.reduce(0.0) { $0 + $1.glucoseMgdl } / Double(points.count)

        let variance = points.reduce(0.0) { acc, p in
            let d = p.glucoseMgdl - mean
            return acc + (d * d)
        } / Double(points.count)

        let sd = sqrt(variance)
        last24hGlucoseSdMgdl = sd

        // NEW: CV (Last 24h)
        last24hGlucoseCvPercent = computeCvPercent(meanMgdl: mean, sdMgdl: sd)
    }

    // ============================================================
    // MARK: - PERIOD KPIs (RAW-derived, no DailyStats)
    // ============================================================

    @MainActor
    func refreshCGMPeriodKPIsV1() async {
        if isPreview { return }

        // Mean (raw samples)
        glucoseMean7dMgdl  = await computeMeanGlucoseMgdlFromRawDaysV1(days: 7)
        glucoseMean14dMgdl = await computeMeanGlucoseMgdlFromRawDaysV1(days: 14)

        // NEW: Mean 30/90
        glucoseMean30dMgdl = await computeMeanGlucoseMgdlFromRawDaysV1(days: 30)
        glucoseMean90dMgdl = await computeMeanGlucoseMgdlFromRawDaysV1(days: 90)

        // SD (raw samples)
        glucoseSd7dMgdl  = await computeGlucoseSdMgdlFromRawDaysV1(days: 7)
        glucoseSd14dMgdl = await computeGlucoseSdMgdlFromRawDaysV1(days: 14)
        glucoseSd30dMgdl = await computeGlucoseSdMgdlFromRawDaysV1(days: 30)
        glucoseSd90dMgdl = await computeGlucoseSdMgdlFromRawDaysV1(days: 90)

        // NEW: CVs (derived from mean + sd; no refetch)
        glucoseCv7dPercent  = computeCvPercent(meanMgdl: glucoseMean7dMgdl,  sdMgdl: glucoseSd7dMgdl)
        glucoseCv14dPercent = computeCvPercent(meanMgdl: glucoseMean14dMgdl, sdMgdl: glucoseSd14dMgdl)
        glucoseCv30dPercent = computeCvPercent(meanMgdl: glucoseMean30dMgdl, sdMgdl: glucoseSd30dMgdl)
        glucoseCv90dPercent = computeCvPercent(meanMgdl: glucoseMean90dMgdl, sdMgdl: glucoseSd90dMgdl)

        // TIR summaries (raw samples -> minutes)
        tir7dSummary  = await computeTIRPeriodSummaryFromRawDaysV1(days: 7)
        tir14dSummary = await computeTIRPeriodSummaryFromRawDaysV1(days: 14)
        tir30dSummary = await computeTIRPeriodSummaryFromRawDaysV1(days: 30)
        tir90dSummary = await computeTIRPeriodSummaryFromRawDaysV1(days: 90)
    }
}

// ============================================================
// MARK: - Private Helpers (RAW period queries)
// ============================================================

private extension HealthStore {

    func mgdlUnitV1() -> HKUnit {
        HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
    }

    func fetchRawCGMSamplesDaysV1(days: Int) async -> [CGMSamplePoint] {
        if isPreview { return [] }
        guard days >= 1 else { return [] }
        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let unit = mgdlUnitV1()

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let quantitySamples = (samples as? [HKQuantitySample]) ?? []

                var byTimestamp: [TimeInterval: CGMSamplePoint] = [:]
                byTimestamp.reserveCapacity(quantitySamples.count)

                for s in quantitySamples {
                    let key = s.startDate.timeIntervalSince1970.rounded()
                    byTimestamp[key] = CGMSamplePoint(
                        id: UUID(),
                        timestamp: s.startDate,
                        glucoseMgdl: s.quantity.doubleValue(for: unit)
                    )
                }

                let points = byTimestamp.values.sorted { $0.timestamp < $1.timestamp }
                continuation.resume(returning: points)
            }

            self.healthStore.execute(query)
        }
    }

    @MainActor
    func computeMeanGlucoseMgdlFromRawDaysV1(days: Int) async -> Double? {
        let points = await fetchRawCGMSamplesDaysV1(days: days)
        guard !points.isEmpty else { return nil }

        let sum = points.reduce(0.0) { $0 + $1.glucoseMgdl }
        return sum / Double(points.count)
    }

    // ============================================================
    // MARK: - SD Helper (Period, RAW-based)
    // ============================================================
    //
    // SD = sqrt( average((x-mean)^2) )  // Population SD
    //
    // ============================================================

    @MainActor
    func computeGlucoseSdMgdlFromRawDaysV1(days: Int) async -> Double? {
        let points = await fetchRawCGMSamplesDaysV1(days: days)
        guard points.count >= 2 else { return nil }

        let mean = points.reduce(0.0) { $0 + $1.glucoseMgdl } / Double(points.count)

        let variance = points.reduce(0.0) { acc, p in
            let d = p.glucoseMgdl - mean
            return acc + (d * d)
        } / Double(points.count)

        return sqrt(variance)
    }

    // ============================================================
    // MARK: - CV Helper (derived; no refetch)
    // ============================================================

    func computeCvPercent(meanMgdl: Double?, sdMgdl: Double?) -> Double? {        // NEW
        guard let meanMgdl, let sdMgdl else { return nil }
        guard meanMgdl > 0 else { return nil }
        let cv = (sdMgdl / meanMgdl) * 100.0
        return max(0, cv)
    }

    func computeCvPercent(meanMgdl: Double, sdMgdl: Double) -> Double? {          // NEW
        guard meanMgdl > 0 else { return nil }
        let cv = (sdMgdl / meanMgdl) * 100.0
        return max(0, cv)
    }

    @MainActor
    func computeTIRPeriodSummaryFromRawDaysV1(days: Int) async -> TIRPeriodSummaryEntry? {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        let points = await fetchRawCGMSamplesDaysV1(days: days)
        if points.isEmpty { return nil }

        var byDay: [Date: [CGMSamplePoint]] = [:]
        byDay.reserveCapacity(days)

        for p in points {
            let day = calendar.startOfDay(for: p.timestamp)
            byDay[day, default: []].append(p)
        }

        var expectedTotal = 0
        var coverageTotal = 0

        var veryLow = 0
        var low = 0
        var inRange = 0
        var high = 0
        var veryHigh = 0

        let minutesPerSample = 5

        for offset in stride(from: (days - 1), through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }

            let expectedForDay: Int
            if calendar.isDate(day, inSameDayAs: now) {
                expectedForDay = max(0, Int(now.timeIntervalSince(todayStart) / 60.0))
            } else {
                expectedForDay = 1440
            }
            expectedTotal += expectedForDay

            let samples = byDay[day] ?? []
            let coverageForDay = min(samples.count * minutesPerSample, expectedForDay)
            coverageTotal += coverageForDay

            for p in samples {
                let v = p.glucoseMgdl
                if v < 54 {
                    veryLow += minutesPerSample
                } else if v < 70 {
                    low += minutesPerSample
                } else if v <= 180 {
                    inRange += minutesPerSample
                } else if v <= 250 {
                    high += minutesPerSample
                } else {
                    veryHigh += minutesPerSample
                }
            }
        }

        let tirSum = veryLow + low + inRange + high + veryHigh
        if tirSum > coverageTotal {
            var overflow = tirSum - coverageTotal

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

        let denom = max(1, expectedTotal)
        let ratio = Double(coverageTotal) / Double(denom)
        let isPartial = coverageTotal < expectedTotal

        return TIRPeriodSummaryEntry(
            id: UUID(),
            days: days,
            veryLowMinutes: max(0, veryLow),
            lowMinutes: max(0, low),
            inRangeMinutes: max(0, inRange),
            highMinutes: max(0, high),
            veryHighMinutes: max(0, veryHigh),
            coverageMinutes: max(0, coverageTotal),
            expectedMinutes: max(0, expectedTotal),
            coverageRatio: min(1.0, max(0.0, ratio)),
            isPartial: isPartial
        )
    }
}
