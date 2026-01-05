//
//  WorkoutMinutesViewModelV1.swift
//  GluVibProbe
//
//  V1: Workout Minutes ViewModel (kein Fetch im VM)
//  - bindet nur HealthStore
//  - Daten kommen aus:
//      healthStore.todayWorkoutMinutes
//      healthStore.last90DaysWorkoutMinutes
//      healthStore.monthlyWorkoutMinutes
//      healthStore.workoutMinutesDaily365
//
//  ✅ FIX:
//  - Entfernt doppelte/uneinheitliche Today-Outputs (todayMinutes)
//  - Einheitliche Naming-Strategie: "Workout Minutes"
//  - sevenDayAverageWorkoutMinutes wird nun sauber aus daily365 berechnet
//

import Foundation
import SwiftUI
import Combine

final class WorkoutMinutesViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (SSoT → View)
    // ============================================================

    @Published var todayWorkoutMinutes: Int = 0                           // ✅ FIX (einheitlich)
    @Published var sevenDayAverageWorkoutMinutes: Int = 0                 // ✅ FIX (wird befüllt)

    @Published var last90DaysData: [DailyStepsEntry] = []                 // Chart Adapter (Steps-Pattern)
    @Published var monthlyDataRaw: [MonthlyMetricEntry] = []
    @Published var daily365: [DailyWorkoutMinutesEntry] = []

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    private let healthStore: HealthStore
    private var cancellables = Set<AnyCancellable>()

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore
        bind()
        sync()
    }

    // ============================================================
    // MARK: - Bindings (HealthStore → Published)
    // ============================================================

    private func bind() {

        // TODAY
        healthStore.$todayWorkoutMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.todayWorkoutMinutes = $0
            }
            .store(in: &cancellables)

        // LAST 90 DAYS (Chart)
        healthStore.$last90DaysWorkoutMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.last90DaysData = entries.map {
                    DailyStepsEntry(date: $0.date, steps: $0.minutes)
                }
            }
            .store(in: &cancellables)

        // MONTHLY
        healthStore.$monthlyWorkoutMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.monthlyDataRaw = $0
            }
            .store(in: &cancellables)

        // 365 (Base Series + 7d Avg Derivation)
        healthStore.$workoutMinutesDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] series in
                guard let self else { return }
                self.daily365 = series
                self.sevenDayAverageWorkoutMinutes = self.computeSevenDayAverageEndingYesterday(from: series) // ✅ FIX
            }
            .store(in: &cancellables)
    }

    // ============================================================
    // MARK: - Initial Sync (Preview / App-Start)
    // ============================================================

    private func sync() {
        todayWorkoutMinutes = healthStore.todayWorkoutMinutes

        last90DaysData = healthStore.last90DaysWorkoutMinutes.map {
            DailyStepsEntry(date: $0.date, steps: $0.minutes)
        }

        monthlyDataRaw = healthStore.monthlyWorkoutMinutes

        daily365 = healthStore.workoutMinutesDaily365
        sevenDayAverageWorkoutMinutes = computeSevenDayAverageEndingYesterday(from: daily365)                 // ✅ FIX
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var formattedToday: String {
        if todayWorkoutMinutes <= 0 { return "–" }
        return "\(todayWorkoutMinutes) min"
    }

    // Workout Minutes hat in V1 kein Target/Goal → Delta bleibt neutral
    var kpiDeltaText: String { "–" }
    var kpiDeltaColor: Color { .secondary }
    var kpiTargetText: String { "" }

    // ============================================================
    // MARK: - Period Averages (Detail Charts)
    // ============================================================

    var avgLast7Days: Int { average(last: 7) }
    var avgLast14Days: Int { average(last: 14) }
    var avgLast30Days: Int { average(last: 30) }
    var avgLast90Days: Int { average(last: 90) }
    var avgLast180Days: Int { average(last: 180) }
    var avgLast365Days: Int { average(last: 365) }

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: avgLast7Days),
            .init(label: "14T",  days: 14,  value: avgLast14Days),
            .init(label: "30T",  days: 30,  value: avgLast30Days),
            .init(label: "90T",  days: 90,  value: avgLast90Days),
            .init(label: "180T", days: 180, value: avgLast180Days),
            .init(label: "365T", days: 365, value: avgLast365Days)
        ]
    }

    private func average(last days: Int) -> Int {
        guard !daily365.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let endDate = calendar.date(byAdding: .day, value: -1, to: today),
              let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            return 0
        }

        let filtered = daily365.filter { e in
            let d = calendar.startOfDay(for: e.date)
            return d >= startDate && d <= endDate && e.minutes > 0
        }

        guard !filtered.isEmpty else { return 0 }
        let sum = filtered.reduce(0) { $0 + $1.minutes }
        return sum / filtered.count
    }

    // ✅ FIX: 7d Avg für Overview-Card (Ending Yesterday, komplette Tage)
    private func computeSevenDayAverageEndingYesterday(from series: [DailyWorkoutMinutesEntry]) -> Int {
        guard !series.isEmpty else { return 0 }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        guard let endDate = calendar.date(byAdding: .day, value: -1, to: todayStart),
              let startDate = calendar.date(byAdding: .day, value: -7, to: todayStart) else {
            return 0
        }

        let filtered = series.filter { e in
            let d = calendar.startOfDay(for: e.date)
            return d >= startDate && d <= endDate && e.minutes > 0
        }

        guard !filtered.isEmpty else { return 0 }
        let sum = filtered.reduce(0) { $0 + $1.minutes }
        return sum / filtered.count
    }

    // ============================================================
    // MARK: - Chart Adapters (Steps-Pattern)
    // ============================================================

    var last90DaysChartData: [DailyStepsEntry] { last90DaysData }
    var monthlyData: [MonthlyMetricEntry] { monthlyDataRaw }

    // ============================================================
    // MARK: - Scales
    // ============================================================

    var dailyScale: MetricScaleResult {
        MetricScaleHelper.scale(
            last90DaysChartData.map { Double($0.steps) },
            for: .moveMinutes
        )
    }

    var periodScale: MetricScaleResult {
        MetricScaleHelper.scale(
            periodAverages.map { Double($0.value) },
            for: .moveMinutes
        )
    }

    var monthlyScale: MetricScaleResult {
        MetricScaleHelper.scale(
            monthlyData.map { Double($0.value) },
            for: .moveMinutes
        )
    }
}
