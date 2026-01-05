//
//  ActivityEnergyViewV1.swift
//  GluVibProbe
//
//  V1 Adapter View:
//  - UI läuft über MetricDetailScaffold
//  - Datenfluss läuft über ActivityEnergyViewModelV1 (kein Fetch im VM)
//  - Refresh läuft über HealthStore.refreshActivity(...)
//  - kJ / EnergyUnit vollständig entfernt
//

import SwiftUI

struct ActivityEnergyViewV1: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    // MARK: - ViewModel

    @StateObject private var viewModel: ActivityEnergyViewModelV1

    // Callback aus dem Dashboard (für Metric-Chips)
    let onMetricSelected: (String) -> Void

    // MARK: - Init

    init(
        viewModel: ActivityEnergyViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: ActivityEnergyViewModelV1(healthStore: HealthStore.shared)) // !!! UPDATED
        }
    }

    // MARK: - Body

    var body: some View {
        MetricDetailScaffold(
            headerTitle: "Activity",
            headerTint: Color.Glu.activityDomain,
            onBack: {                                        // CHANGED: zentral über Scaffold
                appState.currentStatsScreen = .none
            },
            onRefresh: {                                     // CHANGED: refreshable läuft über Bootstrap
                await healthStore.refreshActivity(.pullToRefresh)
            },
            background: {                                    // CHANGED: Background als View-Closure
                LinearGradient(
                    colors: [
                        .white,
                        Color.Glu.activityDomain.opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {

                ActivitySectionCardScaledV2(
                    sectionTitle: "",
                    title: "Activity Energy",
                    kpiTitle: "Active Energy Today",
                    kpiTargetText: "–",
                    kpiCurrentText: viewModel.formattedTodayActiveEnergy,      // !!! UPDATED
                    kpiDeltaText: "–",
                    kpiDeltaColor: nil,
                    hasTarget: false,
                    last90DaysData: viewModel.last90DaysChartData,             // !!! UPDATED
                    periodAverages: viewModel.periodAverages,                  // !!! UPDATED
                    monthlyData: viewModel.monthlyData,                        // !!! UPDATED
                    dailyScale: viewModel.dailyScale,                          // !!! UPDATED
                    periodScale: viewModel.periodScale,                        // !!! UPDATED
                    monthlyScale: viewModel.monthlyScale,                      // !!! UPDATED
                    goalValue: nil,
                    onMetricSelected: onMetricSelected,
                    metrics: AppState.activityVisibleMetrics,
                    showsDailyChart: true,
                    showsPeriodChart: true,
                    showsMonthlyChart: true,
                    customKpiContent: nil,
                    customChartContent: nil,
                    customDailyChartBuilder: nil,                              // !!! UPDATED
                    dailyScaleType: .energyDaily
                )
            }
        }
        .task {
            await healthStore.refreshActivity(.navigation)
        }
    }
}

// MARK: - Preview

#Preview("ActivityEnergyViewV1 – Activity") {
    let previewStore = HealthStore.preview()
    let previewVM = ActivityEnergyViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return ActivityEnergyViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
