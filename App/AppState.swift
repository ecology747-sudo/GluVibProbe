//
//  AppState.swift
//  GluVibProbe
//

import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {

    enum StatsScreen {
        // 🔹 Kein Detail-Screen aktiv → Overview anzeigen
        case none

        // 🔹 Nutrition Overview (Einstiegsseite im Nutrition-Tab)
        case nutritionOverview

        // 🔹 Nutrition-Metriken (Detail-Screens)
        case carbs
        case protein
        case fat
        case calories     // Nutrition Energy

        // 🔹 Activity-Domain
        case steps
        case activityEnergy
        case activityExerciseMinutes
        case movementSplit        // !!! NEW
        // 🔹 Body-Domain (bisher + neu)
        case weight
        case sleep
        case bmi               // BMI Detail-Screen
        case bodyFat           // Body-Fat Detail-Screen
        case restingHeartRate  // Resting-Heart-Rate Detail-Screen
    }

    // Beim Start steht kein Detail-Screen fest
    @Published var currentStatsScreen: StatsScreen = .none
}
