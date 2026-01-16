//
//  GlucoseSDViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct GlucoseSDViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel          // ✅ keep (capability-aware metrics)

    @StateObject private var viewModel: GlucoseSDViewModelV1

    let onMetricSelected: (String) -> Void

    private let color = Color.Glu.metabolicDomain

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
        AppState.metabolicVisibleMetrics(settings: settings)        // ✅ FIX (respect Insulin/CGM toggles)
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
                    title: "SD",

                    kpiTitle: "Today",
                    kpiCurrentText: viewModel.formattedTodaySDKPI,
                    kpiSecondaryText: nil,

                    last90DaysData: viewModel.last90DaysChartData,
                    periodAverages: viewModel.periodAverages,

                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,

                    goalValue: nil,

                    onMetricSelected: onMetricSelected,
                    metrics: visibleMetrics,                         // ✅ FIX (was AppState.metabolicVisibleMetrics)

                    dailyScaleType: .glucoseSdMgdl,

                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: false,

                    customKpiContent: AnyView(
                        HStack(spacing: 12) {

                            KPICard(
                                title: "Last 24h",
                                valueText: viewModel.formattedLast24hSDKPI,
                                unit: viewModel.sdDisplayUnitText,
                                domain: .metabolic
                            )

                            KPICard(
                                title: "Today",
                                valueText: viewModel.formattedTodaySDKPI,
                                unit: viewModel.sdDisplayUnitText,
                                domain: .metabolic
                            )

                            KPICard(
                                title: "Ø 90d",
                                valueText: viewModel.formatted90dSDKPI,
                                unit: viewModel.sdDisplayUnitText,
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

#Preview("GlucoseSDViewV1 – Metabolic") {
    let previewStore = HealthStore.preview()
    let previewVM = GlucoseSDViewModelV1(healthStore: previewStore)
    let previewState = AppState()
    previewState.currentStatsScreen = .SD   // ✅ nicer preview focus

    return GlucoseSDViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
