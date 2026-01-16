//
//  BolusBasalRatioViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct BolusBasalRatioViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel   // ✅ ADD

    @StateObject private var viewModel: BolusBasalRatioViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: BolusBasalRatioViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: BolusBasalRatioViewModelV1())
        }
    }

    var body: some View {
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
                    title: "Bolus/Basal",

                    // KPI
                    kpiTitle: "Bolus/Basal Today",
                    kpiCurrentText: viewModel.formattedTodayRatio,
                    kpiSecondaryText: nil,

                    // Charts
                    last90DaysData: viewModel.last90DaysRatioInt10,
                    periodAverages: viewModel.periodAverages,

                    // Scales (SSoT: VM)
                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,

                    // Target support (none for Ratio)
                    goalValue: nil,

                    // Navigation
                    onMetricSelected: onMetricSelected,
                    metrics: AppState.metabolicVisibleMetrics(settings: settings),   // ✅ FIX

                    // Scale Type (period-adaptiv in der SectionCard)
                    dailyScaleType: .ratioInt10
                )
            }
        }
        .task {
            await healthStore.refreshMetabolic(.navigation)
        }
    }
}

#Preview("BolusBasalRatioViewV1 – Metabolic") {
    let previewStore = HealthStore.preview()
    let previewVM = BolusBasalRatioViewModelV1(healthStore: previewStore)
    let previewState = AppState()
    previewState.currentStatsScreen = .bolusBasalRatio

    return BolusBasalRatioViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
