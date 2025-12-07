//
//  SettingsModel.swift
//  GluVibProbe
//
//  Zentrales Modell für alle Einstellungen & Zielwerte der App.
//  Inkl. HbA1c-Liste (Metabolic Domain)
//

import Foundation
import Combine

final class SettingsModel: ObservableObject {

    // Singleton
    static let shared = SettingsModel()

    // MARK: - Unsaved Changes Flag
    @Published var hasUnsavedChanges: Bool = false

    func markUnsavedChanges() {
        hasUnsavedChanges = true
    }

    func clearUnsavedChanges() {
        hasUnsavedChanges = false
    }

    // MARK: - Published Values

    @Published var dailyStepGoal: Int = 10_000
    @Published var dailySleepGoalMinutes: Int = 8 * 60

    // MARK: Personal
    @Published var gender: String = "Male"
    @Published var birthDate: Date = Date()
    @Published var heightCm: Int = 170
    @Published var weightKg: Int = 75
    @Published var targetWeightKg: Int = 75

    // MARK: Units
    @Published var weightUnit: WeightUnit = .kg
    @Published var heightUnit: HeightUnit = .cm
    @Published var energyUnit: EnergyUnit = .kcal
    @Published var distanceUnit: DistanceUnit = .kilometers
    @Published var glucoseUnit: GlucoseUnit = .mgdL

    // MARK: Metabolic Targets
    @Published var glucoseMin: Int = 70
    @Published var glucoseMax: Int = 180
    @Published var veryLowLimit: Int = 55
    @Published var veryHighLimit: Int = 250

    // MARK: Nutrition Targets
    @Published var dailyCarbs: Int = 200
    @Published var dailyProtein: Int = 80
    @Published var dailyCalories: Int = 2500
    @Published var dailyFat: Int = 70

    // ---------------------------------------------------------------
    // MARK: - NEW HBA1C ENTRIES (Metabolic Domain)
    // ---------------------------------------------------------------
    @Published var hba1cEntries: [HbA1cEntry] = []   // NEW
    // Immer der aktuellste HbA1c-Wert (nach Datum)
    var latestHbA1cEntry: HbA1cEntry? {
        hba1cEntries.max(by: { $0.date < $1.date })
    }

    /// Nur der Prozentwert des neuesten Eintrags (z.B. 6.7)
    var latestHbA1cValuePercent: Double? {
        latestHbA1cEntry?.valuePercent
    }

    // ---------------------------------------------------------------

    private let defaults = UserDefaults.standard

    // MARK: - UserDefaults Keys
    private enum Keys {
        // Steps
        static let dailyStepGoal          = "settings_dailyStepGoal"
        static let dailySleepGoalMinutes  = "settings_dailySleepGoalMinutes"

        // Personal
        static let gender         = "settings_gender"
        static let birthDate      = "settings_birthDate"
        static let heightCm       = "settings_heightCm"
        static let weightKg       = "settings_weightKg"
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

        // -----------------------------------------------------------
        // MARK: - NEW KEY FOR HBA1C STORAGE
        // -----------------------------------------------------------
        static let hba1cEntries  = "settings_hba1cEntries"   // NEW
    }

    // MARK: - Init
    private init() {
        loadFromDefaults()
        clearUnsavedChanges()
    }

    // MARK: - Load
    func loadFromDefaults() {

        // Steps / Sleep
        if defaults.object(forKey: Keys.dailyStepGoal) != nil {
            dailyStepGoal = defaults.integer(forKey: Keys.dailyStepGoal)
        }
        if defaults.object(forKey: Keys.dailySleepGoalMinutes) != nil {
            dailySleepGoalMinutes = defaults.integer(forKey: Keys.dailySleepGoalMinutes)
        }

        // Personal
        if let genderValue = defaults.string(forKey: Keys.gender) {
            gender = genderValue
        }
        if defaults.object(forKey: Keys.birthDate) != nil {
            birthDate = Date(timeIntervalSince1970: defaults.double(forKey: Keys.birthDate))
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

        // Units
        if let raw = defaults.string(forKey: Keys.weightUnit), let v = WeightUnit(rawValue: raw) {
            weightUnit = v
        }
        if let raw = defaults.string(forKey: Keys.heightUnit), let v = HeightUnit(rawValue: raw) {
            heightUnit = v
        }
        if let raw = defaults.string(forKey: Keys.energyUnit), let v = EnergyUnit(rawValue: raw) {
            energyUnit = v
        }
        if let raw = defaults.string(forKey: Keys.distanceUnit), let v = DistanceUnit(rawValue: raw) {
            distanceUnit = v
        }
        if let raw = defaults.string(forKey: Keys.glucoseUnit), let v = GlucoseUnit(rawValue: raw) {
            glucoseUnit = v
        }

        // Metabolic
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

        // -----------------------------------------------------------
        // MARK: - NEW HBA1C LOAD LOGIC
        // -----------------------------------------------------------
        if let data = defaults.data(forKey: Keys.hba1cEntries) {
            if let decoded = try? JSONDecoder().decode([HbA1cEntry].self, from: data) {
                hba1cEntries = decoded
            }
        }
    }

    // MARK: - Save
    func saveToDefaults() {

        // Steps / Sleep
        defaults.set(dailyStepGoal,          forKey: Keys.dailyStepGoal)
        defaults.set(dailySleepGoalMinutes,  forKey: Keys.dailySleepGoalMinutes)

        // Personal
        defaults.set(gender, forKey: Keys.gender)
        defaults.set(birthDate.timeIntervalSince1970, forKey: Keys.birthDate)
        defaults.set(heightCm,       forKey: Keys.heightCm)
        defaults.set(weightKg,       forKey: Keys.weightKg)
        defaults.set(targetWeightKg, forKey: Keys.targetWeightKg)

        // Units
        defaults.set(weightUnit.rawValue,   forKey: Keys.weightUnit)
        defaults.set(heightUnit.rawValue,   forKey: Keys.heightUnit)
        defaults.set(energyUnit.rawValue,   forKey: Keys.energyUnit)
        defaults.set(distanceUnit.rawValue, forKey: Keys.distanceUnit)
        defaults.set(glucoseUnit.rawValue,  forKey: Keys.glucoseUnit)

        // Metabolic
        defaults.set(glucoseMin,    forKey: Keys.glucoseMin)
        defaults.set(glucoseMax,    forKey: Keys.glucoseMax)
        defaults.set(veryLowLimit,  forKey: Keys.veryLowLimit)
        defaults.set(veryHighLimit, forKey: Keys.veryHighLimit)

        // Nutrition
        defaults.set(dailyCarbs,    forKey: Keys.dailyCarbs)
        defaults.set(dailyProtein,  forKey: Keys.dailyProtein)
        defaults.set(dailyCalories, forKey: Keys.dailyCalories)
        defaults.set(dailyFat,      forKey: Keys.dailyFat)

        // -----------------------------------------------------------
        // MARK: - NEW HBA1C SAVE LOGIC
        // -----------------------------------------------------------
        if let encoded = try? JSONEncoder().encode(hba1cEntries) {
            defaults.set(encoded, forKey: Keys.hba1cEntries)
        }

        clearUnsavedChanges()
    }
}
