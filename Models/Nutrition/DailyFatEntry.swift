//  DailyFatEntry.swift
//  GluVibProbe
//
//  Nutrition-Domain: Fat (g) – tägliche Summen

import Foundation

struct DailyFatEntry: Identifiable, Hashable {
    let date: Date
    let grams: Int

    // !!! UPDATED: stabile Identität für Charts
    var id: Date { date }
}
