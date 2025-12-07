//
//  ActivityDashboardView.swift
//  GluVibProbe
//

import SwiftUI

/// Dashboard für die Activity-Domain:
/// - Steps
/// - Activity Energy
///
/// Sleep & Weight gehören zur Body-Domain und werden hier nicht dargestellt.
struct ActivityDashboardView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    var body: some View {

        switch appState.currentStatsScreen {

        // -----------------------------------------------------
        // NEUE FÄLLE → gehören NICHT ins Activity-Dashboard
        // -----------------------------------------------------
        case .none,
             .nutritionOverview:
            EmptyView()     // Fallback, damit Switch vollständig ist

        // -----------------------------------------------------
        // Activity Screens
        // -----------------------------------------------------
        case .steps:
            StepsView(onMetricSelected: handleMetricSelection)

        case .activityEnergy:
            ActivityEnergyView(onMetricSelected: handleMetricSelection)

        // -----------------------------------------------------
        // Nutrition-Screens → im Activity-Dashboard wegparken
        // (sollten hier nicht vorkommen)
        // -----------------------------------------------------
        case .carbs, .protein, .fat, .calories:
            StepsView(onMetricSelected: handleMetricSelection)

        // -----------------------------------------------------
        // Body-Screens → ebenfalls wegparken
        // -----------------------------------------------------
        case .sleep,
             .weight,
             .bmi,                // ✅ NEW
             .bodyFat,            // ✅ NEW
             .restingHeartRate:   // ✅ NEW
            StepsView(onMetricSelected: handleMetricSelection)
        }
    }

    // MARK: - Navigation durch Metric Chips

    private func handleMetricSelection(_ metric: String) {
        switch metric {
        case "Steps":
            appState.currentStatsScreen = .steps

        case "Activity Energy":
            appState.currentStatsScreen = .activityEnergy

        case "Weight":
            appState.currentStatsScreen = .weight

        case "Sleep":
            appState.currentStatsScreen = .sleep

        default:
            break
        }
    }
}

#Preview("ActivityDashboardView") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()

    return ActivityDashboardView()
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
