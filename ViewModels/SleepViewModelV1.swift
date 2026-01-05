//
//  SleepViewModelV1.swift
//  GluVibProbe
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class SleepViewModelV1: ObservableObject {

    // MARK: - Published Outputs (View)

    @Published var todaySleepMinutes: Int = 0

    // !!! UPDATED: these represent "session ending that day" from V1 HealthStore properties
    @Published var last90DaysRaw: [DailySleepEntry] = []                      // !!! UPDATED
    @Published var monthlyRaw: [MonthlyMetricEntry] = []
    @Published var daily365Raw: [DailySleepEntry] = []                        // !!! UPDATED

    @Published var targetSleepMinutes: Int = 8 * 60

    // MARK: - Dependencies

    private let healthStore: HealthStore
    private let settings: SettingsModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        healthStore: HealthStore = .shared,
        settings: SettingsModel = .shared
    ) {
        self.healthStore = healthStore
        self.settings = settings

        bindSettings()
        bindHealthStore()
        syncFromStores()
    }

    // MARK: - Bindings

    private func bindSettings() {
        settings.$dailySleepGoalMinutes
            .sink { [weak self] in self?.targetSleepMinutes = $0 }
            .store(in: &cancellables)
    }

    private func bindHealthStore() {

        healthStore.$todaySleepMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todaySleepMinutes = $0 }
            .store(in: &cancellables)

        // ---------------------------------------------------------
        // !!! UPDATED: bind to the ACTUAL V1 HealthStore properties
        // ---------------------------------------------------------

        healthStore.$last90DaysSleep                                           // !!! UPDATED
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.last90DaysRaw = $0 }                   // !!! UPDATED
            .store(in: &cancellables)

        healthStore.$sleepDaily365                                              // !!! UPDATED
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.daily365Raw = $0 }                     // !!! UPDATED
            .store(in: &cancellables)

        healthStore.$monthlySleep
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.monthlyRaw = $0 }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        todaySleepMinutes = healthStore.todaySleepMinutes

        // !!! UPDATED: pull from actual V1 properties
        last90DaysRaw = healthStore.last90DaysSleep                             // !!! UPDATED
        daily365Raw = healthStore.sleepDaily365                                 // !!! UPDATED

        monthlyRaw = healthStore.monthlySleep
        targetSleepMinutes = settings.dailySleepGoalMinutes
    }

    // MARK: - KPI Formatting

    var formattedTargetSleep: String { Self.formatMinutes(targetSleepMinutes) }
    var formattedTodaySleep: String { Self.formatMinutes(todaySleepMinutes) }

    var deltaSleepMinutes: Int { todaySleepMinutes - targetSleepMinutes }
    var formattedDeltaSleep: String { Self.formatDeltaMinutes(deltaSleepMinutes) }

    var deltaColor: Color {
        if deltaSleepMinutes > 0 { return .green }
        if deltaSleepMinutes < 0 { return .red }
        return Color.Glu.primaryBlue
    }

    // MARK: - Chart Goal

    var goalValueForChart: Int { targetSleepMinutes }

    // MARK: - Chart Adapters

    var last90DaysDataForChart: [DailyStepsEntry] {
        let sorted = last90DaysRaw.sorted { $0.date < $1.date }
        return sorted.map { DailyStepsEntry(date: $0.date, steps: $0.minutes) }
    }

    var monthlyData: [MonthlyMetricEntry] { monthlyRaw }

    // MARK: - Period Averages

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: averageMinutes(last: 7)),
            .init(label: "14T",  days: 14,  value: averageMinutes(last: 14)),
            .init(label: "30T",  days: 30,  value: averageMinutes(last: 30)),
            .init(label: "90T",  days: 90,  value: averageMinutes(last: 90)),
            .init(label: "180T", days: 180, value: averageMinutes(last: 180)),
            .init(label: "365T", days: 365, value: averageMinutes(last: 365))
        ]
    }

    private func averageMinutes(last days: Int) -> Int {
        let source: [DailySleepEntry] = {
            if days > 90, !daily365Raw.isEmpty { return daily365Raw }
            return last90DaysRaw
        }()

        guard !source.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard
            let endDate = calendar.date(byAdding: .day, value: -1, to: today),
            let startDate = calendar.date(byAdding: .day, value: -days, to: today)
        else { return 0 }

        let filtered = source.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= startDate && d <= endDate && entry.minutes > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0) { $0 + $1.minutes }
        let avg = Double(sum) / Double(filtered.count)
        return Int(avg.rounded())
    }

    // MARK: - Axis Label Helper (HOURS, NO unit)

    private func hoursOnlyLabel(_ valueInMinutes: Double) -> String {
        let hours = valueInMinutes / 60.0
        return "\(Int(hours.rounded()))"
    }

    // MARK: - Scales (ticks minutes, labels hours-only)

    var dailyScale: MetricScaleResult {
        let values = last90DaysDataForChart.map { Double($0.steps) }
        let base = MetricScaleHelper.scale(values, for: .sleepMinutes)

        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [weak self] tick in
                self?.hoursOnlyLabel(tick) ?? "\(Int((tick / 60.0).rounded()))"
            }
        )
    }

    var periodScale: MetricScaleResult {
        let values = periodAverages.map { Double($0.value) }
        let base = MetricScaleHelper.scale(values, for: .sleepMinutes)

        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [weak self] tick in
                self?.hoursOnlyLabel(tick) ?? "\(Int((tick / 60.0).rounded()))"
            }
        )
    }

    var monthlyScale: MetricScaleResult {
        let values = monthlyData.map { Double($0.value) }
        let base = MetricScaleHelper.scale(values, for: .sleepMinutes)

        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [weak self] tick in
                self?.hoursOnlyLabel(tick) ?? "\(Int((tick / 60.0).rounded()))"
            }
        )
    }

    // MARK: - Formatting Helpers

    static func formatMinutes(_ minutes: Int) -> String {
        guard minutes > 0 else { return "–" }
        let hours = minutes / 60
        let mins  = minutes % 60
        switch (hours, mins) {
        case (0, let m): return "\(m)m"
        case (let h, 0): return "\(h)h"
        default: return "\(hours)h \(mins)m"
        }
    }

    static func formatDeltaMinutes(_ delta: Int) -> String {
        if delta == 0 { return "0m" }
        let sign = delta > 0 ? "+" : "-"
        let absMinutes = abs(delta)
        let hours = absMinutes / 60
        let mins  = absMinutes % 60
        switch (hours, mins) {
        case (0, let m): return "\(sign)\(m)m"
        case (let h, 0): return "\(sign)\(h)h"
        default: return "\(sign)\(hours)h \(mins)m"
        }
    }
}
