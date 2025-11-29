//
//  WeightViewModel 2.swift
//  GluVibProbe
//
//  Created by MacBookAir on 28.11.25.
//


//
//  WeightViewModel.swift
//  GluVibProbe
//
//  Verantwortlich für alle Weight-Daten & KPIs (MVVM)
//

import Foundation
import Combine

final class WeightViewModel: ObservableObject {

    // MARK: - Published Output für die View

    /// Heutiges Gewicht in kg (als Int, z. B. 75 = 75 kg)
    @Published var todayWeightKg: Int = 0

    /// Gewicht der letzten 90 Tage (Basis für 90d-Chart)
    @Published var last90DaysWeight: [DailyWeightEntry] = []

    /// Monatliche Gewichtswerte (z. B. Ø Gewicht pro Monat – für Monats-Chart)
    @Published var monthlyWeightData: [MonthlyMetricEntry] = []

    /// Tägliches Gewicht der letzten 365 Tage (für Durchschnittswerte)
    @Published var dailyWeight365: [DailyWeightEntry] = []

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
        // 1. HealthKit neu abfragen (Gewicht)
        healthStore.fetchWeightToday()
        healthStore.fetchLast90DaysWeight()
        healthStore.fetchMonthlyWeight()

        // 2. 365-Tage-Reihe für Durchschnittswerte
        loadExtendedWeightData()

        // 3. Werte aus dem HealthStore ins ViewModel spiegeln
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadData()
        }
    }

    // MARK: - Loading Logic

    private func loadData() {
        // aktuelle Tageswerte aus dem HealthStore holen
        todayWeightKg      = healthStore.todayWeightKg
        last90DaysWeight   = healthStore.last90DaysWeight
        monthlyWeightData  = healthStore.monthlyWeight
    }

    private func loadExtendedWeightData() {
        healthStore.fetchWeightDaily(last: 365) { [weak self] entries in
            self?.dailyWeight365 = entries
        }
    }

    // MARK: - Durchschnittswerte – basierend auf dailyWeight365

    /// Durchschnittliches Gewicht der letzten `days` Tage (ohne heutigen Tag)
    private func averageWeight(last days: Int) -> Int {
        guard dailyWeight365.count > 1 else { return 0 }

        let sorted = dailyWeight365.sorted { $0.date < $1.date }
        let withoutToday = Array(sorted.dropLast())
        guard !withoutToday.isEmpty else { return 0 }

        let slice = withoutToday.suffix(days)
        guard !slice.isEmpty else { return 0 }

        let sum = slice.reduce(0) { $0 + $1.weightKg }
        return sum / slice.count
    }

    var avgWeightLast7Days: Int   { averageWeight(last: 7) }
    var avgWeightLast14Days: Int  { averageWeight(last: 14) }
    var avgWeightLast30Days: Int  { averageWeight(last: 30) }
    var avgWeightLast90Days: Int  { averageWeight(last: 90) }
    var avgWeightLast180Days: Int { averageWeight(last: 180) }
    var avgWeightLast365Days: Int { averageWeight(last: 365) }

    // MARK: - Perioden-Durchschnitte für AveragePeriodsBarChart

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: avgWeightLast7Days),
            .init(label: "14T",  days: 14,  value: avgWeightLast14Days),
            .init(label: "30T",  days: 30,  value: avgWeightLast30Days),
            .init(label: "90T",  days: 90,  value: avgWeightLast90Days),
            .init(label: "180T", days: 180, value: avgWeightLast180Days),
            .init(label: "365T", days: 365, value: avgWeightLast365Days)
        ]
    }

    // MARK: - Daten für generische Charts

    /// Mapping Weight → generisches DailyStepsEntry für Last90DaysBarChart
    ///
    /// (Last90DaysBarChart arbeitet mit `DailyStepsEntry.steps` als Int-Wert;
    ///  wir nutzen diesen Slot hier für `weightKg`.)
    var last90DaysDataForChart: [DailyStepsEntry] {
        last90DaysWeight.map { entry in
            DailyStepsEntry(date: entry.date, steps: entry.weightKg)
        }
    }

    // MARK: - Formatting

    /// Heutiges Gewicht formatiert, z. B. "75 kg"
    var formattedTodayWeight: String {
        Self.formatKg(todayWeightKg)
    }

    /// Optional: Durchschnitt 7 Tage formatiert, z. B. "74 kg"
    var formattedAvgWeightLast7Days: String {
        Self.formatKg(avgWeightLast7Days)
    }

    static func formatKg(_ kg: Int) -> String {
        guard kg > 0 else { return "–" }
        return "\(kg) kg"
    }
}