//
//  GlucoseCVViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct GlucoseCVViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel          // ✅ keep (capability-aware metrics)

    @StateObject private var viewModel: GlucoseCVViewModelV1

    let onMetricSelected: (String) -> Void

    private let color = Color.Glu.metabolicDomain

    init(
        viewModel: GlucoseCVViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: GlucoseCVViewModelV1())
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
                    title: "CV",

                    kpiTitle: "Today",
                    kpiCurrentText: viewModel.formattedTodayCVWhole,
                    kpiSecondaryText: nil,

                    last90DaysData: viewModel.last90DaysChartData,
                    periodAverages: viewModel.periodAverages,

                    dailyScale: viewModel.dailyScale,
                    periodScale: viewModel.periodScale,

                    goalValue: Double(settings.cvTargetPercent),

                    onMetricSelected: onMetricSelected,
                    metrics: visibleMetrics,                         // ✅ FIX (was AppState.metabolicVisibleMetrics)

                    dailyScaleType: .glucoseCvPercent,

                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: false,

                    customKpiContent: AnyView(
                        HStack(spacing: 12) {

                            KPICard(
                                title: "Last 24h",
                                valueText: viewModel.formattedLast24hCVWhole,
                                unit: "%",
                                domain: .metabolic
                            )

                            KPICard(
                                title: "Today",
                                valueText: viewModel.formattedTodayCVWhole,
                                unit: "%",
                                domain: .metabolic
                            )

                            KPICard(
                                title: "Ø 90d",
                                valueText: viewModel.formatted90dCVWhole,
                                unit: "%",
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

#Preview("GlucoseCVViewV1 – Metabolic") {
    let previewStore = HealthStore.preview()
    let previewVM = GlucoseCVViewModelV1(healthStore: previewStore)
    let previewState = AppState()
    previewState.currentStatsScreen = .CV   // ✅ nicer preview focus

    return GlucoseCVViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
