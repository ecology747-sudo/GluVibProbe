//
//  ActivityEnergyView.swift
//  GluVibProbe
//
//  Reine View für den Activity-Energy-Screen (MVVM)
//

import SwiftUI

struct ActivityEnergyView: View {

    @StateObject private var viewModel: ActivityEnergyViewModel

    // Callback aus dem Dashboard (für Metric-Chips)
    let onMetricSelected: (String) -> Void

    /// Haupt-Init für die App:
    /// - ohne ViewModel → ActivityEnergyViewModel benutzt automatisch HealthStore.shared
    /// - mit ViewModel → z.B. in Previews kann ein spezielles VM übergeben werden
    init(
        viewModel: ActivityEnergyViewModel? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: ActivityEnergyViewModel())
        }
    }

    var body: some View {
        ZStack {
            // Hintergrund für den Bereich „Körper & Aktivität“
            Color.Glu.activityAccent.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Haupt-Section mit KPI + Charts (Activity Energy)
                    ActivitySectionCard(
                        sectionTitle: "Activity",
                        title: "Activity Energy",
                        kpiTitle: "Active Energy Today",
                        kpiTargetText: "–",                          // aktuell kein Ziel
                        kpiCurrentText: viewModel.formattedTodayActiveEnergy,
                        kpiDeltaText: "–",                            // kein Delta, da kein Ziel
                        hasTarget: false,                             // ❗ nur Current-KPI
                        last90DaysData: viewModel.last90DaysData,
                        monthlyData: viewModel.monthlyActiveEnergyData,
                        dailyGoalForChart: nil,                       // keine RuleMark-Linie
                        onMetricSelected: onMetricSelected,
                        metrics: ["Steps", "Activity Energy"],
                        monthlyMetricLabel: "Active Energy / Month",
                        periodAverages: viewModel.periodAverages,
                        scaleType: .smallInteger                      // kcal = smallInteger
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


#Preview("ActivityEnergyView – Activity") {
    let previewStore = HealthStore.preview()
    let previewVM = ActivityEnergyViewModel(healthStore: previewStore)

    ActivityEnergyView(viewModel: previewVM)
        .environmentObject(previewStore)
}
