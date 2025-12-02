//
//  FatViewModel.swift
//  GluVibProbe
//
//  Nutrition-Domain: Fat (g)
//

import Foundation
import Combine

final class FatViewModel: ObservableObject {

    // MARK: - Published Output für die View

    /// Fett heute in Gramm
    @Published var todayFatGrams: Int = 0

    /// Rohdaten: Fett der letzten 90 Tage
    @Published var last90DaysFat: [DailyFatEntry] = []

    /// Monatliche Fettwerte (Summen)
    @Published var monthlyFatData: [MonthlyMetricEntry] = []

    /// Tägliches Fett der letzten 365 Tage (Basis für Durchschnittswerte)
    @Published var dailyFat365: [DailyFatEntry] = []

    /// Zielwert Fett pro Tag (aus SettingsModel)
    @Published var targetFatGrams: Int = 0

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

        // Ziel immer mit SettingsModel verknüpfen
        settings.$dailyFat
            .receive(on: DispatchQueue.main)
            .assign(to: &$targetFatGrams)
    }

    // MARK: - Lifecycle

    func onAppear() {
        refresh()
    }

    // MARK: - Refresh Logic

    func refresh() {
        // 1) Heute (optional; nutzt Helper wie bei Protein)
        healthStore.fetchFatToday { [weak self] grams in
            DispatchQueue.main.async {
                self?.todayFatGrams = grams
            }
        }

        // 2) 365-Tage-Reihe (inkl. Basis für 90d & Durchschnitte)
        healthStore.fetchFatDaily(last: 365) { [weak self] entries in
            guard let self else { return }
            DispatchQueue.main.async {
                self.dailyFat365 = entries
                self.last90DaysFat = Array(entries.suffix(90))
            }
        }

        // 3) Monatswerte
        healthStore.fetchFatMonthly { [weak self] monthly in
            DispatchQueue.main.async {
                self?.monthlyFatData = monthly
            }
        }
    }

    // MARK: - Daten für Charts

    /// Mapping Fat → generisches DailyStepsEntry für Last90DaysBarChart
    var last90DaysDataForChart: [DailyStepsEntry] {
        last90DaysFat.map { entry in
            DailyStepsEntry(date: entry.date, steps: entry.grams)
        }
    }

    // MARK: - Durchschnittswerte (Gramm) – basierend auf dailyFat365

    private func averageGrams(last days: Int) -> Int {
        guard dailyFat365.count > 1 else { return 0 }

        let sorted = dailyFat365.sorted { $0.date < $1.date }

        // heutigen Tag entfernen (wie bei Sleep/Protein)
        let withoutToday = Array(sorted.dropLast())
        guard !withoutToday.isEmpty else { return 0 }

        let slice = withoutToday.suffix(days)
        guard !slice.isEmpty else { return 0 }

        let sum = slice.reduce(0) { $0 + $1.grams }
        return sum / slice.count
    }

    var avgFatLast7Days: Int   { averageGrams(last: 7) }
    var avgFatLast14Days: Int  { averageGrams(last: 14) }
    var avgFatLast30Days: Int  { averageGrams(last: 30) }
    var avgFatLast90Days: Int  { averageGrams(last: 90) }
    var avgFatLast180Days: Int { averageGrams(last: 180) }
    var avgFatLast365Days: Int { averageGrams(last: 365) }

    // MARK: - Perioden-Durchschnitte für AveragePeriodsBarChart

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: avgFatLast7Days),
            .init(label: "14T",  days: 14,  value: avgFatLast14Days),
            .init(label: "30T",  days: 30,  value: avgFatLast30Days),
            .init(label: "90T",  days: 90,  value: avgFatLast90Days),
            .init(label: "180T", days: 180, value: avgFatLast180Days),
            .init(label: "365T", days: 365, value: avgFatLast365Days)
        ]
    }

    // MARK: - KPI-Formatting

    private func formatGrams(_ grams: Int) -> String {
        guard grams > 0 else { return "–" }
        return "\(grams) g"
    }

    var formattedTargetFat: String {
        formatGrams(targetFatGrams)
    }

    var formattedTodayFat: String {
        formatGrams(todayFatGrams)
    }

    var formattedDeltaFat: String {
        guard targetFatGrams > 0, todayFatGrams > 0 else { return "–" }

        let diff = todayFatGrams - targetFatGrams
        if diff == 0 { return "0 g" }

        let sign = diff > 0 ? "+" : "−"
        return "\(sign)\(abs(diff)) g"
    }

    /// Zielwert für horizontale Chart-Linie
    var goalValueForChart: Int? {
        targetFatGrams > 0 ? targetFatGrams : nil
    }
}
