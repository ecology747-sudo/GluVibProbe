//
//  StepsView1_Archive.swift
//  GluVibProbe
//
//  Reine View für den Steps-Screen (MVVM)
//

import SwiftUI

struct StepsView1_Archive: View {

    @StateObject private var viewModel: StepsViewModel

    // Callback aus dem Dashboard (für Metric-Chips)
    let onMetricSelected: (String) -> Void

    /// Haupt-Init für die App:
    /// - ohne ViewModel → StepsViewModel benutzt automatisch HealthStore.shared
    /// - mit ViewModel → z.B. in Previews kann ein spezielles VM übergeben werden
    init(
        viewModel: StepsViewModel? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: StepsViewModel())
        }
    }

    var body: some View {
        ZStack {
            // Hintergrund für den Bereich „Körper & Aktivität“
            Color.Glu.activityOrange.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Haupt-Section mit KPI + Charts (Steps)
                    BodyActivitySectionCard(
                        sectionTitle: "Activity & Body",
                        title: "Steps",
                        kpiTitle: "Steps",
                        kpiTargetText: viewModel.formattedDailyStepGoal,
                        kpiCurrentText: viewModel.formattedTodaySteps,
                        kpiDeltaText: viewModel.kpiDeltaText,   // 👈 HIER neu
                        last90DaysData: viewModel.last90DaysData,
                        monthlyData: viewModel.monthlyStepsData,
                        dailyStepsGoalForChart: viewModel.dailyStepsGoalInt,
                        onMetricSelected: onMetricSelected,
                        metrics: ["Weight", "Steps", "Sleep", "Activity Energy"],
                        monthlyMetricLabel: "Steps / Month",
                        periodAverages: viewModel.periodAverages
                    )
                    .padding(.horizontal)
                }
                .padding(.top, 16)
            }
            .refreshable {
                // 👇 beim „Pull-to-Refresh“:
                viewModel.refresh()
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

#Preview("StepsView – Body & Activity") {
    // 🔹 Preview-HealthStore mit 365-Tage-Demodaten
    let previewStore = HealthStore.preview()

    // 🔹 ViewModel bekommt diesen Preview-Store (isPreview == true)
    let previewVM = StepsViewModel(healthStore: previewStore)

    return StepsView(viewModel: previewVM)
        .environmentObject(previewStore) // falls andere Views den Store als EnvironmentObject brauchen
}
