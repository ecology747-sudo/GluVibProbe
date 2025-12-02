//
//  ProteinViewModel.swift
//  GluVibProbe
//
//  Nutrition-Domain: Protein (g)
//

import Foundation
import Combine

/// Verantwortlich für alle Protein-Daten & KPIs (MVVM)
final class ProteinViewModel: ObservableObject {

    // MARK: - Published Output für die View

    /// Heutige Proteinaufnahme in Gramm
    @Published var todayProteinGrams: Int = 0

    /// Rohdaten: Protein der letzten 90 Tage
    @Published var last90DaysProtein: [DailyProteinEntry] = []

    /// Rohdaten: Protein der letzten 365 Tage
    @Published var dailyProtein365: [DailyProteinEntry] = []

    /// Monatliche Protein-Summen (z. B. Total g / Monat)
    @Published var monthlyProteinData: [MonthlyMetricEntry] = []

    /// Ziel-Protein (g/Tag) aus Settings
    @Published var targetProteinGrams: Int = 0

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

        // Ziel-Protein immer mit SettingsModel verknüpfen
        settings.$dailyProtein
            .receive(on: DispatchQueue.main)
            .assign(to: &$targetProteinGrams)    }

    // MARK: - Lifecycle

    func onAppear() {
        refresh()
    }

    // MARK: - Refresh Logic

    func refresh() {
        // 1) 365-Tage-Reihe + heute + 90 Tage
        healthStore.fetchProteinDaily(last: 365) { [weak self] entries in
            guard let self else { return }

            let sorted = entries.sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                self.dailyProtein365 = sorted

                // Today = letzter Eintrag
                self.todayProteinGrams = sorted.last?.grams ?? 0

                // 90 Tage = letztes Segment
                if sorted.count <= 90 {
                    self.last90DaysProtein = sorted
                } else {
                    self.last90DaysProtein = Array(sorted.suffix(90))
                }
            }
        }

        // 2) Monatsdaten laden
        healthStore.fetchProteinMonthly { [weak self] monthly in
            DispatchQueue.main.async {
                self?.monthlyProteinData = monthly
            }
        }
    }

    // MARK: - Durchschnittswerte (Gramm) – basierend auf dailyProtein365

    /// Durchschnittliche Proteinaufnahme der letzten `days` Tage (ohne heutigen Tag)
    private func averageProtein(last days: Int) -> Int {
        guard dailyProtein365.count > 1 else { return 0 }

        let sorted = dailyProtein365.sorted { $0.date < $1.date }

        // heutigen Tag entfernen (wie bei Sleep/Activity)
        let withoutToday = Array(sorted.dropLast())
        guard !withoutToday.isEmpty else { return 0 }

        let slice = withoutToday.suffix(days)
        guard !slice.isEmpty else { return 0 }

        let sum = slice.reduce(0) { $0 + $1.grams }
        return sum / slice.count
    }

    var avgProteinLast7Days: Int   { averageProtein(last: 7) }
    var avgProteinLast14Days: Int  { averageProtein(last: 14) }
    var avgProteinLast30Days: Int  { averageProtein(last: 30) }
    var avgProteinLast90Days: Int  { averageProtein(last: 90) }
    var avgProteinLast180Days: Int { averageProtein(last: 180) }
    var avgProteinLast365Days: Int { averageProtein(last: 365) }

    // MARK: - Perioden-Durchschnitte für AveragePeriodsBarChart

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: avgProteinLast7Days),
            .init(label: "14T",  days: 14,  value: avgProteinLast14Days),
            .init(label: "30T",  days: 30,  value: avgProteinLast30Days),
            .init(label: "90T",  days: 90,  value: avgProteinLast90Days),
            .init(label: "180T", days: 180, value: avgProteinLast180Days),
            .init(label: "365T", days: 365, value: avgProteinLast365Days)
        ]
    }

    // MARK: - Daten für Charts

    /// Mapping Protein → generischer DailyStepsEntry (für Last90DaysBarChart)
    var last90DaysDataForChart: [DailyStepsEntry] {
        last90DaysProtein.map { entry in
            DailyStepsEntry(date: entry.date, steps: entry.grams)
        }
    }

    // MARK: - KPI: Target + Delta (Strings für NutritionSectionCard)

    /// Zielwert für das Chart (horizontale Linie)
    var goalValueForChart: Int? {
        targetProteinGrams > 0 ? targetProteinGrams : nil
    }

    var formattedTargetProtein: String {
        guard targetProteinGrams > 0 else { return "–" }
        return "\(targetProteinGrams) g"
    }

    var formattedTodayProtein: String {
        guard todayProteinGrams > 0 else { return "–" }
        return "\(todayProteinGrams) g"
    }

    var deltaProteinGrams: Int {
        todayProteinGrams - targetProteinGrams
    }

    var formattedDeltaProtein: String {
        guard targetProteinGrams > 0, todayProteinGrams > 0 else { return "–" }

        let diff = deltaProteinGrams
        if diff == 0 { return "0 g" }

        let sign = diff > 0 ? "+" : "−"
        return "\(sign)\(abs(diff)) g"
    }
}
