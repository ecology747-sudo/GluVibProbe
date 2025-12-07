//
//  BodyDashboardView.swift
//  GluVibProbe
//

import SwiftUI

/// Dashboard für die Body-Domain:
/// - Sleep
/// - Weight
/// - BMI
/// - Body Fat
/// - Resting Heart Rate
///
/// Steuert, welche Detail-View angezeigt wird, basierend auf appState.currentStatsScreen.
struct BodyDashboardView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    var body: some View {

        switch appState.currentStatsScreen {

        // -----------------------------------------------------
        // NEUE Fälle: gehören NICHT ins Body-Dashboard
        // (werden in anderen Dashboards ausgewertet)
        // -----------------------------------------------------
        case .none,
             .nutritionOverview,
             .carbs, .protein, .fat, .calories,
             .steps, .activityEnergy:
            EmptyView()   // Pflicht, damit der Switch exhaustiv wird

        // -----------------------------------------------------
        // 🟠 BODY-DOMAIN
        // -----------------------------------------------------
        case .sleep:
            SleepView(onMetricSelected: handleMetricSelection)

        case .weight:
            WeightView(onMetricSelected: handleMetricSelection)

        case .bmi:                                           // !!! NEW
            BMIView(onMetricSelected: handleMetricSelection) // !!! NEW

        case .bodyFat:                                       // !!! NEW
            BodyFatView(onMetricSelected: handleMetricSelection) // !!! NEW

        case .restingHeartRate:                              // !!! NEW
            RestingHeartRateView(onMetricSelected: handleMetricSelection) // !!! NEW
        }
    }

    // MARK: - Navigation durch Body-Metric-Chips

    private func handleMetricSelection(_ metric: String) {
        switch metric {
        case "Sleep":
            appState.currentStatsScreen = .sleep

        case "Weight":
            appState.currentStatsScreen = .weight

        case "BMI":                                          // !!! NEW
            appState.currentStatsScreen = .bmi               // !!! NEW

        case "Body Fat":                                     // !!! NEW
            appState.currentStatsScreen = .bodyFat           // !!! NEW

        case "Resting Heart Rate":                           // !!! NEW
            appState.currentStatsScreen = .restingHeartRate  // !!! NEW

        default:
            break
        }
    }
}

#Preview("BodyDashboardView") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()

    return BodyDashboardView()
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
