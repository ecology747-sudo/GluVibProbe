//
//  NutritionDashboardView.swift
//  GluVibProbe
//

import SwiftUI

/// Dashboard für die Nutrition-Domain:
/// - Carbs
/// - Protein
/// - Fat
/// - Nutrition Energy
///
/// Steuert, welche Detail-View angezeigt wird, basierend auf appState.currentStatsScreen
struct NutritionDashboardView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    var body: some View {
        switch appState.currentStatsScreen {

        case .carbs:
            CarbsView(onMetricSelected: handleMetricSelection)

        case .protein:
            ProteinView(onMetricSelected: handleMetricSelection)

        case .fat:
            FatView(onMetricSelected: handleMetricSelection)

        case .calories:
            // 👉 „Calories“-Case bleibt intern für die Navigation,
            //    aber die Metrik heißt überall „Nutrition Energy“
            NutritionEnergyView(onMetricSelected: handleMetricSelection)

        // alle anderen Fälle (gemeinsamer Enum mit Body/Activity)
        case .steps, .activityEnergy, .weight, .sleep:
            // Fallback: Carbs anzeigen, damit der Switch exhaustiv bleibt
            CarbsView(onMetricSelected: handleMetricSelection)
        }
    }

    // MARK: - Navigation durch Nutrition-Metric-Chips

    private func handleMetricSelection(_ metric: String) {
        switch metric {
        case "Carbs":
            appState.currentStatsScreen = .carbs

        case "Protein":
            appState.currentStatsScreen = .protein

        case "Fat":
            appState.currentStatsScreen = .fat

        case "Nutrition Energy":
            appState.currentStatsScreen = .calories   // 🔁 interner Case bleibt

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
