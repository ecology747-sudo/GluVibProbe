//
//  BMIEntry.swift
//  GluVibProbe
//

import Foundation

/// Tages-Eintrag für BMI (Body Domain, V1)
struct BMIEntry: Identifiable {

    /// Stabile ID = Tag (00:00 lokale Zeit)
    var id: Date { dayStart }                     // !!! UPDATED

    /// Datum des Messwerts (kann Uhrzeit enthalten)
    let date: Date

    /// BMI (dimensionslos, z.B. 24.3)
    let bmi: Double

    /// Normalisiert auf Tagesstart (00:00 lokale Zeit)
    var dayStart: Date {                          // !!! NEW
        Calendar.current.startOfDay(for: date)
    }
}
