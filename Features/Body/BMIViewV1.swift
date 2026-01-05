//
//  BMIViewV1.swift
//  GluVibProbe
//
//  V1: BMI View (Body Domain)
//  - exakt WeightViewV1 Scaffold/Design Pattern
//  - kein Fetch im VM (Refresh läuft über HealthStore.refreshBody)
//

import SwiftUI

struct BMIViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: BMIViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: BMIViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: BMIViewModelV1())
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
                    title: "BMI",

                    kpiTitle: "BMI Today",
                    kpiTargetText: "–",
                    kpiCurrentText: viewModel.currentText,                 // !!! UPDATED
                    kpiDeltaText: "–",
                    kpiDeltaColor: nil,
                    hasTarget: false,

                    // ✅ Double-Serie direkt aus dem ViewModel (wie Weight)
                    last90DaysDoubleData: viewModel.last90DaysForChart,    // !!! UPDATED

                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyForChart,                // !!! UPDATED

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

                    dailyScaleType: .weightKg,                              // !!! UPDATED
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

#Preview("BMIViewV1 – Body") {
    let previewStore = HealthStore.preview()
    let previewVM = BMIViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return BMIViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
