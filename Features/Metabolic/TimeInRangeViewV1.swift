//
//  TimeInRangeViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct TimeInRangeViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: TimeInRangeViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: TimeInRangeViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: TimeInRangeViewModelV1())
        }
    }

    var body: some View {
        MetricDetailScaffold(
            headerTitle: "Metabolic",
            headerTint: Color.Glu.metabolicDomain,

            onBack: { appState.currentStatsScreen = .none },

            onRefresh: {
                await healthStore.refreshMetabolic(.pullToRefresh)               // !!! UPDATED (Bolus-Pattern)
            },

            background: {
                LinearGradient(
                    colors: [.white, Color.Glu.metabolicDomain.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {

                // !!! Scaffold only
                Text(viewModel.placeholderText)
                    .font(.headline)
                    .foregroundColor(Color.Glu.primaryBlue)

                // Später: MetabolicSectionCardScaledV1 + Charts
            }
        }
        .task {
            await healthStore.refreshMetabolic(.navigation)                     // !!! UPDATED (Bolus-Pattern)
        }
    }
}

// MARK: - Preview

#Preview("TimeInRangeViewV1 – Metabolic") {
    let previewStore = HealthStore.preview()
    let previewVM = TimeInRangeViewModelV1(healthStore: previewStore)
    let previewState = AppState()
    previewState.currentStatsScreen = .timeInRange

    return TimeInRangeViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
