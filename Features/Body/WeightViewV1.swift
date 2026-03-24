//
//  WeightViewV1.swift
//  GluVibProbe
//
//  Body V1 — Weight Detail Screen
//
//  Purpose
//  - Renders the weight metric detail screen for the Body domain.
//  - Shows the current weight hint state, KPI block, daily / period charts,
//    and the shared body metric chip navigation.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → WeightViewModelV1 (mapping / formatting) → WeightViewV1 (render only)
//
//  Key Connections
//  - WeightViewModelV1: provides formatted KPI values, chart data and today hint text.
//  - HealthStore: provides central badge / attention sources for body warning logic.
//  - AppState: handles metric routing and back navigation.
//  - BodySectionCardScaledV2: shared body card shell for chips, KPIs and charts.
//  - L10n: localized titles and labels for the body / weight metric.
//

import SwiftUI

struct WeightViewV1: View {

    // ============================================================
    // MARK: - Dependencies (Environment)
    // ============================================================

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    // ============================================================
    // MARK: - ViewModel
    // ============================================================

    @StateObject private var viewModel: WeightViewModelV1

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let onMetricSelected: (String) -> Void

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        viewModel: WeightViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(
                wrappedValue: WeightViewModelV1(
                    healthStore: .shared,
                    settings: .shared
                )
            )
        }
    }

    // ============================================================
    // MARK: - Header Badge Gate (Body / Weight)
    // ============================================================

    private var weightAttentionBadgeV1: Bool { // 🟨 UPDATED
        settings.showPermissionWarnings && healthStore.weightAnyAttentionForBadgesV1
    }

    // ============================================================
    // MARK: - Chip Badge Mapping
    // ============================================================

    private func showsBodyWarningBadge(for metric: String) -> Bool { // 🟨 UPDATED
        guard settings.showPermissionWarnings else { return false }

        switch metric {
        case L10n.Weight.title:
            return healthStore.weightAnyAttentionForBadgesV1
        case L10n.Sleep.title:
            return healthStore.sleepAnyAttentionForBadgesV1
        case L10n.BMI.title:
            return healthStore.bmiAnyAttentionForBadgesV1
        case L10n.BodyFat.title:
            return healthStore.bodyFatAnyAttentionForBadgesV1
        case L10n.RestingHeartRate.title:
            return healthStore.restingHeartRateAnyAttentionForBadgesV1
        default:
            return false
        }
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        MetricDetailScaffold(
            headerTitle: L10n.Common.tabBody,
            headerTint: Color.Glu.bodyDomain,
            onBack: {
                appState.currentStatsScreen = .none
            },
            onRefresh: {
                await healthStore.refreshBody(.pullToRefresh)
            },
            showsPermissionBadge: weightAttentionBadgeV1,
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

                // Today info / hint text from ViewModel
                if let hint = viewModel.todayInfoText { // 🟨 UPDATED
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(Color.Glu.primaryBlue)
                        .padding(.horizontal, 2)
                }

                // Shared Body metric card shell
                BodySectionCardScaledV2(
                    sectionTitle: "",
                    title: L10n.Weight.title,

                    kpiTitle: L10n.Weight.todayKPI,
                    kpiTargetText: viewModel.targetText,
                    kpiCurrentText: viewModel.currentText,
                    kpiDeltaText: viewModel.deltaText,
                    kpiDeltaColor: viewModel.deltaColor,
                    hasTarget: true,

                    last90DaysDoubleData: viewModel.last90DaysForChart,
                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyForChart,

                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,

                    goalValue: Int(viewModel.targetWeightKg.rounded()),

                    onMetricSelected: { metric in
                        appState.handleMetricTap(metricName: metric, settings: settings)
                    },
                    metrics: AppState.bodyVisibleMetrics,

                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: false,

                    customKpiContent: nil,
                    customChartContent: nil,

                    dailyScaleType: .weightKg,
                    chartStyle: .bar,

                    isMetricLocked: { metric in
                        !AppState.isUnlocked(metricName: metric, settings: settings)
                    },
                    onLockedMetricSelected: { metric in
                        appState.handleMetricTap(metricName: metric, settings: settings)
                    },

                    showsWarningBadgeForMetric: { metric in
                        showsBodyWarningBadge(for: metric) // 🟨 UPDATED
                    }
                )
            }
        }
        .task {
            await healthStore.refreshBody(.navigation)
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("WeightViewV1 – Body") {
    let previewStore = HealthStore.preview()
    let previewVM = WeightViewModelV1(healthStore: previewStore)
    let previewState = AppState()
    let previewSettings = SettingsModel.shared

    return WeightViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(previewSettings)
}
