//
//  SleepView.swift
//  GluVibProbe
//

import SwiftUI

struct SleepView: View {

    @StateObject private var viewModel: SleepViewModel
    let onMetricSelected: (String) -> Void

    init(
        viewModel: SleepViewModel? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected
        _viewModel = StateObject(wrappedValue: viewModel ?? SleepViewModel())
    }

    var body: some View {
        ZStack {
            // 👉 Body-Domain = Orange
            Color.Glu.bodyAccent.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    BodySectionCardScaled(
                        sectionTitle: "Body",
                        title: "Sleep",
                        kpiTitle: "Sleep Today",
                        kpiTargetText: viewModel.formattedTargetSleep,
                        kpiCurrentText: viewModel.formattedTodaySleep,
                        kpiDeltaText: viewModel.formattedDeltaSleep,
                        hasTarget: true,
                        last90DaysData: viewModel.last90DaysDataForChart,
                        periodAverages: viewModel.periodAveragesForChart,
                        monthlyData: viewModel.monthlyData,
                        dailyScale: viewModel.dailyScale,
                        periodScale: viewModel.periodScale,
                        monthlyScale: viewModel.monthlyScale,
                        goalValue: Int(viewModel.goalValueForChart),
                        onMetricSelected: onMetricSelected,
                        metrics: [                       // !!! UPDATED – alle 5 Body-Metriken
                            "Weight",
                            "Sleep",
                            "BMI",
                            "Body Fat",
                            "Resting Heart Rate"
                        ],
                        showMonthlyChart: true,
                        scaleType: .sleepMinutes,
                        chartStyle: .bar               // !!! NEW – Last 90 Days als Line-Chart
                    )
                    .padding(.horizontal)
                }
                .padding(.top, 16)
            }
            .refreshable {
                viewModel.refresh()
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

// MARK: - Preview

#Preview("SleepView – Body Domain") {
    let appState    = AppState()
    let healthStore = HealthStore.preview()
    let viewModel   = SleepViewModel(healthStore: healthStore)

    return SleepView(
        viewModel: viewModel,
        onMetricSelected: { _ in }
    )
    .environmentObject(appState)
    .environmentObject(healthStore)
}
