//
//  BasalViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct BasalViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: BasalViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: BasalViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: BasalViewModelV1())
        }
    }

    var body: some View {

        // ============================================================
        // Local Adapter: DailyBasalEntry → DailyStepsEntry (für Charts)
        // ============================================================

        let last90StepsLike: [DailyStepsEntry] = viewModel.last90DaysData.map {
            DailyStepsEntry(
                date: $0.date,
                steps: Int($0.basalUnits.rounded())
            )
        }

        MetricDetailScaffold(
            headerTitle: "Metabolic",
            headerTint: Color.Glu.metabolicDomain,

            onBack: {
                appState.currentStatsScreen = .none
            },

            onRefresh: {
                await healthStore.refreshMetabolic(.pullToRefresh)               // !!! UPDATED (konsistent wie Bolus)
            },

            background: {
                LinearGradient(
                    colors: [
                        .white,
                        Color.Glu.metabolicDomain.opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {

                MetabolicSectionCardScaledV1(
                    title: "Basal",

                    // KPI: nur "Basal Today"
                    kpiTitle: "Basal Today",
                    kpiCurrentText: viewModel.formattedTodayBasal,
                    kpiSecondaryText: nil,                                         // !!! IMPORTANT

                    // Charts
                    last90DaysData: last90StepsLike,
                    periodAverages: viewModel.periodAverages,

                    // Scales (SSoT: VM)
                    dailyScale: viewModel.dailyScale,                              // !!! UPDATED
                    periodScale: viewModel.periodScale,                            // !!! UPDATED

                    // Navigation
                    onMetricSelected: onMetricSelected,
                    metrics: AppState.metabolicVisibleMetrics,

                    // Scale Type (period-adaptiv via SectionCard)
                    dailyScaleType: .insulinUnitsDaily                             // !!! IMPORTANT
                )
            }
        }
        .task {
            await healthStore.refreshMetabolic(.navigation)                        // !!! UPDATED (konsistent wie Bolus)
        }
    }
}

// MARK: - Preview

#Preview("BasalViewV1 – Metabolic") {
    let previewStore = HealthStore.preview()
    let previewVM = BasalViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    previewState.currentStatsScreen = .basal

    return BasalViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
