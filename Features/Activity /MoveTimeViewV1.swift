//
//  MoveTimeViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct MoveTimeViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: MoveTimeViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: MoveTimeViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: MoveTimeViewModelV1())
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
                    title: "Move Time",
                    kpiTitle: "Move Time Today",
                    kpiTargetText: viewModel.kpiTargetText,              // leer
                    kpiCurrentText: viewModel.formattedTodayMoveTime,
                    kpiDeltaText: viewModel.kpiDeltaText,                // "–"
                    kpiDeltaColor: viewModel.kpiDeltaColor,              // .secondary
                    hasTarget: false,                                    // ✅ wichtig
                    last90DaysData: viewModel.last90DaysChartData,
                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyData,
                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,
                    goalValue: 0,                                        // irrelevant (hasTarget=false)
                    onMetricSelected: onMetricSelected,
                    metrics: AppState.activityVisibleMetrics,

                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: true,
                    customKpiContent: nil,
                    customChartContent: nil,

                    dailyScaleType: MetricScaleHelper.MetricScaleType.moveMinutes
                )
            }
        }
        .task {
            await healthStore.refreshActivity(.navigation)
        }
    }
}

#Preview("MoveTimeViewV1 – Activity") {
    let previewStore = HealthStore.preview()
    let previewVM = MoveTimeViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return MoveTimeViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)   // ✅ FIX
}
