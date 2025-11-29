import SwiftUI

/// Dashboard für Body-Daten:
/// - Sleep
/// - Weight
///
/// Die Activity-Daten liegen im ActivityDashboardView.
struct BodyDashboardView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    var body: some View {
        switch appState.currentStatsScreen {

        case .sleep:
            // SleepView mit Metric-Navigation
            SleepView(onMetricSelected: handleMetricSelection)

        case .weight:
            // WeightView mit den gleichen Body-Metric-Chips (Sleep / Weight)
            WeightView(onMetricSelected: handleMetricSelection)

        // Falls Nutzer in der Body-Domain einmal „falsch“ auf Steps/Activity landet:
        // Übergangsweise zurück auf Sleep (bis Tabs alles sauber trennen)
        case .steps, .activityEnergy:
            SleepView(onMetricSelected: handleMetricSelection)
        }
    }

    // MARK: - Metric Navigation (Sleep <-> Weight)

    private func handleMetricSelection(_ metric: String) {
        switch metric {

        case "Sleep":
            appState.currentStatsScreen = .sleep

        case "Weight":
            appState.currentStatsScreen = .weight

        // Falls in Body-Domain jemand „Steps“ oder „Activity Energy“ antippt:
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
