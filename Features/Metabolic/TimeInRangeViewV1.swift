//
//  TimeInRangeViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct TimeInRangeViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    @StateObject private var viewModel: TimeInRangeViewModelV1

    let onMetricSelected: (String) -> Void

    init(
        viewModel: TimeInRangeViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: TimeInRangeViewModelV1())
        }
    }

    // ============================================================
    // MARK: - Fixed Scale (TIR 0...100)
    // ============================================================

    private var fixedPercentScale: MetricScaleResult {
        MetricScaleHelper.scale([100], for: .percent0to100)
    }

    // ============================================================
    // MARK: - Header Badge
    // ============================================================

    private var glucoseAttentionBadgeV1: Bool { // 🟨 NEW
        settings.hasCGM && settings.showPermissionWarnings && healthStore.glucoseAnyAttentionForBadgesV1
    }

    // ============================================================
    // MARK: - Today Hint
    // ============================================================

    private var localizedTodayHint: String? { // 🟨 NEW
        guard settings.showPermissionWarnings else { return nil }
        guard let state = viewModel.todayInfoState else { return nil }

        switch state {
        case .noHistory:
            return L10n.TimeInRange.hintNoDataOrPermission
        case .noTodayData:
            return L10n.TimeInRange.hintNoToday
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
            return settings.hasCGM && healthStore.glucoseAnyAttentionForBadgesV1 // 🟨 NEW

        case L10n.Bolus.title:
            return settings.hasCGM && settings.isInsulinTreated && healthStore.bolusAnyAttentionForBadgesV1 // 🟨 NEW

        case L10n.Basal.title:
            return settings.hasCGM && settings.isInsulinTreated && healthStore.basalAnyAttentionForBadgesV1 // 🟨 NEW

        case L10n.BolusBasalRatio.title:
            return settings.hasCGM
                && settings.isInsulinTreated
                && (healthStore.bolusAnyAttentionForBadgesV1 || healthStore.basalAnyAttentionForBadgesV1) // 🟨 NEW

        case L10n.CarbsBolusRatio.title:
            return settings.hasCGM
                && settings.isInsulinTreated
                && (healthStore.carbsReadAuthIssueV1 || healthStore.bolusAnyAttentionForBadgesV1) // 🟨 NEW

        default:
            return false
        }
    }

    var body: some View {

        MetricDetailScaffold(
            headerTitle: L10n.Common.metabolicHeader,
            headerTint: Color.Glu.metabolicDomain, // 🟨 UPDATED
            onBack: { appState.currentStatsScreen = .none },
            onRefresh: { await healthStore.refreshMetabolic(.pullToRefresh) },
            showsPermissionBadge: glucoseAttentionBadgeV1,
            background: {
                LinearGradient(
                    colors: [.white, Color.Glu.metabolicDomain.opacity(0.55)], // 🟨 UPDATED
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {

                if let hint = localizedTodayHint { // 🟨 NEW
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(Color.Glu.primaryBlue)
                        .padding(.horizontal, 2)
                }

                MetabolicSectionCardScaledV1(
                    title: L10n.TimeInRange.title,

                    kpiTitle: L10n.TimeInRange.targetKPI,
                    kpiCurrentText: viewModel.formattedTodayTIRPercent,
                    kpiSecondaryText: nil,

                    last90DaysData: viewModel.last90DaysChartData,
                    periodAverages: viewModel.periodAverages,

                    dailyScale: fixedPercentScale,
                    periodScale: fixedPercentScale,

                    goalValue: Double(settings.tirTargetPercent),

                    onMetricSelected: onMetricSelected,
                    metrics: AppState.metabolicVisibleMetrics(settings: settings),

                    dailyScaleType: .percent0to100,

                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: false,

                    customKpiContent: AnyView(
                        HStack(spacing: 12) {

                            KPICard(
                                title: L10n.TimeInRange.targetKPI,
                                valueText: "\(settings.tirTargetPercent)%",
                                unit: nil,
                                domain: .metabolic
                            )

                            KPICard(
                                title: L10n.TimeInRange.todayKPI,
                                valueText: viewModel.formattedTodayTIRPercent,
                                unit: nil,
                                domain: .metabolic
                            )

                            KPICard(
                                title: L10n.TimeInRange.deltaKPI,
                                valueText: "\(viewModel.kpiDeltaText)%",
                                unit: nil,
                                valueColor: viewModel.kpiDeltaColor,
                                domain: .metabolic
                            )
                        }
                        .padding(.bottom, 8)
                    ),

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

// MARK: - Preview

#Preview("TimeInRangeViewV1 – Metabolic") {
    let previewStore = HealthStore.preview()
    let previewVM = TimeInRangeViewModelV1(healthStore: previewStore)
    let previewState = AppState()
    previewState.currentStatsScreen = .timeInRange

    return TimeInRangeViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
