//
//  ActivityEnergyView.swift
//  GluVibProbe
//
//  Reine View für den Activity-Energy-Screen (MVVM)
//

import SwiftUI

struct ActivityEnergyView: View {

    // MARK: - Environment
    @EnvironmentObject var appState: AppState

    // MARK: - ViewModel

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

            VStack(spacing: 0) {

                // DOMAIN-HEADER „Activity“ + Back-Pfeil
                SectionHeader(
                    title: "Activity",
                    subtitle: nil,
                    tintColor: Color.Glu.activityDomain,
                    onBack: {
                        appState.currentStatsScreen = .none
                    }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Haupt-Section mit KPI + Charts (Activity Energy) – SCALED
                        ActivitySectionCardScaled(
                            sectionTitle: "",
                            title: "Activity Energy",
                            kpiTitle: "Active Energy Today",
                            kpiTargetText: "–",                              // aktuell kein Ziel
                            kpiCurrentText: viewModel.formattedTodayActiveEnergy,
                            kpiDeltaText: "–",                                // kein Delta, da kein Ziel
                            hasTarget: false,                                 // nur Current-KPI
                            last90DaysData: viewModel.last90DaysDataForChart,
                            periodAverages: viewModel.periodAveragesForChart,
                            monthlyData: viewModel.monthlyData,
                            dailyScale: viewModel.dailyScale,
                            periodScale: viewModel.periodScale,
                            monthlyScale: viewModel.monthlyScale,
                            goalValue: nil,                                   // keine RuleMark-Linie
                            onMetricSelected: onMetricSelected,
                            metrics: [
                                "Steps",
                                "Active Time",
                                "Activity Energy",
                                "Movement Split"
                            ]
                        )
                        .padding(.horizontal)
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    viewModel.refresh()
                }
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

// MARK: - Preview

#Preview("ActivityEnergyView – Activity") {
    let previewStore = HealthStore.preview()
    let previewVM = ActivityEnergyViewModel(healthStore: previewStore)
    let previewState = AppState()

    ActivityEnergyView(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
