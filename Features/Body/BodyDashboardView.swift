//
//  BodyDashboardView.swift
//  GluVibProbe
//

import SwiftUI

/// Dashboard für die Body-Domain:
/// - Sleep
/// - Weight
///
/// Steuert, welche Detail-View angezeigt wird, basierend auf appState.currentStatsScreen.
struct BodyDashboardView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    var body: some View {

        switch appState.currentStatsScreen {

        // -----------------------------------------------------
        // NEUE Fälle: gehören NICHT ins Body-Dashboard
        // -----------------------------------------------------
        case .none,
             .nutritionOverview:
            EmptyView()   // Pflicht, damit der Switch exhaustiv wird

        // -----------------------------------------------------
        // 🟠 BODY-DOMAIN
        // -----------------------------------------------------
        case .sleep:
            SleepView(onMetricSelected: handleMetricSelection)

        case .weight:
            WeightView(onMetricSelected: handleMetricSelection)

        // -----------------------------------------------------
        // Andere Domains → wegparken (Fallback: SleepView)
        // -----------------------------------------------------
        case .steps, .activityEnergy,
             .carbs, .protein, .fat, .calories:
            SleepView(onMetricSelected: handleMetricSelection)
        }
    }

    // MARK: - Navigation durch Body-Metric-Chips

    private func handleMetricSelection(_ metric: String) {
        switch metric {
        case "Sleep":
            appState.currentStatsScreen = .sleep

        case "Weight":
            appState.currentStatsScreen = .weight

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
