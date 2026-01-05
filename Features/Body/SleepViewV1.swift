//
//  SleepViewV1.swift
//  GluVibProbe
//
//  V1: Sleep View (Body Domain)
//  - nutzt MetricDetailScaffold
//  - Refresh ausschließlich über HealthStore.refreshBody
//  - KPI mit Target + Delta + Farb-Logik
//

import SwiftUI

struct SleepViewV1: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    // MARK: - ViewModel

    @StateObject private var viewModel: SleepViewModelV1

    let onMetricSelected: (String) -> Void

    // MARK: - Init

    init(
        viewModel: SleepViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: SleepViewModelV1())
        }
    }

    // MARK: - Body

    var body: some View {
        MetricDetailScaffold(
            headerTitle: "Body",
            headerTint: Color.Glu.bodyDomain,

            onBack: {
                appState.currentStatsScreen = .none
            },

            onRefresh: {
                await healthStore.refreshBody(.pullToRefresh)      // ✅ V1-Flow
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
                    title: "Sleep",

                    // KPI
                    kpiTitle: "Sleep Today",
                    kpiTargetText: viewModel.formattedTargetSleep,
                    kpiCurrentText: viewModel.formattedTodaySleep,
                    kpiDeltaText: viewModel.formattedDeltaSleep,
                    kpiDeltaColor: viewModel.deltaColor,
                    hasTarget: true,

                    // Daten
                    last90DaysData: viewModel.last90DaysDataForChart,
                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyData,

                    // Skalen
                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,

                    // Zielwert (Minuten)
                    goalValue: viewModel.goalValueForChart,

                    // Navigation
                    onMetricSelected: onMetricSelected,
                    metrics: AppState.bodyVisibleMetrics,

                    // Charts
                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: false,

                    customKpiContent: nil,
                    customChartContent: nil,

                    // Skalierung
                    dailyScaleType: .sleepMinutes,                  // !!! FIX: Steps-Master-Pattern → Daily Y-Skala folgt Period Picker (nur Last90Days)
                    chartStyle: .bar
                )
            }
        }
        .task {
            await healthStore.refreshBody(.navigation)             // ✅ Navigation-Refresh
        }
    }
}

// MARK: - Preview

#Preview("SleepViewV1 – Body") {
    let previewStore = HealthStore.preview()
    let previewVM = SleepViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return SleepViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
