//
//  WeightViewV1.swift
//  GluVibProbe
//
//  V1: Weight View (Body Domain)
//  - exakt BMIViewV1 Scaffold/Design Pattern
//  - kein Fetch im VM (Refresh läuft über HealthStore.refreshBody)
//

import SwiftUI

struct WeightViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: WeightViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: WeightViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: WeightViewModelV1(healthStore: .shared, settings: .shared))
        }
    }

    var body: some View {

        MetricDetailScaffold(
            headerTitle: "Body",
            headerTint: Color.Glu.bodyDomain,

            onBack: {
                appState.currentStatsScreen = .none                  // !!! UPDATED
            },

            onRefresh: {
                await healthStore.refreshBody(.pullToRefresh)        // !!! UPDATED
            },

            background: {
                LinearGradient(
                    colors: [
                        .white,
                        Color.Glu.bodyDomain.opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {

                BodySectionCardScaledV2(
                    sectionTitle: "",
                    title: "Weight",

                    kpiTitle: "Weight Today",
                    kpiTargetText: viewModel.targetText,          // !!! UPDATED
                    kpiCurrentText: viewModel.currentText,
                    kpiDeltaText: viewModel.deltaText,
                    kpiDeltaColor: viewModel.deltaColor,          // !!! UPDATED
                    hasTarget: true,

                    last90DaysDoubleData: viewModel.last90DaysForChart,

                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyForChart,

                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,

                    goalValue: Int(viewModel.targetWeightKg.rounded()), // !!! UPDATED (Goal-Line optional)

                    onMetricSelected: onMetricSelected,
                    metrics: AppState.bodyVisibleMetrics,

                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: false,

                    customKpiContent: nil,
                    customChartContent: nil,

                    dailyScaleType: .weightKg,
                    chartStyle: .bar
                )
            }
        }
        .task {
            await healthStore.refreshBody(.navigation)               // !!! UPDATED
        }
    }
}

// MARK: - Preview

#Preview("WeightViewV1 – Body") {
    let previewStore = HealthStore.preview()
    let previewVM = WeightViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return WeightViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
