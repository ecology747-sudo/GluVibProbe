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

// MARK: - GlucoseUnit – zentrale Umrechnung & Formatierung  // !!! NEW

extension GlucoseUnit {

    // MARK: Constants

    private static let mgdlPerMmol: Double = 18.0                 // !!! NEW

    // MARK: NumberFormatter (zentral)

    private static func makeFormatter(fractionDigits: Int) -> NumberFormatter { // !!! NEW
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = fractionDigits
        f.maximumFractionDigits = fractionDigits
        return f
    }

    // MARK: Conversion (Display-only)

    /// Wandelt einen mg/dL-Wert (Base Unit) in die gewünschte Anzeigeeinheit um.
    /// - Wichtig: Base bleibt immer mg/dL (Double). Hier wird NUR für Anzeige umgerechnet.
    func convertedValue(fromMgdl mgdl: Double) -> Double {        // !!! NEW
        switch self {
        case .mgdL:
            return mgdl
        case .mmolL:
            return mgdl / Self.mgdlPerMmol
        }
    }

    /// Wandelt einen mmol/L-Wert (Display) zurück nach mg/dL (Base Unit).
    /// - Wird z.B. gebraucht, wenn man mmol-Ticks erzeugt und sie als mg/dL Positionen zurückgibt.
    func mgdlValue(fromMmol mmol: Double) -> Double {             // !!! NEW
        mmol * Self.mgdlPerMmol
    }

    // MARK: Formatting

    /// Formatiert einen mg/dL-Wert (Base Unit) als String (optional inkl. Einheit).
    /// - fractionDigits: z.B. 0 (KPIs), 1 (mmol KPIs), etc.
    func formatted(fromMgdl mgdl: Double, fractionDigits: Int, includeUnit: Bool = true) -> String { // !!! NEW
        let value = convertedValue(fromMgdl: mgdl)

        let f = Self.makeFormatter(fractionDigits: fractionDigits)
        let numberString = f.string(from: NSNumber(value: value))
            ?? String(format: "%.\(fractionDigits)f", value)

        return includeUnit ? "\(numberString) \(label)" : numberString
    }

    /// Formatiert einen mg/dL-Wert (Base Unit) nur als Zahl (ohne Einheit) – für Charts/Achsen/Labels.
    func formattedNumber(fromMgdl mgdl: Double, fractionDigits: Int) -> String { // !!! NEW
        let value = convertedValue(fromMgdl: mgdl)

        let f = Self.makeFormatter(fractionDigits: fractionDigits)
        return f.string(from: NSNumber(value: value))
            ?? String(format: "%.\(fractionDigits)f", value)
    }
}

// MARK: - Weight Unit

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg = "kg"
    case lbs = "lbs"

    var id: String { rawValue }
    var label: String { rawValue }
}

// MARK: - Height Unit
// !!! REMOVED

// MARK: - Energy Unit
// !!! REMOVED (kJ vollständig entfernt; Energie ist immer kcal)

// MARK: - Distance Unit

enum DistanceUnit: String, CaseIterable, Identifiable {
    case kilometers = "km"
    case miles = "mi"

    var id: String { rawValue }
    var label: String { rawValue }
}

// MARK: - DistanceUnit – zentrale Umrechnung & Formatierung

extension DistanceUnit {

    // MARK: Constants

    private static let milesPerKm: Double = 0.62137119223733       // !!! NEW

    // MARK: NumberFormatter (zentral)

    private static func makeFormatter(fractionDigits: Int) -> NumberFormatter { // !!! NEW
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = fractionDigits
        f.maximumFractionDigits = fractionDigits
        return f
    }

    // MARK: Conversion

    /// Wandelt einen km-Wert (Base Unit) in die gewünschte Anzeigeeinheit um.
    /// - Wichtig: Base bleibt immer km (Double). Hier wird NUR für Anzeige umgerechnet.
    func convertedValue(fromKm km: Double) -> Double {              // !!! NEW
        switch self {
        case .kilometers:
            return km
        case .miles:
            return km * Self.milesPerKm
        }
    }

    // MARK: Formatting

    /// Formatiert einen km-Wert (Base Unit) als String inkl. Einheit.
    /// - fractionDigits: z.B. 0 (Charts/Axis) oder 1 (KPIs/Labels)
    func formatted(fromKm km: Double, fractionDigits: Int = 1) -> String { // !!! NEW
        let value = convertedValue(fromKm: km)

        let f = Self.makeFormatter(fractionDigits: fractionDigits)
        let numberString = f.string(from: NSNumber(value: value))
            ?? String(format: "%.\(fractionDigits)f", value)

        return "\(numberString) \(label)"
    }

    /// Formatiert einen km-Wert (Base Unit) nur als Zahl (ohne Einheit) – für Charts/Achsen/Bar-Annotations.
    func formattedNumber(fromKm km: Double, fractionDigits: Int = 0) -> String { // !!! NEW
        let value = convertedValue(fromKm: km)

        let f = Self.makeFormatter(fractionDigits: fractionDigits)
        return f.string(from: NSNumber(value: value))
            ?? String(format: "%.\(fractionDigits)f", value)
    }

    /// Für UI-Detailstrings (z.B. Workout) mit adaptiven Nachkommastellen (ohne "m").
    func formattedAdaptive(fromKm km: Double) -> String {           // !!! NEW
        let absKm = abs(km)
        let digits: Int = (absKm < 1.0) ? 2 : 1
        return formatted(fromKm: km, fractionDigits: digits)
    }
}

// MARK: - WeightUnit – zentrale Umrechnung & Formatierung

extension WeightUnit {

    // MARK: Constants

    private static let lbsPerKg: Double = 2.2046226218

    // MARK: NumberFormatter (zentral)

    private static func makeFormatter(fractionDigits: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = fractionDigits
        f.maximumFractionDigits = fractionDigits
        return f
    }

    // MARK: Conversion

    /// Wandelt einen kg-Wert (Base Unit) in die gewünschte Anzeigeeinheit um.
    /// - Wichtig: Base bleibt immer kg (Double). Hier wird NUR für Anzeige umgerechnet.
    func convertedValue(fromKg kg: Double) -> Double {
        switch self {
        case .kg:
            return kg
        case .lbs:
            return kg * Self.lbsPerKg
        }
    }

    // MARK: Formatting

    /// Formatiert einen kg-Wert (Base Unit) als String inkl. Einheit.
    /// - fractionDigits: z.B. 0 (Charts/Axis) oder 1 (KPIs/Labels)
    func formatted(fromKg kg: Double, fractionDigits: Int = 1) -> String {
        let value = convertedValue(fromKg: kg)

        let f = Self.makeFormatter(fractionDigits: fractionDigits)
        let numberString = f.string(from: NSNumber(value: value))
            ?? String(format: "%.\(fractionDigits)f", value)

        return "\(numberString) \(label)"
    }

    /// Formatiert einen kg-Wert (Base Unit) nur als Zahl (ohne Einheit) – für Charts/Achsen/Bar-Annotations.
    func formattedNumber(fromKg kg: Double, fractionDigits: Int = 0) -> String {
        let value = convertedValue(fromKg: kg)

        let f = Self.makeFormatter(fractionDigits: fractionDigits)
        return f.string(from: NSNumber(value: value))
            ?? String(format: "%.\(fractionDigits)f", value)
    }
}
