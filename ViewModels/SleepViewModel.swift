//
//  SleepViewModel.swift
//  GluVibProbe
//

import Foundation
import Combine

/// Verantwortlich für alle Sleep-Daten & KPIs (MVVM)
final class SleepViewModel: ObservableObject {

    // MARK: - Published Output für die View

    /// Schlaf heute in Minuten
    @Published var todaySleepMinutes: Int = 0

    /// Ziel-Schlafdauer in Minuten (z. B. 8 h)
    @Published var targetSleepMinutes: Int = 8 * 60   // später aus SettingsModel laden

    /// Schlaf der letzten 90 Tage (Basis für 90d-Chart)
    @Published var last90DaysSleep: [DailySleepEntry] = []

    /// Monatliche Schlafsummen (für Monats-Chart)
    @Published var monthlySleepData: [MonthlyMetricEntry] = []

    /// Täglicher Schlaf der letzten 365 Tage (für Durchschnittswerte)
    @Published var dailySleep365: [DailySleepEntry] = []

    // MARK: - Dependencies

    private let healthStore: HealthStore
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore
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

        // 🔜 später: targetSleepMinutes aus SettingsModel übernehmen
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

    // MARK: - Formatting

    /// Formatierter Wert, z. B. "7 h 15 min" oder "–"
    static func formatMinutes(_ minutes: Int) -> String {
        guard minutes > 0 else { return "–" }

        let hours = minutes / 60
        let mins  = minutes % 60

        switch (hours, mins) {
        case (0, let m):
            return "\(m) min"
        case (let h, 0):
            return "\(h) h"
        default:
            return "\(hours) h \(mins) min"
        }
    }

    /// Formatierter Delta-Wert mit Vorzeichen, z. B. "+45 min", "–1 h 15 min"
    static func formatDeltaMinutes(_ delta: Int) -> String {
        if delta == 0 {
            return "0 min"
        }

        let sign = delta > 0 ? "+" : "–"
        let absMinutes = abs(delta)
        let hours = absMinutes / 60
        let mins  = absMinutes % 60

        switch (hours, mins) {
        case (0, let m):
            return "\(sign)\(m) min"
        case (let h, 0):
            return "\(sign)\(h) h"
        default:
            return "\(sign)\(hours) h \(mins) min"
        }
    }
}
