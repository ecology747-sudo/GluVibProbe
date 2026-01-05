//
//  CarbsBolusRatioViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct CarbsBolusRatioViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: CarbsBolusRatioViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: CarbsBolusRatioViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: CarbsBolusRatioViewModelV1())
        }
    }

    var body: some View {

        // Adapter: DailyRatioEntry -> DailyStepsEntry (Int*10)
        let last90StepsLike: [DailyStepsEntry] = viewModel.last90DaysRatio.map {
            DailyStepsEntry(
                date: $0.date,
                steps: Int(($0.ratio * 10.0).rounded())
            )
        }

        MetricDetailScaffold(
            headerTitle: "Metabolic",
            headerTint: Color.Glu.metabolicDomain,

            onBack: { appState.currentStatsScreen = .none },

            onRefresh: {
                await healthStore.refreshNutrition(.pullToRefresh)
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
                    title: "Carbs/Bolus",

                    // KPI: nur Today
                    kpiTitle: "Carbs/Bolus Today",
                    kpiCurrentText: viewModel.formattedTodayRatio,
                    kpiSecondaryText: nil,

                    // Charts
                    last90DaysData: last90StepsLike,
                    periodAverages: viewModel.periodAverages,

                    // Scales (SSoT: VM)
                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,

                    // !!! NEW: Target support (none for Ratio)
                    goalValue: nil,

                    // Navigation
                    onMetricSelected: onMetricSelected,
                    metrics: AppState.metabolicVisibleMetrics,

                    // Scale Type (Int*10, 1 decimal Label)
                    dailyScaleType: .ratioInt10
                )
            }
        }
        .task {
            await healthStore.refreshNutrition(.navigation)
            await healthStore.refreshMetabolic(.navigation)
        }
    }
}

// MARK: - Preview

#Preview("CarbsBolusRatioViewV1 – Metabolic") {
    let previewStore = HealthStore.preview()
    let previewVM = CarbsBolusRatioViewModelV1(healthStore: previewStore)
    let previewState = AppState()
    previewState.currentStatsScreen = .carbsBolusRatio

    return CarbsBolusRatioViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
