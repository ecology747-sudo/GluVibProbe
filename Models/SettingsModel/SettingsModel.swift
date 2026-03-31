//
//  SettingsModel.swift
//  GluVib
//
//  Area: App / Shared Settings
//  File Role:
//  - Central persistent settings model for GluVib user preferences and app-local flags.
//  - Stores display settings, targets, onboarding progress, metabolic user intent,
//    and a temporary migration bridge for legacy monetization state.
//
//  Purpose:
//  - Keep normal app settings and user-controlled preferences in one place.
//  - Persist onboarding and settings values via UserDefaults.
//  - Support the current monetization migration without letting SettingsModel
//    remain the long-term source of truth for premium / trial / free.
//
//  Monetization Rule:
//  - The dedicated monetization layer now owns the central commercial truth.
//  - This file keeps only temporary legacy bridge values that still exist
//    for the current transition phase.
//  - New premium / trial / free decisions should move toward EntitlementManager
//    and CapabilityResolver instead of being created here.
//
//  Key Connections:
//  - EntitlementManager (new central monetization truth)
//  - legacy premium bridge during migration
//  - user intent flags:
//    - hasCGM
//    - isInsulinTreated
//

import Foundation
import Combine

final class SettingsModel: ObservableObject {

    // ============================================================
    // MARK: - Shared Instance
    // ============================================================

    static let shared = SettingsModel()

    // ============================================================
    // MARK: - Unsaved State
    // ============================================================

    @Published var hasUnsavedChanges: Bool = false

    func markUnsavedChanges() { hasUnsavedChanges = true }
    func clearUnsavedChanges() { hasUnsavedChanges = false }

    // ============================================================
    // MARK: - Internal Loading Guard
    // ============================================================

    private var isLoadingFromDefaults: Bool = false

    // ============================================================
    // MARK: - Daily Goals
    // ============================================================

    @Published var dailyStepGoal: Int = 10_000
    @Published var dailySleepGoalMinutes: Int = 8 * 60
    @Published var targetWeightKg: Int = 75

    // ============================================================
    // MARK: - Units
    // ============================================================

    @Published var weightUnit: WeightUnit = .kg
    @Published var distanceUnit: DistanceUnit = .kilometers
    @Published var glucoseUnit: GlucoseUnit = .mgdL

    // ============================================================
    // MARK: - Metabolic Targets
    // ============================================================

    @Published var glucoseMin: Int = 70
    @Published var glucoseMax: Int = 180
    @Published var veryLowLimit: Int = 55
    @Published var veryHighLimit: Int = 250

    @Published var tirTargetPercent: Int = 70
    @Published var cvTargetPercent: Int = 36
    @Published var gmi90TargetPercent: Double = 7.0

    // ============================================================
    // MARK: - Nutrition Targets
    // ============================================================

    @Published var dailyCarbs: Int = 200
    @Published var dailySugar: Int = 50
    @Published var dailyProtein: Int = 80
    @Published var dailyCalories: Int = 2500
    @Published var dailyFat: Int = 70

    // ============================================================
    // MARK: - Global UI Controls
    // ============================================================

    @Published var showPermissionWarnings: Bool = true {
        didSet {
            guard !isLoadingFromDefaults else { return }
            saveToDefaults()
        }
    }

    @Published var debugSimulateNoHealthData: Bool = false {
        didSet {
            guard !isLoadingFromDefaults else { return }
            saveToDefaults()
        }
    }

    // ============================================================
    // MARK: - Main Chart Overlay Toggles
    // ============================================================

    @Published var mainChartShowActivity: Bool = true {
        didSet {
            guard !isLoadingFromDefaults else { return }
            saveToDefaults()
        }
    }

    @Published var mainChartShowCarbs: Bool = true {
        didSet {
            guard !isLoadingFromDefaults else { return }
            saveToDefaults()
        }
    }

    @Published var mainChartShowProtein: Bool = true {
        didSet {
            guard !isLoadingFromDefaults else { return }
            saveToDefaults()
        }
    }

    @Published var mainChartShowBolus: Bool = true {
        didSet {
            guard !isLoadingFromDefaults else { return }
            saveToDefaults()
        }
    }

    @Published var mainChartShowBasal: Bool = true {
        didSet {
            guard !isLoadingFromDefaults else { return }
            saveToDefaults()
        }
    }

    @Published var mainChartShowCGM: Bool = true {
        didSet {
            guard !isLoadingFromDefaults else { return }
            saveToDefaults()
        }
    }

