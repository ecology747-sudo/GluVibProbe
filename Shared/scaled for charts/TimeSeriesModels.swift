//
//  TimeSeriesModels.swift
//  GluVibProbe
//
//  Gemeinsame Modelle für Zeitreihen-Charts:
//  - PeriodAverageEntry  (7T / 14T / 30T / 90T / 180T / 365T)
//  - MonthlyMetricEntry  ("Jan", "Feb", ...)
//  - Last90DaysPeriod    (7 / 14 / 30 / 90 Tage)
//

import Foundation

/// Durchschnittswerte über verschiedene Zeiträume (z. B. 7T, 14T, 30T, 90T, 180T, 365T)
struct PeriodAverageEntry: Identifiable {
    let id = UUID()
    let label: String      // z. B. "7T", "14T", "30T", ...
    let days: Int          // z. B. 7, 14, 30, 90, 180, 365
    let value: Int         // Durchschnittswert (Steps, Minuten, kcal, g, Gewicht, ...)
}

/// Monats-Werte (z. B. Steps / Month, Carbs / Month, Sleep / Month)
struct MonthlyMetricEntry: Identifiable {
    let id = UUID()
    let monthShort: String   // "Jan", "Feb", "Mär", ...
    let value: Int           // Aggregierter Monatswert
}

/// Auswahl für die 90-Tage-Charts (7 / 14 / 30 / 90 Tage sichtbar)
enum Last90DaysPeriod: String, CaseIterable, Identifiable {
    case days7  = "7"
    case days14 = "14"
    case days30 = "30"
    case days90 = "90"

    var id: Self { self }

    /// Anzahl Tage für den gewählten Zeitraum
    var days: Int {
        switch self {
        case .days7:  return 7
        case .days14: return 14
        case .days30: return 30
        case .days90: return 90
        }
    }
}
