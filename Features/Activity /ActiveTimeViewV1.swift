//
//  ActiveTimeViewV1.swift
//  GluVibProbe
//
//  V1 Adapter View:
//  - UI läuft über MetricDetailScaffold
//  - Datenfluss läuft über ActiveTimeViewModelV1 (kein Fetch im VM)
//  - Refresh läuft über HealthStore.refreshActivity(...)
//

import SwiftUI

struct ActiveTimeViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: ActiveTimeViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: ActiveTimeViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: ActiveTimeViewModelV1())
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
                    title: "Active Time",
                    kpiTitle: "Active Time Today",
                    kpiTargetText: "–",
                    kpiCurrentText: viewModel.formattedTodayActiveTime,
                    kpiDeltaText: "–",
                    hasTarget: false,
                    last90DaysData: viewModel.last90DaysChartData,
                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyData,
                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,
                    goalValue: nil,
                    onMetricSelected: onMetricSelected,
                    metrics: [
                        "Steps",
                        "Active Time",
                        "Activity Energy",
                        "Movement Split"
                    ],
                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: true
                )
            }
        }
        .task {
            await healthStore.refreshActivity(.navigation)
        }
    }
}

// MARK: - Preview

#Preview("ActiveTimeViewV1 – Activity") {
    let previewStore = HealthStore.preview()
    let previewVM = ActiveTimeViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return ActiveTimeViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
