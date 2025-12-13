//
//  BodyDashboardView.swift
//  GluVibProbe
//

import SwiftUI

struct BodyDashboardView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    var body: some View {

        switch appState.currentStatsScreen {

        // 🔸 Alle nicht-Body-Fälle → hier nur wegparken
        case .none,
             .nutritionOverview,
             .carbs, .protein, .fat, .calories,
             .steps, .activityEnergy, .movementSplit,
             .activityExerciseMinutes:                      // !!! NEW
            EmptyView()

        // 🟠 BODY-DOMAIN
        case .sleep:
            SleepView(
                onMetricSelected: handleMetricSelection,
                onBack: { appState.currentStatsScreen = .none }   // zurück zur BodyOverview
            )

        case .weight:
            WeightView(
                onMetricSelected: handleMetricSelection,
                onBack: { appState.currentStatsScreen = .none }   // zurück zur BodyOverview
            )

        case .bmi:
            BMIView(
                onMetricSelected: handleMetricSelection,
                onBack: { appState.currentStatsScreen = .none }   // zurück zur BodyOverview
            )

        case .bodyFat:
            BodyFatView(
                onMetricSelected: handleMetricSelection,
                onBack: { appState.currentStatsScreen = .none }   // 🔙 zurück zur BodyOverview
            )

        case .restingHeartRate:
            RestingHeartRateView(
                onMetricSelected: handleMetricSelection,
                onBack: { appState.currentStatsScreen = .none }
            )
        }
    }

    // MARK: - Navigation durch Body-Metric-Chips

    private func handleMetricSelection(_ metric: String) {
        switch metric {
        case "Sleep":
            appState.currentStatsScreen = .sleep
        case "Weight":
            appState.currentStatsScreen = .weight
        case "BMI":
            appState.currentStatsScreen = .bmi
        case "Body Fat":
            appState.currentStatsScreen = .bodyFat
        case "Resting Heart Rate":
            appState.currentStatsScreen = .restingHeartRate
        default:
            break
        }
    }
}

#Preview("BodyDashboardView") {                               // !!! NEW
    let previewStore = HealthStore.preview()                  // !!! NEW
    let previewState = AppState()                             // !!! NEW

    return BodyDashboardView()                                // !!! NEW
        .environmentObject(previewStore)                      // !!! NEW
        .environmentObject(previewState)                      // !!! NEW
}
