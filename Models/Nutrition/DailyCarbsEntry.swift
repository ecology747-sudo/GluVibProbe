//
//  DailyCarbsEntry.swift
//  GluVibProbe
//

import Foundation

/// Nutrition: Carbohydrates pro Tag (in Gramm)
struct DailyCarbsEntry: Identifiable {

    /// Stabile ID = Tag (00:00 lokale Zeit)
    var id: Date { dayStart }                                  // !!! UPDATED

    /// Datum (kann Uhrzeit enthalten)
    let date: Date

    /// Carbs in Gramm
    let grams: Int

    /// Normalisiert auf Tagesstart (00:00 lokale Zeit)
    var dayStart: Date {                                       // !!! NEW
        Calendar.current.startOfDay(for: date)
    }
}
