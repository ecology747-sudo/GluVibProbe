//
//  DailySugarEntry.swift
//  GluVibProbe
//
//  Nutrition V1 — Sugar (g)
//  - Daily aggregated grams per day (full day buckets)
//

import Foundation

struct DailySugarEntry: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let grams: Int
}
