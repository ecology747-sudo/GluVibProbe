//
//  ActivityEnergyEntry.swift
//  GluVibProbe
//

import Foundation

/// Tages-Eintrag für Aktivitätsenergie (kcal)
struct ActivityEnergyEntry: Identifiable {

    /// Eindeutige ID für ForEach / Charts
    let id = UUID()

    /// Datum des Tages (meist 00:00 lokale Zeit)
    let date: Date

    /// Aktivitätsenergie an diesem Tag (z. B. in kcal)
    let activeEnergy: Int
}
