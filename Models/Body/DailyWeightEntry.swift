//
//  DailyWeightEntry.swift
//  GluVibProbe
//

import Foundation

/// Tages-Eintrag für Körpergewicht (Body Domain)
struct DailyWeightEntry: Identifiable {

    /// Stabile ID (Tag)
    var id: Date { date }

    /// Datum des Tages (meist 00:00 lokale Zeit)
    let date: Date

    /// Gewicht in kg (Double, behält Dezimalstellen: z.B. 97.4)
    let kg: Double
}
