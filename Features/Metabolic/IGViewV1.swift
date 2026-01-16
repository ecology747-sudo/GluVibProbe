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
        let base = viewModel.dailyScale   // ✅ ticks + yMax are mg/dL
        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { v in
                // v is mg/dL (chart-space) → label in current unit
                settings.glucoseUnit.formattedNumber(fromMgdl: v, fractionDigits: unitDigits)
            }
        )
    }

    private var periodScaleDisplay: MetricScaleResult {
        let base = viewModel.periodScale  // ✅ ticks + yMax are mg/dL
        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { v in
                settings.glucoseUnit.formattedNumber(fromMgdl: v, fractionDigits: unitDigits)
            }
        )
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

                MetabolicSectionCardScaledV1(
                    title: "IG",

                    // KPI (Default wird durch customKpiContent ersetzt)
                    kpiTitle: "Mean",
                    kpiCurrentText: formattedTodayIG,
                    kpiSecondaryText: unitLabel,

                    // Charts
                    last90DaysData: viewModel.last90DaysChartData,
                    periodAverages: viewModel.periodAverages,

                    // Scales (✅ axis labels follow unit)
                    dailyScale: dailyScaleDisplay,
                    periodScale: periodScaleDisplay,

                    // Target Marker (kein Goal für IG)
                    goalValue: nil,

                    // Navigation + Chips
                    onMetricSelected: onMetricSelected,
                    metrics: AppState.metabolicVisibleMetrics(settings: settings),

                    // Scale Type
                    dailyScaleType: .glucoseMeanMgdl,

                    // Slots
                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: false,

                    // Custom KPI Content (3 KPIs)
                    customKpiContent: AnyView(
                        HStack(spacing: 12) {

                            KPICard(
                                title: "Last 24h",
                                valueText: formattedLast24hIG,
                                unit: unitLabel,
                                domain: .metabolic
                            )

                            KPICard(
                                title: "Today",
                                valueText: formattedTodayIG,
                                unit: unitLabel,
                                domain: .metabolic
                            )

                            KPICard(
                                title: "Ø 90d",
                                valueText: formattedIG90d,
                                unit: unitLabel,
                                domain: .metabolic
                            )
                        }
                        .padding(.bottom, 8)
                    ),

                    customChartContent: nil,
                    customDailyChartBuilder: nil,
                    customPeriodChartContent: nil
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
