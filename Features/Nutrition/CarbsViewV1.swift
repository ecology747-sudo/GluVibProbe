//
//  CarbsViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct CarbsViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: CarbsViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: CarbsViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: CarbsViewModelV1())
        }
    }

    var body: some View {

        // ============================================================
        // MARK: - Local Type Bridge (DailyCarbsEntry -> DailyStepsEntry)
        // NOTE: NutritionSectionCardScaledV2 expects [DailyStepsEntry]
        // ============================================================

        let last90StepsLike: [DailyStepsEntry] = viewModel.last90DaysData.map {
            DailyStepsEntry(date: $0.date, steps: $0.grams)                         // !!! UPDATED
        }

        MetricDetailScaffold(
            headerTitle: "Nutrition",
            headerTint: Color.Glu.nutritionDomain,

            onBack: {
                appState.currentStatsScreen = .nutritionOverview
            },

            onRefresh: {
                await healthStore.refreshNutrition(.pullToRefresh)                  // !!! UPDATED
            },

            background: {
                LinearGradient(
                    colors: [
                        .white,
                        Color.Glu.nutritionDomain.opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {

                NutritionSectionCardScaledV2(
                    sectionTitle: "",
                    title: "Carbs",

                    kpiTitle: "Carbs Today",
                    kpiTargetText: viewModel.formattedDailyCarbsGoal,
                    kpiCurrentText: viewModel.formattedTodayCarbs,
                    kpiDeltaText: viewModel.kpiDeltaText,
                    kpiDeltaColor: viewModel.kpiDeltaColor,
                    hasTarget: true,

                    last90DaysData: last90StepsLike,
                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyCarbsData,

                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,

                    goalValue: viewModel.dailyCarbsGoalInt,

                    onMetricSelected: onMetricSelected,
                    metrics: AppState.nutritionVisibleMetrics,

                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: true,

                    customKpiContent: nil,
                    customChartContent: nil,

                    dailyScaleType: .gramsDaily
                )
            }
        }
        .task {
            await healthStore.refreshNutrition(.navigation)                          // !!! UPDATED
        }
    }
}

// MARK: - Preview

#Preview("CarbsViewV1 – Nutrition") {
    let previewStore = HealthStore.preview()
    let previewVM = CarbsViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return CarbsViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
