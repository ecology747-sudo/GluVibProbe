//
//  BodyFatEntry.swift
//  GluVibProbe
//

import Foundation

/// Tages-Eintrag für Körperfett (Body Domain, V1)
struct BodyFatEntry: Identifiable {

    /// Stabile ID = Tag (00:00 lokale Zeit)
    var id: Date { dayStart }                         // !!! UPDATED

    /// Datum (kann Uhrzeit enthalten, z.B. stats.startDate)
    let date: Date

    /// Körperfett in Prozent (0...100)
    let bodyFatPercent: Double

    /// Normalisiert auf Tagesstart (00:00 lokale Zeit)
    var dayStart: Date {                              // !!! NEW
        Calendar.current.startOfDay(for: date)
    }
}
