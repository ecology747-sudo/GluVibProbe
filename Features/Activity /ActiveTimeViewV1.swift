//
//  ActiveTimeViewV1.swift
//  GluVibProbe
//
//  Activity V1 — Active Time Detail Screen
//
//  Purpose
//  - Renders the active time metric detail screen for the Activity domain.
//  - Shows the KPI block, daily / period / monthly charts,
//    and the shared activity metric chip navigation.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → ActiveTimeViewModelV1 (mapping / formatting) → ActiveTimeViewV1 (render only)
//
//  Key Connections
//  - ActiveTimeViewModelV1: provides formatted values and chart data.
//  - HealthStore: provides the central activity refresh entry points.
//  - AppState: handles navigation back to the activity flow.
//  - ActivitySectionCardScaledV2: shared activity card shell for chips, KPIs and charts.
//

import SwiftUI

struct ActiveTimeViewV1: View {

    // ============================================================
    // MARK: - Dependencies (Environment)
    // ============================================================

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    // ============================================================
    // MARK: - ViewModel
    // ============================================================

    @StateObject private var viewModel: ActiveTimeViewModelV1

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let onMetricSelected: (String) -> Void

    // ============================================================
    // MARK: - Init
    // ============================================================

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

    // ============================================================
    // MARK: - Body
    // ============================================================

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

                // Shared Activity metric card shell
                ActivitySectionCardScaledV2(
                    sectionTitle: "",
                    title: "Active Time",
                    kpiTitle: "Active Time Today",
                    kpiTargetText: "–",
                    kpiCurrentText: viewModel.formattedTodayActiveTime,
                    kpiDeltaText: "–",
                    kpiDeltaColor: nil,
                    hasTarget: false,
                    last90DaysData: viewModel.last90DaysChartData,
                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyData,
                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,
                    goalValue: nil,
                    onMetricSelected: onMetricSelected,
                    metrics: AppState.activityVisibleMetrics,
                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: true,
                    customKpiContent: nil,
                    customChartContent: nil,
                    dailyScaleType: .exerciseMinutes
                )
            }
        }
        .task {
            await healthStore.refreshActivity(.navigation)
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("ActiveTimeViewV1 – Activity") {
    let previewStore = HealthStore.preview()
    let previewVM = ActiveTimeViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return ActiveTimeViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
