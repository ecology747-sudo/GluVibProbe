//
//  SleepView.swift
//  GluVibProbe
//
//  Reine View für den Sleep-Screen (MVVM)
//

import SwiftUI

struct SleepView: View {

    @StateObject private var viewModel: SleepViewModel

    // Callback aus dem Dashboard (für Metric-Chips)
    let onMetricSelected: (String) -> Void

    /// Haupt-Init für die App:
    /// - ohne ViewModel → SleepViewModel benutzt automatisch HealthStore.shared
    /// - mit ViewModel → z.B. in Previews kann ein spezielles VM übergeben werden
    init(
        viewModel: SleepViewModel? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: SleepViewModel())
        }
    }

    var body: some View {
        ZStack {
            // Hintergrund für den Bereich „Körper & Aktivität“
            Color.Glu.activityOrange.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Haupt-Section mit KPI + Charts (Sleep)
                    BodyActivitySectionCard(
                        sectionTitle: "Activity & Body",
                        title: "Sleep",
                        kpiTitle: "Sleep",
                        kpiTargetText: "",                             // kein Target
                        kpiCurrentText: viewModel.formattedTodaySleep, // nur Current
                        kpiDeltaText: "",
                        hasTarget: false,                              // 👉 nur Current-KPI
                        last90DaysData: viewModel.last90DaysDataForChart,
                        monthlyData: viewModel.monthlySleepData,
                        dailyStepsGoalForChart: nil,                   // keine RuleMark
                        onMetricSelected: onMetricSelected,
                        metrics: ["Weight", "Steps", "Sleep", "Activity Energy"],
                        monthlyMetricLabel: "Sleep / Month",
                        periodAverages: viewModel.periodAverages
                        // scaleType bleibt vorerst .steps über BodyActivitySectionCard
                        // (können wir später separat auf .smallInteger umstellen)
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

#Preview("SleepView – Body & Activity") {
    let previewStore = HealthStore.preview()
    let previewVM = SleepViewModel(healthStore: previewStore)

    return SleepView(viewModel: previewVM)
        .environmentObject(previewStore)
}
