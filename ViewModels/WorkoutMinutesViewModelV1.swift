//
//  WorkoutMinutesViewModelV1.swift
//  GluVibProbe
//

import Foundation
import SwiftUI
import Combine

final class WorkoutMinutesViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Info State
    // ============================================================

    enum WorkoutMinutesInfoState {
        case noHistory
        case noTodayData
    }

    // ============================================================
    // MARK: - Published Outputs (SSoT → View)
    // ============================================================

    @Published var todayWorkoutMinutes: Int = 0
    @Published var sevenDayAverageWorkoutMinutes: Int = 0

    @Published var last90DaysData: [DailyStepsEntry] = []
    @Published var monthlyDataRaw: [MonthlyMetricEntry] = []
    @Published var daily365: [DailyWorkoutMinutesEntry] = []

    @Published var workoutMinutesReadAuthIssueV1: Bool = false

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
    // MARK: - Bindings
    // ============================================================

    private func bind() {

        healthStore.$todayWorkoutMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todayWorkoutMinutes = $0 }
            .store(in: &cancellables)

        healthStore.$last90DaysWorkoutMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.last90DaysData = entries.map {
                    DailyStepsEntry(date: $0.date, steps: $0.minutes)
                }
            }
            .store(in: &cancellables)

        healthStore.$monthlyWorkoutMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.monthlyDataRaw = $0 }
            .store(in: &cancellables)

        healthStore.$workoutMinutesDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] series in
                guard let self else { return }
                self.daily365 = series
                self.sevenDayAverageWorkoutMinutes =
                    self.computeSevenDayAverageEndingYesterday(from: series)
            }
            .store(in: &cancellables)

        healthStore.$workoutMinutesReadAuthIssueV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.workoutMinutesReadAuthIssueV1 = $0 }
            .store(in: &cancellables)
    }

    private func sync() {
        todayWorkoutMinutes = healthStore.todayWorkoutMinutes

        last90DaysData = healthStore.last90DaysWorkoutMinutes.map {
            DailyStepsEntry(date: $0.date, steps: $0.minutes)
        }

        monthlyDataRaw = healthStore.monthlyWorkoutMinutes
        daily365 = healthStore.workoutMinutesDaily365

        sevenDayAverageWorkoutMinutes =
            computeSevenDayAverageEndingYesterday(from: daily365)

        workoutMinutesReadAuthIssueV1 = healthStore.workoutMinutesReadAuthIssueV1
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var formattedToday: String {
        if todayWorkoutMinutes <= 0 { return "–" }
        return "\(todayWorkoutMinutes) min"
    }

    var kpiDeltaText: String { "–" }
    var kpiDeltaColor: Color { .secondary }
    var kpiTargetText: String { "" }

    // ============================================================
    // MARK: - Today Hint State
    // ============================================================

    var todayInfoState: WorkoutMinutesInfoState? {

        if todayWorkoutMinutes > 0 { return nil }

        let hasAnyHistory =
            daily365.contains { $0.minutes > 0 } ||
            last90DaysData.contains { $0.steps > 0 }

        if !hasAnyHistory {
            return .noHistory
        }

        return .noTodayData
    }

    // ============================================================
    // MARK: - Period Averages
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: average(last: 7)),
            .init(label: "14T",  days: 14,  value: average(last: 14)),
            .init(label: "30T",  days: 30,  value: average(last: 30)),
            .init(label: "90T",  days: 90,  value: average(last: 90)),
            .init(label: "180T", days: 180, value: average(last: 180)),
            .init(label: "365T", days: 365, value: average(last: 365))
        ]
    }

    private func average(last days: Int) -> Int {
        guard !daily365.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let end = calendar.date(byAdding: .day, value: -1, to: today),
              let start = calendar.date(byAdding: .day, value: -days, to: today)
        else { return 0 }

        let filtered = daily365.filter {
            let d = calendar.startOfDay(for: $0.date)
            return d >= start && d <= end && $0.minutes > 0
        }

        guard !filtered.isEmpty else { return 0 }
        return filtered.reduce(0) { $0 + $1.minutes } / filtered.count
    }

    private func computeSevenDayAverageEndingYesterday(
        from series: [DailyWorkoutMinutesEntry]
    ) -> Int {

        guard !series.isEmpty else { return 0 }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        guard let end = calendar.date(byAdding: .day, value: -1, to: todayStart),
              let start = calendar.date(byAdding: .day, value: -7, to: todayStart)
        else { return 0 }

        let filtered = series.filter {
            let d = calendar.startOfDay(for: $0.date)
            return d >= start && d <= end && $0.minutes > 0
        }

        guard !filtered.isEmpty else { return 0 }
        return filtered.reduce(0) { $0 + $1.minutes } / filtered.count
    }

    // ============================================================
    // MARK: - Scales
    // ============================================================

    var dailyScale: MetricScaleResult {
        MetricScaleHelper.scale(
            last90DaysData.map { Double($0.steps) },
            for: .workoutMinutes // 🟨 UPDATED
        )
    }

    var periodScale: MetricScaleResult {
        MetricScaleHelper.scale(
            periodAverages.map { Double($0.value) },
            for: .workoutMinutes // 🟨 UPDATED
        )
    }

    var monthlyScale: MetricScaleResult {
        MetricScaleHelper.scale(
            monthlyDataRaw.map { Double($0.value) },
            for: .workoutMinutes // 🟨 UPDATED
        )
    }
}
