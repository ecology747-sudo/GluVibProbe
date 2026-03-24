//
//  StepsViewV1.swift
//  GluVibProbe
//
//  Activity V1 — Steps Detail Screen
//
//  Purpose
//  - Renders the steps metric detail screen for the Activity domain.
//  - Shows the current steps hint state, KPI block, daily / period / monthly charts,
//    and the shared activity metric chip navigation.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → StepsViewModelV1 (mapping / formatting) → StepsViewV1 (render only)
//
//  Key Connections
//  - StepsViewModelV1: provides formatted values, chart data and today hint state.
//  - HealthStore: provides the central activity badge / attention sources.
//  - AppState: handles navigation and metric routing.
//  - ActivitySectionCardScaledV2: shared activity card shell for chips, KPIs and charts.
//  - L10n: localized titles and labels for the steps metric.
//

import SwiftUI

struct StepsViewV1: View {

    // ============================================================
    // MARK: - Dependencies (Environment)
    // ============================================================

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject var settings: SettingsModel

    // ============================================================
    // MARK: - ViewModel
    // ============================================================

    @StateObject private var viewModel: StepsViewModelV1

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let onMetricSelected: (String) -> Void

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        viewModel: StepsViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: StepsViewModelV1())
        }
    }

    // ============================================================
    // MARK: - Today Hint
    // ============================================================

    private var localizedTodayHint: String? {
        guard settings.showPermissionWarnings else { return nil }
        guard let state = viewModel.todayInfoState else { return nil }

        switch state {
        case .noHistory:
            return L10n.Steps.hintNoDataOrPermission
        case .noTodayData:
            return L10n.Steps.hintNoToday
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
            showsPermissionBadge: settings.showPermissionWarnings && healthStore.stepsAnyAttentionForBadgesV1,
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

                if let hint = localizedTodayHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(Color.Glu.primaryBlue)
                        .padding(.horizontal, 2)
                }

                ActivitySectionCardScaledV2(
                    sectionTitle: "",
                    title: L10n.Steps.title,
                    kpiTitle: L10n.Steps.todayKPI,
                    kpiTargetText: viewModel.formattedDailyStepGoal,
                    kpiCurrentText: viewModel.formattedTodaySteps,
                    kpiDeltaText: viewModel.kpiDeltaText,
                    kpiDeltaColor: viewModel.kpiDeltaColor,
                    hasTarget: true,
                    monthlyChartTitle: L10n.Steps.monthlyTitle,
                    last90DaysData: viewModel.last90DaysData,
                    periodAverages: viewModel.periodAverages,
                    monthlyData: viewModel.monthlyStepsData,
                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    monthlyScale: viewModel.monthlyScale,
                    goalValue: viewModel.dailyStepsGoalInt,
                    onMetricSelected: { metricName in
                        appState.handleMetricTap(metricName: metricName, settings: settings)
                    },
                    metrics: AppState.activityVisibleMetrics,
                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: true,
                    customKpiContent: nil,
                    customChartContent: nil,
                    customDailyChartBuilder: nil,
                    dailyScaleType: MetricScaleHelper.MetricScaleType.steps,
                    isMetricLocked: { metric in
                        !AppState.isUnlocked(metricName: metric, settings: settings)
                    },
                    onLockedMetricSelected: { metric in
                        appState.handleMetricTap(metricName: metric, settings: settings)
                    },
                    showsWarningBadgeForMetric: { metric in // 🟨 UPDATED
                        guard settings.showPermissionWarnings else { return false }

                        switch metric {
                        case L10n.Steps.title:
                            return healthStore.stepsAnyAttentionForBadgesV1
                        case L10n.WorkoutMinutes.title:
                            return healthStore.workoutMinutesAnyAttentionForBadgesV1
                        case L10n.ActivityEnergy.title:
                            return healthStore.activeEnergyAnyAttentionForBadgesV1
                        case L10n.MovementSplit.title:
                            return healthStore.movementSplitAnyAttentionForBadgesV1
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

#Preview("StepsViewV1 – Activity") {
    let previewStore = HealthStore.preview()
    let previewVM = StepsViewModelV1(healthStore: previewStore)
    let previewState = AppState()
    let previewSettings = SettingsModel.shared

    return StepsViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(previewSettings)
}
