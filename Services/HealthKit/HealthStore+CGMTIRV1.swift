//
//  HealthStore+CGMTIRV1.swift
//  GluVibProbe
//
//  Metabolic V1 — CGM TIR Period KPIs (HYBRID)
//
//  Regel (Performance/Architektur):
//  - Home KPI Tile (TIR): Last 24h minutenbasiert aus RAW ✅ (last24hTIR* Published Props)
//  - Today (Period builder): minutenbasiert aus RAW (00:00 → now) ✅ (todayTIR* Published Props)
//  - Past days: tagesbasiert aus dailyTIR90 ✅
//  - Perioden 7/14/30/90: (days-1) Daily + Today RAW ✅
//
//  Keine DailyStats-Berechnung in dieser Datei.
//  Diese Datei aggregiert nur bereits vorhandene Published State.
//

import Foundation

extension HealthStore {

    // ------------------------------------------------------------
    // MARK: - Public API
    // ------------------------------------------------------------

    /// Recompute Period KPIs from existing caches:
    /// - Today TIR: uses todayTIR* Published Props (computed in HealthStore+CGMV1)
    /// - Past days: uses dailyTIR90 (tagesbasiert)
    /// - Periods: (days-1) Daily + Today RAW
    @MainActor
    func recomputeCGMPeriodKPIsHybridV1() {
        if isPreview { return }

        // !!! FIX: Today summary must stay "00:00 → now"
        tirTodaySummary = buildTodayTIRSummaryFromPublished()

        // Periods (HYBRID): (days-1) from dailyTIR90 + today from Published
        tir7dSummary  = buildHybridTIRSummary(days: 7)
        tir14dSummary = buildHybridTIRSummary(days: 14)
        tir30dSummary = buildHybridTIRSummary(days: 30)
        tir90dSummary = buildHybridTIRSummary(days: 90)
    }

    // ------------------------------------------------------------
    // MARK: - HYBRID builder (Periods)
    // ------------------------------------------------------------

    /// Builds a period summary:
    /// - days-1 full days: summed from dailyTIR90
    /// - today (00:00 → now): added from todayTIR* Published Props
    ///
    /// NOTE:
    /// We intentionally do NOT use last24h here to avoid overlap/double-counting
    /// with "yesterday" daily entries.
    @MainActor
    private func buildHybridTIRSummary(days: Int) -> TIRPeriodSummaryEntry? {
        guard days >= 1 else { return nil }

        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)

        // 1) Past (days-1) full days from DailyTIR90
        let pastDays = max(0, days - 1)
        let pastStart = cal.date(byAdding: .day, value: -pastDays, to: todayStart) ?? todayStart

        let pastEntries = dailyTIR90
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

        // Kalender-Erwartung für Past Days sicherstellen
        let expectedPastCalendar = pastDays * 1440
        if expected < expectedPastCalendar {
            expected = expectedPastCalendar
        }

        // 2) Today (00:00 → now) from Published (RAW-derived)
        veryLow += max(0, todayTIRVeryLowMinutes)
        low += max(0, todayTIRLowMinutes)
        inRange += max(0, todayTIRInRangeMinutes)
        high += max(0, todayTIRHighMinutes)
        veryHigh += max(0, todayTIRVeryHighMinutes)

        coverage += max(0, todayTIRCoverageMinutes)
        expected += max(0, todayTIRExpectedMinutes)

        let ratio = expected > 0 ? (Double(coverage) / Double(expected)) : 0
        let isPartial = coverage < expected

        return TIRPeriodSummaryEntry(
            id: UUID(),
            days: days,
            veryLowMinutes: veryLow,
            lowMinutes: low,
            inRangeMinutes: inRange,
            highMinutes: high,
            veryHighMinutes: veryHigh,
            coverageMinutes: coverage,
            expectedMinutes: expected,
            coverageRatio: ratio,
            isPartial: isPartial
        )
    }

    // ------------------------------------------------------------
    // MARK: - Today summary wrapper (from Published)
    // ------------------------------------------------------------

    /// Today TIR (00:00 → now) from todayTIR* Published Props
    @MainActor
    private func buildTodayTIRSummaryFromPublished() -> TIRPeriodSummaryEntry? {
        let coverage = max(0, todayTIRCoverageMinutes)
        let expected = max(0, todayTIRExpectedMinutes)
        let ratio = expected > 0 ? (Double(coverage) / Double(expected)) : 0
        let isPartial = coverage < expected

        return TIRPeriodSummaryEntry(
            id: UUID(),
            days: 1,
            veryLowMinutes: max(0, todayTIRVeryLowMinutes),
            lowMinutes: max(0, todayTIRLowMinutes),
            inRangeMinutes: max(0, todayTIRInRangeMinutes),
            highMinutes: max(0, todayTIRHighMinutes),
            veryHighMinutes: max(0, todayTIRVeryHighMinutes),
            coverageMinutes: coverage,
            expectedMinutes: expected,
            coverageRatio: ratio,
            isPartial: isPartial
        )
    }
}
