//
//  NutritionEnergyViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct NutritionEnergyViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: NutritionEnergyViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: NutritionEnergyViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: NutritionEnergyViewModelV1())
        }
    }

    var body: some View {

        // ============================================================
        // MARK: - Local Type Bridge (DailyNutritionEnergyEntry -> DailyStepsEntry)
        // NOTE: NutritionSectionCardScaledV2 expects [DailyStepsEntry]
        // ============================================================

        let last90StepsLike: [DailyStepsEntry] = viewModel.last90DaysData.map {       // !!! NEW
            DailyStepsEntry(date: $0.date, steps: $0.energyKcal)                      // !!! NEW
        }                                                                             // !!! NEW

        MetricDetailScaffold(
            headerTitle: "Nutrition",
            headerTint: Color.Glu.nutritionDomain,

            onBack: {
                appState.currentStatsScreen = .nutritionOverview
            },

            onRefresh: {
                await healthStore.refreshNutrition(.pullToRefresh)                    // !!! UPDATED
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
                    title: "Calories",

                    kpiTitle: "Calories Today",
                    kpiTargetText: viewModel.formattedDailyCaloriesGoal,              // !!! UPDATED (VM enthält Einheit)
                    kpiCurrentText: viewModel.formattedTodayKcal,                     // !!! UPDATED (VM enthält Einheit)
                    kpiDeltaText: viewModel.kpiDeltaText,
                    kpiDeltaColor: viewModel.kpiDeltaColor,
                    hasTarget: true,

                    last90DaysData: last90StepsLike,                                  // !!! UPDATED
                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyData,

                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,

                    goalValue: viewModel.dailyCaloriesGoalInt,

                    onMetricSelected: onMetricSelected,
                    metrics: AppState.nutritionVisibleMetrics,

                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: true,

                    customKpiContent: nil,
                    customChartContent: nil,

                    dailyScaleType: MetricScaleHelper.MetricScaleType.energyDaily     // ✅ adaptive Y für Perioden
                )
            }
        }
        .task {
            await healthStore.refreshNutrition(.navigation)                           // !!! UPDATED
        }
    }
}

// MARK: - Preview

#Preview("NutritionEnergyViewV1 – Nutrition") {
    let previewStore = HealthStore.preview()
    let previewVM = NutritionEnergyViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return NutritionEnergyViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
