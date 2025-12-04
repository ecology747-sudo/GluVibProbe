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

    /// 🔹 Skalen für die 3 Charts (neu, Helper-basiert)
    @Published var dailyScale: MetricScaleResult   = MetricScaleHelper.scale([], for: .grams)
    @Published var periodScale: MetricScaleResult  = MetricScaleHelper.scale([], for: .grams)
    @Published var monthlyScale: MetricScaleResult = MetricScaleHelper.scale([], for: .grams)

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
        // 1) Heute
        healthStore.fetchFatToday { [weak self] grams in
            DispatchQueue.main.async {
                self?.todayFatGrams = grams
            }
        }

        // 2) 365-Tage-Reihe (inkl. Basis für 90d & Durchschnitte)
        healthStore.fetchFatDaily(last: 365) { [weak self] entries in
            guard let self else { return }
            let sorted = entries.sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                self.dailyFat365 = sorted
                self.last90DaysFat = Array(sorted.suffix(90))
                self.recomputeScales()
            }
        }

        // 3) Monatswerte
        healthStore.fetchFatMonthly { [weak self] monthly in
            DispatchQueue.main.async {
                self?.monthlyFatData = monthly
                self?.recomputeScales()
            }
        }
    }

    // MARK: - Daten für Charts

    /// Mapping Fat → generisches DailyStepsEntry für Last90DaysScaledBarChart
    var last90DaysDataForChart: [DailyStepsEntry] {
        last90DaysFat.map { entry in
            DailyStepsEntry(date: entry.date, steps: entry.grams)
        }
    }

    // MARK: - Durchschnittswerte (Gramm) – basierend auf dailyFat365
    /// Neue Logik:
    /// - Zeitraum: letzte `days` Kalendertage vor heute (z.B. 7, 14, 30 …)
    /// - es zählen nur Einträge mit grams > 0
    /// - geteilt wird durch die Anzahl der Tage mit Eintrag (nicht durch `days`)
    private func averageGrams(last days: Int) -> Int {
        guard !dailyFat365.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // endDate = gestern, startDate = heute - days
        guard let endDate = calendar.date(byAdding: .day, value: -1, to: today),
              let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            return 0
        }

        let filtered = dailyFat365.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= startDate && d <= endDate && entry.grams > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0) { $0 + $1.grams }
        return sum / filtered.count
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

    // MARK: - Skalen (Helper-System, GRAMM)

    private func recomputeScales() {
        let dailyValues   = last90DaysDataForChart.map { Double($0.steps) }
        let periodValues  = periodAverages.map { Double($0.value) }
        let monthlyValues = monthlyFatData.map { Double($0.value) }

        dailyScale   = MetricScaleHelper.scale(dailyValues,   for: .grams)
        periodScale  = MetricScaleHelper.scale(periodValues,  for: .grams)
        monthlyScale = MetricScaleHelper.scale(monthlyValues, for: .grams)
    }
}
