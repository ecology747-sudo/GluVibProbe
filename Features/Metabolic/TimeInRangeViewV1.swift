//
//  TimeInRangeViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct TimeInRangeViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel   // ✅ keep (needed for targets + capability metrics)

    @StateObject private var viewModel: TimeInRangeViewModelV1

    let onMetricSelected: (String) -> Void

    private let color = Color.Glu.metabolicDomain

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
                    title: "TIR",

                    // KPI (Default wird durch customKpiContent ersetzt)
                    kpiTitle: "Target",
                    kpiCurrentText: viewModel.formattedTodayTIRPercent,
                    kpiSecondaryText: nil,

                    // Charts
                    last90DaysData: viewModel.last90DaysChartData,
                    periodAverages: viewModel.periodAverages,

                    // Scales (fixed 0..100)
                    dailyScale: fixedPercentScale,
                    periodScale: fixedPercentScale,

                    // Target Marker
                    goalValue: Double(settings.tirTargetPercent),

                    // Navigation + Chips
                    onMetricSelected: onMetricSelected,
                    metrics: AppState.metabolicVisibleMetrics(settings: settings),   // ✅ FIX

                    // Scale Type
                    dailyScaleType: .percent0to100,

                    // Slots
                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: false,

                    // Custom KPI Content (3 KPIs wie Steps)
                    customKpiContent: AnyView(
                        HStack(spacing: 12) {
                            KPICard(
                                title: "Target",
                                valueText: "\(settings.tirTargetPercent)%",
                                unit: nil,
                                domain: .metabolic
                            )

                            KPICard(
                                title: "Today",
                                valueText: viewModel.formattedTodayTIRPercent,
                                unit: nil,
                                domain: .metabolic
                            )

                            KPICard(
                                title: "Delta",
                                valueText: "\(viewModel.kpiDeltaText)%",
                                unit: nil,
                                valueColor: viewModel.kpiDeltaColor,
                                domain: .metabolic
                            )
                        }
                        .padding(.bottom, 8)
                    ),

                    // No extra chart blocks
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
