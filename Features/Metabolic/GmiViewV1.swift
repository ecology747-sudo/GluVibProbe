//
//  GMIViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct GMIViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel   // ✅ keep (capability-aware metrics + targets)

    @StateObject private var viewModel: GMIViewModelV1

    let onMetricSelected: (String) -> Void

    private let color = Color.Glu.metabolicDomain

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
        AppState.metabolicVisibleMetrics(settings: settings)         // ✅ FIX (respect Insulin/CGM toggles)
    }

    private var row1: [String] { Array(visibleMetrics.prefix(4)) }  // ✅ FIX
    private var row2: [String] { Array(visibleMetrics.dropFirst(4)) } // ✅ FIX

    // ============================================================
    // MARK: - Target (GMI in Int*10 scale)
    // ============================================================

    private var goalValueInt10: Double? {
        let v = max(0, settings.gmi90TargetPercent)
        guard v > 0 else { return nil }
        return (v * 10.0).rounded()                                  // ✅ FIX (6.7 -> 67)
    }

    // ============================================================
    // MARK: - Dynamic Y-Axis (based on max bar) — Int*10
    // ============================================================

    private var gmiValuesInt10: [Double] {
        viewModel.periodAverages.map { Double($0.value) }.filter { $0 > 0 }
    }

    private var yMaxInt10: Double {
        let maxV = gmiValuesInt10.max() ?? 0
        guard maxV > 0 else { return 100 } // fallback (== 10.0)
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

    var body: some View {
        MetricDetailScaffold(
            headerTitle: "Metabolic",
            headerTint: color,
            onBack: { appState.currentStatsScreen = .none },
            onRefresh: {
                await healthStore.refreshMetabolic(.pullToRefresh)
            },
            background: {
                LinearGradient(
                    colors: [.white, color.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {

                // ============================================================
                // Metric Chips (capability-aware)
                // ============================================================

                MetricChipGroup(
                    row1: row1,
                    row2: row2,
                    selected: "GMI",
                    accent: color,
                    onSelect: onMetricSelected
                )

                // ============================================================
                // KPI Row: Last 24h | Today | 90 Days
                // ============================================================

                HStack(spacing: 12) {

                    KPICard(
                        title: "Last 24h",
                        valueText: viewModel.formattedLast24hGMI,
                        unit: nil,
                        domain: .metabolic
                    )

                    KPICard(
                        title: "Today",
                        valueText: viewModel.formattedTodayGMI,
                        unit: nil,
                        domain: .metabolic
                    )

                    KPICard(
                        title: "Ø 90d",
                        valueText: viewModel.formatted90dGMI,
                        unit: nil,
                        domain: .metabolic
                    )
                }
                .padding(.bottom, 8)

                // ============================================================
                // Chart: Period Average Chart (≤90d) — dynamic Y scale
                // ============================================================

                ChartCard(borderColor: color) {
                    AveragePeriodsScaledBarChart(
                        data: viewModel.periodAverages,
                        metricLabel: "GMI",
                        barColor: color,
                        goalValue: goalValueInt10,                 // ✅ FIX (correct scale)
                        yAxisTicks: yTicksInt10,
                        yMax: yMaxInt10,
                        valueLabel: valueLabelInt10
                    )
                    .frame(height: 240)
                }

                // ============================================================
                // HbA1c Lab Values (Settings-based, read-only) — UNDER chart
                // ============================================================

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
                Text("HbA1c Lab Results")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)
            }

            if sorted.isEmpty {
                Text("No HbA1c lab values recorded yet.")
                    .font(.caption)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.70))
            } else {

                HStack {
                    Text("Date")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.8))

                    Spacer()

                    Text("HbA1c")
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
                    Text("Manage all lab values in Settings.")
                        .font(.caption2)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.60))
                        .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Preview

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
