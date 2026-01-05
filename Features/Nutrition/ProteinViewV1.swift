//
//  ProteinViewV1.swift
//  GluVibProbe
//
//  V1 kompatibel
//

import SwiftUI

struct ProteinViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: ProteinViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: ProteinViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: ProteinViewModelV1())
        }
    }

    var body: some View {

        // ============================================================
        // MARK: - Local Type Bridge (DailyProteinEntry -> DailyStepsEntry)
        // NOTE: NutritionSectionCardScaledV2 expects [DailyStepsEntry]
        // ============================================================

        let last90StepsLike: [DailyStepsEntry] = viewModel.last90DaysData.map {      // !!! NEW
            DailyStepsEntry(date: $0.date, steps: $0.grams)                          // !!! NEW
        }                                                                            // !!! NEW

        MetricDetailScaffold(
            headerTitle: "Nutrition",
            headerTint: Color.Glu.nutritionDomain,

            onBack: {
                appState.currentStatsScreen = .nutritionOverview
            },

            onRefresh: {
                await healthStore.refreshNutrition(.pullToRefresh)                   // !!! UPDATED
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
                    title: "Protein",

                    kpiTitle: "Protein Today",
                    kpiTargetText: viewModel.formattedDailyProteinGoal,
                    kpiCurrentText: viewModel.formattedTodayProtein,
                    kpiDeltaText: viewModel.kpiDeltaText,
                    kpiDeltaColor: viewModel.kpiDeltaColor,
                    hasTarget: true,

                    last90DaysData: last90StepsLike,
                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyProteinData,

                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,

                    goalValue: viewModel.dailyProteinGoalInt,

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
            await healthStore.refreshNutrition(.navigation)                           // !!! UPDATED
        }
    }
}

// MARK: - Preview

#Preview("ProteinViewV1 – Nutrition") {
    let previewStore = HealthStore.preview()
    let previewVM = ProteinViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return ProteinViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
