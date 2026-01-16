// ============================================================
// MARK: - SettingsModel.swift  // !!! UPDATED (Metabolic Premium Capability)
// ============================================================

import Foundation
import Combine

final class SettingsModel: ObservableObject {

    static let shared = SettingsModel()

    @Published var hasUnsavedChanges: Bool = false

    func markUnsavedChanges() { hasUnsavedChanges = true }
    func clearUnsavedChanges() { hasUnsavedChanges = false }

    // MARK: - Published Values

    @Published var dailyStepGoal: Int = 10_000

    @Published var dailySleepGoalMinutes: Int = 8 * 60
    @Published var targetWeightKg: Int = 75

    // MARK: Units
    @Published var weightUnit: WeightUnit = .kg
    @Published var distanceUnit: DistanceUnit = .kilometers
    @Published var glucoseUnit: GlucoseUnit = .mgdL

    // MARK: Metabolic Targets
    @Published var glucoseMin: Int = 70
    @Published var glucoseMax: Int = 180
    @Published var veryLowLimit: Int = 55
    @Published var veryHighLimit: Int = 250

    // TIR Target (%)
    @Published var tirTargetPercent: Int = 70

    // CV Target (%)
    @Published var cvTargetPercent: Int = 36                      // !!! NEW

    // GMI90 Target (%) — stored as Double
    @Published var gmi90TargetPercent: Double = 7.0               // !!! NEW

    // MARK: Nutrition Targets
    @Published var dailyCarbs: Int = 200
    @Published var dailyProtein: Int = 80
    @Published var dailyCalories: Int = 2500
    @Published var dailyFat: Int = 70

    // MARK: Metabolic Feature Flags (User intent)
    @Published var isInsulinTreated: Bool = false
    @Published var hasCGM: Bool = false

    // ============================================================
    // MARK: - Capability Flag (Free vs Premium gating)
    // ============================================================
    @Published var hasMetabolicPremium: Bool = false                 // !!! NEW

    @Published var hba1cEntries: [HbA1cEntry] = []

    var latestHbA1cEntry: HbA1cEntry? { hba1cEntries.max(by: { $0.date < $1.date }) }
    var latestHbA1cValuePercent: Double? { latestHbA1cEntry?.valuePercent }

    private let defaults = UserDefaults.standard

    private enum Keys {

        static let dailyStepGoal          = "settings_dailyStepGoal"
        static let dailySleepGoalMinutes  = "settings_dailySleepGoalMinutes"
        static let targetWeightKg         = "settings_targetWeightKg"

        static let weightUnit    = "settings_weightUnit"
        static let distanceUnit  = "settings_distanceUnit"
        static let glucoseUnit   = "settings_glucoseUnit"

        static let glucoseMin    = "settings_glucoseMin"
        static let glucoseMax    = "settings_glucoseMax"
        static let veryLowLimit  = "settings_veryLowLimit"
        static let veryHighLimit = "settings_veryHighLimit"

        static let tirTargetPercent = "settings_tirTargetPercent"

        // CV + GMI Targets
        static let cvTargetPercent        = "settings_cvTargetPercent"        // !!! NEW
        static let gmi90TargetPercent     = "settings_gmi90TargetPercent"     // !!! NEW

        static let dailyCarbs    = "settings_dailyCarbs"
        static let dailyProtein  = "settings_dailyProtein"
        static let dailyCalories = "settings_dailyCalories"
        static let dailyFat      = "settings_dailyFat"

        static let isInsulinTreated = "settings_isInsulinTreated"
        static let hasCGM           = "settings_hasCGM"

        static let hba1cEntries     = "settings_hba1cEntries"

        static let hasMetabolicPremium = "settings_hasMetabolicPremium"       // !!! NEW
    }

    private init() {
        loadFromDefaults()
        clearUnsavedChanges()
    }

