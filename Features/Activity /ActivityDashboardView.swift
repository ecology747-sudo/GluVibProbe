//
//  ActivityDashboardView.swift
//  GluVibProbe
//

import SwiftUI

/// Dashboard für die Activity-Domain:
/// - Steps
/// - Activity Energy
///
/// Sleep & Weight wandern später in die Body-Domain (eigenes Dashboard).
struct ActivityDashboardView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    var body: some View {
        switch appState.currentStatsScreen {

        case .steps:
            // Steps-Flow mit Metric-Chips
            StepsView(onMetricSelected: handleMetricSelection)

        case .activityEnergy:
            // Activity-Energy-Flow
            ActivityEnergyView(onMetricSelected: handleMetricSelection)

        case .weight:
            // Übergangsweise: weiter auf Steps anzeigen,
            // bis Weight in der Body-Domain separat hängt.
            StepsView(onMetricSelected: handleMetricSelection)

        case .sleep:
            // Übergangsweise: weiter auf Steps anzeigen,
            // bis Sleep in der Body-Domain separat hängt.
            StepsView(onMetricSelected: handleMetricSelection)
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

    return ActivityDashboardView()
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
