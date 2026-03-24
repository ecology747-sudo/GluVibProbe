//
//  GlucoseConversionHelper.swift
//  GluVibProbe
//

import Foundation

/// Zentrale Helferfunktionen für Glukose-Umrechnungen.
/// Wird u. a. in SettingsView und MetabolicSettingsSection verwendet.
enum GlucoseConverter {

    /// mg/dL → mmol/L
    static func mgToMmol(_ mg: Int) -> Double {
        Double(mg) / 18.0
    }

    /// mmol/L → mg/dL (gerundet)
    static func mmolToMg(_ mmol: Double) -> Int {
        Int((mmol * 18.0).rounded())
    }
}
