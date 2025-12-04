//
//  WeightViewModel.swift
//  GluVibProbe
//
//  Body-Domain: Verantwortlich für alle Weight-Daten & KPIs (MVVM)
//

import Foundation
import Combine

/// Verantwortlich für alle Weight-Daten & KPIs (MVVM)
final class WeightViewModel: ObservableObject {

    // MARK: - Published Output für die View

    /// Letztes bekanntes Gewicht (kg, Basis in kg)
    @Published var todayWeightKg: Int = 0

    /// Rohdaten: Gewicht der letzten 90 Tage (direkt aus HealthStore, Basis kg)
    @Published var last90DaysWeightRaw: [DailyStepsEntry] = []

    /// Monatliche Gewichtswerte (z. B. Ø Gewicht / Monat) – Basis kg
    @Published var monthlyWeightData: [MonthlyMetricEntry] = []

    /// Tägliches Gewicht der letzten 365 Tage (Rohdaten, Basis kg)
    /// steps-Feld = Gewicht in kg
    @Published var dailyWeight365Raw: [DailyStepsEntry] = []

    // MARK: - Dependencies

    private let healthStore: HealthStore
    private let settings: SettingsModel

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

    // MARK: - Refresh Logic

    func refresh() {
        // 1. HealthKit neu abfragen (Weight)
        healthStore.fetchWeightToday()
        healthStore.fetchLast90DaysWeight()
        healthStore.fetchMonthlyWeight()

        // 2. 365-Tage-Reihe für Durchschnittswerte & Forward-Fill
        healthStore.fetchWeightDaily(last: 365) { [weak self] entries in
            self?.dailyWeight365Raw = entries
        }

        // 3. Werte aus dem HealthStore ins ViewModel spiegeln
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadData()
        }
    }

    // MARK: - Loading Logic

    private func loadData() {
        todayWeightKg       = healthStore.todayWeightKg
        last90DaysWeightRaw = healthStore.last90DaysWeight
        monthlyWeightData   = healthStore.monthlyWeight
    }

    // MARK: - Forward-Fill-Logik (Lücken mit letztem Wert füllen)

    /// Erzeugt aus einer täglichen Reihe (mit 0 = "keine Messung")
    /// eine forward-gefüllte Reihe:
    /// - ab der ersten echten Messung wird jeder 0-Wert
    ///   durch den letzten bekannten Wert ersetzt
    private func forwardFilled(_ entries: [DailyStepsEntry]) -> [DailyStepsEntry] {
        guard !entries.isEmpty else { return [] }

        let sorted = entries.sorted { $0.date < $1.date }
        var result: [DailyStepsEntry] = []
        var lastKnown: Int? = nil

        for entry in sorted {
            let value = entry.steps

            if value > 0 {
                // echter Messwert → merken und übernehmen
                lastKnown = value
                result.append(entry)
            } else if let last = lastKnown {
                // kein Wert, aber wir haben schon einen vorherigen Messwert
                result.append(
                    DailyStepsEntry(date: entry.date, steps: last)
                )
            } else {
                // ganz am Anfang, bevor überhaupt eine Messung existiert → 0 lassen
                result.append(entry)
            }
        }

        return result
    }

    // MARK: - Gefüllte Reihen (Basis kg)

    /// 365-Tage-Reihe mit forward-fill (Basis für Durchschnitte)
    var dailyWeight365Filled: [DailyStepsEntry] {
        forwardFilled(dailyWeight365Raw)
    }

    /// 90-Tage-Reihe für den Chart (ebenfalls forward-filled, Basis kg → dann Einheit)
    private var last90DaysFilledBase: [DailyStepsEntry] {
        let filled = dailyWeight365Filled
        guard !filled.isEmpty else { return [] }

        if filled.count <= 90 {
            return filled
        } else {
            return Array(filled.suffix(90))
        }
    }

    // MARK: - Durchschnittswerte (auf Basis der gefüllten Reihe, kg)

    private func averageKg(last days: Int) -> Int {
        let filled = dailyWeight365Filled
        guard !filled.isEmpty else { return 0 }

        let slice = filled.suffix(days)
        guard !slice.isEmpty else { return 0 }

        let sum = slice.reduce(0) { $0 + $1.steps }
        return sum / slice.count
    }

    var avgWeightLast7Days: Int   { averageKg(last: 7) }
    var avgWeightLast14Days: Int  { averageKg(last: 14) }
    var avgWeightLast30Days: Int  { averageKg(last: 30) }
    var avgWeightLast90Days: Int  { averageKg(last: 90) }
    var avgWeightLast180Days: Int { averageKg(last: 180) }
    var avgWeightLast365Days: Int { averageKg(last: 365) }

    // MARK: - Perioden-Durchschnitte (Basis kg)

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

    // MARK: - Chart-Daten in der gewählten Einheit (kg / lbs)

    /// 90-Tage-Daten (forward-filled) in der aktuell gewählten Einheit
    var last90DaysDataForChart: [DailyStepsEntry] {
        let unit = settings.weightUnit
        let base = last90DaysFilledBase

        guard unit != .kg else {
            return base
        }

        return base.map { entry in
            let converted = unit.convertedValue(fromKg: entry.steps)
            return DailyStepsEntry(date: entry.date, steps: converted)
        }
    }

    /// Perioden-Durchschnitte in der aktuell gewählten Einheit
    var periodAveragesForChart: [PeriodAverageEntry] {
        let unit = settings.weightUnit
        guard unit != .kg else { return periodAverages }

        return periodAverages.map { entry in
            let converted = unit.convertedValue(fromKg: entry.value)
            return PeriodAverageEntry(
                label: entry.label,
                days: entry.days,
                value: converted
            )
        }
    }

    /// Monatsdaten in der aktuell gewählten Einheit
    var monthlyData: [MonthlyMetricEntry] {
        let unit = settings.weightUnit
        guard unit != .kg else { return monthlyWeightData }

        return monthlyWeightData.map { entry in
            let converted = unit.convertedValue(fromKg: entry.value)
            return MonthlyMetricEntry(
                monthShort: entry.monthShort,
                value: converted
            )
        }
    }

    // MARK: - Standardisierte Scaling-Outputs für SectionCardScaled

    /// Skala für Tages-Chart (Weight)
    var dailyScale: MetricScaleResult {
        let values = last90DaysDataForChart.map { Double($0.steps) }
        return MetricScaleHelper.scale(values, for: .weightKg)
    }

    /// Skala für Perioden-Chart (Durchschnittswerte)
    var periodScale: MetricScaleResult {
        let values = periodAveragesForChart.map { Double($0.value) }
        return MetricScaleHelper.scale(values, for: .weightKg)
    }

    /// Skala für Monats-Chart (falls genutzt)
    var monthlyScale: MetricScaleResult {
        let values = monthlyData.map { Double($0.value) }
        return MetricScaleHelper.scale(values, for: .weightKg)
    }

    // MARK: - Formatting für die View (KPI-Strings)

    /// Formatierter Wert für die KPI "Weight Today" inkl. Einheit
    /// nutzt SettingsModel.weightUnit + WeightUnit-Extension
    var formattedTodayWeightKg: String {
        guard todayWeightKg > 0 else { return "–" }

        let unit = settings.weightUnit       // .kg oder .lbs
        return unit.formatted(fromKg: todayWeightKg)
    }
}
