//
//  CarbsBolusRatioViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct CarbsBolusRatioViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel   // ✅ ADD

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
        MetricDetailScaffold(
            headerTitle: "Metabolic",
            headerTint: Color.Glu.metabolicDomain,

            onBack: { appState.currentStatsScreen = .none },

            onRefresh: {
                // SSoT – Metabolic refresh reicht (Carbs90 + Bolus90 + Derived)
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
                    last90DaysData: viewModel.last90DaysRatioInt10,
                    periodAverages: viewModel.periodAverages,

                    // Scales
                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,

                    goalValue: nil,

                    // Navigation
                    onMetricSelected: onMetricSelected,
                    metrics: AppState.metabolicVisibleMetrics(settings: settings),   // ✅ FIX

                    // Scale Type (Int*10)
                    dailyScaleType: .ratioInt10
                )
            }
        }
        .task {
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
        .environmentObject(SettingsModel.shared) // ✅ required now (settings used in view)
}