    // ============================================================
    // MARK: - History Metric Picker Toggles
    // ============================================================

    @Published var historyShowActivity: Bool = true {
        didSet {
            guard !isLoadingFromDefaults else { return }
            saveToDefaults()
        }
    }

    @Published var historyShowCarbs: Bool = true {
        didSet {
            guard !isLoadingFromDefaults else { return }
            saveToDefaults()
        }
    }

    @Published var historyShowWeight: Bool = true {
        didSet {
            guard !isLoadingFromDefaults else { return }
            saveToDefaults()
        }
    }

    @Published var historyShowBolus: Bool = true {
        didSet {
            guard !isLoadingFromDefaults else { return }
            saveToDefaults()
        }
    }

    @Published var historyShowBasal: Bool = true {
        didSet {
            guard !isLoadingFromDefaults else { return }
            saveToDefaults()
        }
    }

    @Published var historyShowCGM: Bool = true {
        didSet {
            guard !isLoadingFromDefaults else { return }
            saveToDefaults()
        }
    }

    // ============================================================
    // MARK: - Onboarding / Installation Flags
    // ============================================================

    @Published var hasAcceptedDisclaimer: Bool = false
    @Published var hasSeenHealthPermissionGate: Bool = false
    @Published var hasCompletedOnboarding: Bool = false

    // ============================================================
    // MARK: - Legacy Monetization Bridge
    // ============================================================
    // 🟨 UPDATED
    // Transitional only:
    // - kept to support the current migration phase
    // - not intended to remain the long-term monetization truth
    // - EntitlementManager should become the authoritative source

    @Published var isPremiumEnabled: Bool = false {
        didSet {
            if hasMetabolicPremium != isPremiumEnabled {
                hasMetabolicPremium = isPremiumEnabled
            }
        }
    }

    @Published var hasMetabolicPremium: Bool = false {
        didSet {
            if isPremiumEnabled != hasMetabolicPremium {
                isPremiumEnabled = hasMetabolicPremium
            }
        }
    }

    @Published var trialStartDate: Date? = nil

    private let trialLengthDays: Int = 30

    var isTrialActive: Bool {
        guard isPremiumEnabled == false else { return false }
        guard let start = trialStartDate else { return false }
        guard let end = Calendar.current.date(byAdding: .day, value: trialLengthDays, to: start) else {
            return false
        }
        return Date() < end
    }

    var trialDaysRemaining: Int? {
        guard isPremiumEnabled == false else { return nil }
        guard let start = trialStartDate else { return nil }
        guard let end = Calendar.current.date(byAdding: .day, value: trialLengthDays, to: start) else {
            return nil
        }

        let calendar = Calendar.current
        let from = calendar.startOfDay(for: Date())
        let to = calendar.startOfDay(for: end)
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        return max(0, days)
    }

    var hasMetabolicPremiumEffective: Bool {
        isPremiumEnabled || isTrialActive
    }

    enum AccessStatus: Equatable {
        case premiumPurchased
        case trial(daysLeft: Int)
        case free
    }

    var accessStatus: AccessStatus {
        if isPremiumEnabled { return .premiumPurchased }
        if let days = trialDaysRemaining, isTrialActive { return .trial(daysLeft: days) }
        return .free
    }

    func ensureTrialStartedIfEligible() {
        guard hasCompletedOnboarding else { return }
        guard isPremiumEnabled == false else { return }
        guard trialStartDate == nil else { return }

        trialStartDate = Date()
        saveToDefaults()
    }

    // ============================================================
    // MARK: - Metabolic User Intent
    // ============================================================

    @Published var hasCGM: Bool = false
    @Published var isInsulinTreated: Bool = false

    // ============================================================
    // MARK: - Priming Filters
    // ============================================================

    @Published var excludeBolusPriming: Bool = false
    @Published var bolusPrimingThresholdU: Double = 1.0

    @Published var excludeBasalPriming: Bool = false
    @Published var basalPrimingThresholdU: Double = 1.0

    // ============================================================
    // MARK: - HbA1c Manual Entries
    // ============================================================

    @Published var hba1cEntries: [HbA1cEntry] = []

    var latestHbA1cEntry: HbA1cEntry? {
        hba1cEntries.max(by: { $0.date < $1.date })
    }

    var latestHbA1cValuePercent: Double? {
        latestHbA1cEntry?.valuePercent
    }

    // ============================================================
    // MARK: - Persistence
    // ============================================================

    private let defaults = UserDefaults.standard

