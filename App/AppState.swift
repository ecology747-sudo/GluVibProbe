//
//  AppState.swift
//  GluVibProbe
//

import SwiftUI
import Combine   // 🔥 WICHTIG für ObservableObject + @Published

@MainActor
final class AppState: ObservableObject {

    enum StatsScreen {
        case steps
        case activityEnergy
        case weight
        case sleep

        // 🔹 Nutrition-Domain
        case carbs
        case protein
        case fat
        case calories
    }

    @Published var currentStatsScreen: StatsScreen = .steps
}
