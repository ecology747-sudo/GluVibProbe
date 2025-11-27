//
//  ActivityEnergyViewModel.swift
//  GluVibProbe
//
//  Verantwortlich für alle Activity-Energy-Daten & KPIs (MVVM)
//

import Foundation
import Combine

final class ActivityEnergyViewModel: ObservableObject {

    // MARK: - Published Output for the View

    /// Aktivitätsenergie heute (kcal)
    @Published var todayActiveEnergy: Int = 0

    /// 90-Tage-Daten für den Chart (für die bestehenden Charts als DailyStepsEntry gemappt)
    @Published var last90DaysData: [DailyStepsEntry] = []

    /// Monatliche Aktivitätsenergie (für Monats-Chart)
    @Published var monthlyActiveEnergyData: [MonthlyMetricEntry] = []

    /// Tägliche Aktivitätsenergie der letzten 365 Tage (Basis für Durchschnitts-Logik)
    @Published var dailyActiveEnergy365: [ActivityEnergyEntry] = []

    // MARK: - Dependencies

    private let healthStore: HealthStore
    private let settings: SettingsModel   // aktuell noch nicht aktiv genutzt, aber bereit für spätere Energy-Ziele

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initializer

    init(
        healthStore: HealthStore = .shared,
        settings: SettingsModel = .shared
    ) {
        self.healthStore = healthStore
        self.settings = settings
    }

    // MARK: - Lifecycle

    func onAppear() {
        refresh()
    }

    // MARK: - Refresh Logic (HealthKit neu abfragen)

    func refresh() {
        // 1. HealthKit neu abfragen (Activity Energy)
        healthStore.fetchActiveEnergyToday()
        healthStore.fetchLast90DaysActiveEnergy()
        healthStore.fetchMonthlyActiveEnergy()

        // 2. 365-Tage-Reihe für die Durchschnittswerte neu laden
        healthStore.fetchActiveEnergyDaily(last: 365) { [weak self] entries in
            self?.dailyActiveEnergy365 = entries
        }

        // 3. Nach kurzer Zeit die aktuellen Werte aus dem HealthStore
        //    ins ViewModel spiegeln
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadData()
        }
    }

    // MARK: - Loading Logic (bestehende Werte)

    private func loadData() {
        // Heute
        todayActiveEnergy = healthStore.todayActiveEnergy

        // 90-Tage-Verlauf (für Last90DaysBarChart → DailyStepsEntry-Mapping)
        last90DaysData = healthStore.last90DaysActiveEnergy.map {
            DailyStepsEntry(date: $0.date, steps: $0.activeEnergy)
        }

        // Monatsverlauf
        monthlyActiveEnergyData = healthStore.monthlyActiveEnergy
    }

    // MARK: - Durchschnittswerte (Activity Energy) – basierend auf dailyActiveEnergy365

    /// Durchschnittliche Aktivitätsenergie der letzten 7 Tage
    var avgActiveEnergyLast7Days: Int {
        averageActiveEnergy(last: 7)
    }

    /// Durchschnittliche Aktivitätsenergie der letzten 14 Tage
    var avgActiveEnergyLast14Days: Int {
        averageActiveEnergy(last: 14)
    }

    /// Durchschnittliche Aktivitätsenergie der letzten 30 Tage
    var avgActiveEnergyLast30Days: Int {
        averageActiveEnergy(last: 30)
    }

    /// Durchschnittliche Aktivitätsenergie der letzten 90 Tage
    var avgActiveEnergyLast90Days: Int {
        averageActiveEnergy(last: 90)
    }

    /// Durchschnittliche Aktivitätsenergie der letzten 180 Tage
    var avgActiveEnergyLast180Days: Int {
        averageActiveEnergy(last: 180)
    }

    /// Durchschnittliche Aktivitätsenergie der letzten 365 Tage
    var avgActiveEnergyLast365Days: Int {
        averageActiveEnergy(last: 365)
    }

    /// Durchschnittswerte für den Perioden-Chart
    var periodAverages: [PeriodAverageEntry] {
        [
            PeriodAverageEntry(label: "7T",   days: 7,   value: avgActiveEnergyLast7Days),
            PeriodAverageEntry(label: "14T",  days: 14,  value: avgActiveEnergyLast14Days),
            PeriodAverageEntry(label: "30T",  days: 30,  value: avgActiveEnergyLast30Days),
            PeriodAverageEntry(label: "90T",  days: 90,  value: avgActiveEnergyLast90Days),
            PeriodAverageEntry(label: "180T", days: 180, value: avgActiveEnergyLast180Days),
            PeriodAverageEntry(label: "365T", days: 365, value: avgActiveEnergyLast365Days)
        ]
    }

    /// Durchschnitt der letzten `days` Tage – ohne heutigen Tag (wie bei Steps)
    private func averageActiveEnergy(last days: Int) -> Int {
        guard dailyActiveEnergy365.count > 1 else { return 0 }

        let sorted = dailyActiveEnergy365.sorted { $0.date < $1.date }

        // heutigen Tag entfernen
        let withoutToday = Array(sorted.dropLast())
        guard !withoutToday.isEmpty else { return 0 }

        let slice = withoutToday.suffix(days)
        let sum = slice.reduce(0) { $0 + $1.activeEnergy }

        return sum / slice.count
    }

    // MARK: - Formatting for the View

    /// Formatierter Wert für "Current" (heute, kcal)
    var formattedTodayActiveEnergy: String {
        numberFormatter.string(from: NSNumber(value: todayActiveEnergy))
            ?? "\(todayActiveEnergy)"
    }

    // MARK: - Number Formatter

    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}
