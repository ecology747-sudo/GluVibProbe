//
//  CarbsViewModel.swift
//  GluVibProbe
//
//  Verantwortlich für alle Carbs-Daten & KPIs (MVVM)
//

import Foundation
import Combine
import SwiftUI

/// Verantwortlich für Carbohydrate-Tracking (g/Tag)
final class CarbsViewModel: ObservableObject {

    // MARK: - Published Output für die View

    /// Kohlenhydrate heute (g)
    @Published var todayCarbsGrams: Int = 0

    /// Ziel-Kohlenhydrate in g (aus SettingsModel)
    @Published var targetCarbsGrams: Int = 0

    /// Carbs der letzten 90 Tage (Rohdaten aus HealthStore)
    @Published var last90DaysCarbs: [DailyCarbsEntry] = []

    /// Monatliche Carbs-Summen (für Monats-Chart)
    @Published var monthlyCarbsData: [MonthlyMetricEntry] = []

    /// Tägliche Carbs der letzten 365 Tage (für Durchschnittswerte)
    @Published var dailyCarbs365: [DailyCarbsEntry] = []

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

        // Ziel-Kohlenhydrate immer mit SettingsModel verknüpfen
        settings.$dailyCarbs
            .receive(on: DispatchQueue.main)
            .assign(to: &$targetCarbsGrams)
    }

    // MARK: - Lifecycle

    func onAppear() {
        refresh()
    }

    // MARK: - Refresh Logic

    func refresh() {
        // 1. HealthKit neu abfragen (Carbs)
        healthStore.fetchCarbsToday()
        healthStore.fetchLast90DaysCarbs()
        healthStore.fetchMonthlyCarbs()

        // 2. 365-Tage-Reihe für Durchschnittswerte laden
        loadExtendedCarbsData()

        // 3. Werte aus dem HealthStore ins ViewModel spiegeln
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadData()
        }
    }

    // MARK: - Loading Logic

    private func loadData() {
        todayCarbsGrams  = healthStore.todayCarbsGrams
        last90DaysCarbs  = healthStore.last90DaysCarbs
        monthlyCarbsData = healthStore.monthlyCarbs
        // targetCarbsGrams kommt aus SettingsModel (Binding im Init)
    }

    private func loadExtendedCarbsData() {
        healthStore.fetchCarbsDaily(last: 365) { [weak self] entries in
            self?.dailyCarbs365 = entries
        }
    }

    // MARK: - Durchschnittswerte (g) – basierend auf dailyCarbs365

    // 🔴 ALT (vorherige Logik – über reine Daten-Suffixe, inkl. "Lücken" als 0,
    //     und mit "dropLast()" für heute)
    //
    // private func averageGrams(last days: Int) -> Int {
    //     guard dailyCarbs365.count > 1 else { return 0 }
    //
    //     let sorted = dailyCarbs365.sorted { $0.date < $1.date }
    //     let withoutToday = Array(sorted.dropLast())
    //     guard !withoutToday.isEmpty else { return 0 }
    //
    //     let slice = withoutToday.suffix(days)
    //     guard !slice.isEmpty else { return 0 }
    //
    //     let sum = slice.reduce(0) { $0 + $1.grams }
    //     return sum / slice.count
    // }

    /// 🟢 NEU:
    /// Durchschnittliche Carbs der letzten `days` **Kalendertage vor heute**
    /// (Zeitraum bleibt gleich, z.B. 7 Tage), aber:
    ///   - Tage ohne Eintrag (grams <= 0) werden NICHT mitgerechnet
    ///   - geteilt wird durch die Anzahl der **Tage mit Eintrag**, nicht durch `days`
    private func averageGrams(last days: Int) -> Int {
        guard !dailyCarbs365.isEmpty else { return 0 }

        let calendar = Calendar.current

        // "Heute" als Start-of-Day
        let today = calendar.startOfDay(for: Date())

        // Enddatum = gestern (heutiger Tag bleibt wie vorher draußen)
        guard let endDate = calendar.date(byAdding: .day, value: -1, to: today),
              let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            return 0
        }

        // Nur Einträge im Kalenderraster [startDate ... endDate], mit grams > 0
        let filtered = dailyCarbs365.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= startDate && d <= endDate && entry.grams > 0
        }

        // Wenn keine gültigen Tage → 0
        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0) { $0 + $1.grams }
        return sum / filtered.count
    }

    var avgCarbsLast7Days: Int   { averageGrams(last: 7) }
    var avgCarbsLast14Days: Int  { averageGrams(last: 14) }
    var avgCarbsLast30Days: Int  { averageGrams(last: 30) }
    var avgCarbsLast90Days: Int  { averageGrams(last: 90) }
    var avgCarbsLast180Days: Int { averageGrams(last: 180) }
    var avgCarbsLast365Days: Int { averageGrams(last: 365) }

    // MARK: - Perioden-Durchschnitte für AveragePeriodsBarChart

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: avgCarbsLast7Days),
            .init(label: "14T",  days: 14,  value: avgCarbsLast14Days),
            .init(label: "30T",  days: 30,  value: avgCarbsLast30Days),
            .init(label: "90T",  days: 90,  value: avgCarbsLast90Days),
            .init(label: "180T", days: 180, value: avgCarbsLast180Days),
            .init(label: "365T", days: 365, value: avgCarbsLast365Days)
        ]
    }

    // MARK: - Daten für Charts (generisches Format)

    /// Mapping Carbs → generisches DailyStepsEntry für 90-Tage-Chart
    var last90DaysDataForChart: [DailyStepsEntry] {
        last90DaysCarbs.map { entry in
            DailyStepsEntry(date: entry.date, steps: entry.grams)
        }
    }

    /// Zielwert für das Chart (RuleMark-Linie in g)
    var goalValueForChart: Double {
        Double(targetCarbsGrams)
    }

    // MARK: - KPIs (Target / Today / Delta)

    /// Formatierter Zielwert, z. B. "220 g"
    var formattedTargetCarbs: String {
        guard targetCarbsGrams > 0 else { return "–" }
        return "\(targetCarbsGrams) g"
    }

    /// Formatierter Today-Wert, z. B. "185 g"
    var formattedTodayCarbs: String {
        guard todayCarbsGrams > 0 else { return "–" }
        return "\(todayCarbsGrams) g"
    }

    /// Delta in g (heute minus Ziel) – mit + / −, damit Delta-Farbe greift
    var formattedDeltaCarbs: String {
        guard todayCarbsGrams > 0, targetCarbsGrams > 0 else { return "–" }

        let diff = todayCarbsGrams - targetCarbsGrams
        if diff == 0 { return "0 g" }

        let sign = diff > 0 ? "+" : "-"
        return "\(sign)\(abs(diff)) g"
    }

    // MARK: - Skalen für das neue Helper-System (GRAMM) – zentral über MetricScaleHelper

    /// Skala für den 90-Tage-Chart (Last90DaysScaledBarChart)
    var dailyScale: MetricScaleResult {
        let values = last90DaysDataForChart.map { Double($0.steps) }
        return MetricScaleHelper.scale(values, for: .grams)
    }

    /// Skala für AveragePeriodsScaledBarChart
    var periodScale: MetricScaleResult {
        let values = periodAverages.map { Double($0.value) }
        return MetricScaleHelper.scale(values, for: .grams)
    }

    /// Skala für MonthlyScaledBarChart
    var monthlyScale: MetricScaleResult {
        let values = monthlyCarbsData.map { Double($0.value) }
        return MetricScaleHelper.scale(values, for: .grams)
    }
}
