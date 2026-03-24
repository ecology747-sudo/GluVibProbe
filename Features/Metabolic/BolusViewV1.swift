//
//  BolusViewV1.swift
//  GluVibProbe
//
//  Metabolic V1 — Bolus Detail Screen
//
//  Purpose
//  - Renders the bolus metric detail screen for the Metabolic domain.
//  - Shows the current bolus hint state, KPI block, daily / period charts,
//    and the shared metabolic metric chip navigation.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → BolusViewModelV1 (mapping / formatting) → BolusViewV1 (render only)
//
//  Key Connections
//  - BolusViewModelV1: provides formatted values, chart data and today hint state.
//  - HealthStore: provides the central metabolic badge / attention sources and refresh entry points.
//  - AppState: provides the visible metabolic metric routing context.
//  - MetabolicSectionCardScaledV1: shared metabolic card shell for chips, KPIs and charts.
//  - L10n: localized titles and labels for the bolus metric.
//

import SwiftUI

struct BolusViewV1: View {

    // ============================================================
    // MARK: - Dependencies (Environment)
    // ============================================================

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    // ============================================================
    // MARK: - ViewModel
    // ============================================================

    @StateObject private var viewModel: BolusViewModelV1

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let onMetricSelected: (String) -> Void

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        viewModel: BolusViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: BolusViewModelV1())
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
            return L10n.Bolus.hintNoDataOrPermission
        case .noTodayData:
            return L10n.Bolus.hintNoToday
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
            return settings.hasCGM && healthStore.glucoseReadAuthIssueV1

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

        // ============================================================
        // MARK: - Local Type Bridge
        // MetabolicSectionCardScaledV1 expects [DailyStepsEntry]
        // ============================================================

        let last90StepsLike: [DailyStepsEntry] = viewModel.last90DaysData.map {
            DailyStepsEntry(
                date: $0.date,
                steps: Int($0.bolusUnits.rounded())
            )
        }

        MetricDetailScaffold(
            headerTitle: L10n.Common.metabolicHeader,
            headerTint: Color.Glu.metabolicDomain,
            onBack: {
                appState.currentStatsScreen = .none
            },
            onRefresh: {
                await healthStore.refreshMetabolicTherapyDaily90LightV1(refreshSource: "bolus-detail-pull")
            },
            showsPermissionBadge: settings.showPermissionWarnings && healthStore.bolusAnyAttentionForBadgesV1,
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

                if let hint = localizedTodayHint { // 🟨 UPDATED
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(Color.Glu.primaryBlue)
                        .padding(.horizontal, 2)
                }

                MetabolicSectionCardScaledV1(
                    title: L10n.Bolus.title,
                    kpiTitle: L10n.Bolus.todayKPI,
                    kpiCurrentText: viewModel.formattedTodayBolus,
                    kpiSecondaryText: nil,
                    last90DaysData: last90StepsLike,
                    periodAverages: viewModel.periodAverages,
                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,
                    goalValue: nil,
                    onMetricSelected: { metric in // 🟨 UPDATED
                        appState.handleMetricTap(metricName: metric, settings: settings)
                    },
                    metrics: AppState.metabolicVisibleMetrics(settings: settings),
                    dailyScaleType: .insulinUnitsDaily,
                    showsWarningBadgeForMetric: { metric in
                        showsMetabolicWarningBadge(for: metric)
                    }
                )
            }
        }
        .task {
            await healthStore.refreshMetabolicTherapyDaily90LightV1(refreshSource: "bolus-detail-nav")
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("BolusViewV1 – Metabolic") {
    let previewStore = HealthStore.preview()
    let previewVM = BolusViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return BolusViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
