//
//  RestingHeartRateViewV1.swift
//  GluVibProbe
//
//  V1: Resting Heart Rate View (Body Domain)
//  - exakt Weight/BMI/BodyFat V1 Pattern
//  - kein Fetch im VM
//

import SwiftUI

struct RestingHeartRateViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: RestingHeartRateViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: RestingHeartRateViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: RestingHeartRateViewModelV1())
        }
    }

    var body: some View {

        MetricDetailScaffold(
            headerTitle: "Body",
            headerTint: Color.Glu.bodyDomain,

            onBack: {
                appState.currentStatsScreen = .none
            },

            onRefresh: {
                await healthStore.refreshBody(.pullToRefresh)
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
                    title: "Resting Heart Rate",

                    kpiTitle: "Resting HR Today",
                    kpiTargetText: "–",
                    kpiCurrentText: viewModel.formattedTodayRestingHR,
                    kpiDeltaText: "–",
                    kpiDeltaColor: nil,
                    hasTarget: false,

                    last90DaysData: viewModel.last90DaysDataForChart,
                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyData,

                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,

                    goalValue: nil,

                    onMetricSelected: onMetricSelected,
                    metrics: AppState.bodyVisibleMetrics,

                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: false,

                    customKpiContent: nil,
                    customChartContent: nil,

                    dailyScaleType: .heartRateBpm,
                    chartStyle: .bar
                )
            }
        }
        .task {
            await healthStore.refreshBody(.navigation)
        }
    }
}

// MARK: - Preview

#Preview("RestingHeartRateViewV1 – Body") {
    let previewStore = HealthStore.preview()
    let previewVM = RestingHeartRateViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return RestingHeartRateViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
