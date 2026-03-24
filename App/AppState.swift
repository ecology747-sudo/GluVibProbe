//
//  AppState.swift
//  GluVibProbe
//
//  App-wide Navigation + Metric Routing (SSoT UI state)
//  - Maps metric names (strings) to StatsScreen routes.
//  - Applies gating rules (free lead metrics vs. premium-locked metrics).
//  - Central entry point for metric taps (Views never route ad-hoc).
//

import SwiftUI
import Combine
import OSLog

@MainActor
final class AppState: ObservableObject {

    // ============================================================
    // MARK: - Stats Screens (Routing Targets)
    // ============================================================

    enum StatsScreen {

        case none

        // Nutrition
        case nutritionOverview
        case carbs
        case carbsDayparts
        case sugar
        case protein
        case fat
        case calories

        // Activity
        case steps
        case activityEnergy
        case activityExerciseMinutes
        case movementSplit
        case moveTime
        case workoutMinutes

        // Body
        case weight
        case sleep
        case bmi
        case bodyFat
        case restingHeartRate

        // Metabolic (V1)
        case metabolicOverview
        case bolus
        case basal
        case bolusBasalRatio
        case carbsBolusRatio

        case timeInRange
        case gmi
        case range

        case SD
        case CV

        case ig
    }

    // ============================================================
    // MARK: - Metric Visibility Lists (Chip Sources)
    // ============================================================

    static let activityVisibleMetrics: [String] = [ // 🟨 UPDATED
        L10n.Steps.title,
        L10n.WorkoutMinutes.title,
        L10n.ActivityEnergy.title,
        L10n.MovementSplit.title
    ]

    static let nutritionVisibleMetrics: [String] = [
        L10n.Carbs.title,
        L10n.CarbsDayparts.title,
        L10n.Sugar.title,
        L10n.Protein.title,
        L10n.Fat.title,
        L10n.NutritionEnergy.title
    ]

    static let bodyVisibleMetrics: [String] = [
        L10n.Weight.title,
        L10n.Sleep.title,
        L10n.BMI.title,
        L10n.BodyFat.title,
        L10n.RestingHeartRate.title
    ]

    static let metabolicVisibleMetrics: [String] = [
        L10n.Bolus.title,
        L10n.Basal.title,
        L10n.BolusBasalRatio.title,
        L10n.CarbsBolusRatio.title,
        L10n.TimeInRange.title,
        L10n.IG.title,
        L10n.GMI.title,
        L10n.SD.title,
        L10n.CV.title,
        L10n.Range.title
    ]

    // ============================================================
    // MARK: - Metric Name Normalization
    // ============================================================

    private static func normalizedMetricName(_ rawName: String) -> String {
        rawName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }

    // ============================================================
    // MARK: - Gating Helpers
    // ============================================================

    static func isLeadFree(screen: StatsScreen) -> Bool {
        switch screen {
        case .steps,
             .weight,
             .carbs,
             .carbsDayparts,
             .sugar,
             .protein,
             .calories:
            return true
        default:
            return false
        }
    }

    static func isMetabolic(screen: StatsScreen) -> Bool {
        switch screen {
        case .metabolicOverview,
             .bolus, .basal, .bolusBasalRatio, .carbsBolusRatio,
             .timeInRange, .ig, .gmi, .SD, .CV, .range:
            return true
        default:
            return false
        }
    }

    static func isUnlocked(screen: StatsScreen, settings: SettingsModel) -> Bool {

        if isLeadFree(screen: screen) { return true }

        switch screen {
        case .nutritionOverview:
            return true
        default:
            break
        }

        if isMetabolic(screen: screen) {
            return settings.hasMetabolicPremiumEffective
        }

        return settings.hasMetabolicPremiumEffective
    }

    // ============================================================
    // MARK: - Metric Name → Screen Mapping
    // ============================================================

    static func statsScreen(forMetricName rawName: String) -> StatsScreen? {
        let name = normalizedMetricName(rawName)

        switch name {

        case L10n.Carbs.title:             return .carbs
        case L10n.CarbsDayparts.title:     return .carbsDayparts
        case L10n.Sugar.title:             return .sugar
        case L10n.Protein.title:           return .protein
        case L10n.Fat.title:               return .fat
        case L10n.NutritionEnergy.title:   return .calories

        case L10n.Steps.title, "Steps":                    return .steps // 🟨 UPDATED
        case L10n.WorkoutMinutes.title, "Workout Minutes": return .workoutMinutes // 🟨 UPDATED
        case L10n.ActivityEnergy.title, "Activity Energy", "Active Energy":
            return .activityEnergy // 🟨 UPDATED
        case L10n.MovementSplit.title, "Movement Split":   return .movementSplit // 🟨 UPDATED
        case "Exercise Minutes":                           return .activityExerciseMinutes
        case "Move Time":                                  return .moveTime

        case L10n.Weight.title:            return .weight
        case L10n.Sleep.title:             return .sleep
        case L10n.BMI.title:               return .bmi
        case L10n.BodyFat.title:           return .bodyFat
        case L10n.RestingHeartRate.title:  return .restingHeartRate

        case L10n.Bolus.title:            return .bolus
        case L10n.Basal.title:            return .basal
        case L10n.BolusBasalRatio.title:  return .bolusBasalRatio
        case L10n.CarbsBolusRatio.title:  return .carbsBolusRatio
        case L10n.TimeInRange.title:      return .timeInRange
        case L10n.IG.title:               return .ig
        case L10n.GMI.title:              return .gmi
        case L10n.SD.title:               return .SD
        case L10n.CV.title:               return .CV
        case L10n.Range.title:            return .range

        default:
            return nil
        }
    }

