//
//  ActivityDashboardView.swift
//  GluVibProbe
//

import SwiftUI

struct ActivityDashboardView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    var body: some View {

        switch appState.currentStatsScreen {

        // -----------------------------------------------------
        // NICHT-ACTIVITY → gehört NICHT ins Activity-Dashboard
        // -----------------------------------------------------
        case .none,

             // Nutrition
             .nutritionOverview,

             // ✅ Metabolic (V1)
             .metabolicOverview,
             .bolus,
             .basal,
             .bolusBasalRatio,
             .carbsBolusRatio,
             .timeInRange,                 // !!! NEW
             .gmi:                         // !!! NEW
            EmptyView()

        // -----------------------------------------------------
        // Activity Screens
        // -----------------------------------------------------
        case .steps:
            StepsViewV1(onMetricSelected: handleMetricSelection)

        case .activityEnergy:
            ActivityEnergyViewV1(onMetricSelected: handleMetricSelection)

        case .activityExerciseMinutes:
            ActiveTimeViewV1(onMetricSelected: handleMetricSelection)

        case .movementSplit:
            MovementSplitViewV1(onMetricSelected: handleMetricSelection)

        case .moveTime:
            MoveTimeViewV1(onMetricSelected: handleMetricSelection)

        case .workoutMinutes:
            WorkoutMinutesViewV1(onMetricSelected: handleMetricSelection)

        // -----------------------------------------------------
        // Nutrition-Screens → im Activity-Dashboard wegparken
        // (dein bisheriges Verhalten: fallback auf Steps)
        // -----------------------------------------------------
        case .carbs,
             .protein,
             .fat,
             .calories:
            StepsViewV1(onMetricSelected: handleMetricSelection)

        // -----------------------------------------------------
        // Body-Screens → ebenfalls wegparken (fallback auf Steps)
        // -----------------------------------------------------
        case .sleep,
             .weight,
             .bmi,
             .bodyFat,
             .restingHeartRate:
            StepsViewV1(onMetricSelected: handleMetricSelection)
        }
    }

    // MARK: - Navigation durch Metric Chips

    private func handleMetricSelection(_ metric: String) {
        switch metric {

        case "Steps":
            appState.currentStatsScreen = .steps

        case "Active Time":
            appState.currentStatsScreen = .activityExerciseMinutes

        case "Activity Energy":
            appState.currentStatsScreen = .activityEnergy

        case "Movement Split":
            appState.currentStatsScreen = .movementSplit

        case "Move Time", "MoveTime", "Move Minutes", "Move", "moveTime":
            appState.currentStatsScreen = .moveTime

        case "Workout Minutes":
            appState.currentStatsScreen = .workoutMinutes

        // (Body) — bleibt wie gehabt
        case "Weight":
            appState.currentStatsScreen = .weight

        case "Sleep":
            appState.currentStatsScreen = .sleep

        default:
            break
        }
    }
}

#Preview("Activity Dashboard") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()

    previewState.currentStatsScreen = .steps

    return ActivityDashboardView()
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
