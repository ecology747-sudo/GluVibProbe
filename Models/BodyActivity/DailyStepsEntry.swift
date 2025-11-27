//
//  DailyStepsEntry.swift
//  GluVibProbe
//

import Foundation

/// Tages-Eintrag für Schritte (Body & Activity Domain)
struct DailyStepsEntry: Identifiable {

    /// Eindeutige ID für ForEach / Charts
    let id = UUID()

    /// Datum des Tages (meist 00:00 lokale Zeit)
    let date: Date

    /// Anzahl Schritte an diesem Tag
    let steps: Int
}
