//
//  SleepViewModel.swift
//  GluVibProbe
//

import Foundation
import Combine
import SwiftUI

/// Verantwortlich für alle Sleep-Daten & KPIs (MVVM)
final class SleepViewModel: ObservableObject {

    // MARK: - Published Output für die View

    /// Schlaf heute in Minuten
    @Published var todaySleepMinutes: Int = 0

    /// Ziel-Schlafdauer in Minuten (aus SettingsModel)
    @Published var targetSleepMinutes: Int = 8 * 60   // wird im Init an Settings angebunden

    /// Schlaf der letzten 90 Tage (Basis für 90d-Chart)
    @Published var last90DaysSleep: [DailySleepEntry] = []

    /// Monatliche Schlafsummen (für Monats-Chart)
    @Published var monthlySleepData: [MonthlyMetricEntry] = []

    /// Täglicher Schlaf der letzten 365 Tage (für Durchschnittswerte)
    @Published var dailySleep365: [DailySleepEntry] = []

    // MARK: - Dependencies

    private let healthStore: HealthStore
    private let settings: SettingsModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        healthStore: HealthStore = .shared,
        settings: SettingsModel = .shared
    ) {
        self.healthStore = healthStore
        self.settings = settings

        // Sleep-Ziel immer mit SettingsModel verknüpfen
        settings.$dailySleepGoalMinutes
            .receive(on: DispatchQueue.main)
            .assign(to: &$targetSleepMinutes)
    }

    // MARK: - Lifecycle

    func onAppear() {
        refresh()
    }

    // MARK: - Refresh Logic

    func refresh() {
        // 1. HealthKit neu abfragen
        healthStore.fetchSleepToday()
        healthStore.fetchLast90DaysSleep()
        healthStore.fetchMonthlySleep()

        // 2. 365-Tage-Reihe für Durchschnittswerte
        loadExtendedSleepData()

        // 3. Werte aus dem HealthStore ins ViewModel spiegeln
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadData()
        }
    }

    // MARK: - Loading Logic

    private func loadData() {
        todaySleepMinutes = healthStore.todaySleepMinutes
        last90DaysSleep   = healthStore.last90DaysSleep
        monthlySleepData  = healthStore.monthlySleep
        // targetSleepMinutes kommt aus SettingsModel (Binding im Init)
    }

    private func loadExtendedSleepData() {
        healthStore.fetchSleepDaily(last: 365) { [weak self] entries in
            self?.dailySleep365 = entries
        }
    }

    // MARK: - Durchschnittswerte (Minuten) – basierend auf dailySleep365

    /// Durchschnittlicher Schlaf der letzten `days` Tage (ohne heutigen Tag)
    private func averageMinutes(last days: Int) -> Int {
        guard dailySleep365.count > 1 else { return 0 }

        let sorted = dailySleep365.sorted { $0.date < $1.date }
        let withoutToday = Array(sorted.dropLast())
        guard !withoutToday.isEmpty else { return 0 }

        let slice = withoutToday.suffix(days)
        guard !slice.isEmpty else { return 0 }

        let sum = slice.reduce(0) { $0 + $1.minutes }
        return sum / slice.count
    }

    var avgSleepLast7Days: Int   { averageMinutes(last: 7) }
    var avgSleepLast14Days: Int  { averageMinutes(last: 14) }
    var avgSleepLast30Days: Int  { averageMinutes(last: 30) }
    var avgSleepLast90Days: Int  { averageMinutes(last: 90) }
    var avgSleepLast180Days: Int { averageMinutes(last: 180) }
    var avgSleepLast365Days: Int { averageMinutes(last: 365) }

    // MARK: - Perioden-Durchschnitte für AveragePeriodsBarChart

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: avgSleepLast7Days),
            .init(label: "14T",  days: 14,  value: avgSleepLast14Days),
            .init(label: "30T",  days: 30,  value: avgSleepLast30Days),
            .init(label: "90T",  days: 90,  value: avgSleepLast90Days),
            .init(label: "180T", days: 180, value: avgSleepLast180Days),
            .init(label: "365T", days: 365, value: avgSleepLast365Days)
        ]
    }

    // MARK: - Daten für Charts

    /// Mapping Sleep → generisches DailyStepsEntry für Last90DaysBarChart
    var last90DaysDataForChart: [DailyStepsEntry] {
        last90DaysSleep.map { entry in
            DailyStepsEntry(date: entry.date, steps: entry.minutes)
        }
    }

    // MARK: - KPI: Target + Delta

    /// Delta in Minuten (heute minus Ziel)
    var deltaSleepMinutes: Int {
        todaySleepMinutes - targetSleepMinutes
    }

    var formattedTargetSleep: String {
        Self.formatMinutes(targetSleepMinutes)
    }

    var formattedTodaySleep: String {
        Self.formatMinutes(todaySleepMinutes)
    }

    var formattedDeltaSleep: String {
        Self.formatDeltaMinutes(deltaSleepMinutes)
    }

    /// Farblogik für Delta wie bei Steps:
    /// + → grün, – → rot, 0 → blau
    var deltaColor: Color {
        if deltaSleepMinutes > 0 {
            return .green
        } else if deltaSleepMinutes < 0 {
            return .red
        } else {
            return Color.Glu.primaryBlue
        }
    }

    // MARK: - Chart Goal (für gestrichelte Linie)

    /// Zielwert für das Chart; je nach Chart in Minuten oder Stunden genutzt
    var goalValueForChart: Double {
        Double(targetSleepMinutes)
    }

    // MARK: - Formatting

    static func formatMinutes(_ minutes: Int) -> String {
        guard minutes > 0 else { return "–" }

        let hours = minutes / 60
        let mins  = minutes % 60

        switch (hours, mins) {
        case (0, let m):
            // nur Minuten, z. B. "45m"
            return "\(m)m"
        case (let h, 0):
            // nur Stunden, z. B. "8h"
            return "\(h)h"
        default:
            // kompakt, z. B. "7h 40m"
            return "\(hours)h \(mins)m"
        }
    }

    static func formatDeltaMinutes(_ delta: Int) -> String {
        if delta == 0 {
            return "0m"
        }

        // WICHTIG: normales Minus "-" verwenden,
        // damit BodySectionCard.deltaColor es erkennt
        let sign = delta > 0 ? "+" : "-"

        let absMinutes = abs(delta)
        let hours = absMinutes / 60
        let mins  = absMinutes % 60

        switch (hours, mins) {
        case (0, let m):
            // z. B. "+15m" oder "-15m"
            return "\(sign)\(m)m"
        case (let h, 0):
            // z. B. "-1h"
            return "\(sign)\(h)h"
        default:
            // z. B. "-1h 5m"
            return "\(sign)\(hours)h \(mins)m"
        }
    }
}
