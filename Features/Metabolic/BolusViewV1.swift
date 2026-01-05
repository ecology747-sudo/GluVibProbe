//
//  BolusViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct BolusViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: BolusViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: BolusViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: BolusViewModelV1())
        }
    }

    var body: some View {

        // Local Adapter: DailyBolusEntry → DailyStepsEntry (für Charts)
        let last90StepsLike: [DailyStepsEntry] = viewModel.last90DaysData.map {
            DailyStepsEntry(
                date: $0.date,
                steps: Int($0.bolusUnits.rounded())
            )
        }

        MetricDetailScaffold(
            headerTitle: "Metabolic",
            headerTint: Color.Glu.metabolicDomain,

            onBack: { appState.currentStatsScreen = .none },

            onRefresh: {
                await healthStore.refreshMetabolic(.pullToRefresh)
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

                MetabolicSectionCardScaledV1(
                    title: "Bolus",

                    // KPI
                    kpiTitle: "Bolus Today",
                    kpiCurrentText: viewModel.formattedTodayBolus,
                    kpiSecondaryText: nil,

                    // Charts
                    last90DaysData: last90StepsLike,
                    periodAverages: viewModel.periodAverages,

                    // Scales
                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,

                    // !!! NEW: Target support (none for Bolus)
                    goalValue: nil,

                    // Navigation
                    onMetricSelected: onMetricSelected,
                    metrics: AppState.metabolicVisibleMetrics,

                    // Scale Type
                    dailyScaleType: .insulinUnitsDaily
                )
            }
        }
        .task {
            await healthStore.refreshMetabolic(.navigation)
        }
    }
}

// MARK: - Preview

#Preview("BolusViewV1 – Metabolic") {
    let previewStore = HealthStore.preview()
    let previewVM = BolusViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return BolusViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
