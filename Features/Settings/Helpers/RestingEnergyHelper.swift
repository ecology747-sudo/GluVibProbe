//
//  RestingEnergyHelper.swift
//  GluVibProbe
//
//  Dynamische Berechnung der Resting Energy (BMR)
//  – basiert auf SettingsModel + optional Tagesgewicht
//

import Foundation

/// Vereinfachtes biologisches Geschlecht für die BMR-Berechnung.
enum RestingEnergySex {
    case male
    case female
    case other
}

struct RestingEnergyHelper {

    // MARK: - Public API
    ///
    /// Berechnet die Resting Energy (BMR) nach Mifflin–St Jeor.
    ///
    /// Gewicht-Priorität:
    ///   1) weightOverrideKg = effektives Gewicht der Body-Domain
    ///      (HealthKit letzte Messung oder Settings-Fallback)
    ///   2) settings.weightKg (nur wenn kein override)
    ///
    /// Die Resting Energy wird IMMER berechnet – es gibt keine manuelle Eingabe mehr.
    ///
    /// - Parameters:
    ///   - settings: SettingsModel Singleton
    ///   - weightOverrideKg: optionales Tagesgewicht (z. B. aus WeightViewModel)
    ///   - referenceDate: Datum für die Altersberechnung (Standard: heute)
    /// - Returns: BMR in kcal/Tag
    static func restingEnergyFromSettings(
        _ settings: SettingsModel,
        weightOverrideKg: Double? = nil,
        referenceDate: Date = Date()
    ) -> Double {

        // 1) Effektives Gewicht bestimmen – override hat immer Priorität
        let usedWeightKgRaw = weightOverrideKg ?? Double(settings.weightKg)
        let usedWeightKg = max(usedWeightKgRaw, 0.0)

        // 2) Größe (cm)
        let heightCm = max(Double(settings.heightCm), 0.0)

        // 3) Alter in Jahren (falls negative Eingaben → 0)
        let ageYearsRaw = age(from: settings.birthDate, referenceDate: referenceDate)
        let ageYears = max(ageYearsRaw, 0)

        // 4) Geschlecht aus Settings mappen
        let sex = sex(fromGender: settings.gender)

        // 5) Endgültige Berechnung mit Mifflin–St Jeor
        return calculateBMRMifflinStJeor(
            weightKg: usedWeightKg,
            heightCm: heightCm,
            ageYears: ageYears,
            sex: sex
        )
    }


    // MARK: - Mifflin–St Jeor Formel
    ///
    /// BMR = 10 * Gewicht(kg)
    ///     + 6.25 * Größe(cm)
    ///     - 5 * Alter(Jahre)
    ///     + Geschlechtsfaktor
    ///
    /// Faktor:
    ///   Male:   +5
    ///   Female: -161
    ///   Other:  Mittelwert
    ///
    static func calculateBMRMifflinStJeor(
        weightKg: Double,
        heightCm: Double,
        ageYears: Int,
        sex: RestingEnergySex
    ) -> Double {

        let base =
            10.0 * weightKg +
            6.25 * heightCm -
            5.0 * Double(ageYears)

        let sexOffset: Double
        switch sex {
        case .male:
            sexOffset = 5.0
        case .female:
            sexOffset = -161.0
        case .other:
            sexOffset = (5.0 - 161.0) / 2.0   // neutraler Mittelwert
        }

        return base + sexOffset
    }


    // MARK: - Helper-Funktionen

    /// Mappt SettingsModel.gender (String) auf unser internes Enum.
    static func sex(fromGender gender: String) -> RestingEnergySex {
        let lower = gender.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) Female zuerst eindeutig abfangen
        if lower == "female" || lower == "f" {
            return .female
        }

        // 2) Male eindeutig abfangen
        if lower == "male" || lower == "m" {
            return .male
        }

        // 3) Rest → "other"
        return .other
    }

    /// Berechnet Alter in Jahren aus einem Geburtsdatum.
    static func age(from birthDate: Date, referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let comp = calendar.dateComponents([.year], from: birthDate, to: referenceDate)
        return comp.year ?? 0
    }
}