    static func isUnlocked(metricName: String, settings: SettingsModel) -> Bool {
        guard let screen = statsScreen(forMetricName: metricName) else { return false }
        return isUnlocked(screen: screen, settings: settings)
    }

    // ============================================================
    // MARK: - Tap Handling (Central Gate)
    // ============================================================

    func handleMetricTap(metricName: String, settings: SettingsModel) {
        guard let screen = Self.statsScreen(forMetricName: metricName) else {
            GluLog.routing.error("Metric tap unresolved | metric=\(metricName, privacy: .public)")
            openAccountRoute(.manage)
            return
        }

        if Self.isUnlocked(screen: screen, settings: settings) {
            GluLog.routing.notice(
                "Metric tap allowed | metric=\(metricName, privacy: .public) screen=\(String(describing: screen), privacy: .public)"
            )
            currentStatsScreen = screen
        } else {
            GluLog.routing.notice(
                "Metric tap blocked by gating | metric=\(metricName, privacy: .public) screen=\(String(describing: screen), privacy: .public)"
            )
            openAccountRoute(.manage)
        }
    }

    // ============================================================
    // MARK: - Post-Gating Enforcement
    // ============================================================

    func enforceAccessAfterPremiumChange(settings: SettingsModel) {
        guard !Self.isUnlocked(screen: currentStatsScreen, settings: settings) else { return }

        let previousScreen = currentStatsScreen

        switch currentStatsScreen {

        case .activityEnergy, .activityExerciseMinutes, .movementSplit, .moveTime, .workoutMinutes:
            currentStatsScreen = .steps

        case .sleep, .bmi, .bodyFat, .restingHeartRate:
            currentStatsScreen = .weight

        case .carbsDayparts, .sugar, .protein, .fat, .calories:
            currentStatsScreen = .carbs

        case .metabolicOverview,
             .bolus, .basal, .bolusBasalRatio, .carbsBolusRatio,
             .timeInRange, .ig, .gmi, .SD, .CV, .range:
            currentStatsScreen = .none

        default:
            currentStatsScreen = .none
        }

        GluLog.routing.notice(
            "Access enforcement applied | from=\(String(describing: previousScreen), privacy: .public) to=\(String(describing: self.currentStatsScreen), privacy: .public)"
        )
    }

    // ============================================================
    // MARK: - Metabolic Visible Metrics (dynamic)
    // ============================================================

    static func metabolicScreen(for metric: String) -> StatsScreen? {
        switch metric {
        case L10n.Bolus.title:            return .bolus
        case L10n.Basal.title:            return .basal
        case L10n.BolusBasalRatio.title:  return .bolusBasalRatio
        case L10n.CarbsBolusRatio.title:  return .carbsBolusRatio
        case L10n.TimeInRange.title:      return .timeInRange
        case L10n.IG.title:               return .ig
        case L10n.GMI.title:              return .gmi
        case L10n.Range.title:            return .range
        case L10n.SD.title:               return .SD
        case L10n.CV.title:               return .CV
        default:                          return nil
        }
    }

    @Published var currentStatsScreen: StatsScreen = .none
    @Published var isMetabolicReportPresented: Bool = false

    @Published var requestedTab: GluTab? = nil
    @Published var settingsStartDomain: SettingsDomain = .units

    @Published var isAccountSheetPresented: Bool = false
    @Published var isSettingsSheetPresented: Bool = false
    @Published var pendingSettingsStartDomain: SettingsDomain? = nil

    // ============================================================
    // MARK: - Account Sheet Routing
    // ============================================================

    enum AccountRoute: Hashable {
        case help
        case manage
        case faq
        case appInfo
        case legal

        case settingsMenu
        case targetsThresholdsMenu

        case targetsMetabolic
        case targetsActivity
        case targetsBody
        case targetsNutrition

        case units
        case healthKitPermissions
    }

    @Published var pendingAccountRoute: AccountRoute? = nil

    func presentAccountSheet() {
        GluLog.routing.debug("Account sheet presented")
        isAccountSheetPresented = true
    }

    func requestOpenSettings(startDomain: SettingsDomain) {
        GluLog.routing.notice(
            "Settings requested | startDomain=\(String(describing: startDomain), privacy: .public)"
        )
        settingsStartDomain = startDomain
        pendingSettingsStartDomain = startDomain
        isAccountSheetPresented = false
    }

    func openAccountRoute(_ route: AccountRoute) {
        GluLog.routing.notice(
            "Account route opened | route=\(String(describing: route), privacy: .public)"
        )
        pendingAccountRoute = route
        isAccountSheetPresented = true
    }

    static func metabolicVisibleMetrics(settings: SettingsModel) -> [String] {

        guard settings.hasMetabolicPremiumEffective else { return [] }

        var out: [String] = [
            L10n.TimeInRange.title,
            L10n.IG.title,
            L10n.GMI.title,
            L10n.SD.title,
            L10n.CV.title,
            L10n.Range.title
        ]

        if settings.hasCGM, settings.isInsulinTreated {
            out.insert(contentsOf: [
                L10n.Bolus.title,
                L10n.Basal.title,
                L10n.BolusBasalRatio.title,
                L10n.CarbsBolusRatio.title
            ], at: 0)
        }

        return out
    }
}
