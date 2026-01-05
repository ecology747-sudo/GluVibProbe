//
//  StepsViewModelV1.swift
//  GluVibProbe
//
//  V1: Steps ViewModel
//  - KEIN Fetch im ViewModel
//  - Single Source of Truth: HealthStore
//  - Targets aus SettingsModel
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class StepsViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    // KPIs
    @Published var todaySteps: Int = 0
    @Published var dailyStepsGoalInt: Int = 0

    // Chart Data
    @Published var last90DaysData: [DailyStepsEntry] = []
    @Published var monthlyStepsData: [MonthlyMetricEntry] = []
    @Published var dailySteps365: [DailyStepsEntry] = []

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    private let healthStore: HealthStore
    private let settings: SettingsModel
    private var cancellables = Set<AnyCancellable>()

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        healthStore: HealthStore = .shared,
        settings: SettingsModel = .shared
    ) {
        self.healthStore = healthStore
        self.settings = settings

        bindHealthStore()
        bindSettings()
        syncFromStores()
    }

    // ============================================================
    // MARK: - Bindings (SSoT → ViewModel)
    // ============================================================

    private func bindHealthStore() {

        healthStore.$todaySteps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todaySteps = $0 }
            .store(in: &cancellables)

        healthStore.$last90Days
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.last90DaysData = $0 }
            .store(in: &cancellables)

        healthStore.$monthlySteps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.monthlyStepsData = $0 }
            .store(in: &cancellables)

        healthStore.$stepsDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.dailySteps365 = $0 }
            .store(in: &cancellables)
    }

    private func bindSettings() {

        settings.$dailyStepGoal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.dailyStepsGoalInt = $0 }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        todaySteps = healthStore.todaySteps
        last90DaysData = healthStore.last90Days
        monthlyStepsData = healthStore.monthlySteps
        dailySteps365 = healthStore.stepsDaily365
        dailyStepsGoalInt = settings.dailyStepGoal
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var formattedTodaySteps: String {
        numberFormatter.string(from: NSNumber(value: todaySteps)) ?? "\(todaySteps)"
    }

    var formattedDailyStepGoal: String {
        numberFormatter.string(from: NSNumber(value: dailyStepsGoalInt)) ?? "\(dailyStepsGoalInt)"
    }

    var kpiDeltaText: String {
        let diff = todaySteps - dailyStepsGoalInt
        let sign: String = diff > 0 ? "+" : diff < 0 ? "−" : "±"
        let absValue = abs(diff)
        let formatted = numberFormatter.string(from: NSNumber(value: absValue)) ?? "\(absValue)"
        return "\(sign) \(formatted)"
    }

    var kpiDeltaColor: Color {
        let diff = todaySteps - dailyStepsGoalInt
        if diff > 0 { return .green }
        if diff < 0 { return .red }
        return Color.Glu.primaryBlue
    }

    // ============================================================
    // MARK: - Period Averages
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: averageSteps(last: 7)),
            .init(label: "14T",  days: 14,  value: averageSteps(last: 14)),
            .init(label: "30T",  days: 30,  value: averageSteps(last: 30)),
            .init(label: "90T",  days: 90,  value: averageSteps(last: 90)),
            .init(label: "180T", days: 180, value: averageSteps(last: 180)),
            .init(label: "365T", days: 365, value: averageSteps(last: 365))
        ]
    }

    private func averageSteps(last days: Int) -> Int {
        let source = dailySteps365.isEmpty ? last90DaysData : dailySteps365
        guard !source.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard
            let endDate = calendar.date(byAdding: .day, value: -1, to: today),
            let startDate = calendar.date(byAdding: .day, value: -days, to: today)
        else { return 0 }

        let filtered = source.filter {
            let d = calendar.startOfDay(for: $0.date)
            return d >= startDate && d <= endDate && $0.steps > 0
        }

        guard !filtered.isEmpty else { return 0 }
        return filtered.reduce(0) { $0 + $1.steps } / filtered.count
    }

    // ============================================================
    // MARK: - Chart Scales
    // ============================================================

    var dailyScale: MetricScaleResult {
        MetricScaleHelper.scale(last90DaysData.map { Double($0.steps) }, for: .steps)
    }

    var periodScale: MetricScaleResult {
        MetricScaleHelper.scale(periodAverages.map { Double($0.value) }, for: .steps)
    }

    var monthlyScale: MetricScaleResult {
        MetricScaleHelper.scale(monthlyStepsData.map { Double($0.value) }, for: .steps)
    }

    // ============================================================
    // MARK: - Formatter
    // ============================================================

    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}