    func loadFromDefaults() {

        if defaults.object(forKey: Keys.dailyStepGoal) != nil {
            dailyStepGoal = defaults.integer(forKey: Keys.dailyStepGoal)
        }

        if defaults.object(forKey: Keys.dailySleepGoalMinutes) != nil {
            dailySleepGoalMinutes = defaults.integer(forKey: Keys.dailySleepGoalMinutes)
        }
        if defaults.object(forKey: Keys.targetWeightKg) != nil {
            targetWeightKg = defaults.integer(forKey: Keys.targetWeightKg)
        }

        if let raw = defaults.string(forKey: Keys.weightUnit), let v = WeightUnit(rawValue: raw) {
            weightUnit = v
        }
        if let raw = defaults.string(forKey: Keys.distanceUnit), let v = DistanceUnit(rawValue: raw) {
            distanceUnit = v
        }
        if let raw = defaults.string(forKey: Keys.glucoseUnit), let v = GlucoseUnit(rawValue: raw) {
            glucoseUnit = v
        }

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

        if defaults.object(forKey: Keys.tirTargetPercent) != nil {
            tirTargetPercent = defaults.integer(forKey: Keys.tirTargetPercent)
        }

        // CV + GMI Targets
        if defaults.object(forKey: Keys.cvTargetPercent) != nil {              // !!! NEW
            cvTargetPercent = defaults.integer(forKey: Keys.cvTargetPercent)   // !!! NEW
        }
        if defaults.object(forKey: Keys.gmi90TargetPercent) != nil {           // !!! NEW
            gmi90TargetPercent = defaults.double(forKey: Keys.gmi90TargetPercent) // !!! NEW
        }

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

        if defaults.object(forKey: Keys.isInsulinTreated) != nil {
            isInsulinTreated = defaults.bool(forKey: Keys.isInsulinTreated)
        }
        if defaults.object(forKey: Keys.hasCGM) != nil {
            hasCGM = defaults.bool(forKey: Keys.hasCGM)
        }

        if defaults.object(forKey: Keys.hasMetabolicPremium) != nil {
            hasMetabolicPremium = defaults.bool(forKey: Keys.hasMetabolicPremium)
        }

        if let data = defaults.data(forKey: Keys.hba1cEntries),
           let decoded = try? JSONDecoder().decode([HbA1cEntry].self, from: data) {
            hba1cEntries = decoded
        }
    }

    func saveToDefaults() {

        defaults.set(dailyStepGoal, forKey: Keys.dailyStepGoal)
        defaults.set(dailySleepGoalMinutes, forKey: Keys.dailySleepGoalMinutes)
        defaults.set(targetWeightKg, forKey: Keys.targetWeightKg)

        defaults.set(weightUnit.rawValue, forKey: Keys.weightUnit)
        defaults.set(distanceUnit.rawValue, forKey: Keys.distanceUnit)
        defaults.set(glucoseUnit.rawValue, forKey: Keys.glucoseUnit)

        defaults.set(glucoseMin, forKey: Keys.glucoseMin)
        defaults.set(glucoseMax, forKey: Keys.glucoseMax)
        defaults.set(veryLowLimit, forKey: Keys.veryLowLimit)
        defaults.set(veryHighLimit, forKey: Keys.veryHighLimit)

        defaults.set(tirTargetPercent, forKey: Keys.tirTargetPercent)

        // CV + GMI Targets
        defaults.set(cvTargetPercent, forKey: Keys.cvTargetPercent)                 // !!! NEW
        defaults.set(gmi90TargetPercent, forKey: Keys.gmi90TargetPercent)           // !!! NEW

        defaults.set(dailyCarbs, forKey: Keys.dailyCarbs)
        defaults.set(dailyProtein, forKey: Keys.dailyProtein)
        defaults.set(dailyCalories, forKey: Keys.dailyCalories)
        defaults.set(dailyFat, forKey: Keys.dailyFat)

        defaults.set(isInsulinTreated, forKey: Keys.isInsulinTreated)
        defaults.set(hasCGM, forKey: Keys.hasCGM)

        defaults.set(hasMetabolicPremium, forKey: Keys.hasMetabolicPremium)

        if let encoded = try? JSONEncoder().encode(hba1cEntries) {
            defaults.set(encoded, forKey: Keys.hba1cEntries)
        }

        clearUnsavedChanges()
    }
}
