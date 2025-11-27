//
//  SettingsModel.swift
//  GluVibProbe
//

import Foundation
import Combine   // wichtig für @Published & ObservableObject

/// Zentrales Modell für alle Einstellungen & Zielwerte der App.
final class SettingsModel: ObservableObject {

    // Singleton für einfachen Zugriff im Projekt
    static let shared = SettingsModel()

    // MARK: - Published Values

    /// Tagesziel für Schritte
    @Published var dailyStepGoal: Int = 10_000
    
    // MARK: - Personal Settings

    @Published var gender: String = "Male"
    @Published var birthDate: Date = Date()
    @Published var heightCm: Int = 170
    @Published var weightKg: Int = 75
    @Published var targetWeightKg: Int = 75

    // MARK: - Units

    @Published var weightUnit: WeightUnit = .kg
    @Published var heightUnit: HeightUnit = .cm
    @Published var energyUnit: EnergyUnit = .kcal
    @Published var distanceUnit: DistanceUnit = .kilometers
    // glucoseUnit hast du ja schon oben bei Metabolic
    
    // MARK: - Metabolic Targets

    @Published var glucoseMin: Int = 70
    @Published var glucoseMax: Int = 180
    @Published var veryLowLimit: Int = 55
    @Published var veryHighLimit: Int = 250
    @Published var glucoseUnit: GlucoseUnit = .mgdL
    
    // MARK: - Nutrition Targets

    @Published var dailyCarbs: Int = 200       // g
    @Published var dailyProtein: Int = 80     // g
    @Published var dailyCalories: Int = 2500  // kcal
    @Published var dailyFat: Int = 70         // g


    // MARK: - Persistenz (UserDefaults)

    /// Zugriff auf UserDefaults
    private let defaults = UserDefaults.standard

    /// Alle Schlüssel, unter denen wir Einstellungen speichern
    private enum Keys {

        // Steps
        static let dailyStepGoal = "settings_dailyStepGoal"

        // Personal
        static let gender        = "settings_gender"
        static let birthDate     = "settings_birthDate"
        static let heightCm      = "settings_heightCm"
        static let weightKg      = "settings_weightKg"
        static let targetWeightKg = "settings_targetWeightKg"

        // Units
        static let weightUnit    = "settings_weightUnit"
        static let heightUnit    = "settings_heightUnit"
        static let energyUnit    = "settings_energyUnit"
        static let distanceUnit  = "settings_distanceUnit"
        static let glucoseUnit   = "settings_glucoseUnit"

        // Metabolic
        static let glucoseMin    = "settings_glucoseMin"
        static let glucoseMax    = "settings_glucoseMax"
        static let veryLowLimit  = "settings_veryLowLimit"
        static let veryHighLimit = "settings_veryHighLimit"

        // Nutrition
        static let dailyCarbs    = "settings_dailyCarbs"
        static let dailyProtein  = "settings_dailyProtein"
        static let dailyCalories = "settings_dailyCalories"
        static let dailyFat      = "settings_dailyFat"
    }


    // MARK: - Init

    private init() {
        loadFromDefaults()   // ⬅️ Beim Start Werte aus UserDefaults laden
    }


    // MARK: - Load-Funktion

