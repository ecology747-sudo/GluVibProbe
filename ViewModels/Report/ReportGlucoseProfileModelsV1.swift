//
//  ReportGlucoseProfileModelsV1.swift
//  GluVibProbe
//
//  Report V1 — Glucose Profile (Median + Percentile Bands)
//  - Pure models (no logic)
//  - Base unit: mg/dL
//  - 15-minute slots (96 slots / 24h)
//

import Foundation

struct ReportGlucoseProfilePointV1: Identifiable {
    let id = UUID()

    /// Slot index 0...95 (15-minute steps)
    let slot: Int

    /// Percentiles (Base unit mg/dL)
    let p05: Double?
    let p25: Double?
    let p50: Double?
    let p75: Double?
    let p95: Double?

    /// Count of contributing values in this slot (across all days)
    let sampleCount: Int
}

struct ReportGlucoseProfileV1 {
    /// Full days included (e.g. 30 full days, usually ending yesterday)
    let days: Int

    /// Always 96 points (15-minute slots)
    let points: [ReportGlucoseProfilePointV1]

    /// Target range boundaries (Base unit mg/dL)
    let targetMinMgdl: Double
    let targetMaxMgdl: Double

    /// Optional additional thresholds (Base unit mg/dL)
    let veryLowLimitMgdl: Double
    let veryHighLimitMgdl: Double

    /// Coverage info (optional)
    let distinctDaysWithAnyData: Int
}
