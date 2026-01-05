//
//  RestingHeartRateEntry.swift
//  GluVibProbe
//

import Foundation

/// Tages-Eintrag für Ruhepuls (Body Domain, V1)
struct RestingHeartRateEntry: Identifiable {

    /// Stabile ID = Tag (00:00 lokale Zeit)
    var id: Date { dayStart }                         // !!! UPDATED

    /// Datum (kann Uhrzeit enthalten, z.B. stats.startDate)
    let date: Date

    /// Ruhepuls in bpm (Name bleibt wie in deinen Call-Sites)
    let restingHeartRate: Int                         // !!! UPDATED

    /// Normalisiert auf Tagesstart (00:00 lokale Zeit)
    var dayStart: Date {                              // !!! NEW
        Calendar.current.startOfDay(for: date)
    }
}
