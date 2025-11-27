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
            Color.Glu.activityOrange.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Haupt-Section mit KPI + Charts (Activity Energy)
                    BodyActivitySectionCard(
                        sectionTitle: "Activity & Body",
                        title: "Activity Energy",
                        kpiTitle: "Activity Energy",
                        kpiTargetText: "",                            // kein Ziel
                        kpiCurrentText: viewModel.formattedTodayActiveEnergy,
                        kpiDeltaText: "",                              // kein Delta
                        hasTarget: false,                              // 👉 nur Current-KPI zentriert
                        last90DaysData: viewModel.last90DaysData,
                        monthlyData: viewModel.monthlyActiveEnergyData,
                        dailyStepsGoalForChart: nil,                   // keine Ziel-Linie
                        onMetricSelected: onMetricSelected,
                        metrics: ["Weight", "Steps", "Sleep", "Activity Energy"],
                        monthlyMetricLabel: "kcal / Month",
                        periodAverages: viewModel.periodAverages,
                        scaleType: .smallInteger                       // 👉 andere Skala
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

#Preview("ActivityEnergyView – Body & Activity") {
    let previewStore = HealthStore.preview()
    let previewVM = ActivityEnergyViewModel(healthStore: previewStore)

    return ActivityEnergyView(viewModel: previewVM)
        .environmentObject(previewStore)
}
