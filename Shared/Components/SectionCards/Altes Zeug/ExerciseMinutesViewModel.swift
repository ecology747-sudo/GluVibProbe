//
//  ExerciseMinutesViewModel.swift
//  GluVibProbe
//
//  Verantwortlich für alle Exercise-Minutes-Daten & KPIs (MVVM)
//

import Foundation
import Combine

final class ExerciseMinutesViewModel: ObservableObject {

    // MARK: - Published Output for the View
    // ----------------------------------------------------

    /// Trainingsminuten (Exercise Minutes) heute
    @Published var todayExerciseMinutes: Int = 0             // !!! NEW

    /// 90-Tage-Daten (tägliche Exercise Minutes)
    @Published var last90DaysData: [DailyExerciseMinutesEntry] = []   // !!! NEW

    /// Monatliche Summen (für Monthly-Chart)
    @Published var monthlyExerciseMinutesData: [MonthlyMetricEntry] = [] // !!! NEW

    /// Tägliche Exercise Minutes der letzten 365 Tage
    /// (Basis für Durchschnitts-Logik)
    @Published var dailyExerciseMinutes365: [DailyExerciseMinutesEntry] = [] // !!! NEW


    // MARK: - Dependencies
    // ----------------------------------------------------

    private let healthStore: HealthStore                     // !!! NEW

    /// Speicher für Combine-Subscriptions (Reserve – aktuell ungenutzt)
    private var cancellables = Set<AnyCancellable>()         // !!! NEW


    // MARK: - Initializer
    // ----------------------------------------------------

    init(healthStore: HealthStore = .shared) {               // !!! NEW
        self.healthStore = healthStore                       // !!! NEW
    }


    // MARK: - Lifecycle
    // ----------------------------------------------------

    /// Wird von der View (ExerciseMinutesView) in `onAppear()` aufgerufen.
    func onAppear() {                                        // !!! NEW
        refresh()                                            // !!! NEW
    }


    // MARK: - Refresh Logic (HealthKit neu abfragen)
    // ----------------------------------------------------

    /// Fragt HealthKit neu ab und aktualisiert alle relevanten Werte.
    func refresh() {                                         // !!! NEW
        // 1. Heutige Exercise Minutes laden
        healthStore.fetchExerciseMinutesToday { [weak self] minutes in
            DispatchQueue.main.async {
                self?.todayExerciseMinutes = minutes
            }
        }

        // 2. 90-Tage-Verlauf (Tagessummen) laden
        healthStore.fetchLast90DaysExerciseMinutes { [weak self] entries in
            DispatchQueue.main.async {
                self?.last90DaysData = entries
            }
        }

        // 3. Monatsverlauf (Summen pro Monat) laden
        healthStore.fetchMonthlyExerciseMinutes { [weak self] monthly in
            DispatchQueue.main.async {
                self?.monthlyExerciseMinutesData = monthly
            }
        }

        // 4. 365-Tage-Reihe für Durchschnittswerte laden
        healthStore.fetchExerciseMinutesDaily(last: 365) { [weak self] entries in
            DispatchQueue.main.async {
                self?.dailyExerciseMinutes365 = entries
            }
        }
    }

    // MARK: - Overview-Helper (für ActivityOverview)            // !!! NEW

    /// 7-Tage-Durchschnitt der Exercise Minutes (Kalendertage vor heute),
    /// gleiche Logik wie im AveragePeriods-BarChart.
    var sevenDayAverageExerciseMinutes: Int {                    // !!! NEW
        averageMinutes(last: 7)
    }

    // MARK: - Durchschnittswerte (Exercise Minutes)
    // ----------------------------------------------------

    /// Durchschnittliche Exercise Minutes der letzten 7 Kalendertage **vor heute**
    var avgExerciseMinutesLast7Days: Int {                   // !!! NEW
        averageMinutes(last: 7)
    }

    /// Durchschnitt der letzten 14 Kalendertage **vor heute**
    var avgExerciseMinutesLast14Days: Int {                  // !!! NEW
        averageMinutes(last: 14)
    }

    /// Durchschnitt der letzten 30 Kalendertage **vor heute**
    var avgExerciseMinutesLast30Days: Int {                  // !!! NEW
        averageMinutes(last: 30)
    }

    /// Durchschnitt der letzten 90 Kalendertage **vor heute**
    var avgExerciseMinutesLast90Days: Int {                  // !!! NEW
        averageMinutes(last: 90)
    }

