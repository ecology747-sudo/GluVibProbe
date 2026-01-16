//
//  HealthStore+CGMKPIV1.swift
//  GluVibProbe
//
//  Metabolic V1 — CGM KPI V1 (RAW → Quick KPIs)
//
//  Diese Datei ist ausschließlich für minutenbasierte CGM-KPIs aus RAW zuständig:
//
//  1) RAW INPUT (DayProfile / MainChart Backbone)
//     - CGM Samples für Today/Yesterday/DayBefore → cgmSamples3Days
//     - triggert rebuildMainChartCacheFromRaw3DaysV1() nach RAW-Publish
//
//  2) QUICK KPIs (RAW-derived, minute-based)
//     - Today (00:00 → now): todayGlucoseMeanMgdl + todayTIR* + Coverage/Expected/Ratio/isPartial
//     - Last 24h (ROLLING WINDOW): last24hGlucoseMeanMgdl + last24hTIR* + Coverage/Expected/Ratio/isPartial
//       !!! UPDATED: Last 24h endet NICHT bei Date()/now, sondern bei der letzten verfügbaren CGM-Messung
//       (windowEnd = last(cgmSamples3Days).timestamp). Dadurch ist die 24h-Coverage korrekt, auch wenn HealthKit
//       CGM-Daten zeitverzögert liefert (z. B. ~3h Delay).
//     - Last 24h SD + CV: last24hGlucoseSdMgdl + last24hGlucoseCvPercent
//
//  WICHTIG: Keine Period-KPIs (7/14/30/90), kein Hybrid, keine DailyStats in dieser Datei.
//           Period/Hybrid lebt in CGM TIR/Range Dateien und DailyStats90.
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

            // Dedup by timestamp (deterministic)
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

            Task { @MainActor in
                self.cgmSamples3Days = points

                // MainChart backbone
                self.rebuildMainChartCacheFromRaw3DaysV1()

                // TODAY KPIs (00:00 → now)
                self.updateTodayGlucoseAndTIRFromRawV1()

                // LAST 24H KPIs (rolling window ending at last available CGM sample)
                self.updateLast24hGlucoseFromRawV1()
                self.updateLast24hTIRFromRawV1()
                self.updateLast24hGlucoseSdFromRawV1()

                // Period KPIs intentionally removed from CGM KPI V1
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - TODAY KPIs (Mean + TIR + Coverage) — RAW only
    // ============================================================

    @MainActor
    private func updateTodayGlucoseAndTIRFromRawV1() {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.startOfDay(for: now)

        let expected = max(0, Int(now.timeIntervalSince(start) / 60.0))
        todayGlucoseExpectedMinutes = expected
        todayTIRExpectedMinutes = expected

        let today = cgmSamples3Days
            .filter { $0.timestamp >= start && $0.timestamp <= now }

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

        // Reset buckets
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

        let sum = today.reduce(0.0) { $0 + $1.glucoseMgdl }
        todayGlucoseMeanMgdl = sum / Double(today.count)

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

        // Clamp buckets to coverage
        let tirSum =
            todayTIRVeryLowMinutes
            + todayTIRLowMinutes
            + todayTIRInRangeMinutes
            + todayTIRHighMinutes
            + todayTIRVeryHighMinutes

        if tirSum > cappedCoverage {
            var remaining = tirSum - cappedCoverage

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

        // Today wrapper summary (optional helper state)
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

        // !!! UPDATED: rolling 24h window ends at last available CGM sample timestamp
        let end = lastAvailableCGMWindowEndV1()
        let start = end.addingTimeInterval(-24 * 60 * 60)

        let expected = 1440
        last24hGlucoseExpectedMinutes = expected

        let points = cgmSamples3Days
            .filter { $0.timestamp >= start && $0.timestamp <= end }

        let minutesPerSample = 5
        let coverage = points.count * minutesPerSample
        let cappedCoverage = min(coverage, expected)

        last24hGlucoseCoverageMinutes = cappedCoverage

        let ratio = Double(cappedCoverage) / Double(max(1, expected))
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

        // !!! UPDATED: rolling 24h window ends at last available CGM sample timestamp
        let end = lastAvailableCGMWindowEndV1()
        let start = end.addingTimeInterval(-24 * 60 * 60)

        let expected = 1440
        last24hTIRExpectedMinutes = expected

        let points = cgmSamples3Days
            .filter { $0.timestamp >= start && $0.timestamp <= end }

        let minutesPerSample = 5
        let coverage = points.count * minutesPerSample
        let cappedCoverage = min(coverage, expected)

        last24hTIRCoverageMinutes = cappedCoverage

        let ratio = Double(cappedCoverage) / Double(max(1, expected))
        last24hTIRCoverageRatio = min(1.0, max(0.0, ratio))
        last24hTIRIsPartial = cappedCoverage < expected

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

    @MainActor
    private func updateLast24hGlucoseSdFromRawV1() {

        // !!! UPDATED: rolling 24h window ends at last available CGM sample timestamp
        let end = lastAvailableCGMWindowEndV1()
        let start = end.addingTimeInterval(-24 * 60 * 60)

        let points = cgmSamples3Days
            .filter { $0.timestamp >= start && $0.timestamp <= end }

        guard points.count >= 2 else {
            last24hGlucoseSdMgdl = nil
            last24hGlucoseCvPercent = nil
            return
        }

        let mean = points.reduce(0.0) { $0 + $1.glucoseMgdl } / Double(points.count)

        let variance = points.reduce(0.0) { acc, p in
            let d = p.glucoseMgdl - mean
            return acc + (d * d)
        } / Double(points.count)

        let sd = sqrt(variance)
        last24hGlucoseSdMgdl = sd
        last24hGlucoseCvPercent = computeCvPercent(meanMgdl: mean, sdMgdl: sd)
    }
}

// ============================================================
// MARK: - Private Helpers
// ============================================================

private extension HealthStore {

    // !!! NEW: unified window end for "Last 24h" KPIs (prevents false partial coverage when HealthKit is delayed)
    func lastAvailableCGMWindowEndV1() -> Date {
        cgmSamples3Days.last?.timestamp ?? Date()
    }

    func computeCvPercent(meanMgdl: Double, sdMgdl: Double) -> Double? {
        guard meanMgdl > 0 else { return nil }
        return max(0, (sdMgdl / meanMgdl) * 100.0)
    }
}
