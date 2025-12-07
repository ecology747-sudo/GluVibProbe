//
//  BodyFatViewModel.swift
//  GluVibProbe
//
//  Body-Domain: Body Fat (%)
//  - lädt tägliche Body-Fat-Werte (max. 365 Tage) aus HealthStore+BodyFat
//  - berechnet Last-90-Days-Verlauf für das Bar-Chart
//  - berechnet Perioden-Durchschnittswerte (7 / 14 / 30 / 90 / 180 / 365 Tage)
//  - liefert Skalen für BodySectionCardScaled / AveragePeriodsScaledBarChart
//

import Foundation
import Combine

final class BodyFatViewModel: ObservableObject {

    // MARK: - Published Output für die View

    /// Letzter bekannter Körperfettwert in % (z.B. 18.7)
    @Published private(set) var todayBodyFatPercent: Double = 0

    /// 90-Tage-Reihe (BodyFatEntry), aus 365er-Reihe abgeleitet
    @Published private(set) var last90DaysEntries: [BodyFatEntry] = []

    /// 90-Tage-Daten für Charts (Adapter auf DailyStepsEntry: steps = % gerundet)
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

    /// Tägliche Body-Fat-Werte der letzten 365 Tage (Basis für Perioden-Berechnung)
    private var dailyBodyFat365: [BodyFatEntry] = []

    // MARK: - Dependencies

    private let healthStore: HealthStore

    // MARK: - Init

    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore

        // Default-Skala: vorerst wie Weight, bis ein eigener ScaleType (.bodyFatPercent) existiert
        let defaultScale = MetricScaleHelper.scale([], for: .weightKg)
        self.dailyScale   = defaultScale
        self.periodScale  = defaultScale
        self.monthlyScale = defaultScale
    }

    // MARK: - KPI-Text

    /// z.B. "18.7"
    var todayBodyFatText: String {
        guard todayBodyFatPercent > 0 else { return "–" }
        return String(format: "%.1f", todayBodyFatPercent)
    }

    // MARK: - Lifecycle

    func onAppear() {
        refresh()
    }

    func refresh() {
        // 365-Tage-Reihe aus HealthKit laden und alles daraus ableiten
        healthStore.fetchBodyFatDaily(last: 365) { [weak self] entries in
            guard let self else { return }

            DispatchQueue.main.async {
                self.handleFetched(entries: entries)
            }
        }
    }

    // MARK: - Verarbeitung der HealthStore-Daten

    private func handleFetched(entries: [BodyFatEntry]) {
        // Rohdaten nach Datum sortieren (älteste → neueste)
        let sorted = entries.sorted { $0.date < $1.date }
        dailyBodyFat365 = sorted

        // KPI: letzter *nicht-null* Body-Fat-Wert
        todayBodyFatPercent = latestNonZeroBodyFat(from: sorted) ?? 0

        // ---- Last 90 Days (für Bar-Chart) ----
        let last90 = Array(sorted.suffix(90))
        last90DaysEntries = last90

        last90DaysDataForChart = last90.map { e in
            DailyStepsEntry(
                date: e.date,
                steps: Int(round(e.bodyFatPercent))   // Adapter: steps = gerundeter %
            )
        }

        // ---- Perioden-Durchschnittswerte (Basis: 365er-Reihe) ----
        let avg7   = averageBodyFatLast(7)
        let avg14  = averageBodyFatLast(14)
        let avg30  = averageBodyFatLast(30)
        let avg90  = averageBodyFatLast(90)
        let avg180 = averageBodyFatLast(180)
        let avg365 = averageBodyFatLast(365)

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

        // Body Fat zeigt aktuell keinen Monthly-Chart → Fallback-Skala + leere Daten.
        monthlyData  = []
        monthlyScale = dailyScale
    }

    // MARK: - Hilfsfunktionen

    /// Sucht den letzten Body-Fat-Wert > 0 in der Zeitreihe (von hinten nach vorne).
    private func latestNonZeroBodyFat(from entries: [BodyFatEntry]) -> Double? {
        for entry in entries.reversed() {
            if entry.bodyFatPercent > 0 {
                return entry.bodyFatPercent
            }
        }
        return nil
    }

    /// Durchschnitts-Body-Fat (%) der letzten `days` Kalendertage **vor heute**.
    ///
    /// Regeln:
    /// - heutiger Tag wird ausgeschlossen
    /// - nur Tage mit bodyFatPercent > 0 werden gewertet
    /// - Mittelwert = Summe / Anzahl der Tage mit gültigem Wert
    private func averageBodyFatLast(_ days: Int) -> Double {
        guard !dailyBodyFat365.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Zeitraum [startDate ... endDate] = [heute - days ... gestern]
        guard let endDate = calendar.date(byAdding: .day, value: -1, to: today),
              let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            return 0
        }

        let filtered = dailyBodyFat365.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= startDate && d <= endDate && entry.bodyFatPercent > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0.0) { $0 + $1.bodyFatPercent }
        return sum / Double(filtered.count)
    }
}
