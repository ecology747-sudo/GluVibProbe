//
//  StepsViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct StepsViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: StepsViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: StepsViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: StepsViewModelV1())
        }
    }

    var body: some View {
        MetricDetailScaffold(
            headerTitle: "Activity",
            headerTint: Color.Glu.activityDomain,

            onBack: {
                appState.currentStatsScreen = .none
            },

            onRefresh: {
                await healthStore.refreshActivity(.pullToRefresh)
            },

            background: {
                LinearGradient(
                    colors: [
                        .white,
                        Color.Glu.activityDomain.opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                
                ActivitySectionCardScaledV2(
                    sectionTitle: "",
                    title: "Steps",
                    kpiTitle: "Steps Today",
                    kpiTargetText: viewModel.formattedDailyStepGoal,
                    kpiCurrentText: viewModel.formattedTodaySteps,
                    kpiDeltaText: viewModel.kpiDeltaText,
                    kpiDeltaColor: viewModel.kpiDeltaColor,
                    hasTarget: true,
                    last90DaysData: viewModel.last90DaysData,
                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyStepsData,
                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,
                    goalValue: viewModel.dailyStepsGoalInt,
                    onMetricSelected: onMetricSelected,
                    metrics: AppState.activityVisibleMetrics,
                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: true,
                    customKpiContent: nil,
                    customChartContent: nil,

                    dailyScaleType: MetricScaleHelper.MetricScaleType.steps
                )
            }
        }
        .task {
            await healthStore.refreshActivity(.navigation)
        }
    }
}

#Preview("StepsViewV1 – Activity") {
    let previewStore = HealthStore.preview()
    let previewVM = StepsViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return StepsViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
