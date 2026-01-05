//
//  MoveTimeViewModelV1.swift
//  GluVibProbe
//
//  V1: Move-Time-ViewModel (kein Fetch im VM)
//  - bindet nur HealthStore
//  - Daten kommen aus:
//      todayMoveTimeMinutes
//      last90DaysMoveTime
//      monthlyMoveTime
//      moveTimeDaily365
//

import Foundation
import SwiftUI
import Combine

final class MoveTimeViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (SSoT → View)
    // ============================================================

    @Published var todayMoveTimeMinutes: Int = 0
    @Published var last90DaysData: [DailyStepsEntry] = []                 // Chart Adapter (Steps-Pattern)
    @Published var monthlyDataRaw: [MonthlyMetricEntry] = []
    @Published var moveTimeDaily365: [DailyMoveTimeEntry] = []

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
        bindHealthStore()
        syncFromStores()
    }

    // ============================================================
    // MARK: - Bindings (HealthStore → Published)
    // ============================================================

    private func bindHealthStore() {

        healthStore.$todayMoveTimeMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todayMoveTimeMinutes = $0 }
            .store(in: &cancellables)

        healthStore.$last90DaysMoveTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.last90DaysData = entries.map {
                    DailyStepsEntry(date: $0.date, steps: $0.minutes)
                }
            }
            .store(in: &cancellables)

        healthStore.$monthlyMoveTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.monthlyDataRaw = $0 }
            .store(in: &cancellables)

        healthStore.$moveTimeDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.moveTimeDaily365 = $0 }
            .store(in: &cancellables)
    }

    // ============================================================
    // MARK: - Initial Sync (Preview / App-Start)
    // ============================================================

    private func syncFromStores() {

        todayMoveTimeMinutes = healthStore.todayMoveTimeMinutes

        last90DaysData = healthStore.last90DaysMoveTime.map {
            DailyStepsEntry(date: $0.date, steps: $0.minutes)
        }

        monthlyDataRaw = healthStore.monthlyMoveTime
        moveTimeDaily365 = healthStore.moveTimeDaily365
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var formattedTodayMoveTime: String {
        if todayMoveTimeMinutes <= 0 { return "–" }
        return "\(todayMoveTimeMinutes) min"
    }

    // Move Time hat in V1 kein Target/Goal → Delta bleibt neutral
    var kpiDeltaText: String { "–" }                                       // ✅ FIX (damit View nicht crasht)
    var kpiDeltaColor: Color { .secondary }                                // ✅ FIX

    var kpiTargetText: String { "" }                                       // ✅ FIX (kein Target)

    // ============================================================
    // MARK: - Period Averages
    // ============================================================

    var avgLast7Days: Int { averageMoveTime(last: 7) }
    var avgLast14Days: Int { averageMoveTime(last: 14) }
    var avgLast30Days: Int { averageMoveTime(last: 30) }
    var avgLast90Days: Int { averageMoveTime(last: 90) }
    var avgLast180Days: Int { averageMoveTime(last: 180) }
    var avgLast365Days: Int { averageMoveTime(last: 365) }

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

    private func averageMoveTime(last days: Int) -> Int {
        guard !moveTimeDaily365.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let endDate = calendar.date(byAdding: .day, value: -1, to: today),
              let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            return 0
        }

        let filtered = moveTimeDaily365.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= startDate && d <= endDate && entry.minutes > 0
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
