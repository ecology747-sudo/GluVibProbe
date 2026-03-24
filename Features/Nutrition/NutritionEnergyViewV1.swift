//
//  NutritionEnergyViewV1.swift
//  GluVibProbe
//
//  Nutrition V1 — Energy Detail Screen
//
//  Purpose
//  - Renders the nutrition energy metric detail screen for the Nutrition domain.
//  - Shows the current energy hint state, KPI block, daily / period / monthly charts,
//    and the shared nutrition metric chip navigation.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → NutritionEnergyViewModelV1 (mapping / formatting) → NutritionEnergyViewV1 (render only)
//
//  Key Connections
//  - NutritionEnergyViewModelV1: provides formatted values, chart data and today hint text.
//  - HealthStore: provides the central nutrition badge / attention sources.
//  - AppState: handles navigation and metric routing.
//  - NutritionSectionCardScaledV2: shared nutrition card shell for chips, KPIs and charts.
//  - L10n: localized titles and labels for the nutrition energy metric.
//

import SwiftUI

struct NutritionEnergyViewV1: View {

    // ============================================================
    // MARK: - Dependencies (Environment)
    // ============================================================

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    // ============================================================
    // MARK: - ViewModel
    // ============================================================

    @StateObject private var viewModel: NutritionEnergyViewModelV1

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let onMetricSelected: (String) -> Void

    // ============================================================
    // MARK: - Init
    // ============================================================

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

    // ============================================================
    // MARK: - Header Badge Gate (Nutrition / Energy)
    // ============================================================

    private var nutritionEnergyAttentionBadgeV1: Bool { // 🟨 UPDATED
        settings.showPermissionWarnings && healthStore.nutritionEnergyAnyAttentionForBadgesV1
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {

        // ============================================================
        // MARK: - Local Type Bridge
        // NutritionSectionCardScaledV2 expects [DailyStepsEntry]
        // ============================================================

        let last90StepsLike: [DailyStepsEntry] = viewModel.last90DaysData.map {
            DailyStepsEntry(date: $0.date, steps: $0.energyKcal)
        }

        MetricDetailScaffold(
            headerTitle: L10n.Common.tabNutrition,
            headerTint: Color.Glu.nutritionDomain,
            onBack: {
                appState.currentStatsScreen = .nutritionOverview
            },
            onRefresh: {
                await healthStore.refreshNutrition(.pullToRefresh)
            },
            showsPermissionBadge: nutritionEnergyAttentionBadgeV1,
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

                // Today info / hint text from ViewModel
                if let hint = viewModel.todayInfoText {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(Color.Glu.primaryBlue)
                        .padding(.horizontal, 2)
                }

                // Shared Nutrition metric card shell
                NutritionSectionCardScaledV2(
                    sectionTitle: "",
                    title: L10n.NutritionEnergy.title,

                    kpiTitle: L10n.NutritionEnergy.todayKPI,
                    kpiTargetText: viewModel.formattedDailyCaloriesGoal,
                    kpiCurrentText: viewModel.formattedTodayKcal,
                    kpiDeltaText: viewModel.kpiDeltaText,
                    kpiDeltaColor: viewModel.kpiDeltaColor,
                    hasTarget: true,

                    last90DaysData: last90StepsLike,
                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyData,

                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,

                    goalValue: viewModel.dailyCaloriesGoalInt,

                    onMetricSelected: { metric in
                        appState.handleMetricTap(metricName: metric, settings: settings)
                    },
                    metrics: AppState.nutritionVisibleMetrics,

                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: true,

                    customKpiContent: nil,
                    customChartContent: nil,

                    dailyScaleType: .energyDaily,

                    isMetricLocked: { metric in
                        !AppState.isUnlocked(metricName: metric, settings: settings)
                    },
                    onLockedMetricSelected: { _ in
                        appState.openAccountRoute(.manage)
                    },

                    // Nutrition goldstandard:
                    // each chip resolves its own attention source centrally from HealthStore
                    showsWarningBadgeForMetric: { metric in // 🟨 UPDATED
                        guard settings.showPermissionWarnings else { return false }

                        switch metric {
                        case L10n.Carbs.title:
                            return healthStore.carbsAnyAttentionForBadgesV1
                        case L10n.CarbsDayparts.title:
                            return healthStore.carbsAnyAttentionForBadgesV1
                        case L10n.Sugar.title:
                            return healthStore.sugarAnyAttentionForBadgesV1
                        case L10n.Protein.title:
                            return healthStore.proteinAnyAttentionForBadgesV1
                        case L10n.Fat.title:
                            return healthStore.fatAnyAttentionForBadgesV1
                        case L10n.NutritionEnergy.title:
                            return healthStore.nutritionEnergyAnyAttentionForBadgesV1
                        default:
                            return false
                        }
                    }
                )
            }
        }
        .task {
            await healthStore.refreshNutrition(.navigation)
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("NutritionEnergyViewV1 – Nutrition") {
    let previewStore = HealthStore.preview()
    let previewVM = NutritionEnergyViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return NutritionEnergyViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
