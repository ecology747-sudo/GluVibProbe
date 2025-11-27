//
//  StepsViewModel.swift
//  GluVibProbe
//
//  Verantwortlich für alle Steps-Daten & KPIs (MVVM)
//

import Foundation
import Combine

final class StepsViewModel: ObservableObject {

    // MARK: - Published Output for the View

    /// Schritte heute
    @Published var todaySteps: Int = 0

    /// Schritte, die noch zum Ziel fehlen
    @Published var stepsToGo: Int = 0
    
    /// Zielwert Schritte (Int) – kommt aus SettingsModel, wird im Chart für die RuleMark verwendet
    @Published var dailyStepsGoalInt: Int = 0

    /// 90-Tage-Daten für den Chart
    @Published var last90DaysData: [DailyStepsEntry] = []

    /// Monatliche Schritt-Summen (für Monats-Chart)
    @Published var monthlyStepsData: [MonthlyMetricEntry] = []

    /// Tägliche Schritte der letzten 365 Tage (Basis für Durchschnitts-Logik)
    @Published var dailySteps365: [DailyStepsEntry] = []

    // MARK: - Dependencies

    private let healthStore: HealthStore
    private let settings: SettingsModel

    /// Speicher für Combine-Subscriptions
    private var cancellables = Set<AnyCancellable>()


    // MARK: - Initializer

