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

    /// Monatliche Schlafsummen (für Monats-Chart, Minuten)
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

    /// 🟢 NEU:
    /// Durchschnittlicher Schlaf der letzten `days` **Kalendertage vor heute**
    /// (z.B. 7 Tage), aber:
    ///   - heute wird ausgeschlossen
    ///   - Tage ohne Eintrag (minutes <= 0) werden NICHT mitgerechnet
    ///   - geteilt wird durch die Anzahl der Tage mit Eintrag
    private func averageMinutes(last days: Int) -> Int {
        guard !dailySleep365.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Zeitraum: [startDate ... endDate] = [heute - days ... gestern]
        guard let endDate = calendar.date(byAdding: .day, value: -1, to: today),
              let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            return 0
        }

        // Nur Einträge im Kalenderraster mit minutes > 0
        let filtered = dailySleep365.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= startDate && d <= endDate && entry.minutes > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0) { $0 + $1.minutes }
        return sum / filtered.count
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

    // MARK: - Daten für Charts (Minutes → generic Entries)

    /// Mapping Sleep → generisches DailyStepsEntry für Last90DaysScaledBarChart
    var last90DaysDataForChart: [DailyStepsEntry] {
        last90DaysSleep.map { entry in
            DailyStepsEntry(date: entry.date, steps: entry.minutes)
        }
    }

    /// Monatsdaten (bereits Minuten)
    var monthlyData: [MonthlyMetricEntry] {
        monthlySleepData
    }

    /// Perioden-Durchschnitte direkt in Minuten
    var periodAveragesForChart: [PeriodAverageEntry] {
        periodAverages
    }

    // MARK: - Scaling-Outputs für SectionCardScaled

    /// Skala für Tages-Chart (Sleep in Minuten, Achse in Stunden)
    var dailyScale: MetricScaleResult {
        let values = last90DaysDataForChart.map { Double($0.steps) }
        return MetricScaleHelper.scale(values, for: .sleepMinutes)
    }

    /// Skala für Perioden-Chart (Durchschnittswerte, Minuten → Stunden)
    var periodScale: MetricScaleResult {
        let values = periodAveragesForChart.map { Double($0.value) }
        return MetricScaleHelper.scale(values, for: .sleepMinutes)
    }

    /// Skala für Monats-Chart (Monatssummen, Minuten → Stunden)
    var monthlyScale: MetricScaleResult {
        let values = monthlyData.map { Double($0.value) }
        return MetricScaleHelper.scale(values, for: .sleepMinutes)
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

    /// Farblogik (falls direkt in der View genutzt werden soll)
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

    /// Zielwert für das Chart; in Minuten
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
            return "\(m)m"
        case (let h, 0):
            return "\(h)h"
        default:
            return "\(hours)h \(mins)m"
        }
    }

    static func formatDeltaMinutes(_ delta: Int) -> String {
        if delta == 0 {
            return "0m"
        }

        // normales Minus "-" verwenden
        let sign = delta > 0 ? "+" : "-"

        let absMinutes = abs(delta)
        let hours = absMinutes / 60
        let mins  = absMinutes % 60

        switch (hours, mins) {
        case (0, let m):
            return "\(sign)\(m)m"
        case (let h, 0):
            return "\(sign)\(h)h"
        default:
            return "\(sign)\(hours)h \(mins)m"
        }
    }
}
