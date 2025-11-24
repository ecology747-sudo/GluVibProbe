//
//  AppState.swift
//  GluVibProbe
//

import SwiftUI
import Combine   // 🔥 WICHTIG für ObservableObject + @Published

@MainActor
final class AppState: ObservableObject {

    // MARK: - Statistik-Screens (für die Pfeilnavigation)
    enum StatsScreen {
        case steps
        case activityEnergy
        case weight
        case sleep
    }

    @Published var currentStatsScreen: StatsScreen = .steps
}
