//
//  IGViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct IGViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    @StateObject private var viewModel: InterstitialGlucoseViewModelV1

    let onMetricSelected: (String) -> Void

    private let color = Color.Glu.metabolicDomain

    init(
        viewModel: InterstitialGlucoseViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: InterstitialGlucoseViewModelV1())
        }
    }

    // ============================================================
    // MARK: - Unit Helpers (mg/dL ↔ mmol/L) — Display only
    // ============================================================

    private var unitLabel: String {
        settings.glucoseUnit.label
    }

    private var unitDigits: Int {
        (settings.glucoseUnit == .mgdL) ? 0 : 1
    }

    private func formattedGlucoseFromMgdl(_ mgdl: Double?) -> String {
        let v = mgdl ?? 0
        guard v > 0 else { return "–" }
        return settings.glucoseUnit.formattedNumber(fromMgdl: v, fractionDigits: unitDigits)
    }

    private func formattedGlucoseFromMgdlInt(_ mgdlInt: Int) -> String {
        guard mgdlInt > 0 else { return "–" }
        return settings.glucoseUnit.formattedNumber(fromMgdl: Double(mgdlInt), fractionDigits: unitDigits)
    }

    // ============================================================
    // MARK: - KPI Values
    // ============================================================

    private var formattedLast24hIG: String {
        formattedGlucoseFromMgdl(healthStore.last24hGlucoseMeanMgdl)
    }

    private var formattedTodayIG: String {
        formattedGlucoseFromMgdlInt(viewModel.todayMeanMgdl)
    }

    private var formattedIG90d: String {
        formattedGlucoseFromMgdlInt(viewModel.ig90dMeanMgdl)
    }

    // ============================================================
    // MARK: - Axis Label Fix (ticks stay mg/dL, labels follow Settings)
    // ============================================================

    private var dailyScaleDisplay: MetricScaleResult {
        let base = viewModel.dailyScale
        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { v in
                settings.glucoseUnit.formattedNumber(fromMgdl: v, fractionDigits: unitDigits)
            }
        )
    }

    private var periodScaleDisplay: MetricScaleResult {
        let base = viewModel.periodScale
        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { v in
                settings.glucoseUnit.formattedNumber(fromMgdl: v, fractionDigits: unitDigits)
            }
        )
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
            return L10n.IG.hintNoDataOrPermission
        case .noTodayData:
            return L10n.IG.hintNoToday
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
            headerTint: color,
            onBack: { appState.currentStatsScreen = .none },
            onRefresh: { await healthStore.refreshMetabolic(.pullToRefresh) },
            showsPermissionBadge: glucoseAttentionBadgeV1, // 🟨 NEW
            background: {
                LinearGradient(
                    colors: [.white, color.opacity(0.55)],
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
                    title: L10n.IG.title,

                    kpiTitle: L10n.IG.meanKPI,
                    kpiCurrentText: formattedTodayIG,
                    kpiSecondaryText: unitLabel,

                    last90DaysData: viewModel.last90DaysChartData,
                    periodAverages: viewModel.periodAverages,

                    dailyScale: dailyScaleDisplay,
                    periodScale: periodScaleDisplay,

                    goalValue: nil,

                    onMetricSelected: onMetricSelected,
                    metrics: AppState.metabolicVisibleMetrics(settings: settings),

                    dailyScaleType: .glucoseMeanMgdl,

                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: false,

                    customKpiContent: AnyView(
                        HStack(spacing: 12) {

                            KPICard(
                                title: L10n.IG.last24hKPI,
                                valueText: formattedLast24hIG,
                                unit: unitLabel,
                                domain: .metabolic
                            )

                            KPICard(
                                title: L10n.IG.todayKPI,
                                valueText: formattedTodayIG,
                                unit: unitLabel,
                                domain: .metabolic
                            )

                            KPICard(
                                title: L10n.IG.average90dKPI,
                                valueText: formattedIG90d,
                                unit: unitLabel,
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

private struct IGViewV1_PreviewWrapper: View {
    var body: some View {
        let previewStore = HealthStore.preview()
        let previewVM = InterstitialGlucoseViewModelV1(healthStore: previewStore)
        let previewState = AppState()
        previewState.currentStatsScreen = .ig

        return IGViewV1(viewModel: previewVM)
            .environmentObject(previewStore)
            .environmentObject(previewState)
            .environmentObject(SettingsModel.shared)
    }
}

#Preview("IGViewV1 – Metabolic") {
    IGViewV1_PreviewWrapper()
}
