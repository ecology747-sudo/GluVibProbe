//
//  NutritionEnergyViewModel.swift
//  GluVibProbe
//
//  Domain: NUTRITION – Nutrition Energy (kcal / kJ)
//

import Foundation
import Combine

final class NutritionEnergyViewModel: ObservableObject {

    // MARK: - Published Output für die View

    /// Heutige Nahrungsenergie in **kcal** (Basis aus HealthKit)
    @Published var todayEnergyKcal: Int = 0

    /// 90-Tage-Nahrungsenergie (Basis: kcal pro Tag)
    @Published var last90DaysEnergy: [DailyNutritionEnergyEntry] = []

    /// Monatliche Nahrungsenergie (Summen je Monat, Basis: kcal)
    @Published var monthlyEnergy: [MonthlyMetricEntry] = []

    /// 365-Tage-Reihe für Durchschnittswerte (Basis: kcal)
    @Published var dailyEnergy365: [DailyNutritionEnergyEntry] = []

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
    }

    // MARK: - Lifecycle

    func onAppear() {
        refresh()
    }

    /// HealthKit neu abfragen + lokale Published-Werte auffrischen
    func refresh() {
        // 1) HealthKit-Fetches anstoßen (liegen in HealthStore+NutritionEnergy.swift)
        healthStore.fetchNutritionEnergyToday { [weak self] kcal in
            self?.todayEnergyKcal = kcal
        }

        healthStore.fetchNutritionEnergyDaily(last: 90) { [weak self] entries in
            self?.last90DaysEnergy = entries
        }

        healthStore.fetchNutritionEnergyMonthly { [weak self] monthly in
            self?.monthlyEnergy = monthly
        }

        // 365-Tage-Reihe für Durchschnittswerte
        healthStore.fetchNutritionEnergyDaily(last: 365) { [weak self] entries in
            self?.dailyEnergy365 = entries
        }
    }

    // MARK: - Settings / Target

    /// Zielwert aus SettingsModel (Basis: kcal)
    private var targetKcal: Int {
        settings.dailyCalories
    }

    /// Aktuelle Energieeinheit (kcal oder kJ) aus Settings
    private var energyUnit: EnergyUnit {
        settings.energyUnit
    }

    /// Zielwert in der aktuell gewählten Einheit (Int)
    private var targetInCurrentUnit: Int {
        convertKcalToCurrentUnit(targetKcal)
    }

    /// Heute in der aktuell gewählten Einheit (Int)
    private var todayInCurrentUnit: Int {
        convertKcalToCurrentUnit(todayEnergyKcal)
    }

    // MARK: - Umrechnung kcal ↔︎ kJ

    /// 1 kcal ≈ 4.184 kJ
    private func convertKcalToCurrentUnit(_ kcal: Int) -> Int {
        switch energyUnit {
        case .kcal:
            return kcal
        case .kilojoules:                     // ✅ richtiger Case-Name
            let value = Double(kcal) * 4.184
            return Int(value.rounded())
        }
    }

    private var unitLabel: String {
        switch energyUnit {
        case .kcal:
            return "kcal"
        case .kilojoules:                     // ✅ richtiger Case-Name
            return "kJ"
        }
    }

    // MARK: - KPI-Texte (für NutritionEnergyView)

    /// KPI: Zielwert-Text (z. B. "2 500 kcal" oder "10 460 kJ")
    var targetText: String {
        guard targetKcal > 0 else { return "–" }

        let value = targetInCurrentUnit
        let formatted = numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) \(unitLabel)"
    }

    /// KPI: Current-Text (heute)
    var currentText: String {
        guard todayEnergyKcal > 0 else { return "–" }

        let value = todayInCurrentUnit
        let formatted = numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) \(unitLabel)"
    }

    /// KPI: Delta-Text (Current – Target) z. B. "+120 kcal" oder "−800 kJ"
    var deltaText: String {
        guard targetKcal > 0, todayEnergyKcal > 0 else { return "–" }

        let delta = todayInCurrentUnit - targetInCurrentUnit
        if delta == 0 { return "0 \(unitLabel)" }

        let sign = delta > 0 ? "+" : "–"
        let absValue = abs(delta)
        let formatted = numberFormatter.string(from: NSNumber(value: absValue)) ?? "\(absValue)"

        return "\(sign)\(formatted) \(unitLabel)"
    }

    // MARK: - Chart-Daten für NutritionSectionCard

    /// Wert für die horizontale Ziel-Linie im 90d-Chart
    var chartGoalValue: Int? {
        guard targetKcal > 0 else { return nil }
        return targetInCurrentUnit
    }

    /// 90d-Chart-Daten in generisches Format (DailyStepsEntry) konvertiert
    var last90DaysForChart: [DailyStepsEntry] {
        last90DaysEnergy.map { entry in
            let converted = convertKcalToCurrentUnit(entry.energyKcal)
            return DailyStepsEntry(
                date: entry.date,
                steps: converted
            )
        }
    }

    /// Perioden-Durchschnittswerte für 7, 14, 30, 90, 180, 365 Tage
    var periodAverages: [PeriodAverageEntry] {
        [
            PeriodAverageEntry(label: "7T",   days: 7,   value: averageEnergy(last: 7)),
            PeriodAverageEntry(label: "14T",  days: 14,  value: averageEnergy(last: 14)),
            PeriodAverageEntry(label: "30T",  days: 30,  value: averageEnergy(last: 30)),
            PeriodAverageEntry(label: "90T",  days: 90,  value: averageEnergy(last: 90)),
            PeriodAverageEntry(label: "180T", days: 180, value: averageEnergy(last: 180)),
            PeriodAverageEntry(label: "365T", days: 365, value: averageEnergy(last: 365))
        ]
    }

    /// Monatsdaten direkt aus HealthStore (werden in NutritionEnergyView weitergereicht)
    var monthlyEnergyForChart: [MonthlyMetricEntry] {
        monthlyEnergy.map { entry in
            let converted = convertKcalToCurrentUnit(entry.value)
            return MonthlyMetricEntry(monthShort: entry.monthShort, value: converted)
        }
    }

    // MARK: - Durchschnittswerte

    /// Durchschnitt der letzten `days` Tage (ohne heutigen Tag) in aktueller Einheit
    private func averageEnergy(last days: Int) -> Int {
        guard dailyEnergy365.count > 1 else { return 0 }

        let sorted = dailyEnergy365.sorted { $0.date < $1.date }

        // heutigen Tag entfernen
        let withoutToday = Array(sorted.dropLast())
        guard !withoutToday.isEmpty else { return 0 }

        let slice = withoutToday.suffix(days)
        if slice.isEmpty { return 0 }

        let sumKcal = slice.reduce(0) { $0 + $1.energyKcal }
        let avgKcal = sumKcal / slice.count

        return convertKcalToCurrentUnit(avgKcal)
    }

    // MARK: - Formatter

    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}
