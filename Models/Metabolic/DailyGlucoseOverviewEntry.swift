//
//  DailyGlucoseOverviewEntry.swift
//  GluVibProbe
//
//  Metabolic Overview — 7-day lightweight daily series (yesterday ... -6)
//  - SSoT: HealthStore
//  - No minute data, no fetch logic here
//

import Foundation

struct DailyGlucoseOverviewEntry: Identifiable {
    let id = UUID()
    let date: Date               // startOfDay (local)
    let meanMgdl: Double

    // TIR minutes (daily)
    let veryLowMinutes: Int
    let lowMinutes: Int
    let inRangeMinutes: Int
    let highMinutes: Int
    let veryHighMinutes: Int

    let coverageMinutes: Int
}
