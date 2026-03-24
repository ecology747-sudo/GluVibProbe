//
//  NutritionDashboardView.swift
//  GluVibProbe
//
//  Nutrition Dashboard Router (V1)
//  - Central switch for Nutrition detail screens.
//  - Chip navigation maps metric strings to AppState.StatsScreen.
//  - Fallback stays on NutritionOverviewViewV1 (no cross-domain routing here).
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

        case .carbsDayparts: // 🟨 NEW
            CarbsDaypartsViewV1(onMetricSelected: handleMetricSelection)

        case .sugar: // 🟨 NEW
            SugarViewV1(onMetricSelected: handleMetricSelection)

        case .protein:
            ProteinViewV1(onMetricSelected: handleMetricSelection)

        case .fat:
            FatViewV1(onMetricSelected: handleMetricSelection)

        case .calories:
            NutritionEnergyViewV1(onMetricSelected: handleMetricSelection)

        // -----------------------------------------------------
        // Alle anderen Domains → hier immer Overview
        // -----------------------------------------------------
        default:
            NutritionOverviewViewV1()
        }
    }

    // MARK: - Nutrition Chip Navigation

    private func handleMetricSelection(_ metric: String) {
        switch metric {
        case "Carbs":
            appState.currentStatsScreen = .carbs
        case "Carbs Split": // 🟨 NEW
            appState.currentStatsScreen = .carbsDayparts
        case "Sugar": // 🟨 NEW
            appState.currentStatsScreen = .sugar
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