    /// Lädt gespeicherte Werte aus UserDefaults.
    /// Wird beim App-Start im init() ausgeführt.
    func loadFromDefaults() {

        // Schrittziel laden, falls vorhanden
                if defaults.object(forKey: Keys.dailyStepGoal) != nil {
                    self.dailyStepGoal = defaults.integer(forKey: Keys.dailyStepGoal)
                }
        
        
        // MARK: Personal
        if let genderValue = defaults.string(forKey: Keys.gender) {
            gender = genderValue
        }

        if defaults.object(forKey: Keys.birthDate) != nil {
            let time = defaults.double(forKey: Keys.birthDate)
            birthDate = Date(timeIntervalSince1970: time)
        }

        if defaults.object(forKey: Keys.heightCm) != nil {
            heightCm = defaults.integer(forKey: Keys.heightCm)
        }

        if defaults.object(forKey: Keys.weightKg) != nil {
            weightKg = defaults.integer(forKey: Keys.weightKg)
        }

        if defaults.object(forKey: Keys.targetWeightKg) != nil {
            targetWeightKg = defaults.integer(forKey: Keys.targetWeightKg)
        }
        
        // MARK: Units
        if let weightUnitRaw = defaults.string(forKey: Keys.weightUnit),
           let unit = WeightUnit(rawValue: weightUnitRaw) {
            weightUnit = unit
        }

        if let heightUnitRaw = defaults.string(forKey: Keys.heightUnit),
           let unit = HeightUnit(rawValue: heightUnitRaw) {
            heightUnit = unit
        }

        if let energyUnitRaw = defaults.string(forKey: Keys.energyUnit),
           let unit = EnergyUnit(rawValue: energyUnitRaw) {
            energyUnit = unit
        }

        if let distanceUnitRaw = defaults.string(forKey: Keys.distanceUnit),
           let unit = DistanceUnit(rawValue: distanceUnitRaw) {
            distanceUnit = unit
        }

        if let glucoseUnitRaw = defaults.string(forKey: Keys.glucoseUnit),
           let unit = GlucoseUnit(rawValue: glucoseUnitRaw) {
            glucoseUnit = unit
        }
        
        // MARK: Metabolic

                if defaults.object(forKey: Keys.glucoseMin) != nil {
                    glucoseMin = defaults.integer(forKey: Keys.glucoseMin)
                }

                if defaults.object(forKey: Keys.glucoseMax) != nil {
                    glucoseMax = defaults.integer(forKey: Keys.glucoseMax)
                }

                if defaults.object(forKey: Keys.veryLowLimit) != nil {
                    veryLowLimit = defaults.integer(forKey: Keys.veryLowLimit)
                }

                if defaults.object(forKey: Keys.veryHighLimit) != nil {
                    veryHighLimit = defaults.integer(forKey: Keys.veryHighLimit)
                }

                if let unitRaw = defaults.string(forKey: Keys.glucoseUnit),
                   let unit = GlucoseUnit(rawValue: unitRaw) {
                    glucoseUnit = unit
                }
        
        // Nutrition
                if defaults.object(forKey: Keys.dailyCarbs) != nil {
                    dailyCarbs = defaults.integer(forKey: Keys.dailyCarbs)
                }
                if defaults.object(forKey: Keys.dailyProtein) != nil {
                    dailyProtein = defaults.integer(forKey: Keys.dailyProtein)
                }
                if defaults.object(forKey: Keys.dailyCalories) != nil {
                    dailyCalories = defaults.integer(forKey: Keys.dailyCalories)
                }
                if defaults.object(forKey: Keys.dailyFat) != nil {
                    dailyFat = defaults.integer(forKey: Keys.dailyFat)
                }

        // weitere Werte kommen hier später hinzu
        // if defaults.object(forKey: Keys.dailyCarbGoal) != nil {
        //     self.dailyCarbGoal = defaults.integer(forKey: Keys.dailyCarbGoal)
        // }
    }


    // MARK: - Save-Funktion

    /// Speichert alle relevanten Settings-Werte in UserDefaults.
    /// Wird später vom Save-Button in der SettingsView aufgerufen.
    func saveToDefaults() {

        // MARK: Steps
        defaults.set(dailyStepGoal, forKey: Keys.dailyStepGoal)

        // MARK: Personal
        defaults.set(gender, forKey: Keys.gender)
        defaults.set(birthDate.timeIntervalSince1970, forKey: Keys.birthDate)
        defaults.set(heightCm, forKey: Keys.heightCm)
        defaults.set(weightKg, forKey: Keys.weightKg)
        defaults.set(targetWeightKg, forKey: Keys.targetWeightKg)

        // MARK: Units
        defaults.set(weightUnit.rawValue,   forKey: Keys.weightUnit)
        defaults.set(heightUnit.rawValue,   forKey: Keys.heightUnit)
        defaults.set(energyUnit.rawValue,   forKey: Keys.energyUnit)
        defaults.set(distanceUnit.rawValue, forKey: Keys.distanceUnit)
        defaults.set(glucoseUnit.rawValue,  forKey: Keys.glucoseUnit)

        // MARK: Metabolic
        defaults.set(glucoseMin,    forKey: Keys.glucoseMin)
        defaults.set(glucoseMax,    forKey: Keys.glucoseMax)
        defaults.set(veryLowLimit,  forKey: Keys.veryLowLimit)
        defaults.set(veryHighLimit, forKey: Keys.veryHighLimit)

        // MARK: Nutrition
        defaults.set(dailyCarbs,    forKey: Keys.dailyCarbs)
        defaults.set(dailyProtein,  forKey: Keys.dailyProtein)
        defaults.set(dailyCalories, forKey: Keys.dailyCalories)
        defaults.set(dailyFat,      forKey: Keys.dailyFat)
    }
}
