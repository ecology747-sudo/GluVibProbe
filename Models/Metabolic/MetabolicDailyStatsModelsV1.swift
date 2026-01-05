//
//  MetabolicDailyStatsModelsV1.swift
//  GluVibProbe
//
//  Metabolic Domain – DailyStats Models (V1)
//
//  Zweck:
//  - Tagesbasierte Statistik (≥90 Tage)
//  - Grundlage für Trends, Rolling Averages, KPIs
//  - 1 Entry pro Kalendertag
//  - Nur „dumb structs“
//
//  Wichtige Regel:
//  - Intern immer mg/dL
//  - mmol/L ausschließlich Anzeige (Units Settings)
//

import Foundation

// MARK: - Daily Glucose Statistics

struct DailyGlucoseStatsEntry: Identifiable {
    let id: UUID
    let date: Date

    let meanMgdl: Double
    let standardDeviationMgdl: Double
    let coefficientOfVariationPercent: Double

    let coverageMinutes: Int
    let expectedMinutes: Int
    let isPartial: Bool
}

// MARK: - Time in Range (TIR)

struct DailyTIREntry: Identifiable {
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

// MARK: - TIR Period Summary (NEW)

struct TIRPeriodSummaryEntry: Identifiable {
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

// MARK: - Insulin Daily Aggregates

struct DailyBolusEntry: Identifiable {
    let id: UUID
    let date: Date
    let bolusUnits: Double
}

struct DailyBasalEntry: Identifiable {
    let id: UUID
    let date: Date
    let basalUnits: Double
}

// MARK: - Derived Ratios (Daily)

struct DailyBolusBasalRatioEntry: Identifiable {
    let id: UUID
    let date: Date
    let ratio: Double
}

struct DailyCarbBolusRatioEntry: Identifiable {
    let id: UUID
    let date: Date
    let gramsPerUnit: Double
}
