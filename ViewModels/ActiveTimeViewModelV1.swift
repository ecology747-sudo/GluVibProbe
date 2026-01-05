//
//  ActiveTimeViewModelV1.swift
//  GluVibProbe
//
//  V1: Active-Time-ViewModel (kein Fetch im VM)
//  - bindet nur HealthStore
//  - 365er-Reihe kommt aus HealthStore.activeTimeDaily365
//

import Foundation
import Combine

final class ActiveTimeViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (SSoT → View)
    // ============================================================

    @Published var todayActiveTimeMinutes: Int = 0
    @Published var last90DaysData: [DailyStepsEntry] = []
    @Published var monthlyDataRaw: [MonthlyMetricEntry] = []
    @Published var activeTimeDaily365: [DailyExerciseMinutesEntry] = []

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

        healthStore.$todayExerciseMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todayActiveTimeMinutes = $0 }
            .store(in: &cancellables)

        healthStore.$last90DaysExerciseMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.last90DaysData = entries.map {
                    DailyStepsEntry(date: $0.date, steps: $0.minutes)
                }
            }
            .store(in: &cancellables)

        healthStore.$monthlyExerciseMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.monthlyDataRaw = $0 }
            .store(in: &cancellables)

        healthStore.$activeTimeDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.activeTimeDaily365 = $0 }
            .store(in: &cancellables)
    }

    // ============================================================
    // MARK: - Initial Sync (Preview / App-Start)
    // ============================================================

    private func syncFromStores() {

        todayActiveTimeMinutes = healthStore.todayExerciseMinutes

        last90DaysData = healthStore.last90DaysExerciseMinutes.map {
            DailyStepsEntry(date: $0.date, steps: $0.minutes)
        }

        monthlyDataRaw = healthStore.monthlyExerciseMinutes
        activeTimeDaily365 = healthStore.activeTimeDaily365
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var formattedTodayActiveTime: String {
        if todayActiveTimeMinutes <= 0 { return "–" }
        return "\(todayActiveTimeMinutes) min"
    }

    // ============================================================
    // MARK: - Period Averages
    // ============================================================

    var avgLast7Days: Int { averageActiveTime(last: 7) }
    var avgLast14Days: Int { averageActiveTime(last: 14) }
    var avgLast30Days: Int { averageActiveTime(last: 30) }
    var avgLast90Days: Int { averageActiveTime(last: 90) }
    var avgLast180Days: Int { averageActiveTime(last: 180) }
    var avgLast365Days: Int { averageActiveTime(last: 365) }

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

    private func averageActiveTime(last days: Int) -> Int {
        guard !activeTimeDaily365.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let endDate = calendar.date(byAdding: .day, value: -1, to: today),
              let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            return 0
        }

        let filtered = activeTimeDaily365.filter { entry in
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

    var last90DaysChartData: [DailyStepsEntry] {
        last90DaysData
    }

    var monthlyData: [MonthlyMetricEntry] {
        monthlyDataRaw
    }

    // ============================================================
    // MARK: - Scales
    // ============================================================

    var dailyScale: MetricScaleResult {
        MetricScaleHelper.scale(
            last90DaysChartData.map { Double($0.steps) },
            for: .exerciseMinutes
        )
    }

    var periodScale: MetricScaleResult {
        MetricScaleHelper.scale(
            periodAverages.map { Double($0.value) },
            for: .exerciseMinutes
        )
    }

    var monthlyScale: MetricScaleResult {
        MetricScaleHelper.scale(
            monthlyData.map { Double($0.value) },
            for: .exerciseMinutes
        )
    }
}
