//
//  DailyProteinEntry.swift
//  GluVibProbe
//

import Foundation

/// Nutrition: Protein pro Tag (in Gramm)
struct DailyProteinEntry: Identifiable, Hashable {
    let date: Date
    let grams: Int

    // Für Charts meist eindeutig genug
    var id: Date { date }
}
