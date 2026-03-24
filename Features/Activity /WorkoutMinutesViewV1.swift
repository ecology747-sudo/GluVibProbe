//
//  WorkoutMinutesViewV1.swift
//  GluVibProbe
//
//  Activity V1 — Workout Minutes Detail Screen
//
//  Purpose
//  - Renders the workout minutes metric detail screen for the Activity domain.
//  - Shows the current workout minutes hint state, KPI block, daily / period / monthly charts,
//    and the shared activity metric chip navigation.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → WorkoutMinutesViewModelV1 (mapping / formatting) → WorkoutMinutesViewV1 (render only)
//
//  Key Connections
//  - WorkoutMinutesViewModelV1: provides formatted values, chart data and today hint state.
//  - HealthStore: provides the central activity badge / attention sources.
//  - AppState: handles navigation and metric routing.
//  - ActivitySectionCardScaledV2: shared activity card shell for chips, KPIs and charts.
//  - L10n: localized titles and labels for the workout minutes metric.
//

import SwiftUI

struct WorkoutMinutesViewV1: View {

    // ============================================================
    // MARK: - Dependencies (Environment)
    // ============================================================

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject var settings: SettingsModel

    // ============================================================
    // MARK: - ViewModel
    // ============================================================

    @StateObject private var viewModel: WorkoutMinutesViewModelV1

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let onMetricSelected: (String) -> Void

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        viewModel: WorkoutMinutesViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: WorkoutMinutesViewModelV1())
        }
    }

    // ============================================================
    // MARK: - Today Hint
    // ============================================================

    private var localizedTodayHint: String? { // 🟨 UPDATED
        guard settings.showPermissionWarnings else { return nil }
        guard let state = viewModel.todayInfoState else { return nil }

        switch state {
        case .noHistory:
            return L10n.WorkoutMinutes.hintNoDataOrPermission
        case .noTodayData:
            return L10n.WorkoutMinutes.hintNoToday
        }
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        MetricDetailScaffold(
            headerTitle: L10n.Common.activity,
            headerTint: Color.Glu.activityDomain,
            onBack: {
                appState.currentStatsScreen = .none
            },
            onRefresh: {
                await healthStore.refreshActivity(.pullToRefresh)
            },
            showsPermissionBadge: settings.showPermissionWarnings && healthStore.workoutMinutesAnyAttentionForBadgesV1, // 🟨 UPDATED
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

                // Today info / hint text from ViewModel
                if let hint = localizedTodayHint { // 🟨 UPDATED
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(Color.Glu.primaryBlue)
                        .padding(.horizontal, 2)
                }

                // Shared Activity metric card shell
                ActivitySectionCardScaledV2(
                    sectionTitle: "",
                    title: L10n.WorkoutMinutes.title,
                    kpiTitle: L10n.WorkoutMinutes.todayKPI,
                    kpiTargetText: viewModel.kpiTargetText,
                    kpiCurrentText: viewModel.formattedToday,
                    kpiDeltaText: viewModel.kpiDeltaText,
                    kpiDeltaColor: viewModel.kpiDeltaColor,
                    hasTarget: false,
                    last90DaysData: viewModel.last90DaysData,
                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyDataRaw,
                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,
                    goalValue: 0,
                    onMetricSelected: { metric in
                        appState.handleMetricTap(metricName: metric, settings: settings)
                    },
                    metrics: AppState.activityVisibleMetrics,
                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: true,
                    customKpiContent: nil,
                    customChartContent: nil,
                    dailyScaleType: .workoutMinutes,
                    isMetricLocked: { metric in
                        !AppState.isUnlocked(metricName: metric, settings: settings)
                    },
                    onLockedMetricSelected: { metric in
                        appState.handleMetricTap(metricName: metric, settings: settings)
                    },
                    showsWarningBadgeForMetric: { metric in
                        guard settings.showPermissionWarnings else { return false }

                        switch metric {
                        case L10n.Steps.title:
                            return healthStore.stepsAnyAttentionForBadgesV1
                        case L10n.WorkoutMinutes.title:
                            return healthStore.workoutMinutesAnyAttentionForBadgesV1
                        case L10n.ActivityEnergy.title:
                            return healthStore.activeEnergyAnyAttentionForBadgesV1 // 🟨 UPDATED
                        case L10n.MovementSplit.title:
                            return healthStore.movementSplitAnyAttentionForBadgesV1 // 🟨 UPDATED
                        default:
                            return false
                        }
                    }
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

#Preview("WorkoutMinutesViewV1 – Activity") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()
    let previewVM = WorkoutMinutesViewModelV1(healthStore: previewStore)

    return WorkoutMinutesViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
