//
//  GMIViewV1.swift
//  GluVibProbe
//
//  Metabolic V1 — GMI Detail Screen
//
//  Purpose
//  - Renders the GMI metric detail screen for the Metabolic domain.
//  - Shows the current GMI hint state, KPI content, period chart,
//    metric chip navigation and the read-only HbA1c lab values card.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → GMIViewModelV1 (mapping / formatting) → GMIViewV1 (render only)
//
//  Key Connections
//  - GMIViewModelV1: provides formatted values, chart data and today hint state.
//  - HealthStore: provides the central metabolic badge / attention sources and refresh entry points.
//  - AppState: provides the visible metabolic metric routing context.
//  - MetricChipGroup: renders the visible metabolic metric chips.
//  - AveragePeriodsScaledBarChart: renders the period-based GMI comparison chart.
//  - MetabolicHbA1cLabValuesCardV1: renders read-only HbA1c lab values from Settings.
//  - L10n: localized titles and labels for the GMI metric.
//

import SwiftUI

struct GMIViewV1: View {

    // ============================================================
    // MARK: - Dependencies (Environment)
    // ============================================================

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    // ============================================================
    // MARK: - ViewModel
    // ============================================================

    @StateObject private var viewModel: GMIViewModelV1

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let onMetricSelected: (String) -> Void

    // ============================================================
    // MARK: - Styling
    // ============================================================

    private let color = Color.Glu.metabolicDomain

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        viewModel: GMIViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: GMIViewModelV1())
        }
    }

    // ============================================================
    // MARK: - Capability-aware Metrics (Chips)
    // ============================================================

    private var visibleMetrics: [String] {
        AppState.metabolicVisibleMetrics(settings: settings)
    }

    private var row1: [String] {
        Array(visibleMetrics.prefix(4))
    }

    private var row2: [String] {
        Array(visibleMetrics.dropFirst(4))
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
            return L10n.GMI.hintNoDataOrPermission
        case .noTodayData:
            return L10n.GMI.hintNoToday
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
    // MARK: - Target (GMI in Int*10 scale)
    // ============================================================

    private var goalValueInt10: Double? {
        let v = max(0, settings.gmi90TargetPercent)
        guard v > 0 else { return nil }
        return (v * 10.0).rounded()
    }

    // ============================================================
    // MARK: - Dynamic Y-Axis (based on max bar) — Int*10
    // ============================================================

    private var gmiValuesInt10: [Double] {
        viewModel.periodAverages.map { Double($0.value) }.filter { $0 > 0 }
    }

    private var yMaxInt10: Double {
        let maxV = gmiValuesInt10.max() ?? 0
        guard maxV > 0 else { return 100 }
        let padded = maxV * 1.15
        return ceil(padded / 5.0) * 5.0
    }

    private var yTicksInt10: [Double] {
        let step = max(5.0, yMaxInt10 / 4.0)
        let roundedStep = ceil(step / 5.0) * 5.0
        return stride(from: 0.0, through: yMaxInt10, by: roundedStep).map { $0 }
    }

    private var valueLabelInt10: (Double) -> String {
        { v in
            let out = v / 10.0
            return String(format: "%.1f", out)
        }
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        MetricDetailScaffold(
            headerTitle: L10n.Common.metabolicHeader,
            headerTint: color,
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
                        color.opacity(0.55)
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

                // Shared metric chip navigation
                MetricChipGroup(
                    row1: row1,
                    row2: row2,
                    selected: L10n.GMI.title,
                    accent: color,
                    onSelect: { metric in // 🟨 UPDATED
                        appState.handleMetricTap(metricName: metric, settings: settings)
                    },
                    showsWarningBadge: { metric in
                        showsMetabolicWarningBadge(for: metric)
                    }
                )

                // KPI row
                HStack(spacing: 12) {

                    KPICard(
                        title: L10n.GMI.last24hKPI,
                        valueText: viewModel.formattedLast24hGMI,
                        unit: nil,
                        domain: .metabolic
                    )

                    KPICard(
                        title: L10n.GMI.todayKPI,
                        valueText: viewModel.formattedTodayGMI,
                        unit: nil,
                        domain: .metabolic
                    )

                    KPICard(
                        title: L10n.GMI.average90dKPI,
                        valueText: viewModel.formatted90dGMI,
                        unit: nil,
                        domain: .metabolic
                    )
                }
                .padding(.bottom, 8)

                // Period chart card
                ChartCard(borderColor: color) {
                    AveragePeriodsScaledBarChart(
                        data: viewModel.periodAverages,
                        metricLabel: L10n.GMI.title,
                        barColor: color,
                        goalValue: goalValueInt10,
                        yAxisTicks: yTicksInt10,
                        yMax: yMaxInt10,
                        valueLabel: valueLabelInt10
                    )
                    .frame(height: 240)
                }

                // HbA1c settings-based lab values card
                ChartCard(borderColor: color) {
                    MetabolicHbA1cLabValuesCardV1(
                        entries: settings.hba1cEntries
                    )
                    .padding(.vertical, 6)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }
        .task {
            await healthStore.refreshMetabolic(.navigation)
        }
    }
}

// ============================================================
// MARK: - HbA1c Lab Values Card (read-only, Settings-based)
// ============================================================

private struct MetabolicHbA1cLabValuesCardV1: View {

    let entries: [HbA1cEntry]

    private static let df: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none
        return df
    }()

    private var sorted: [HbA1cEntry] {
        entries.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text(L10n.GMI.labResultsTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)
            }

            if sorted.isEmpty {
                Text(L10n.GMI.labResultsEmpty)
                    .font(.caption)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.70))
            } else {

                HStack {
                    Text(L10n.GMI.labResultsDate)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.8))

                    Spacer()

                    Text(L10n.GMI.labResultsHbA1c)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.8))
                        .frame(width: 60, alignment: .trailing)

                    Text("%")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.8))
                        .frame(width: 20, alignment: .leading)
                }

                ForEach(Array(sorted.prefix(3)), id: \.id) { entry in
                    HStack(spacing: 8) {
                        Text(Self.df.string(from: entry.date))
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)

                        Spacer()

                        Text(String(format: "%.1f", entry.valuePercent))
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(Color.Glu.primaryBlue)
                            .frame(width: 60, alignment: .trailing)

                        Text("%")
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)
                            .frame(width: 20, alignment: .leading)
                    }
                    .padding(.vertical, 2)
                }

                if sorted.count > 3 {
                    Text(L10n.GMI.labResultsManageHint)
                        .font(.caption2)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.60))
                        .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("GMIViewV1 – Metabolic") {
    let previewStore = HealthStore.preview()
    let previewVM = GMIViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    previewState.currentStatsScreen = .gmi

    return GMIViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
