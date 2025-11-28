//
//  BodyDashboardView.swift
//  GluVibProbe
//

import SwiftUI

/// Dashboard für Body-Daten:
/// - Sleep
/// - (später) Weight
///
/// Die Activity-Daten liegen jetzt im ActivityDashboardView.
struct BodyDashboardView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    var body: some View {
        switch appState.currentStatsScreen {

        case .sleep:
            // SleepView mit Metric-Navigation
            SleepView(onMetricSelected: handleMetricSelection)

        case .weight:
            // 💡 Ab jetzt eigene WeightView (mit Metric-Chips)
            WeightView(onMetricSelected: handleMetricSelection)

        // Übergangsweise weiterhin SleepView,
        // bis Steps/Activity hier nicht mehr über das Body-Dashboard laufen
        case .steps:
            SleepView(onMetricSelected: handleMetricSelection)

        case .activityEnergy:
            SleepView(onMetricSelected: handleMetricSelection)
        }
    }

    // MARK: - Metric Navigation

    private func handleMetricSelection(_ metric: String) {
        switch metric {

        case "Sleep":
            appState.currentStatsScreen = .sleep

        case "Weight":
            appState.currentStatsScreen = .weight

        case "Steps":
            appState.currentStatsScreen = .steps

        case "Activity Energy":
            appState.currentStatsScreen = .activityEnergy

        default:
            break
        }
    }
}

#Preview {
    let previewStore = HealthStore.preview()
    let previewState = AppState()
    previewState.currentStatsScreen = .sleep

    return BodyDashboardView()
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