    init(
        healthStore: HealthStore = .shared,
        settings: SettingsModel = .shared
    ) {
        self.healthStore = healthStore
        self.settings = settings

        // Reagiere auf Änderungen des Step-Ziels (z.B. nach "Save Settings")
        settings.$dailyStepGoal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recalculateStepsToGo()
            }
            .store(in: &cancellables)
    }


    // MARK: - Lifecycle

    func onAppear() {
        refresh()   // 👈 immer richtige, aktuelle Daten holen
    }
    
    // MARK: - Refresh Logic (HealthKit neu abfragen)

    func refresh() {
        // 1. HealthKit neu abfragen
        healthStore.fetchStepsToday()
        healthStore.fetchLast90Days()
        healthStore.fetchMonthlySteps()

        // 2. 365-Tage-Reihe für die Durchschnittswerte neu laden
        loadExtendedStepsData()

        // 3. Nach kurzer Zeit die aktuellen Werte aus dem HealthStore
        //    ins ViewModel spiegeln (heute, 90 Tage, Monatsdaten, stepsToGo)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadData()
        }
    }


    // MARK: - Loading Logic (bestehende Werte)

    private func loadData() {
        // Heute
        todaySteps = healthStore.todaySteps

        // Zielwert aus Einstellungen
        let goal = settings.dailyStepGoal
        dailyStepsGoalInt = goal                      // 👈 für KPI & Chart
        stepsToGo = max(goal - todaySteps, 0)

        // 90-Tage-Verlauf (z.B. für Last90DaysBarChart)
        last90DaysData = healthStore.last90Days

        // Monatsverlauf
        monthlyStepsData = healthStore.monthlySteps
    }

    // MARK: - Loading Logic (365 Tage für Durchschnittswerte)

    private func loadExtendedStepsData() {
        // holt die letzten 365 Tage als Tagesreihe
        healthStore.fetchStepsDaily(last: 365) { [weak self] entries in
            self?.dailySteps365 = entries
        }
    }


    // MARK: - Durchschnittswerte (Steps) – basierend auf dailySteps365

    /// Durchschnittliche Schritte der letzten 7 Tage
    var avgStepsLast7Days: Int {
        averageSteps(last: 7)
    }

    /// Durchschnittliche Schritte der letzten 14 Tage
    var avgStepsLast14Days: Int {
        averageSteps(last: 14)
    }

    /// Durchschnittliche Schritte der letzten 30 Tage
    var avgStepsLast30Days: Int {
        averageSteps(last: 30)
    }

    /// Durchschnittliche Schritte der letzten 90 Tage
    var avgStepsLast90Days: Int {
        averageSteps(last: 90)
    }

    /// Durchschnittliche Schritte der letzten 180 Tage
    var avgStepsLast180Days: Int {
        averageSteps(last: 180)
    }

    /// Durchschnittliche Schritte der letzten 365 Tage
    var avgStepsLast365Days: Int {
        averageSteps(last: 365)
    }
    
    // MARK: - Durchschnittswerte für den Perioden-Chart

        var periodAverages: [PeriodAverageEntry] {
            [
                PeriodAverageEntry(label: "7T",   days: 7,   value: avgStepsLast7Days),
                PeriodAverageEntry(label: "14T",  days: 14,  value: avgStepsLast14Days),
                PeriodAverageEntry(label: "30T",  days: 30,  value: avgStepsLast30Days),
                PeriodAverageEntry(label: "90T",  days: 90,  value: avgStepsLast90Days),
                PeriodAverageEntry(label: "180T", days: 180, value: avgStepsLast180Days),
                PeriodAverageEntry(label: "365T", days: 365, value: avgStepsLast365Days)
            ]
        }

    // MARK: - Durchschnittswerte (Steps) – basierend auf dailySteps365

    /// Durchschnitt der letzten `days` Tage – **ohne** heutigen Tag (wie Apple Health).
    private func averageSteps(last days: Int) -> Int {
        // Mindestens 2 Tage nötig (heute + mindestens ein abgeschlossener Tag)
        guard dailySteps365.count > 1 else { return 0 }

        // 1️⃣ nach Datum sortieren (falls noch nicht garantiert)
        let sorted = dailySteps365.sorted { $0.date < $1.date }

        // 2️⃣ heutigen Tag entfernen (letzter Eintrag)
        let withoutToday = Array(sorted.dropLast())

        // falls danach nichts mehr übrig ist → 0
        guard !withoutToday.isEmpty else { return 0 }

        // 3️⃣ die letzten `days` abgeschlossenen Tage nehmen
        let slice = withoutToday.suffix(days)

        let sum = slice.reduce(0) { $0 + $1.steps }
        return sum / slice.count
    }


    // MARK: - Ziel-Logik (Steps to Go)

    /// Berechnet `stepsToGo` aus aktuellem Ziel (`settings.dailyStepGoal`)
    /// und den heutigen Schritten (`todaySteps`).
    private func recalculateStepsToGo() {
        let goal = settings.dailyStepGoal
        stepsToGo = max(goal - todaySteps, 0)
    }


    // MARK: - Formatting for the View

    /// Formatierter Wert für "Current" (heute)
    var formattedTodaySteps: String {
        numberFormatter.string(from: NSNumber(value: todaySteps))
            ?? "\(todaySteps)"
    }

    /// Formatierter Wert für "Remaining" / "Delta (roh)" – aktuell noch als Steps to go
    var formattedStepsToGo: String {
        numberFormatter.string(from: NSNumber(value: stepsToGo))
            ?? "\(stepsToGo)"
    }

    /// Formatierter Zielwert für KPI-Card ("Target")
    var formattedDailyStepGoal: String {
        numberFormatter.string(from: NSNumber(value: dailyStepsGoalInt))
            ?? "\(dailyStepsGoalInt)"
    }

    /// KPI-Delta-Text für die Karte "Delta"
    ///
    /// Berechnung:
    ///     diff = Current - Target
    /// Darstellung:
    ///     + 1 234  → über Ziel
    ///     − 567    → unter Ziel
    ///     ± 0      → exakt im Zielbereich
    var kpiDeltaText: String {
        let diff = todaySteps - dailyStepsGoalInt          // Current - Target
        let sign: String

        if diff > 0 {
            sign = "+"
        } else if diff < 0 {
            sign = "−"                                     // schönes Minus
        } else {
            sign = "±"                                     // exakt im Ziel
        }

        let absValue = abs(diff)
        let formatted = numberFormatter.string(from: NSNumber(value: absValue))
            ?? "\(absValue)"

        return "\(sign) \(formatted)"
    }


    // MARK: - Number Formatter

    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}