    /// Durchschnitt der letzten 180 Kalendertage **vor heute**
    var avgExerciseMinutesLast180Days: Int {                 // !!! NEW
        averageMinutes(last: 180)
    }

    /// Durchschnitt der letzten 365 Kalendertage **vor heute**
    var avgExerciseMinutesLast365Days: Int {                 // !!! NEW
        averageMinutes(last: 365)
    }


    // MARK: - Durchschnittswerte für den Perioden-Chart
    // ----------------------------------------------------

    /// Aggregierte Durchschnittswerte für den "Average Periods"-Chart
    var periodAverages: [PeriodAverageEntry] {               // !!! NEW
        [
            PeriodAverageEntry(label: "7T",   days: 7,   value: avgExerciseMinutesLast7Days),
            PeriodAverageEntry(label: "14T",  days: 14,  value: avgExerciseMinutesLast14Days),
            PeriodAverageEntry(label: "30T",  days: 30,  value: avgExerciseMinutesLast30Days),
            PeriodAverageEntry(label: "90T",  days: 90,  value: avgExerciseMinutesLast90Days),
            PeriodAverageEntry(label: "180T", days: 180, value: avgExerciseMinutesLast180Days),
            PeriodAverageEntry(label: "365T", days: 365, value: avgExerciseMinutesLast365Days)
        ]
    }


    // MARK: - Scaled Chart Outputs (für SectionCardScaled)
    // ----------------------------------------------------

    /// Interne Rohdaten – 90 Tage Exercise Minutes
    var last90DaysDataForChart: [DailyExerciseMinutesEntry] {    // !!! NEW
        last90DaysData
    }

    /// Chart-Input für deine bestehenden Scaled-Charts
    /// (Struktur wie bei Steps-Chart, Wert = Minuten)
    var last90DaysChartData: [DailyStepsEntry] {                 // !!! NEW
        last90DaysDataForChart.map { entry in
            DailyStepsEntry(date: entry.date, steps: entry.minutes)
        }
    }

    /// Alias für Monatsdaten – standardisiert für alle Domains
    var monthlyData: [MonthlyMetricEntry] {                      // !!! NEW
        monthlyExerciseMinutesData
    }

    /// Skala für Tages-Chart (Exercise Minutes)
    var dailyScale: MetricScaleResult {
        let values = last90DaysDataForChart.map { Double($0.minutes) }
        return MetricScaleHelper.scale(values, for: .exerciseMinutes)   // !!! UPDATED
    }

    var periodScale: MetricScaleResult {
        let values = periodAverages.map { Double($0.value) }
        return MetricScaleHelper.scale(values, for: .exerciseMinutes)   // !!! UPDATED
    }

    /// Skala für Monats-Chart
    var monthlyScale: MetricScaleResult {                        // !!! NEW
        let values = monthlyData.map { Double($0.value) }
        return MetricScaleHelper.scale(values, for: .energyDaily)
    }


    // MARK: - Durchschnitts-Helfer
    // ----------------------------------------------------

    /// Durchschnitt der letzten `days` Kalendertage **vor heute**.
    /// - heutiger Tag ausgeschlossen
    /// - Tage ohne Eintrag (minutes <= 0) werden ignoriert
    /// - geteilt wird durch die Anzahl der Tage mit Eintrag, nicht durch `days`
    //private func averageMinutes(last days: Int) -> Int {         // !!! NEW
    func averageMinutes(last days: Int) -> Int {
        guard !dailyExerciseMinutes365.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Zeitraum [startDate ... endDate] = [heute - days ... gestern]
        guard let endDate = calendar.date(byAdding: .day, value: -1, to: today),
              let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            return 0
        }

        // Nur Einträge im Kalenderraster mit > 0 Minuten
        let filtered = dailyExerciseMinutes365.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= startDate && d <= endDate && entry.minutes > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0) { $0 + $1.minutes }
        return sum / filtered.count
    }


    // MARK: - Formatting for the View
    // ----------------------------------------------------

    /// Formatierter Wert für "Current" (heutige Exercise Minutes)
    var formattedTodayExerciseMinutes: String {                  // !!! NEW
        numberFormatter.string(from: NSNumber(value: todayExerciseMinutes))
            ?? "\(todayExerciseMinutes)"
    }


    // MARK: - Number Formatter
    // ----------------------------------------------------

    private let numberFormatter: NumberFormatter = {             // !!! NEW
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}