    private enum Keys {

        static let dailyStepGoal = "settings_dailyStepGoal"
        static let dailySleepGoalMinutes = "settings_dailySleepGoalMinutes"
        static let targetWeightKg = "settings_targetWeightKg"

        static let weightUnit = "settings_weightUnit"
        static let distanceUnit = "settings_distanceUnit"
        static let glucoseUnit = "settings_glucoseUnit"

        static let glucoseMin = "settings_glucoseMin"
        static let glucoseMax = "settings_glucoseMax"
        static let veryLowLimit = "settings_veryLowLimit"
        static let veryHighLimit = "settings_veryHighLimit"

        static let tirTargetPercent = "settings_tirTargetPercent"
        static let cvTargetPercent = "settings_cvTargetPercent"
        static let gmi90TargetPercent = "settings_gmi90TargetPercent"

        static let dailyCarbs = "settings_dailyCarbs"
        static let dailySugar = "settings_dailySugar"
        static let dailyProtein = "settings_dailyProtein"
        static let dailyCalories = "settings_dailyCalories"
        static let dailyFat = "settings_dailyFat"

        static let isInsulinTreated = "settings_isInsulinTreated"
        static let hasCGM = "settings_hasCGM"

        static let hba1cEntries = "settings_hba1cEntries"

        static let isPremiumEnabled = "settings_isPremiumEnabled"
        static let hasMetabolicPremium = "settings_hasMetabolicPremium"
        static let trialStartDate = "settings_trialStartDate"

        static let excludeBolusPriming = "settings_excludeBolusPriming"
        static let bolusPrimingThresholdU = "settings_bolusPrimingThresholdU"
        static let excludeBasalPriming = "settings_excludeBasalPriming"
        static let basalPrimingThresholdU = "settings_basalPrimingThresholdU"

        static let hasAcceptedDisclaimer = "settings_hasAcceptedDisclaimer"
        static let hasSeenHealthPermissionGate = "settings_hasSeenHealthPermissionGate"
        static let hasCompletedOnboarding = "settings_hasCompletedOnboarding"

        static let showPermissionWarnings = "settings_showPermissionWarnings"
        static let debugSimulateNoHealthData = "settings_debugSimulateNoHealthData"

        static let mainChartShowActivity = "settings_mainChartShowActivity"
        static let mainChartShowCarbs = "settings_mainChartShowCarbs"
        static let mainChartShowProtein = "settings_mainChartShowProtein"
        static let mainChartShowBolus = "settings_mainChartShowBolus"
        static let mainChartShowBasal = "settings_mainChartShowBasal"
        static let mainChartShowCGM = "settings_mainChartShowCGM"

        static let historyShowActivity = "settings_historyShowActivity"
        static let historyShowCarbs = "settings_historyShowCarbs"
        static let historyShowWeight = "settings_historyShowWeight"
        static let historyShowBolus = "settings_historyShowBolus"
        static let historyShowBasal = "settings_historyShowBasal"
        static let historyShowCGM = "settings_historyShowCGM"
    }

    // ============================================================
    // MARK: - Priming Threshold Helpers
    // ============================================================

    private static let primingThresholdOptions: [Double] = [0.5, 1.0, 1.5]

    private func normalizedPrimingThreshold(_ value: Double) -> Double {
        guard value > 0 else { return 1.0 }
        let options = Self.primingThresholdOptions
        let nearest = options.min(by: { abs($0 - value) < abs($1 - value) }) ?? 1.0
        return nearest
    }

    // ============================================================
    // MARK: - Init
    // ============================================================

    private init() {
        loadFromDefaults()
        clearUnsavedChanges()
    }

    // ============================================================
    // MARK: - Load
    // ============================================================

