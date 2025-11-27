//
//  BodyActivityDashboardView.swift
//  GluVibProbe
//

import SwiftUI

struct BodyActivityDashboardView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    var body: some View {
        switch appState.currentStatsScreen {

        case .steps:
            StepsView(onMetricSelected: handleMetricSelection)

        case .activityEnergy:
            ActivityEnergyView(onMetricSelected: handleMetricSelection)

        case .weight:
            // WeightView
            StepsView(onMetricSelected: handleMetricSelection)

        case .sleep:
            // SleepView
            // StepsView(onMetricSelected: handleMetricSelection)
            SleepView(onMetricSelected: handleMetricSelection)
        }
    }

    // MARK: - Navigation durch Metric Chips
    private func handleMetricSelection(_ metric: String) {
        switch metric {
        case "Steps":
            appState.currentStatsScreen = .steps

        case "Activity Energy":
            appState.currentStatsScreen = .activityEnergy

        case "Weight":
            appState.currentStatsScreen = .weight

        case "Sleep":
            appState.currentStatsScreen = .sleep

        default:
            break
        }
    }
}

#Preview {
    let previewStore = HealthStore.preview()
    let previewState = AppState()

    return BodyActivityDashboardView()
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
