//
//  BMIViewV1.swift
//  GluVibProbe
//
//  Body V1 — BMI Detail Screen
//
//  Purpose
//  - Renders the BMI metric detail screen for the Body domain.
//  - Shows the current BMI hint state, KPI block, daily / period charts,
//    and the shared body metric chip navigation.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → BMIViewModelV1 (mapping / formatting) → BMIViewV1 (render only)
//
//  Key Connections
//  - BMIViewModelV1: provides formatted KPI values, chart data and today hint text.
//  - HealthStore: provides central badge / attention sources for body warning logic.
//  - AppState: handles metric routing and back navigation.
//  - BodySectionCardScaledV2: shared body card shell for chips, KPIs and charts.
//  - L10n: localized titles and labels for the body / BMI metric.
//

import SwiftUI

struct BMIViewV1: View {

    // ============================================================
    // MARK: - Dependencies (Environment)
    // ============================================================

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject var settings: SettingsModel

    // ============================================================
    // MARK: - ViewModel
    // ============================================================

    @StateObject private var viewModel: BMIViewModelV1

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let onMetricSelected: (String) -> Void

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        viewModel: BMIViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: BMIViewModelV1())
        }
    }

    // ============================================================
    // MARK: - Header Badge Gate (Body / BMI)
    // ============================================================

    private var bmiAttentionBadgeV1: Bool {
        settings.showPermissionWarnings && healthStore.bmiAnyAttentionForBadgesV1 // 🟨 UPDATED
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
            showsPermissionBadge: bmiAttentionBadgeV1,
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

                if let hint = viewModel.todayInfoText {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(Color.Glu.primaryBlue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                }

                BodySectionCardScaledV2(
                    sectionTitle: "",
                    title: L10n.BMI.title,

                    kpiTitle: L10n.BMI.todayKPI,
                    kpiTargetText: "–",
                    kpiCurrentText: viewModel.currentText,
                    kpiDeltaText: "–",
                    kpiDeltaColor: nil,
                    hasTarget: false,

                    last90DaysDoubleData: viewModel.last90DaysForChart,
                    periodAverages: viewModel.periodAverages,
                    monthlyData: [],

                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,

                    goalValue: nil,

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

#Preview("BMIViewV1 – Body") {
    let previewStore = HealthStore.preview()
    let previewVM = BMIViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return BMIViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
