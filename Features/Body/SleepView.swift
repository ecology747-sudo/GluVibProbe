//
//  SleepView.swift
//  GluVibProbe
//

import SwiftUI

struct SleepView: View {

    @StateObject private var viewModel: SleepViewModel
    let onMetricSelected: (String) -> Void

    // !!! NEW: optionaler Back-Callback
    let onBack: (() -> Void)?

    init(
        viewModel: SleepViewModel? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in },
        onBack: (() -> Void)? = nil        // !!! NEW
    ) {
        self.onMetricSelected = onMetricSelected
        self.onBack = onBack              // !!! NEW
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
                        metrics: [                       // alle 5 Body-Metriken
                            "Weight",
                            "Sleep",
                            "BMI",
                            "Body Fat",
                            "Resting Heart Rate"
                        ],
                        showMonthlyChart: true,
                        scaleType: .sleepMinutes,
                        chartStyle: .bar,
                        onBack: onBack                 // !!! NEW – Pfeil-Logik
                    )
                    .padding(.horizontal)
                }
              
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
        onMetricSelected: { _ in },
        onBack: nil
    )
    .environmentObject(appState)
    .environmentObject(healthStore)
}
