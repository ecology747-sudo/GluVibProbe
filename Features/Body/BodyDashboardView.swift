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

        // -----------------------------------------------------
        // Nicht-Body-Fälle → hier nur wegparken
        // -----------------------------------------------------
        case .none,

             // Nutrition
             .nutritionOverview,
             .carbs, .protein, .fat, .calories,

             // Activity
             .steps, .activityEnergy, .activityExerciseMinutes,
             .movementSplit, .moveTime, .workoutMinutes,

             // Metabolic
             .metabolicOverview,
             .bolus, .basal,
             .bolusBasalRatio, .carbsBolusRatio,
             .timeInRange,                       // !!! NEW
             .gmi:                               // !!! NEW
            EmptyView()

        // -----------------------------------------------------
        // BODY-DOMAIN (V1)
        // -----------------------------------------------------
        case .sleep:
            SleepViewV1(onMetricSelected: handleMetricSelection)

        case .weight:
            WeightViewV1(onMetricSelected: handleMetricSelection)

        case .bmi:
            BMIViewV1(onMetricSelected: handleMetricSelection)

        case .bodyFat:
            BodyFatViewV1(onMetricSelected: handleMetricSelection)

        case .restingHeartRate:
            RestingHeartRateViewV1(onMetricSelected: handleMetricSelection)
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

#Preview("Body Dashboard") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()

    previewState.currentStatsScreen = .weight

    return BodyDashboardView()
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
