//
//  CarbsBolusRatioViewV1.swift
//  GluVibProbe
//
//  Metabolic V1 — Carbs / Bolus Ratio Detail Screen
//
//  Purpose
//  - Renders the carbs-to-bolus ratio metric detail screen for the Metabolic domain.
//  - Shows the current ratio hint state, KPI block, daily / period charts,
//    and the shared metabolic metric chip navigation.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → CarbsBolusRatioViewModelV1 (mapping / formatting) → CarbsBolusRatioViewV1 (render only)
//
//  Key Connections
//  - CarbsBolusRatioViewModelV1: provides formatted values, chart data and today hint state.
//  - HealthStore: provides the central metabolic badge / attention sources and refresh entry points.
//  - AppState: handles navigation and metric routing.
//  - MetabolicSectionCardScaledV1: shared metabolic card shell for chips, KPIs and charts.
//  - L10n: localized titles and labels for the carbs / bolus ratio metric.
//

import SwiftUI

struct CarbsBolusRatioViewV1: View {

    // ============================================================
    // MARK: - Dependencies (Environment)
    // ============================================================

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    // ============================================================
    // MARK: - ViewModel
    // ============================================================

    @StateObject private var viewModel: CarbsBolusRatioViewModelV1

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let onMetricSelected: (String) -> Void

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        viewModel: CarbsBolusRatioViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: CarbsBolusRatioViewModelV1())
        }
    }

    // ============================================================
    // MARK: - Header Badge
    // ============================================================

    private var showsHeaderBadgeV1: Bool { // 🟨 UPDATED
        settings.showPermissionWarnings
        && (healthStore.carbsReadAuthIssueV1 || healthStore.bolusAnyAttentionForBadgesV1)
    }

    // ============================================================
    // MARK: - Today Hint
    // ============================================================

    private var localizedTodayHint: String? { // 🟨 UPDATED
        guard settings.showPermissionWarnings else { return nil }
        guard let state = viewModel.todayInfoState else { return nil }

        switch state {
        case .noHistory:
            return L10n.CarbsBolusRatio.hintNoDataOrPermission
        case .noTodayData:
            return L10n.CarbsBolusRatio.hintNoToday
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
            return settings.hasCGM
                && settings.showPermissionWarnings
                && healthStore.glucoseReadAuthIssueV1

        case L10n.Bolus.title:
            return settings.hasCGM
                && settings.isInsulinTreated
                && settings.showPermissionWarnings
                && healthStore.bolusAnyAttentionForBadgesV1

        case L10n.Basal.title:
            return settings.hasCGM
                && settings.isInsulinTreated
                && settings.showPermissionWarnings
                && healthStore.basalAnyAttentionForBadgesV1

        case L10n.BolusBasalRatio.title:
            return settings.hasCGM
                && settings.isInsulinTreated
                && settings.showPermissionWarnings
                && (healthStore.bolusAnyAttentionForBadgesV1 || healthStore.basalAnyAttentionForBadgesV1)

        case L10n.CarbsBolusRatio.title:
            return settings.hasCGM
                && settings.isInsulinTreated
                && settings.showPermissionWarnings
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
            headerTint: Color.Glu.metabolicDomain,
            onBack: {
                appState.currentStatsScreen = .none
            },
            onRefresh: {
                await healthStore.refreshMetabolicTherapyDaily90LightV1(refreshSource: "carbsbolus-detail-pull")
            },
            showsPermissionBadge: showsHeaderBadgeV1,
            background: {
                LinearGradient(
                    colors: [
                        .white,
                        Color.Glu.metabolicDomain.opacity(0.55)
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
                    title: L10n.CarbsBolusRatio.title,
                    kpiTitle: L10n.CarbsBolusRatio.todayKPI,
                    kpiCurrentText: viewModel.formattedTodayRatio,
                    kpiSecondaryText: nil,
                    last90DaysData: viewModel.last90DaysRatioInt10,
                    periodAverages: viewModel.periodAverages,
                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    goalValue: nil,
                    onMetricSelected: { metric in // 🟨 UPDATED
                        appState.handleMetricTap(metricName: metric, settings: settings)
                    },
                    metrics: AppState.metabolicVisibleMetrics(settings: settings),
                    dailyScaleType: .ratioInt10,
                    showsWarningBadgeForMetric: { metric in
                        showsMetabolicWarningBadge(for: metric)
                    }
                )
            }
        }
        .task {
            await healthStore.refreshMetabolicTherapyDaily90LightV1(refreshSource: "carbsbolus-detail-nav")
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("CarbsBolusRatioViewV1 – Metabolic") {
    let previewStore = HealthStore.preview()
    let previewVM = CarbsBolusRatioViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    previewState.currentStatsScreen = .carbsBolusRatio

    return CarbsBolusRatioViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
