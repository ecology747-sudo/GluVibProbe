//
//  RestingHeartRateViewV1.swift
//  GluVibProbe
//
//  Body V1 — Resting Heart Rate Detail Screen
//
//  Purpose
//  - Renders the resting heart rate metric detail screen for the Body domain.
//  - Shows the current resting-heart-rate hint state, KPI block, daily / period charts,
//    and the shared body metric chip navigation.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → RestingHeartRateViewModelV1 (mapping / formatting) → RestingHeartRateViewV1 (render only)
//
//  Key Connections
//  - RestingHeartRateViewModelV1: provides formatted KPI values, chart data and today hint text.
//  - HealthStore: provides central badge / attention sources for body warning logic.
//  - AppState: handles metric routing and back navigation.
//  - BodySectionCardScaledV2: shared body card shell for chips, KPIs and charts.
//  - L10n: localized titles and labels for the body / resting-heart-rate metric.
//

import SwiftUI

struct RestingHeartRateViewV1: View {

    // ============================================================
    // MARK: - Dependencies (Environment)
    // ============================================================

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject var settings: SettingsModel

    // ============================================================
    // MARK: - ViewModel
    // ============================================================

    @StateObject private var viewModel: RestingHeartRateViewModelV1

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let onMetricSelected: (String) -> Void

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        viewModel: RestingHeartRateViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: RestingHeartRateViewModelV1())
        }
    }

    // ============================================================
    // MARK: - Header Badge Gate (Body / Resting Heart Rate)
    // ============================================================

    private var restingHeartRateAttentionBadgeV1: Bool {
        settings.showPermissionWarnings && healthStore.restingHeartRateAnyAttentionForBadgesV1 // 🟨 UPDATED
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
            showsPermissionBadge: restingHeartRateAttentionBadgeV1,
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
                        .frame(maxWidth: .infinity, alignment: .leading) // 🟨 UPDATED
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                }

                BodySectionCardScaledV2(
                    sectionTitle: "",
                    title: L10n.RestingHeartRate.title,

                    kpiTitle: L10n.RestingHeartRate.todayKPI,
                    kpiTargetText: "–",
                    kpiCurrentText: viewModel.formattedTodayRestingHR,
                    kpiDeltaText: "–",
                    kpiDeltaColor: nil,
                    hasTarget: false,

                    last90DaysData: viewModel.last90DaysDataForChart,
                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyData,

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

                    dailyScaleType: .heartRateBpm,
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

#Preview("RestingHeartRateViewV1 – Body") {
    let previewStore = HealthStore.preview()
    let previewVM = RestingHeartRateViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return RestingHeartRateViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
