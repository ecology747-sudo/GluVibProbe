//
//  AppState.swift
//  GluVibProbe
//

import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {

    enum StatsScreen {

        case none

        // Nutrition
        case nutritionOverview
        case carbs
        case protein
        case fat
        case calories

        // Activity
        case steps
        case activityEnergy
        case activityExerciseMinutes
        case movementSplit
        case moveTime
        case workoutMinutes

        // Body
        case weight
        case sleep
        case bmi
        case bodyFat
        case restingHeartRate

        // Metabolic (V1)
        case metabolicOverview                                   // Entry (noch ohne View)
        case bolus
        case basal
        case bolusBasalRatio
        case carbsBolusRatio

        // !!! NEW (CGM / Derived)
        case timeInRange                                         // !!! NEW
        case gmi                                                 // !!! NEW
    }

    static let activityVisibleMetrics: [String] = [
        "Steps",
        "Workout Minutes",
        "Activity Energy",
        "Movement Split"
    ]

    static let nutritionVisibleMetrics: [String] = [
        "Carbs",
        "Protein",
        "Fat",
        "Calories"
    ]

    static let bodyVisibleMetrics: [String] = [
        "Weight",
        "Sleep",
        "BMI",
        "Body Fat",
        "Resting Heart Rate"
    ]

    // ============================================================
    // MARK: - Metabolic Visible Metrics (V1)
    // ============================================================

    static let metabolicVisibleMetrics: [String] = [
        "Bolus",
        "Basal",
        "Bolus/Basal",
        "Carbs/Bolus",

        "TIR",                                                   // !!! NEW
        "GMI"                                                    // !!! NEW
    ]

    @Published var currentStatsScreen: StatsScreen = .none
}
