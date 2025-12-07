//
//  BMIViewModel.swift
//  GluVibProbe
//
//  Body-Domain: BMI
//  - lädt tägliche BMI-Werte (max. 365 Tage) aus HealthStore+BMI
//  - berechnet Last-90-Days-Verlauf für das Bar-Chart
//  - berechnet Perioden-Durchschnittswerte (7 / 14 / 30 / 90 / 180 / 365 Tage)
//  - liefert Skalen für BodySectionCardScaled / AveragePeriodsScaledBarChart
//

import Foundation
import Combine

final class BMIViewModel: ObservableObject {

    // MARK: - Published Output für die View

    /// Letzter bekannter BMI-Wert (z.B. 24.3)
    @Published private(set) var todayBMI: Double = 0

    /// 90-Tage-Reihe (BMIEntry), aus 365er-Reihe abgeleitet
    @Published private(set) var last90DaysEntries: [BMIEntry] = []

    /// 90-Tage-Daten für Charts (Adapter auf DailyStepsEntry: steps = gerundeter BMI)
    @Published private(set) var last90DaysDataForChart: [DailyStepsEntry] = []

    /// Perioden-Durchschnittswerte für das AveragePeriodsScaledBarChart
    @Published private(set) var periodAveragesForChart: [PeriodAverageEntry] = []

    /// Monatliche Daten – aktuell nicht genutzt, aber für SectionCard-Schnittstelle nötig
    @Published private(set) var monthlyData: [MonthlyMetricEntry] = []

    /// Skalen für die drei Chart-Blöcke in BodySectionCardScaled
    @Published private(set) var dailyScale: MetricScaleResult
    @Published private(set) var periodScale: MetricScaleResult
    @Published private(set) var monthlyScale: MetricScaleResult

    // MARK: - Interne Rohdaten

    /// Tägliche BMI-Werte der letzten 365 Tage (Basis für Perioden-Berechnung)
    private var dailyBMI365: [BMIEntry] = []

    // MARK: - Dependencies

    private let healthStore: HealthStore

    // MARK: - Init

    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore

        // Default-Skala: vorerst wie Weight, bis ein eigener ScaleType (.bmi) existiert
        let defaultScale = MetricScaleHelper.scale([], for: .weightKg)
        self.dailyScale   = defaultScale
        self.periodScale  = defaultScale
        self.monthlyScale = defaultScale
    }

    // MARK: - KPI-Text

    /// z.B. "24.3"
    var todayBMIText: String {
        guard todayBMI > 0 else { return "–" }
        return String(format: "%.1f", todayBMI)
    }

    // MARK: - Lifecycle

    func onAppear() {
        refresh()
    }

    func refresh() {
        // 365-Tage-Reihe aus HealthKit laden und alles daraus ableiten
        healthStore.fetchBMIDaily(last: 365) { [weak self] entries in
            guard let self else { return }

            DispatchQueue.main.async {
                self.handleFetched(entries: entries)
            }
        }
    }

    // MARK: - Verarbeitung der HealthStore-Daten

    private func handleFetched(entries: [BMIEntry]) {
        // Rohdaten nach Datum sortieren (älteste → neueste)
        let sorted = entries.sorted { $0.date < $1.date }
        dailyBMI365 = sorted

        // KPI: letzter *nicht-null* BMI-Wert
        todayBMI = latestNonZeroBMI(from: sorted) ?? 0

        // ---- Last 90 Days (für Bar-Chart) ----
        let last90 = Array(sorted.suffix(90))
        last90DaysEntries = last90

        last90DaysDataForChart = last90.map { e in
            DailyStepsEntry(
                date: e.date,
                steps: Int(round(e.bmi))   // Adapter: steps = gerundeter BMI
            )
        }

        // ---- Perioden-Durchschnittswerte (Basis: 365er-Reihe) ----
        let avg7   = averageBMILast(7)
        let avg14  = averageBMILast(14)
        let avg30  = averageBMILast(30)
        let avg90  = averageBMILast(90)
        let avg180 = averageBMILast(180)
        let avg365 = averageBMILast(365)

        let periods: [PeriodAverageEntry] = [
            .init(label: "7T",   days: 7,   value: Int(round(avg7))),
            .init(label: "14T",  days: 14,  value: Int(round(avg14))),
            .init(label: "30T",  days: 30,  value: Int(round(avg30))),
            .init(label: "90T",  days: 90,  value: Int(round(avg90))),
            .init(label: "180T", days: 180, value: Int(round(avg180))),
            .init(label: "365T", days: 365, value: Int(round(avg365)))
        ]

        periodAveragesForChart = periods

        // ---- Skalen berechnen (Daily / Period / Monthly) ----

        let dailyValues  = last90DaysDataForChart.map { Double($0.steps) }
        let periodValues = periodAveragesForChart.map { Double($0.value) }

        dailyScale  = MetricScaleHelper.scale(dailyValues,  for: .weightKg)
        periodScale = MetricScaleHelper.scale(periodValues, for: .weightKg)

        // BMI zeigt aktuell keinen Monthly-Chart → Fallback-Skala + leere Daten.
        monthlyData  = []
        monthlyScale = dailyScale
    }

    // MARK: - Hilfsfunktionen

    /// Sucht den letzten BMI > 0 in der Zeitreihe (von hinten nach vorne).
    private func latestNonZeroBMI(from entries: [BMIEntry]) -> Double? {
        for entry in entries.reversed() {
            if entry.bmi > 0 {
                return entry.bmi
            }
        }
        return nil
    }

    /// Durchschnitts-BMI der letzten `days` Kalendertage **vor heute**.
    ///
    /// Regeln:
    /// - heutiger Tag wird ausgeschlossen
    /// - nur Tage mit BMI > 0 werden gewertet
    /// - Mittelwert = Summe / Anzahl der Tage mit gültigem Wert
    private func averageBMILast(_ days: Int) -> Double {
        guard !dailyBMI365.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Zeitraum [startDate ... endDate] = [heute - days ... gestern]
        guard let endDate = calendar.date(byAdding: .day, value: -1, to: today),
              let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            return 0
        }

        let filtered = dailyBMI365.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= startDate && d <= endDate && entry.bmi > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0.0) { $0 + $1.bmi }
        return sum / Double(filtered.count)
    }
}
