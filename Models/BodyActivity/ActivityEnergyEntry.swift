//
//  ActivityEnergyEntry.swift
//  GluVibProbe
//

import Foundation

/// Ein Tages-Eintrag für Aktivitätsenergie (kcal)
struct ActivityEnergyEntry: Identifiable {
    let id = UUID()
    let date: Date
    let activeEnergy: Int
}
