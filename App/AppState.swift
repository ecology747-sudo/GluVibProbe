//
//  AppState.swift
//  GluVibProbe
//

import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {

    enum StatsScreen {

        case none

        // Nutrition
        case nutritionOverview
        case carbs
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

    static let activityVisibleMetrics: [String] = [
        "Steps",
        "Workout Minutes",
        "Activity Energy",
        "Movement Split"
    ]

    static let nutritionVisibleMetrics: [String] = [
        "Carbs",
        "Protein",
        "Fat",
        "Calories"
    ]

    static let bodyVisibleMetrics: [String] = [
        "Weight",
        "Sleep",
        "BMI",
        "Body Fat",
        "Resting Heart Rate"
    ]

    static let metabolicVisibleMetrics: [String] = [
        "Bolus",
        "Basal",
        "Bolus/Basal",
        "Carbs/Bolus",
        "TIR",
        "IG",
        "GMI",
        "SD",
        "CV",
        "Range"
    ]

    // ============================================================
    // MARK: - Metric Routing (Central)
    // ============================================================

    static func metabolicScreen(for metric: String) -> StatsScreen? {
        switch metric {
        case "Bolus":        return .bolus
        case "Basal":        return .basal
        case "Bolus/Basal":  return .bolusBasalRatio
        case "Carbs/Bolus":  return .carbsBolusRatio
        case "TIR":          return .timeInRange
        case "IG":           return .ig
        case "GMI":          return .gmi
        case "Range":        return .range
        case "SD":           return .SD
        case "CV":           return .CV
        default:             return nil
        }
    }

    @Published var currentStatsScreen: StatsScreen = .none

    // ============================================================
    // MARK: - Global Tab Routing
    // ============================================================

    /// One-shot request: some view can ask the root to switch the bottom tab.
    @Published var requestedTab: GluTab? = nil

    /// Settings deep-link start domain (used by ContentView when showing SettingsView).
    @Published var settingsStartDomain: SettingsDomain = .units

    // ============================================================
    // MARK: - Global Sheets (Account + Settings)
    // ============================================================

    @Published var isAccountSheetPresented: Bool = false
    @Published var isSettingsSheetPresented: Bool = false

    /// Pending intent: open Settings after Account sheet has fully dismissed.
    /// This prevents SwiftUI "double sheet in same tick" conflicts.
    @Published var pendingSettingsStartDomain: SettingsDomain? = nil

    // ============================================================
    // MARK: - Account Sheet Deep Links
    // ============================================================

    // UPDATED
    enum AccountRoute: Hashable {
        case help
        case manage
        case faq
        case appInfo
        case legal
    }

    // UPDATED: one-shot in-sheet route request (handled by AccountSheetRootView)
    @Published var pendingAccountRoute: AccountRoute? = nil

    func presentAccountSheet() {
        isAccountSheetPresented = true
    }

    func requestOpenSettings(startDomain: SettingsDomain) {
        settingsStartDomain = startDomain
        pendingSettingsStartDomain = startDomain
        isAccountSheetPresented = false
    }

    // UPDATED: open Account Sheet + push destination inside sheet
    func openAccountRoute(_ route: AccountRoute) {
        pendingAccountRoute = route
        isAccountSheetPresented = true
    }

    // ============================================================
    // MARK: - Metabolic Metrics (Settings-gated)
    // ============================================================

    static func metabolicVisibleMetrics(settings: SettingsModel) -> [String] {

        var out: [String] = [
            "TIR",
            "IG",
            "GMI",
            "SD",
            "CV",
            "Range"
        ]

        if settings.hasCGM, settings.isInsulinTreated {
            out.insert(contentsOf: [
                "Bolus",
                "Basal",
                "Bolus/Basal",
                "Carbs/Bolus"
            ], at: 0)
        }

        return out
    }
}
