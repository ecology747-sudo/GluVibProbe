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

    /// 90-Tage-Daten (Basis: kcal, intern)
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

    /// Durchschnittliche Aktivitätsenergie der letzten 7 Kalendertage **vor heute**
    var avgActiveEnergyLast7Days: Int {
        averageActiveEnergy(last: 7)
    }

    /// Durchschnittliche Aktivitätsenergie der letzten 14 Kalendertage **vor heute**
    var avgActiveEnergyLast14Days: Int {
        averageActiveEnergy(last: 14)
    }

    /// Durchschnittliche Aktivitätsenergie der letzten 30 Kalendertage **vor heute**
    var avgActiveEnergyLast30Days: Int {
        averageActiveEnergy(last: 30)
    }

    /// Durchschnittliche Aktivitätsenergie der letzten 90 Kalendertage **vor heute**
    var avgActiveEnergyLast90Days: Int {
        averageActiveEnergy(last: 90)
    }

    /// Durchschnittliche Aktivitätsenergie der letzten 180 Kalendertage **vor heute**
    var avgActiveEnergyLast180Days: Int {
        averageActiveEnergy(last: 180)
    }

    /// Durchschnittliche Aktivitätsenergie der letzten 365 Kalendertage **vor heute**
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

    /// 🟢 NEU:
    /// Durchschnitt der letzten `days` **Kalendertage vor heute** (Basis kcal),
    /// mit diesen Regeln:
    ///   - heutiger Tag wird ausgeschlossen
    ///   - Tage ohne Eintrag (activeEnergy <= 0) werden NICHT gewertet
    ///   - geteilt wird durch die Anzahl der Tage mit Eintrag, nicht durch `days`
    private func averageActiveEnergy(last days: Int) -> Int {
        guard !dailyActiveEnergy365.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Zeitraum [startDate ... endDate] = [heute - days ... gestern]
        guard let endDate = calendar.date(byAdding: .day, value: -1, to: today),
              let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            return 0
        }

        // Nur Einträge im Kalenderraster mit > 0 kcal
        let filtered = dailyActiveEnergy365.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= startDate && d <= endDate && entry.activeEnergy > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0) { $0 + $1.activeEnergy }
        return sum / filtered.count
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

    // MARK: - Chart-Daten in der gewählten Einheit (kcal / kJ)

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

    // MARK: - Standardisierte Scaling-Outputs für SectionCardScaled

    /// Alias für Monatsdaten – standardisiert für alle Domains
    var monthlyData: [MonthlyMetricEntry] {
        monthlyActiveEnergyDataForChart
    }

    /// Skala für Tages-Chart (Energy, Tageswerte)
    var dailyScale: MetricScaleResult {
        let values = last90DaysDataForChart.map { Double($0.steps) }
        return MetricScaleHelper.scale(values, for: .energyDaily)
    }

    /// Skala für Perioden-Chart (Durchschnittswerte, pro Tag)
    var periodScale: MetricScaleResult {
        let values = periodAveragesForChart.map { Double($0.value) }
        return MetricScaleHelper.scale(values, for: .energyDaily)
    }

    /// Skala für Monats-Chart (Energy-Monatssummen)
    var monthlyScale: MetricScaleResult {
        let values = monthlyData.map { Double($0.value) }
        return MetricScaleHelper.scale(values, for: .energyMonthly)
    }

    // MARK: - Number Formatter

    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}
