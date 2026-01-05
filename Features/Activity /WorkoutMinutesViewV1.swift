//
//  WorkoutMinutesViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct WorkoutMinutesViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: WorkoutMinutesViewModelV1
    let onMetricSelected: (String) -> Void

    init(
        viewModel: WorkoutMinutesViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: WorkoutMinutesViewModelV1())
        }
    }

    var body: some View {
        MetricDetailScaffold(
            headerTitle: "Activity",
            headerTint: Color.Glu.activityDomain,
            onBack: { appState.currentStatsScreen = .none },
            onRefresh: { await healthStore.refreshActivity(.pullToRefresh) },
            background: {
                LinearGradient(
                    colors: [.white, Color.Glu.activityDomain.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ActivitySectionCardScaledV2(
                    sectionTitle: "",
                    title: "Workout Minutes",            // ✅ EXACT
                    kpiTitle: "Workout Minutes Today",
                    kpiTargetText: viewModel.kpiTargetText,
                    kpiCurrentText: viewModel.formattedToday,
                    kpiDeltaText: viewModel.kpiDeltaText,
                    kpiDeltaColor: viewModel.kpiDeltaColor,
                    hasTarget: false,

                    last90DaysData: viewModel.last90DaysChartData,
                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyData,

                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,

                    goalValue: 0,
                    onMetricSelected: onMetricSelected,
                    metrics: AppState.activityVisibleMetrics,
                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: true,

                    customKpiContent: nil,
                    customChartContent: nil,

                    dailyScaleType: .moveMinutes
                )
            }
        }
        .task {
            await healthStore.refreshActivity(.navigation)
        }
    }
}

#Preview("WorkoutMinutesViewV1 – Activity") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()
    let previewVM = WorkoutMinutesViewModelV1(healthStore: previewStore)

    return WorkoutMinutesViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
