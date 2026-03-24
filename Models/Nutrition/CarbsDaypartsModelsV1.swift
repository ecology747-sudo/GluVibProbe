//
//  CarbsDaypartsModelsV1.swift
//  GluVibProbe
//
//  Nutrition — Carbs Split (V1)
//  - Used for chart-only metric: Ø Carbs (g) by daypart over 7/14/30/90 days
//

import Foundation

enum CarbsDaypartV1: String, CaseIterable, Identifiable {
    case morning
    case afternoon
    case night

    var id: String { rawValue }

    var labelDE: String {
        switch self {
        case .morning: return "Vormittag"
        case .afternoon: return "Nachmittag"
        case .night: return "Nacht"
        }
    }
}

struct DailyCarbsByDaypartEntryV1: Identifiable, Hashable {
    let id = UUID()
    let date: Date // startOfDay (local)

    let morningGrams: Int
    let afternoonGrams: Int
    let nightGrams: Int

    var totalGrams: Int {
        morningGrams + afternoonGrams + nightGrams
    }
}

struct CarbsDaypartPeriodAverageEntryV1: Identifiable, Hashable {
    let id = UUID()

    /// Window size in days (7/14/30/90)
    let windowDays: Int

    /// Segment averages (g/day) within the window
    let morningAvg: Int
    let afternoonAvg: Int
    let nightAvg: Int

    var totalAvg: Int {
        morningAvg + afternoonAvg + nightAvg
    }

    var labelDE: String {
        "\(windowDays) Tage"
    }
}
