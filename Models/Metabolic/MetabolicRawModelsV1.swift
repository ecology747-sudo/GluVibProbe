//
//  MetabolicRawModelsV1.swift
//  GluVibProbe
//
//  Metabolic Domain – Raw Models (V1)
//
//  Zweck:
//  - Darstellungsebene für DayProfile (0–24 Uhr)
//  - Minuten- / Event-basierte Daten
//  - KEINE Statistik, KEINE Berechnungen
//  - Nur „dumb structs“
//
//  Architektur:
//  - Apple Health → HealthStore → diese Models → ViewModels → Charts
//  - Keine Methoden, keine Logik
//

import Foundation

// MARK: - CGM (Continuous Glucose Monitoring)

struct CGMSamplePoint: Identifiable {
    let id: UUID
    let timestamp: Date
    let glucoseMgdl: Double
}

// MARK: - Fingerstick Blood Glucose (optional Overlay)

struct FingerGlucoseEvent: Identifiable {
    let id: UUID
    let timestamp: Date
    let glucoseMgdl: Double
}

// MARK: - Insulin Bolus (Event)

struct InsulinBolusEvent: Identifiable {
    let id: UUID
    let timestamp: Date
    let units: Double
}

// MARK: - Insulin Basal (Event)

struct InsulinBasalEvent: Identifiable {                 // CHANGE: Segment -> Event
    let id: UUID
    let timestamp: Date                                  // CHANGE
    let units: Double                                    // CHANGE
}

// MARK: - Nutrition Events (Carbs / Protein)

enum NutritionEventKind {
    case carbs
    case protein
}

struct NutritionEvent: Identifiable {
    let id: UUID
    let timestamp: Date
    let grams: Double
    let kind: NutritionEventKind
}

// MARK: - Activity Overlay (Workouts / Movement)

enum ActivityOverlayKind {
    case workout
    case movement
}

struct ActivityOverlayEvent: Identifiable {
    let id: UUID
    let start: Date
    let end: Date
    let kind: ActivityOverlayKind
}

// ============================================================
// MARK: - MainChart DayProfile (V1)
// ============================================================

struct MainChartDayProfileV1: Identifiable {
    let id: UUID
    let day: Date
    let builtAt: Date
    let isToday: Bool

    // Raw overlays (aus HealthStore RAW3DAYS)
    let cgm: [CGMSamplePoint]
    let bolus: [InsulinBolusEvent]
    let basal: [InsulinBasalEvent]                        // CHANGE: Segment -> Event

    let carbs: [NutritionEvent]
    let protein: [NutritionEvent]

    let activity: [ActivityOverlayEvent]
    let finger: [FingerGlucoseEvent]
}