    func loadFromDefaults() {

        isLoadingFromDefaults = true
        defer { isLoadingFromDefaults = false }

        if defaults.object(forKey: Keys.dailyStepGoal) != nil {
            dailyStepGoal = defaults.integer(forKey: Keys.dailyStepGoal)
        }

        if defaults.object(forKey: Keys.dailySleepGoalMinutes) != nil {
            dailySleepGoalMinutes = defaults.integer(forKey: Keys.dailySleepGoalMinutes)
        }

        if defaults.object(forKey: Keys.targetWeightKg) != nil {
            targetWeightKg = defaults.integer(forKey: Keys.targetWeightKg)
        }

        if let raw = defaults.string(forKey: Keys.weightUnit),
           let value = WeightUnit(rawValue: raw) {
            weightUnit = value
        }

        if let raw = defaults.string(forKey: Keys.distanceUnit),
           let value = DistanceUnit(rawValue: raw) {
            distanceUnit = value
        }

        if let raw = defaults.string(forKey: Keys.glucoseUnit),
           let value = GlucoseUnit(rawValue: raw) {
            glucoseUnit = value
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

        if defaults.object(forKey: Keys.cvTargetPercent) != nil {
            cvTargetPercent = defaults.integer(forKey: Keys.cvTargetPercent)
        }

        if defaults.object(forKey: Keys.gmi90TargetPercent) != nil {
            gmi90TargetPercent = defaults.double(forKey: Keys.gmi90TargetPercent)
        }

        if defaults.object(forKey: Keys.dailyCarbs) != nil {
            dailyCarbs = defaults.integer(forKey: Keys.dailyCarbs)
        }

        if defaults.object(forKey: Keys.dailySugar) != nil {
            dailySugar = defaults.integer(forKey: Keys.dailySugar)
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

        if defaults.object(forKey: Keys.isPremiumEnabled) != nil {
            isPremiumEnabled = defaults.bool(forKey: Keys.isPremiumEnabled)
            hasMetabolicPremium = isPremiumEnabled
        } else if defaults.object(forKey: Keys.hasMetabolicPremium) != nil {
            let legacyValue = defaults.bool(forKey: Keys.hasMetabolicPremium)
            hasMetabolicPremium = legacyValue
            isPremiumEnabled = legacyValue
        }

        if let ts = defaults.object(forKey: Keys.trialStartDate) as? TimeInterval {
            trialStartDate = Date(timeIntervalSince1970: ts)
        }

        if defaults.object(forKey: Keys.excludeBolusPriming) != nil {
            excludeBolusPriming = defaults.bool(forKey: Keys.excludeBolusPriming)
        }

        if defaults.object(forKey: Keys.bolusPrimingThresholdU) != nil {
            bolusPrimingThresholdU = normalizedPrimingThreshold(
                defaults.double(forKey: Keys.bolusPrimingThresholdU)
            )
        }

        if defaults.object(forKey: Keys.excludeBasalPriming) != nil {
            excludeBasalPriming = defaults.bool(forKey: Keys.excludeBasalPriming)
        }

        if defaults.object(forKey: Keys.basalPrimingThresholdU) != nil {
            basalPrimingThresholdU = normalizedPrimingThreshold(
                defaults.double(forKey: Keys.basalPrimingThresholdU)
            )
        }

        if let data = defaults.data(forKey: Keys.hba1cEntries),
           let decoded = try? JSONDecoder().decode([HbA1cEntry].self, from: data) {
            hba1cEntries = decoded
        }

        if defaults.object(forKey: Keys.hasAcceptedDisclaimer) != nil {
            hasAcceptedDisclaimer = defaults.bool(forKey: Keys.hasAcceptedDisclaimer)
        }

        if defaults.object(forKey: Keys.hasSeenHealthPermissionGate) != nil {
            hasSeenHealthPermissionGate = defaults.bool(forKey: Keys.hasSeenHealthPermissionGate)
        }

        if defaults.object(forKey: Keys.hasCompletedOnboarding) != nil {
            hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        }

        if defaults.object(forKey: Keys.showPermissionWarnings) != nil {
            showPermissionWarnings = defaults.bool(forKey: Keys.showPermissionWarnings)
        }

        if defaults.object(forKey: Keys.debugSimulateNoHealthData) != nil {
            debugSimulateNoHealthData = defaults.bool(forKey: Keys.debugSimulateNoHealthData)
        }

        if defaults.object(forKey: Keys.mainChartShowActivity) != nil {
            mainChartShowActivity = defaults.bool(forKey: Keys.mainChartShowActivity)
        }

        if defaults.object(forKey: Keys.mainChartShowCarbs) != nil {
            mainChartShowCarbs = defaults.bool(forKey: Keys.mainChartShowCarbs)
        }

        if defaults.object(forKey: Keys.mainChartShowProtein) != nil {
            mainChartShowProtein = defaults.bool(forKey: Keys.mainChartShowProtein)
        }

        if defaults.object(forKey: Keys.mainChartShowBolus) != nil {
            mainChartShowBolus = defaults.bool(forKey: Keys.mainChartShowBolus)
        }

        if defaults.object(forKey: Keys.mainChartShowBasal) != nil {
            mainChartShowBasal = defaults.bool(forKey: Keys.mainChartShowBasal)
        }

        if defaults.object(forKey: Keys.mainChartShowCGM) != nil {
            mainChartShowCGM = defaults.bool(forKey: Keys.mainChartShowCGM)
        }

        if defaults.object(forKey: Keys.historyShowActivity) != nil {
            historyShowActivity = defaults.bool(forKey: Keys.historyShowActivity)
        }

        if defaults.object(forKey: Keys.historyShowCarbs) != nil {
            historyShowCarbs = defaults.bool(forKey: Keys.historyShowCarbs)
        }

        if defaults.object(forKey: Keys.historyShowWeight) != nil {
            historyShowWeight = defaults.bool(forKey: Keys.historyShowWeight)
        }

        if defaults.object(forKey: Keys.historyShowBolus) != nil {
            historyShowBolus = defaults.bool(forKey: Keys.historyShowBolus)
        }

        if defaults.object(forKey: Keys.historyShowBasal) != nil {
            historyShowBasal = defaults.bool(forKey: Keys.historyShowBasal)
        }

        if defaults.object(forKey: Keys.historyShowCGM) != nil {
            historyShowCGM = defaults.bool(forKey: Keys.historyShowCGM)
        }
    }

    // ============================================================
    // MARK: - Save
    // ============================================================

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
        defaults.set(cvTargetPercent, forKey: Keys.cvTargetPercent)
        defaults.set(gmi90TargetPercent, forKey: Keys.gmi90TargetPercent)

        defaults.set(dailyCarbs, forKey: Keys.dailyCarbs)
        defaults.set(dailySugar, forKey: Keys.dailySugar)
        defaults.set(dailyProtein, forKey: Keys.dailyProtein)
        defaults.set(dailyCalories, forKey: Keys.dailyCalories)
        defaults.set(dailyFat, forKey: Keys.dailyFat)

        defaults.set(isInsulinTreated, forKey: Keys.isInsulinTreated)
        defaults.set(hasCGM, forKey: Keys.hasCGM)

        defaults.set(isPremiumEnabled, forKey: Keys.isPremiumEnabled)
        defaults.set(isPremiumEnabled, forKey: Keys.hasMetabolicPremium)
        hasMetabolicPremium = isPremiumEnabled

        defaults.set(excludeBolusPriming, forKey: Keys.excludeBolusPriming)
        defaults.set(bolusPrimingThresholdU, forKey: Keys.bolusPrimingThresholdU)
        defaults.set(excludeBasalPriming, forKey: Keys.excludeBasalPriming)
        defaults.set(basalPrimingThresholdU, forKey: Keys.basalPrimingThresholdU)

        if let encoded = try? JSONEncoder().encode(hba1cEntries) {
            defaults.set(encoded, forKey: Keys.hba1cEntries)
        }

        defaults.set(hasAcceptedDisclaimer, forKey: Keys.hasAcceptedDisclaimer)
        defaults.set(hasSeenHealthPermissionGate, forKey: Keys.hasSeenHealthPermissionGate)
        defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)

        if let start = trialStartDate {
            defaults.set(start.timeIntervalSince1970, forKey: Keys.trialStartDate)
        } else {
            defaults.removeObject(forKey: Keys.trialStartDate)
        }

        defaults.set(showPermissionWarnings, forKey: Keys.showPermissionWarnings)
        defaults.set(debugSimulateNoHealthData, forKey: Keys.debugSimulateNoHealthData)

        defaults.set(mainChartShowActivity, forKey: Keys.mainChartShowActivity)
        defaults.set(mainChartShowCarbs, forKey: Keys.mainChartShowCarbs)
        defaults.set(mainChartShowProtein, forKey: Keys.mainChartShowProtein)
        defaults.set(mainChartShowBolus, forKey: Keys.mainChartShowBolus)
        defaults.set(mainChartShowBasal, forKey: Keys.mainChartShowBasal)
        defaults.set(mainChartShowCGM, forKey: Keys.mainChartShowCGM)

        defaults.set(historyShowActivity, forKey: Keys.historyShowActivity)
        defaults.set(historyShowCarbs, forKey: Keys.historyShowCarbs)
        defaults.set(historyShowWeight, forKey: Keys.historyShowWeight)
        defaults.set(historyShowBolus, forKey: Keys.historyShowBolus)
        defaults.set(historyShowBasal, forKey: Keys.historyShowBasal)
        defaults.set(historyShowCGM, forKey: Keys.historyShowCGM)

        clearUnsavedChanges()
    }
}
