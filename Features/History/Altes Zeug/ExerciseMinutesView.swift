//
//  ExerciseMinutesView.swift
//  GluVibProbe
//
//  Reine View für den Active-Time-Screen (vormals Exercise Minutes) – MVVM
//

import SwiftUI

struct ExerciseMinutesView: View {

    // MARK: - Environment
    @EnvironmentObject var appState: AppState

    // MARK: - ViewModel

    @StateObject private var viewModel: ExerciseMinutesViewModel

    // Callback aus dem Dashboard (für Metric-Chips)
    let onMetricSelected: (String) -> Void

    // MARK: - Init

    /// Haupt-Init für die App:
    /// - ohne ViewModel → ExerciseMinutesViewModel benutzt automatisch HealthStore.shared
    /// - mit ViewModel → z.B. in Previews kann ein spezielles VM übergeben werden
    init(
        viewModel: ExerciseMinutesViewModel? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(
                wrappedValue: ExerciseMinutesViewModel()
            )
        }
    }

    // MARK: - Body

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

                        // Haupt-Section mit KPI + Charts (Active Time) – SCALED
                        ActivitySectionCardScaled(
                            sectionTitle: "",
                            title: "Active Time",
                            kpiTitle: "Active Time Today",
                            // Aktuell ohne Ziel-Flow:
                            kpiTargetText: "",
                            kpiCurrentText: viewModel.formattedTodayExerciseMinutes,
                            kpiDeltaText: "",
                            hasTarget: false,

                            // Chart-Daten
                            last90DaysData: viewModel.last90DaysChartData,
                            periodAverages: viewModel.periodAverages,
                            monthlyData: viewModel.monthlyData,

                            // Skalen (MetricScaleHelper)
                            dailyScale: viewModel.dailyScale,
                            periodScale: viewModel.periodScale,
                            monthlyScale: viewModel.monthlyScale,

                            // Zielwert aktuell nicht genutzt
                            goalValue: nil,

                            // Metric-Chip-Navigation
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
                    // Pull-to-Refresh → HealthKit neu abfragen
                    viewModel.refresh()
                }
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

#Preview("ExerciseMinutesView – Activity") {
    let previewStore = HealthStore.preview()
    let previewVM = ExerciseMinutesViewModel(healthStore: previewStore)
    let previewState = AppState()

    return ExerciseMinutesView(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
