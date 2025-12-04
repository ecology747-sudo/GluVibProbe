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

        // 🔹 Andere Domains (falls Navigation ausgebaut wird)
        case steps
        case activityEnergy
        case weight
        case sleep
    }

    // Beim Start steht kein Detail-Screen fest
    @Published var currentStatsScreen: StatsScreen = .none
}
