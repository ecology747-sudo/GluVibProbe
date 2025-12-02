//
//  SettingsUnits.swift
//  GluVibProbe
//

import Foundation

// MARK: - Glucose Unit

enum GlucoseUnit: String, CaseIterable, Identifiable {
    case mgdL = "mg/dL"
    case mmolL = "mmol/L"

    var id: String { rawValue }
    var label: String { rawValue }
}

// MARK: - Weight Unit

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg = "kg"
    case lbs = "lbs"

    var id: String { rawValue }
    var label: String { rawValue }
}

// MARK: - Height Unit

enum HeightUnit: String, CaseIterable, Identifiable {
    case cm = "cm"
    case feetInches = "ft/in"

    var id: String { rawValue }
    var label: String { rawValue }
}

// MARK: - Energy Unit

enum EnergyUnit: String, CaseIterable, Identifiable {
    case kcal = "kcal"
    case kilojoules = "kJ"

    var id: String { rawValue }
    var label: String { rawValue }
}

// MARK: - Distance Unit

enum DistanceUnit: String, CaseIterable, Identifiable {
    case kilometers = "km"
    case miles = "mi"

    var id: String { rawValue }
    var label: String { rawValue }
}

// MARK: - WeightUnit – zentrale Umrechnung & Formatierung

extension WeightUnit {

    /// Wandelt einen kg-Wert in die aktuell gewünschte Einheit um.
    /// - kg → kg
    /// - kg → lbs (gerundet)
    func convertedValue(fromKg kg: Int) -> Int {
        switch self {
        case .kg:
            return kg
        case .lbs:
            return Int((Double(kg) * 2.20462).rounded())
        }
    }

    /// Formatiert einen kg-Wert inkl. Einheit,
    /// z. B. "82 kg" oder "181 lbs"
    func formatted(fromKg kg: Int) -> String {
        "\(convertedValue(fromKg: kg)) \(label)"
    }
}
