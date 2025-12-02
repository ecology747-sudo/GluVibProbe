//  DailyCarbsEntry.swift
//  GluVibProbe
//

import Foundation

/// Nutrition: Carbohydrates pro Tag (in Gramm)
struct DailyCarbsEntry: Identifiable {
    let id = UUID()
    let date: Date
    let grams: Int
}
