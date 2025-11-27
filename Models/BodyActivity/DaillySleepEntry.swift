//
//  DailySleepEntry.swift
//  GluVibProbe
//

import Foundation

/// Tages-Eintrag für Schlaf (Body & Activity Domain)
struct DailySleepEntry: Identifiable {

    /// Eindeutige ID für ForEach / Charts
    let id = UUID()

    /// Datum des Tages (meist 00:00 lokale Zeit)
    let date: Date

    /// Gesamter Schlaf dieses Tages in Minuten
    let minutes: Int
}
