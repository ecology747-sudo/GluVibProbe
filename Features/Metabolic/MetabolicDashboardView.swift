//
//  MetabolicDashboardView.swift
//  GluVibProbe
//
//  Metabolic Dashboard Router (V1)
//  - KEINE Overview-View bis Premium/Free sauber steht (bleibt EmptyView)
//  - Switch ist sauber/exhaustive (ohne default)
//  - MetabolicDashboardView ist NUR für Metabolic-Screens zuständig
//

import SwiftUI

struct MetabolicDashboardView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    var body: some View {

        switch appState.currentStatsScreen {

        // -----------------------------------------------------
        // KEINE Overview-View bis Premium/Free sauber steht
        // -----------------------------------------------------
        case .none,
             .metabolicOverview:
            EmptyView()

        // -----------------------------------------------------
        // Metabolic Metrics (V1)
        // -----------------------------------------------------
        case .bolus:
            BolusViewV1(onMetricSelected: handleMetricSelection)

        case .basal:
            BasalViewV1(onMetricSelected: handleMetricSelection)

        case .bolusBasalRatio:
            BolusBasalRatioViewV1(onMetricSelected: handleMetricSelection)

        case .carbsBolusRatio:
            CarbsBolusRatioViewV1(onMetricSelected: handleMetricSelection)

        case .timeInRange:
            TimeInRangeViewV1(onMetricSelected: handleMetricSelection)

        case .ig:
            IGViewV1(onMetricSelected: handleMetricSelection)

        case .gmi:
            GMIViewV1(onMetricSelected: handleMetricSelection)

        case .range:
            RangeViewV1(onMetricSelected: handleMetricSelection)

        case .SD:
            GlucoseSDViewV1(onMetricSelected: handleMetricSelection)

        case .CV:
            GlucoseCVViewV1(onMetricSelected: handleMetricSelection)

        // -----------------------------------------------------
        // Andere Domains → hier NICHT zuständig
        // -----------------------------------------------------
        case .nutritionOverview,
             .carbs, .carbsDayparts, .sugar, .protein, .fat, .calories,   // 🟨 UPDATED: add carbsDayparts

             .steps, .activityEnergy, .activityExerciseMinutes,
             .movementSplit, .moveTime, .workoutMinutes,

             .weight, .sleep, .bmi, .bodyFat, .restingHeartRate:
            EmptyView()
        }
    }

    // MARK: - Metabolic Metric Navigation (central)

    private func handleMetricSelection(_ metric: String) {
        if let target = AppState.metabolicScreen(for: metric) {
            appState.currentStatsScreen = target
        }
    }
}

// MARK: - Preview

#Preview("MetabolicDashboardView") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()
    previewState.currentStatsScreen = .ig

    return MetabolicDashboardView()
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
