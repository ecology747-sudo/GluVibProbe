//  DailyFatEntry.swift
//  GluVibProbe
//
//  Nutrition-Domain: Fat (g) – tägliche Summen

import Foundation

struct DailyFatEntry: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let grams: Int
}
