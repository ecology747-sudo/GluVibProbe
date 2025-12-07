//  RestingHeartRateViewModel.swift
//  GluVibProbe
//
//  Body-Domain: Resting Heart Rate (bpm)
//  - Nutzung von HealthStore+RestingHeartRate
//  - KPI + Last-90-Days-Line-Chart
//  - Period Averages (7/14/30/90/180/365) für AveragePeriodsScaledBarChart
//

import Foundation
import Combine

final class RestingHeartRateViewModel: ObservableObject {

    // MARK: - Published Werte für View & Charts

    /// Letzter bekannter (plausibler) Ruhepuls (bpm)
    @Published private(set) var todayRestingHR: Int = 0

    /// Rohdaten der letzten 90 Tage (bereits plausibilisiert)
    @Published private(set) var last90DaysEntries: [RestingHeartRateEntry] = []

    /// Rohdaten der letzten 365 Tage (bereits plausibilisiert)
    @Published private(set) var dailyRestingHR365: [RestingHeartRateEntry] = []

    /// Für Charts aufbereitete 90-Tage-Daten (steps = bpm)
    @Published private(set) var last90DaysDataForChart: [DailyStepsEntry] = []

    /// Perioden-Durchschnittswerte (7 / 14 / 30 / 90 / 180 / 365 Tage)
    @Published private(set) var periodAveragesForChart: [PeriodAverageEntry] = []

    /// Monatliche Werte – aktuell nicht genutzt
    @Published private(set) var monthlyData: [MonthlyMetricEntry] = []

    /// Skalen für die drei Charts
    @Published private(set) var dailyScale: MetricScaleResult
    @Published private(set) var periodScale: MetricScaleResult
    @Published private(set) var monthlyScale: MetricScaleResult

    // MARK: - Dependencies

    private let healthStore: HealthStore

    // MARK: - Init

    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore

        // Basis-Skala: Heart-Rate-Profil
        let defaultScale = MetricScaleHelper.scale([], for: .heartRateBpm)
        self.dailyScale   = defaultScale
        self.periodScale  = defaultScale
        self.monthlyScale = defaultScale
    }

    // MARK: - KPI-Text

    /// KPI-Text für „Resting HR Today“
    var todayRestingHeartRateText: String {
        todayRestingHR > 0 ? "\(todayRestingHR) bpm" : "– bpm"
    }

    /// Alias (für alte Stellen)
    var todayRestingHRText: String {
        todayRestingHeartRateText
    }

    // MARK: - Lifecycle

    func onAppear() {
        refresh()
    }

    func refresh() {
        // 1) 90 Tage für Line-Chart + KPI
        fetchLast90Days()

        // 2) 365 Tage für Period Averages (7/14/30/90/180/365)
        fetchPeriodBase365()
    }

    // MARK: - Plausibilitäts-Filter

    /// Bereich, in dem ein Ruhepuls als plausibel gilt.
    /// (kannst du bei Bedarf anpassen)
    private func isPlausible(_ bpm: Int) -> Bool {
        bpm >= 35 && bpm <= 130
    }

    // MARK: - Private Ladefunktionen

    /// 90 Tage Ruhepuls (für Line-Chart + KPI)
    private func fetchLast90Days() {
        healthStore.fetchRestingHeartRateDaily(last: 90) { [weak self] entries in
            guard let self else { return }

            DispatchQueue.main.async {
                // Nur plausible bpm-Werte behalten
                let cleaned = entries.filter { self.isPlausible($0.restingHeartRate) }

                self.last90DaysEntries = cleaned

                // KPI = letzter plausibler Wert
                self.todayRestingHR = cleaned.last?.restingHeartRate ?? 0

                // Adapter für Chart
                self.last90DaysDataForChart = cleaned.map { e in
                    DailyStepsEntry(
                        date: e.date,
                        steps: e.restingHeartRate
                    )
                }

                // Skala (nur über plausible Werte)
                let values = self.last90DaysDataForChart.map { Double($0.steps) }
                self.dailyScale = MetricScaleHelper.scale(values, for: .heartRateBpm)

                // Monthly aktuell nicht genutzt → Fallback
                self.monthlyData  = []
                self.monthlyScale = self.dailyScale
            }
        }
    }

    /// 365 Tage Ruhepuls (Basis für Period Averages)
    private func fetchPeriodBase365() {
        healthStore.fetchRestingHeartRateDaily(last: 365) { [weak self] entries in
            guard let self else { return }

            DispatchQueue.main.async {
                // Nur plausible Werte für Perioden-Berechnung
                self.dailyRestingHR365 = entries.filter { self.isPlausible($0.restingHeartRate) }
                self.recomputePeriodAverages()
            }
        }
    }

    // MARK: - Perioden-Durchschnitte (7/14/30/90/180/365)

    /// Durchschnitt der letzten `days` Kalendertage **vor heute**
    /// - heutiger Tag wird ausgeschlossen
    /// - nur plausible bpm-Werte werden berücksichtigt
    private func averageRestingHR(last days: Int) -> Int {
        guard !dailyRestingHR365.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())

        guard let endDate   = calendar.date(byAdding: .day, value: -1, to: today),
              let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            return 0
        }

        let filtered = dailyRestingHR365.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= startDate &&
                   d <= endDate &&
                   isPlausible(entry.restingHeartRate)
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0) { $0 + $1.restingHeartRate }
        return sum / filtered.count
    }

    /// Baut Perioden-Durchschnittswerte & Skala für AveragePeriodsScaledBarChart
    private func recomputePeriodAverages() {
        let avg7   = averageRestingHR(last: 7)
        let avg14  = averageRestingHR(last: 14)
        let avg30  = averageRestingHR(last: 30)
        let avg90  = averageRestingHR(last: 90)
        let avg180 = averageRestingHR(last: 180)
        let avg365 = averageRestingHR(last: 365)

        let periods: [PeriodAverageEntry] = [
            .init(label: "7T",   days: 7,   value: avg7),
            .init(label: "14T",  days: 14,  value: avg14),
            .init(label: "30T",  days: 30,  value: avg30),
            .init(label: "90T",  days: 90,  value: avg90),
            .init(label: "180T", days: 180, value: avg180),
            .init(label: "365T", days: 365, value: avg365)
        ]

        periodAveragesForChart = periods

        let values = periods.map { Double($0.value) }
        periodScale = MetricScaleHelper.scale(values, for: .heartRateBpm)
    }
}
