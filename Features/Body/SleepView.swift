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

                    BodySectionCard(
                        sectionTitle: "Body",
                        title: "Sleep",
                        kpiTitle: "Sleep Today",
                        kpiTargetText: "",
                        // 👉 KPI in Stunden + Minuten
                        kpiCurrentText: SleepViewModel.formatMinutes(viewModel.todaySleepMinutes),
                        kpiDeltaText: "",
                        hasTarget: false,
                        // 👉 Sleep-Daten in generische Entries gemapped
                        last90DaysData: viewModel.last90DaysDataForChart,
                        monthlyData: viewModel.monthlySleepData,
                        dailyGoalForChart: nil,
                        onMetricSelected: onMetricSelected,
                        metrics: ["Sleep", "Weight"],
                        monthlyMetricLabel: "Sleep / Month",
                        periodAverages: viewModel.periodAverages,
                        scaleType: .hours 
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
    let appState   = AppState()
    let healthStore = HealthStore.preview()
    let viewModel  = SleepViewModel(healthStore: healthStore)

    return SleepView(
        viewModel: viewModel,
        onMetricSelected: { _ in }
    )
    .environmentObject(appState)
    .environmentObject(healthStore)
}
