//
//  DailyNutritionEnergyEntry.swift
//  GluVibProbe
//
//  Nutrition-Domain: tägliche Nahrungsenergie (immer in kcal gespeichert)
//

import Foundation

struct DailyNutritionEnergyEntry: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let energyKcal: Int
}
