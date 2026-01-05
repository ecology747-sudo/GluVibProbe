//
//  DailyNutritionEnergyEntry.swift
//  GluVibProbe
//
//  Nutrition-Domain: tägliche Nahrungsenergie (immer in kcal gespeichert)
//

import Foundation

/// Täglicher Nutrition-Energy-Wert in kcal
struct DailyNutritionEnergyEntry: Identifiable, Hashable {
    let date: Date
    let energyKcal: Int

    // Für Charts meist eindeutig genug
    var id: Date { date }                   // !!! UPDATED (statt UUID → Date, wie Protein/Carbs-Pattern)
}
