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

        // 🟠 BODY-DOMAIN

        case .sleep:
            SleepView(onMetricSelected: handleMetricSelection)

        case .weight:
            WeightView(onMetricSelected: handleMetricSelection)

        // Alle anderen Fälle (Activity / Nutrition / Metabolic)
        // → Fallback: Body-Standard „Sleep“ anzeigen,
        //   damit der Switch exhaustiv bleibt und wir
        //   NICHT wieder im Activity-Layout landen.
        case .steps, .activityEnergy, .carbs, .protein, .fat, .calories:
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
