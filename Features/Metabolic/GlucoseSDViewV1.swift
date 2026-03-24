//
//  GlucoseSDViewV1.swift
//  GluVibProbe
//
//  Metabolic V1 — Glucose SD Detail Screen
//
//  Purpose
//  - Renders the glucose standard deviation metric detail screen for the Metabolic domain.
//  - Shows the current SD hint state, KPI content, daily / period charts,
//    and the shared metabolic metric chip navigation.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → GlucoseSDViewModelV1 (mapping / formatting) → GlucoseSDViewV1 (render only)
//
//  Key Connections
//  - GlucoseSDViewModelV1: provides formatted values, chart data, display units and today hint state.
//  - HealthStore: provides the central metabolic badge / attention sources and refresh entry points.
//  - AppState: provides the visible metabolic metric routing context.
//  - MetabolicSectionCardScaledV1: shared metabolic card shell for chips, KPIs and charts.
//  - L10n: localized titles and labels for the glucose SD metric.
//

import SwiftUI

struct GlucoseSDViewV1: View {

    // ============================================================
    // MARK: - Dependencies (Environment)
    // ============================================================

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    // ============================================================
    // MARK: - ViewModel
    // ============================================================

    @StateObject private var viewModel: GlucoseSDViewModelV1

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let onMetricSelected: (String) -> Void

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        viewModel: GlucoseSDViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: GlucoseSDViewModelV1())
        }
    }

    // ============================================================
    // MARK: - Capability-aware Metrics (Chips)
    // ============================================================

    private var visibleMetrics: [String] {
        AppState.metabolicVisibleMetrics(settings: settings)
    }

    // ============================================================
    // MARK: - Header Badge
    // ============================================================

    private var glucoseAttentionBadgeV1: Bool { // 🟨 UPDATED
        settings.hasCGM && settings.showPermissionWarnings && healthStore.glucoseAnyAttentionForBadgesV1
    }

    // ============================================================
    // MARK: - Today Hint
    // ============================================================

    private var localizedTodayHint: String? { // 🟨 UPDATED
        guard settings.showPermissionWarnings else { return nil }
        guard let state = viewModel.todayInfoState else { return nil }

        switch state {
        case .noHistory:
            return L10n.SD.hintNoDataOrPermission
        case .noTodayData:
            return L10n.SD.hintNoToday
        }
    }

    // ============================================================
    // MARK: - Chip Badge Mapping
    // ============================================================

    private func showsMetabolicWarningBadge(for metric: String) -> Bool {
        switch metric {

        case L10n.IG.title,
             L10n.TimeInRange.title,
             L10n.GMI.title,
             L10n.SD.title,
             L10n.CV.title,
             L10n.Range.title:
            return settings.hasCGM && healthStore.glucoseAnyAttentionForBadgesV1

        case L10n.Bolus.title:
            return settings.hasCGM && settings.isInsulinTreated && healthStore.bolusAnyAttentionForBadgesV1

        case L10n.Basal.title:
            return settings.hasCGM && settings.isInsulinTreated && healthStore.basalAnyAttentionForBadgesV1

        case L10n.BolusBasalRatio.title:
            return settings.hasCGM
                && settings.isInsulinTreated
                && (healthStore.bolusAnyAttentionForBadgesV1 || healthStore.basalAnyAttentionForBadgesV1)

        case L10n.CarbsBolusRatio.title:
            return settings.hasCGM
                && settings.isInsulinTreated
                && (healthStore.carbsReadAuthIssueV1 || healthStore.bolusAnyAttentionForBadgesV1)

        default:
            return false
        }
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        MetricDetailScaffold(
            headerTitle: L10n.Common.metabolicHeader,
            headerTint: Color.Glu.metabolicDomain, // 🟨 UPDATED
            onBack: {
                appState.currentStatsScreen = .none
            },
            onRefresh: {
                await healthStore.refreshMetabolic(.pullToRefresh)
            },
            showsPermissionBadge: glucoseAttentionBadgeV1,
            background: {
                LinearGradient(
                    colors: [
                        .white,
                        Color.Glu.metabolicDomain.opacity(0.55) // 🟨 UPDATED
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

                // Shared Metabolic metric card shell
                MetabolicSectionCardScaledV1(
                    title: L10n.SD.title,
                    kpiTitle: L10n.SD.todayKPI,
                    kpiCurrentText: viewModel.formattedTodaySDKPI,
                    kpiSecondaryText: nil,
                    last90DaysData: viewModel.last90DaysChartData,
                    periodAverages: viewModel.periodAverages,
                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    goalValue: nil,
                    onMetricSelected: { metric in // 🟨 UPDATED
                        appState.handleMetricTap(metricName: metric, settings: settings)
                    },
                    metrics: visibleMetrics,
                    dailyScaleType: .glucoseSdMgdl,
                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: false,
                    customKpiContent: AnyView(
                        HStack(spacing: 12) {

                            KPICard(
                                title: L10n.SD.last24hKPI,
                                valueText: viewModel.formattedLast24hSDKPI,
                                unit: viewModel.sdDisplayUnitText,
                                domain: .metabolic
                            )

                            KPICard(
                                title: L10n.SD.todayKPI,
                                valueText: viewModel.formattedTodaySDKPI,
                                unit: viewModel.sdDisplayUnitText,
                                domain: .metabolic
                            )

                            KPICard(
                                title: L10n.SD.average90dKPI,
                                valueText: viewModel.formatted90dSDKPI,
                                unit: viewModel.sdDisplayUnitText,
                                domain: .metabolic
                            )
                        }
                        .padding(.bottom, 8)
                    ),
                    customChartContent: nil,
                    customDailyChartBuilder: nil,
                    customPeriodChartContent: nil,
                    showsWarningBadgeForMetric: { metric in
                        showsMetabolicWarningBadge(for: metric)
                    }
                )
            }
        }
        .task {
            await healthStore.refreshMetabolic(.navigation)
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("GlucoseSDViewV1 – Metabolic") {
    let previewStore = HealthStore.preview()
    let previewVM = GlucoseSDViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    previewState.currentStatsScreen = .SD

    return GlucoseSDViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
