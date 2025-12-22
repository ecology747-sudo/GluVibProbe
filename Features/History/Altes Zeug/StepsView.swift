//
//  StepsView.swift
//  GluVibProbe
//
//  LEGACY (nicht weiterentwickeln)
//
//  Hintergrund:
//  - Diese View nutzt das historische StepsViewModel (mit Fetch-Logik im VM).
//  - Der neue Datenfluss läuft über StepsViewV1 + StepsViewModelV1 + HealthStore+Bootstrap.
//
//  Status:
//  - Diese Datei bleibt vorerst im Projekt, um Referenz / Vergleich zu ermöglichen.
//  - Aktive Nutzung erfolgt über: StepsViewV1.swift
//

import SwiftUI

@available(*, deprecated, message: "Legacy: Use StepsViewV1 (StepsViewModelV1 + HealthStore.refreshActivity) instead.")

struct StepsView: View {

    // MARK: - Environment
    @EnvironmentObject var appState: AppState

    // MARK: - ViewModel

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
            Color.Glu.activityAccent.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // DOMAIN-HEADER „Activity“ (Rot) + Back-Pfeil
                SectionHeader(
                    title: "Activity",
                    subtitle: nil,
                    tintColor: Color.Glu.activityDomain,
                    onBack: {
                        // Zurück zur Activity Overview
                        appState.currentStatsScreen = .none
                    }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Haupt-Section mit KPI + Charts (Steps) – SCALED
                        ActivitySectionCardScaled(
                            sectionTitle: "",
                            title: "Steps",
                            kpiTitle: "Steps Today",
                            kpiTargetText: viewModel.formattedDailyStepGoal,
                            kpiCurrentText: viewModel.formattedTodaySteps,
                            kpiDeltaText: viewModel.kpiDeltaText,
                            hasTarget: true,
                            last90DaysData: viewModel.last90DaysDataForChart,
                            periodAverages: viewModel.periodAverages,
                            monthlyData: viewModel.monthlyData,
                            dailyScale: viewModel.dailyScale,
                            periodScale: viewModel.periodScale,
                            monthlyScale: viewModel.monthlyScale,
                            goalValue: viewModel.dailyStepsGoalInt,
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

#Preview("StepsView – Activity") {
    let previewStore = HealthStore.preview()
    let previewVM = StepsViewModel(healthStore: previewStore)
    let previewState = AppState()

    return StepsView(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
