//
//  NutritionDashboardView.swift
//  GluVibProbe
//

import SwiftUI

struct NutritionDashboardView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    var body: some View {

        switch appState.currentStatsScreen {

        // -----------------------------------------------------
        // Overview / kein Detail aktiv
        // -----------------------------------------------------
        case .none,
             .nutritionOverview:
            NutritionOverviewViewV1()

        // -----------------------------------------------------
        // Nutrition-Metriken (V1)
        // -----------------------------------------------------
        case .carbs:
            CarbsViewV1(onMetricSelected: handleMetricSelection)

        case .protein:
            ProteinViewV1(onMetricSelected: handleMetricSelection)

        case .fat:
            FatViewV1(onMetricSelected: handleMetricSelection)

        case .calories:
            NutritionEnergyViewV1(onMetricSelected: handleMetricSelection)

        // -----------------------------------------------------
        // Andere Domains → gehören NICHT hierher
        // -----------------------------------------------------
        case .steps,
             .activityEnergy,
             .activityExerciseMinutes,
             .movementSplit,
             .moveTime,
             .workoutMinutes,

             .weight,
             .sleep,
             .bmi,
             .bodyFat,
             .restingHeartRate,

             .metabolicOverview,
             .bolus,
             .basal,
             .bolusBasalRatio,
             .carbsBolusRatio,

             .timeInRange,                 // !!! NEW (AppState)
             .gmi:                         // !!! NEW (AppState)
            NutritionOverviewViewV1()
        }
    }

    // MARK: - Nutrition Chip Navigation

    private func handleMetricSelection(_ metric: String) {
        switch metric {
        case "Carbs":
            appState.currentStatsScreen = .carbs
        case "Protein":
            appState.currentStatsScreen = .protein
        case "Fat":
            appState.currentStatsScreen = .fat
        case "Calories":
            appState.currentStatsScreen = .calories
        default:
            break
        }
    }
}

// MARK: - Preview

#Preview("Nutrition Dashboard") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()

    previewState.currentStatsScreen = .nutritionOverview

    return NutritionDashboardView()
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
