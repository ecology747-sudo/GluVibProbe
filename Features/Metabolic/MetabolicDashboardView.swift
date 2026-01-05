//
//  MetabolicDashboardView.swift
//  GluVibProbe
//
//  - KEINE Overview-View bis Premium/Free sauber steht (bleibt EmptyView)
//  - Switch ist sauber/exhaustive (ohne kaputtes default-Nesting)
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

        // -----------------------------------------------------
        // !!! NEW: CGM / Derived (Scaffold only)
        // -----------------------------------------------------
        case .timeInRange:                                        // !!! NEW
            TimeInRangeViewV1(onMetricSelected: handleMetricSelection) // !!! NEW

        case .gmi:                                                // !!! NEW
            GMIViewV1(onMetricSelected: handleMetricSelection)     // !!! NEW

        // -----------------------------------------------------
        // Andere Domains → hier NICHT zuständig
        // -----------------------------------------------------
        case .nutritionOverview,
             .carbs, .protein, .fat, .calories,
             .steps, .activityEnergy, .activityExerciseMinutes,
             .movementSplit, .moveTime, .workoutMinutes,
             .weight, .sleep, .bmi, .bodyFat, .restingHeartRate:
            EmptyView()
        }
    }

    // MARK: - Metabolic Metric Navigation

    private func handleMetricSelection(_ metric: String) {
        switch metric {

        case "Bolus":
            appState.currentStatsScreen = .bolus
          

        case "Basal":
            appState.currentStatsScreen = .basal

        case "Bolus/Basal":
            appState.currentStatsScreen = .bolusBasalRatio

        case "Carbs/Bolus":
            appState.currentStatsScreen = .carbsBolusRatio

        // !!! NEW
        case "TIR":
            appState.currentStatsScreen = .timeInRange

        case "GMI":
            appState.currentStatsScreen = .gmi

        default:
            break
        }
    }
}

// MARK: - Preview

#Preview("MetabolicDashboardView") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()
    previewState.currentStatsScreen = .bolus

    return MetabolicDashboardView()
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
