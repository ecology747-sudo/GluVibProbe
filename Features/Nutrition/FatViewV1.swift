//
//  FatViewV1.swift
//  GluVibProbe
//
//  V1 kompatibel (wie Carbs/Protein)
//

import SwiftUI

struct FatViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: FatViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: FatViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: FatViewModelV1())
        }
    }

    var body: some View {

        // ============================================================
        // MARK: - Local Type Bridge (DailyFatEntry -> DailyStepsEntry)  // !!! NEW
        // ============================================================

        let last90StepsLike: [DailyStepsEntry] = viewModel.last90DaysData.map {      // !!! NEW
            DailyStepsEntry(date: $0.date, steps: $0.grams)                          // !!! NEW
        }                                                                            // !!! NEW

        let daily365StepsLike: [DailyStepsEntry] = viewModel.fatDaily365.map {       // !!! NEW
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
                    title: "Fat",

                    kpiTitle: "Fat Today",
                    kpiTargetText: viewModel.formattedDailyFatGoal,                  // !!! UPDATED (VM already adds "g")
                    kpiCurrentText: viewModel.formattedTodayFat,                     // !!! UPDATED (VM already adds "g")
                    kpiDeltaText: viewModel.kpiDeltaText,
                    kpiDeltaColor: viewModel.kpiDeltaColor,
                    hasTarget: true,

                    last90DaysData: last90StepsLike,
                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyFatData,

                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,

                    goalValue: viewModel.dailyFatGoalInt,

                    onMetricSelected: onMetricSelected,
                    metrics: AppState.nutritionVisibleMetrics,                        // !!! UPDATED
                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: true,

                    customKpiContent: nil,                                           // !!! UPDATED
                    customChartContent: nil,                                         // !!! UPDATED

                    dailyScaleType: .gramsDaily
                )
            }
        }
        .task {
            await healthStore.refreshNutrition(.navigation)                           // !!! UPDATED
        }
    }
}

#Preview("FatViewV1 – Nutrition") {
    let previewStore = HealthStore.preview()
    let previewVM = FatViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return FatViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
