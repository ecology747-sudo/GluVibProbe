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
            Color.Glu.activityOrange.opacity(0.18).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    BodyActivitySectionCard(
                        sectionTitle: "Körper & Aktivität",
                        title: "Sleep",

                        // ---------- KPI ----------
                        kpiTitle: "Sleep Today",
                        kpiTargetText: "",
                        kpiCurrentText: SleepViewModel.formatMinutes(viewModel.todaySleepMinutes),
                        kpiDeltaText: "",
                        hasTarget: false,

                        // ---------- CHART DATEN ----------
                        last90DaysData: viewModel.last90DaysDataForChart,   // ✅ Richtig
                        monthlyData: viewModel.monthlySleepData,            // ✅ Richtig

                        dailyStepsGoalForChart: nil,

                        // ---------- CHIP NAVIGATION ----------
                        onMetricSelected: onMetricSelected,
                        metrics: ["Weight", "Steps", "Sleep", "Activity Energy"],

                        monthlyMetricLabel: "Sleep / Month",

                        // ---------- PERIOD AVG ----------
                        periodAverages: viewModel.periodAverages,           // ✅ Richtig

                        // ---------- SCALE ----------
                        scaleType: .hours                                   // 🔥 Wichtig
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
#Preview("SleepView – Body & Activity") {
    let previewStore = HealthStore.preview()
    let previewVM = SleepViewModel(healthStore: previewStore)

    return SleepView(
        viewModel: previewVM,
        onMetricSelected: { _ in }
    )
    .environmentObject(previewStore)
}
