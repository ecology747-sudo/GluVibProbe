//
//  ActivityEnergyView.swift
//  GluVibProbe
//

import SwiftUI

struct ActivityEnergyView: View {

    // MARK: - ViewModel

    @StateObject private var viewModel: ActivityEnergyViewModel

    // Callback nach oben (ActivityDashboardView),
    // damit der Dashboard-Switch weiß, welche Metrik gewählt wurde
    let onMetricSelected: (String) -> Void

    // MARK: - Init

    init(
        viewModel: ActivityEnergyViewModel? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected
        _viewModel = StateObject(
            wrappedValue: viewModel ?? ActivityEnergyViewModel()
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 🔴 Activity-Domain-Hintergrund
            Color.Glu.activityAccent.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    ActivitySectionCard(
                        sectionTitle: "Activity",
                        title: "Activity Energy",
                        kpiTitle: "Active Energy Today",
                        // kein Target für Activity Energy
                        kpiTargetText: "",
                        kpiCurrentText: viewModel.formattedTodayActiveEnergy,
                        kpiDeltaText: "",
                        hasTarget: false,
                        last90DaysData: viewModel.last90DaysData,
                        monthlyData: viewModel.monthlyActiveEnergyData,
                        dailyGoalForChart: nil,
                        // 🔑 WICHTIG: Callback nach oben durchreichen
                        onMetricSelected: onMetricSelected,
                        metrics: ["Steps", "Activity Energy"],
                        monthlyMetricLabel: "Active Energy / Month",
                        periodAverages: viewModel.periodAverages,
                        scaleType: .smallInteger
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

#Preview {
    ActivityEnergyView()
}
