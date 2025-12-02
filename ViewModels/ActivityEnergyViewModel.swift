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

    /// Aktivitätsenergie heute (Basis: kcal)
    @Published var todayActiveEnergy: Int = 0

    /// 90-Tage-Daten (Basis: kcal, intern) – für Chart gemappt
    @Published var last90DaysData: [DailyStepsEntry] = []

    /// Monatliche Aktivitätsenergie (Basis: kcal)
    @Published var monthlyActiveEnergyData: [MonthlyMetricEntry] = []

    /// Tägliche Aktivitätsenergie der letzten 365 Tage (Basis: kcal)
    @Published var dailyActiveEnergy365: [ActivityEnergyEntry] = []

    // MARK: - Dependencies

    private let healthStore: HealthStore
    private let settings: SettingsModel   // für EnergyUnit (kcal / kJ)

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
        // 1. HealthKit neu abfragen (Activity Energy – Basis immer kcal)
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
        // Heute (Basis: kcal)
        todayActiveEnergy = healthStore.todayActiveEnergy

        // 90-Tage-Verlauf (Basis: kcal)
        last90DaysData = healthStore.last90DaysActiveEnergy.map {
            DailyStepsEntry(date: $0.date, steps: $0.activeEnergy)
        }

        // Monatsverlauf (Basis: kcal)
        monthlyActiveEnergyData = healthStore.monthlyActiveEnergy
    }

    // MARK: - Durchschnittswerte (Activity Energy, Basis kcal)

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

    /// Durchschnittswerte (Basis kcal) für den Perioden-Chart
    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: avgActiveEnergyLast7Days),
            .init(label: "14T",  days: 14,  value: avgActiveEnergyLast14Days),
            .init(label: "30T",  days: 30,  value: avgActiveEnergyLast30Days),
            .init(label: "90T",  days: 90,  value: avgActiveEnergyLast90Days),
            .init(label: "180T", days: 180, value: avgActiveEnergyLast180Days),
            .init(label: "365T", days: 365, value: avgActiveEnergyLast365Days)
        ]
    }

    /// Durchschnitt der letzten `days` Tage – ohne heutigen Tag (Basis kcal)
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

    // MARK: - Unit Conversion & Formatting (kcal <-> kJ)

    /// Basis ist immer kcal, Settings steuern nur Anzeige-Einheit
    private func convertKcal(_ value: Int, to unit: EnergyUnit) -> Int {
        guard value > 0 else { return 0 }

        switch unit {
        case .kcal:
            return value
        case .kilojoules:
            // 1 kcal ≈ 4.184 kJ
            return Int((Double(value) * 4.184).rounded())
        }
    }

    private func formatEnergy(_ valueKcal: Int, unit: EnergyUnit) -> String {
        let converted = convertKcal(valueKcal, to: unit)
        guard converted > 0 else { return "–" }

        let numberString = numberFormatter.string(from: NSNumber(value: converted))
            ?? "\(converted)"

        return "\(numberString) \(unit.label)"
    }

    // MARK: - Formatting for the View

    /// Formatierter Wert für "Active Energy Today" inkl. Einheit (kcal/kJ)
    var formattedTodayActiveEnergy: String {
        let unit = settings.energyUnit
        return formatEnergy(todayActiveEnergy, unit: unit)
    }

    /// 90-Tage-Daten in der aktuell gewählten Einheit für das Chart
    var last90DaysDataForChart: [DailyStepsEntry] {
        let unit = settings.energyUnit
        guard unit != .kcal else { return last90DaysData }

        return last90DaysData.map { entry in
            let converted = convertKcal(entry.steps, to: unit)
            return DailyStepsEntry(date: entry.date, steps: converted)
        }
    }

    /// Monatsdaten in der aktuell gewählten Einheit
    var monthlyActiveEnergyDataForChart: [MonthlyMetricEntry] {
        let unit = settings.energyUnit
        guard unit != .kcal else { return monthlyActiveEnergyData }

        return monthlyActiveEnergyData.map { entry in
            let converted = convertKcal(entry.value, to: unit)
            return MonthlyMetricEntry(
                monthShort: entry.monthShort,
                value: converted
            )
        }
    }

    /// Perioden-Durchschnitte in der aktuell gewählten Einheit
    var periodAveragesForChart: [PeriodAverageEntry] {
        let unit = settings.energyUnit
        guard unit != .kcal else { return periodAverages }

        return periodAverages.map { entry in
            let converted = convertKcal(entry.value, to: unit)
            return PeriodAverageEntry(
                label: entry.label,
                days: entry.days,
                value: converted
            )
        }
    }

    // MARK: - Number Formatter

    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}
