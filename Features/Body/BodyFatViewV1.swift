//
//  BodyFatViewV1.swift
//  GluVibProbe
//
//  V1: Body Fat View (Body Domain)
//  - exakt WeightViewV1 / BMIViewV1 Scaffold/Design Pattern
//  - kein Fetch im VM
//

import SwiftUI

struct BodyFatViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: BodyFatViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: BodyFatViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: BodyFatViewModelV1())
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
                    title: "Body Fat",

                    kpiTitle: "Body Fat Today",
                    kpiTargetText: "–",
                    kpiCurrentText: viewModel.formattedTodayBodyFat,     // ✅ 1 dec
                    kpiDeltaText: "–",
                    kpiDeltaColor: nil,
                    hasTarget: false,

                    last90DaysData: viewModel.last90DaysDataForChart,     // ✅ Adapter (Double-Flow)
                    periodAverages: viewModel.periodAverages,            // ✅ bis 365
                    monthlyData: viewModel.monthlyBodyFatDataForChart,    // !!! UPDATED: Adapter statt Raw Published

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

                    dailyScaleType: .percentInt10,    // !!! UPDATED
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

#Preview("BodyFatViewV1 – Body") {
    let previewStore = HealthStore.preview()
    let previewVM = BodyFatViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return BodyFatViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
