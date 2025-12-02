//
//  DailyProteinEntry.swift
//  GluVibProbe
//

import Foundation

/// Täglicher Protein-Wert in Gramm (g)
struct DailyProteinEntry: Identifiable, Hashable {
    let date: Date
    let grams: Int

    // Für Charts meist eindeutig genug
    var id: Date { date }
}
