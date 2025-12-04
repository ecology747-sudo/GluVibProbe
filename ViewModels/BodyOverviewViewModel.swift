//
//  BodyOverviewViewModel.swift
//  GluVibProbe
//
//  Verantwortlich für die Body-Overview (Sleep + Weight KPIs)
//

import Foundation
import Combine

@MainActor
final class BodyOverviewViewModel: ObservableObject {

    // MARK: - Published Output

    /// Heutiger Schlaf in Minuten
    @Published var todaySleepMinutes: Int = 0

    /// Letztes bekanntes Gewicht (kg – bereits mit Forward-Fill/Fallback in HealthStore)
    @Published var todayWeightKg: Int = 0

    // MARK: - Dependencies

    private let healthStore: HealthStore

    // MARK: - Init

    init(healthStore: HealthStore) {
        self.healthStore = healthStore
    }

    // MARK: - Loading / Refresh

    /// Sehr schlanke Refresh-Logik:
    /// nimmt die aktuellen Werte direkt aus dem HealthStore.
    func refresh() {
        todaySleepMinutes = healthStore.todaySleepMinutes
        todayWeightKg     = healthStore.todayWeightKg
    }

    // MARK: - Formatting Helpers

    /// Formatiert Minuten als "7h 15m"
    var formattedTodaySleep: String {
        Self.formatMinutes(todaySleepMinutes)
    }

    /// Formatiert Gewicht als "98 kg"
    var formattedTodayWeight: String {
        guard todayWeightKg > 0 else { return "–" }
        return "\(todayWeightKg) kg"
    }

    // MARK: - Static Formatter

    private static func formatMinutes(_ minutes: Int) -> String {
        guard minutes > 0 else { return "–" }

        let hours = minutes / 60
        let mins  = minutes % 60

        switch (hours, mins) {
        case (0, let m):
            return "\(m)m"
        case (let h, 0):
            return "\(h)h"
        default:
            return "\(hours)h \(mins)m"
        }
    }
}
