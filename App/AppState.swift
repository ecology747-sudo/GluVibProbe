//
//  AppState.swift
//  GluVib
//
//  Area: App / Navigation State
//  File Role:
//  - Central app-wide navigation and metric routing state.
//  - Maps localized metric titles to routing targets.
//  - Applies monetization-aware access checks before opening metric screens.
//
//  Purpose:
//  - Keep routing decisions out of individual Views.
//  - Prepare AppState for the new monetization capability layer.
//  - Maintain the current app flow while the migration is still in progress.
//
//  Current Transition Scope:
//  - AppState now understands the new monetization capability model.
//  - Legacy compatibility helpers are intentionally kept for the ongoing migration.
//  - Localized EN / DE metric titles are respected in routing and chip visibility.
//
//  Key Connections:
//  - EntitlementManager
//  - CapabilityResolver
//  - SettingsModel
//  - localized metric titles via L10n
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

        // Metabolic
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
    // MARK: - Published State
    // ============================================================

    @Published var currentStatsScreen: StatsScreen = .none
    @Published var isMetabolicReportPresented: Bool = false

    @Published var requestedTab: GluTab? = nil
    @Published var settingsStartDomain: SettingsDomain = .units

    @Published var isAccountSheetPresented: Bool = false
    @Published var isSettingsSheetPresented: Bool = false
    @Published var pendingSettingsStartDomain: SettingsDomain? = nil
    @Published var pendingAccountRoute: AccountRoute? = nil

    // ============================================================
    // MARK: - Internal Capability Resolver
    // ============================================================

    private static let capabilityResolver = CapabilityResolver()

    // ============================================================
    // MARK: - Metric Visibility Lists (Chip Sources)
    // ============================================================

    static let activityVisibleMetrics: [String] = [
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
    // MARK: - Metric Name → Screen Mapping
    // ============================================================

    static func statsScreen(forMetricName rawName: String) -> StatsScreen? {
        let name = normalizedMetricName(rawName)

        switch name {

        // Nutrition
        case L10n.Carbs.title:
            return .carbs
        case L10n.CarbsDayparts.title:
            return .carbsDayparts
        case L10n.Sugar.title:
            return .sugar
        case L10n.Protein.title:
            return .protein
        case L10n.Fat.title:
            return .fat
        case L10n.NutritionEnergy.title:
            return .calories

        // Activity
        case L10n.Steps.title, "Steps":
            return .steps
        case L10n.WorkoutMinutes.title, "Workout Minutes":
            return .workoutMinutes
        case L10n.ActivityEnergy.title, "Activity Energy", "Active Energy":
            return .activityEnergy
        case L10n.MovementSplit.title, "Movement Split":
            return .movementSplit
        case "Exercise Minutes":
            return .activityExerciseMinutes
        case "Move Time":
            return .moveTime

        // Body
        case L10n.Weight.title:
            return .weight
        case L10n.Sleep.title:
            return .sleep
        case L10n.BMI.title:
            return .bmi
        case L10n.BodyFat.title:
            return .bodyFat
        case L10n.RestingHeartRate.title:
            return .restingHeartRate

        // Metabolic
        case L10n.Bolus.title:
            return .bolus
        case L10n.Basal.title:
            return .basal
        case L10n.BolusBasalRatio.title:
            return .bolusBasalRatio
        case L10n.CarbsBolusRatio.title:
            return .carbsBolusRatio
        case L10n.TimeInRange.title:
            return .timeInRange
        case L10n.IG.title:
            return .ig
        case L10n.GMI.title:
            return .gmi
        case L10n.SD.title:
            return .SD
        case L10n.CV.title:
            return .CV
        case L10n.Range.title:
            return .range

        default:
            return nil
        }
    }

    static func metabolicScreen(for metric: String) -> StatsScreen? {
        switch metric {
        case L10n.Bolus.title:
            return .bolus
        case L10n.Basal.title:
            return .basal
        case L10n.BolusBasalRatio.title:
            return .bolusBasalRatio
        case L10n.CarbsBolusRatio.title:
            return .carbsBolusRatio
        case L10n.TimeInRange.title:
            return .timeInRange
        case L10n.IG.title:
            return .ig
        case L10n.GMI.title:
            return .gmi
        case L10n.Range.title:
            return .range
        case L10n.SD.title:
            return .SD
        case L10n.CV.title:
            return .CV
        default:
            return nil
        }
    }

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

    // ============================================================
    // MARK: - Monetization Mapping
    // ============================================================

    static func monetizationScreen(for statsScreen: StatsScreen) -> MonetizationScreen {
        switch statsScreen {
        case .none:
            return .none

        // Overviews
        case .nutritionOverview:
            return .nutritionOverview
        case .metabolicOverview:
            return .metabolicOverview

        // Nutrition
        case .carbs:
            return .carbs
        case .carbsDayparts:
            return .carbsDayparts
        case .sugar:
            return .sugar
        case .protein:
            return .protein
        case .fat:
            return .fat
        case .calories:
            return .calories

        // Activity
        case .steps:
            return .steps
        case .activityEnergy:
            return .activityEnergy
        case .activityExerciseMinutes:
            return .activityExerciseMinutes
        case .movementSplit:
            return .movementSplit
        case .moveTime:
            return .moveTime
        case .workoutMinutes:
            return .workoutMinutes

        // Body
        case .weight:
            return .weight
        case .sleep:
            return .sleep
        case .bmi:
            return .bmi
        case .bodyFat:
            return .bodyFat
        case .restingHeartRate:
            return .restingHeartRate

        // Metabolic
        case .bolus:
            return .bolus
        case .basal:
            return .basal
        case .bolusBasalRatio:
            return .bolusBasalRatio
        case .carbsBolusRatio:
            return .carbsBolusRatio
        case .timeInRange:
            return .timeInRange
        case .gmi:
            return .gmi
        case .range:
            return .range
        case .SD:
            return .SD
        case .CV:
            return .CV
        case .ig:
            return .ig
        }
    }

    // ============================================================
    // MARK: - Capability Set Builders
    // ============================================================

    static func capabilitySet(entitlementManager: EntitlementManager) -> AppCapabilitySet {
        let context = MonetizationCapabilityContext(
            entitlementStatus: entitlementManager.entitlementStatus
        )
        return capabilityResolver.makeCapabilitySet(context: context)
    }

    /// Transitional legacy bridge for still-migrating call sites.
    ///
    /// This method mirrors the new entitlement language from the current legacy
    /// SettingsModel state so AppState can already consume the capability layer
    /// before all callers are switched to EntitlementManager.
    static func capabilitySet(settings: SettingsModel) -> AppCapabilitySet {
        let entitlementStatus: EntitlementStatus

        if settings.isPremiumEnabled {
            entitlementStatus = .premium(plan: .unknown)
        } else if settings.isTrialActive {
            entitlementStatus = .trial(daysRemaining: settings.trialDaysRemaining ?? 0)
        } else {
            entitlementStatus = .free
        }

        let context = MonetizationCapabilityContext(
            entitlementStatus: entitlementStatus
        )
        return capabilityResolver.makeCapabilitySet(context: context)
    }

    // ============================================================
    // MARK: - Access Checks
    // ============================================================

    static func accessDecision(
        for screen: StatsScreen,
        entitlementManager: EntitlementManager
    ) -> AccessDecision {
        let capabilities = capabilitySet(entitlementManager: entitlementManager)
        let monetizationScreen = monetizationScreen(for: screen)
        return capabilityResolver.accessDecision(
            for: monetizationScreen,
            capabilities: capabilities
        )
    }

    static func isUnlocked(
        screen: StatsScreen,
        entitlementManager: EntitlementManager
    ) -> Bool {
        let capabilities = capabilitySet(entitlementManager: entitlementManager)
        let monetizationScreen = monetizationScreen(for: screen)
        return capabilityResolver.canOpen(
            screen: monetizationScreen,
            capabilities: capabilities
        )
    }

    static func isUnlocked(
        metricName: String,
        entitlementManager: EntitlementManager
    ) -> Bool {
        guard let screen = statsScreen(forMetricName: metricName) else { return false }
        return isUnlocked(screen: screen, entitlementManager: entitlementManager)
    }

    // ============================================================
    // MARK: - Legacy Access Checks (Transition Bridge)
    // ============================================================

    static func accessDecision(
        for screen: StatsScreen,
        settings: SettingsModel
    ) -> AccessDecision {
        let capabilities = capabilitySet(settings: settings)
        let monetizationScreen = monetizationScreen(for: screen)
        return capabilityResolver.accessDecision(
            for: monetizationScreen,
            capabilities: capabilities
        )
    }

    static func isUnlocked(
        screen: StatsScreen,
        settings: SettingsModel
    ) -> Bool {
        let capabilities = capabilitySet(settings: settings)
        let monetizationScreen = monetizationScreen(for: screen)
        return capabilityResolver.canOpen(
            screen: monetizationScreen,
            capabilities: capabilities
        )
    }

    static func isUnlocked(
        metricName: String,
        settings: SettingsModel
    ) -> Bool {
        guard let screen = statsScreen(forMetricName: metricName) else { return false }
        return isUnlocked(screen: screen, settings: settings)
    }

    // ============================================================
    // MARK: - Tap Handling (Capability-Aware)
    // ============================================================

    func handleMetricTap(
        metricName: String,
        settings: SettingsModel,
        entitlementManager: EntitlementManager
    ) {
        guard let screen = Self.statsScreen(forMetricName: metricName) else {
            GluLog.routing.error("Metric tap unresolved | metric=\(metricName, privacy: .public)")
            openAccountRoute(.manage)
            return
        }

        if Self.isUnlocked(screen: screen, entitlementManager: entitlementManager) {
            GluLog.routing.notice(
                "Metric tap allowed | metric=\(metricName, privacy: .public) screen=\(String(describing: screen), privacy: .public)"
            )
            currentStatsScreen = screen
        } else {
            GluLog.routing.notice(
                "Metric tap blocked by monetization | metric=\(metricName, privacy: .public) screen=\(String(describing: screen), privacy: .public)"
            )
            openAccountRoute(.manage)
        }
    }

    /// Transitional overload for call sites not yet migrated to EntitlementManager.
    func handleMetricTap(metricName: String, settings: SettingsModel) {
        guard let screen = Self.statsScreen(forMetricName: metricName) else {
            GluLog.routing.error("Metric tap unresolved | metric=\(metricName, privacy: .public)")
            openAccountRoute(.manage)
            return
        }

        if Self.isUnlocked(screen: screen, settings: settings) {
            GluLog.routing.notice(
                "Metric tap allowed (legacy bridge) | metric=\(metricName, privacy: .public) screen=\(String(describing: screen), privacy: .public)"
            )
            currentStatsScreen = screen
        } else {
            GluLog.routing.notice(
                "Metric tap blocked by monetization (legacy bridge) | metric=\(metricName, privacy: .public) screen=\(String(describing: screen), privacy: .public)"
            )
            openAccountRoute(.manage)
        }
    }

    // ============================================================
    // MARK: - Post-Gating Enforcement
    // ============================================================

    func enforceAccessAfterPremiumChange(
        settings: SettingsModel,
        entitlementManager: EntitlementManager
    ) {
        guard !Self.isUnlocked(screen: currentStatsScreen, entitlementManager: entitlementManager) else { return }

        let previousScreen = currentStatsScreen

        switch currentStatsScreen {

        case .activityEnergy,
             .activityExerciseMinutes,
             .movementSplit,
             .moveTime,
             .workoutMinutes:
            currentStatsScreen = .steps

        case .sleep,
             .bmi,
             .bodyFat,
             .restingHeartRate:
            currentStatsScreen = .weight

        case .carbsDayparts,
             .sugar,
             .protein,
             .fat,
             .calories:
            currentStatsScreen = .carbs

        case .metabolicOverview,
             .bolus,
             .basal,
             .bolusBasalRatio,
             .carbsBolusRatio,
             .timeInRange,
             .ig,
             .gmi,
             .SD,
             .CV,
             .range:
            currentStatsScreen = .none

        default:
            currentStatsScreen = .none
        }

        GluLog.routing.notice(
            "Access enforcement applied | from=\(String(describing: previousScreen), privacy: .public) to=\(String(describing: self.currentStatsScreen), privacy: .public)"
        )
    }

    /// Transitional overload for call sites not yet migrated to EntitlementManager.
    func enforceAccessAfterPremiumChange(settings: SettingsModel) {
        guard !Self.isUnlocked(screen: currentStatsScreen, settings: settings) else { return }

        let previousScreen = currentStatsScreen

        switch currentStatsScreen {

        case .activityEnergy,
             .activityExerciseMinutes,
             .movementSplit,
             .moveTime,
             .workoutMinutes:
            currentStatsScreen = .steps

        case .sleep,
             .bmi,
             .bodyFat,
             .restingHeartRate:
            currentStatsScreen = .weight

        case .carbsDayparts,
             .sugar,
             .protein,
             .fat,
             .calories:
            currentStatsScreen = .carbs

        case .metabolicOverview,
             .bolus,
             .basal,
             .bolusBasalRatio,
             .carbsBolusRatio,
             .timeInRange,
             .ig,
             .gmi,
             .SD,
             .CV,
             .range:
            currentStatsScreen = .none

        default:
            currentStatsScreen = .none
        }

        GluLog.routing.notice(
            "Access enforcement applied (legacy bridge) | from=\(String(describing: previousScreen), privacy: .public) to=\(String(describing: self.currentStatsScreen), privacy: .public)"
        )
    }

    // ============================================================
    // MARK: - Account / Settings Navigation
    // ============================================================

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

    // ============================================================
    // MARK: - Metabolic Visible Metrics
    // ============================================================

    static func metabolicVisibleMetrics(
        settings: SettingsModel,
        entitlementManager: EntitlementManager
    ) -> [String] {
        let capabilities = capabilitySet(entitlementManager: entitlementManager)

        let screens = capabilityResolver.visibleMetabolicMetrics(
            capabilities: capabilities,
            hasCGM: settings.hasCGM,
            isInsulinTreated: settings.isInsulinTreated
        )

        return screens.compactMap { localizedMetricTitle(for: $0) }
    }

    /// Transitional overload for call sites not yet migrated to EntitlementManager.
    static func metabolicVisibleMetrics(settings: SettingsModel) -> [String] {
        let capabilities = capabilitySet(settings: settings)

        let screens = capabilityResolver.visibleMetabolicMetrics(
            capabilities: capabilities,
            hasCGM: settings.hasCGM,
            isInsulinTreated: settings.isInsulinTreated
        )

        return screens.compactMap { localizedMetricTitle(for: $0) }
    }

    // ============================================================
    // MARK: - Localized Metric Titles
    // ============================================================

    private static func localizedMetricTitle(for screen: MonetizationScreen) -> String? {
        switch screen {
        case .bolus:
            return L10n.Bolus.title
        case .basal:
            return L10n.Basal.title
        case .bolusBasalRatio:
            return L10n.BolusBasalRatio.title
        case .carbsBolusRatio:
            return L10n.CarbsBolusRatio.title
        case .timeInRange:
            return L10n.TimeInRange.title
        case .ig:
            return L10n.IG.title
        case .gmi:
            return L10n.GMI.title
        case .SD:
            return L10n.SD.title
        case .CV:
            return L10n.CV.title
        case .range:
            return L10n.Range.title
        default:
            return nil
        }
    }
}
