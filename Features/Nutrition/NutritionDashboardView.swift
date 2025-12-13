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
            EmptyView()

        // -----------------------------------------------------
        // Nutrition-Metriken
        // -----------------------------------------------------
        case .carbs:
            CarbsView(
                onMetricSelected: handleMetricSelection,
                onBack: { appState.currentStatsScreen = .nutritionOverview }
            )

        case .protein:
            ProteinView(
                onMetricSelected: handleMetricSelection,
                onBack: { appState.currentStatsScreen = .nutritionOverview }
            )

        case .fat:
            FatView(
                onMetricSelected: handleMetricSelection,
                onBack: { appState.currentStatsScreen = .nutritionOverview }
            )

        case .calories:
            NutritionEnergyView(
                onMetricSelected: handleMetricSelection,
                onBack: { appState.currentStatsScreen = .nutritionOverview }
            )

        // -----------------------------------------------------
        // Andere Domains – Fallback (sollten hier eigentlich
        // nicht landen, aber für Vollständigkeit)
        // -----------------------------------------------------
        case .steps,
             .activityEnergy,
             .activityExerciseMinutes,
             .movementSplit,
             .weight,
             .sleep,
             .bmi,
             .bodyFat,
             .restingHeartRate:
            CarbsView(
                onMetricSelected: handleMetricSelection
                // onBack wird hier NICHT übergeben → Default {} greift
            )
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
        case "Nutrition Energy":
            appState.currentStatsScreen = .calories
        default:
            break
        }
    }
}

#Preview("NutritionDashboardView") {                          // !!! NEW
    let previewStore = HealthStore.preview()                  // !!! NEW
    let previewState = AppState()                             // !!! NEW

    return NutritionDashboardView()                           // !!! NEW
        .environmentObject(previewStore)                      // !!! NEW
        .environmentObject(previewState)                      // !!! NEW
}
