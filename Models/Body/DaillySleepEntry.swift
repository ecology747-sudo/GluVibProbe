//
//  DailySleepEntry.swift
//  GluVibProbe
//

import Foundation

/// Tages-Eintrag für Schlaf (Body & Activity Domain, V1-stabil)
struct DailySleepEntry: Identifiable {

    /// Stabile ID = Tag (00:00 lokale Zeit)
    var id: Date { dayStart }                       // !!! UPDATED

    /// Datum (kann 00:00 sein, muss aber nicht)
    let date: Date

    /// Gesamter Schlaf dieses Tages in Minuten
    let minutes: Int

    /// Normalisiert auf Tagesstart (00:00 lokale Zeit)
    var dayStart: Date {                            // !!! NEW
        Calendar.current.startOfDay(for: date)
    }
}
