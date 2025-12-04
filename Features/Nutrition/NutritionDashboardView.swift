//
//  NutritionDashboardView.swift
//  GluVibProbe
//

import SwiftUI

/// Dashboard für die Nutrition-Domain:
/// Steuert, welche Detail-View angezeigt wird.
/// Wird NUR angezeigt, wenn ein Nutrition-Detail aktiv ist.
/// Die Overview wird NICHT hier angezeigt, sondern in ContentView.
struct NutritionDashboardView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    var body: some View {

        switch appState.currentStatsScreen {

        // -----------------------------------------------------
        // NEUE FÄLLE → werden NICHT hier behandelt
        // -----------------------------------------------------
        case .none,
             .nutritionOverview:
            // Sollte nie passieren, aber wir geben
            // einen Fallback zurück, damit der Switch vollständig ist.
            EmptyView()

        // -----------------------------------------------------
        // Nutrition-Metriken
        // -----------------------------------------------------
        case .carbs:
            CarbsView(onMetricSelected: handleMetricSelection)

        case .protein:
            ProteinView(onMetricSelected: handleMetricSelection)

        case .fat:
            FatView(onMetricSelected: handleMetricSelection)

        case .calories:
            NutritionEnergyView(onMetricSelected: handleMetricSelection)

        // -----------------------------------------------------
        // Andere Domains – Fallback
        // (sollten eigentlich nicht über dieses Dashboard kommen)
        // -----------------------------------------------------
        case .steps, .activityEnergy, .weight, .sleep:
            CarbsView(onMetricSelected: handleMetricSelection)
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

#Preview("NutritionDashboardView") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()

    return NutritionDashboardView()
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
