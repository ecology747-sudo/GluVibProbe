//
//  StepsViewModelV1.swift
//  GluVibProbe
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class StepsViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Info State
    // ============================================================

    enum StepsInfoState { // 🟨 UPDATED
        case noHistory
        case noTodayData
    }

    // ============================================================
    // MARK: - Published State
    // ============================================================

    @Published var todaySteps: Int = 0
    @Published var dailyStepsGoalInt: Int = 0

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
    // MARK: - Bindings
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

    // ============================================================
    // MARK: - Initial Sync
    // ============================================================

    private func syncFromStores() {
        todaySteps = healthStore.todaySteps
        dailyStepsGoalInt = settings.dailyStepGoal

        last90DaysData = healthStore.last90Days
        monthlyStepsData = healthStore.monthlySteps
        dailySteps365 = healthStore.stepsDaily365
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var formattedTodaySteps: String {
        if todaySteps <= 0 { return "–" }
        return numberFormatter.string(from: NSNumber(value: todaySteps)) ?? "\(todaySteps)"
    }

    var formattedDailyStepGoal: String {
        numberFormatter.string(from: NSNumber(value: dailyStepsGoalInt)) ?? "\(dailyStepsGoalInt)"
    }

    var kpiDeltaText: String {
        guard todaySteps > 0 else { return "–" }

        let diff = todaySteps - dailyStepsGoalInt
        let sign: String = diff > 0 ? "+" : diff < 0 ? "−" : "±"
        let absValue = abs(diff)
        let formatted = numberFormatter.string(from: NSNumber(value: absValue)) ?? "\(absValue)"
        return "\(sign) \(formatted)"
    }

    var kpiDeltaColor: Color {
        guard todaySteps > 0 else { return Color.Glu.primaryBlue }

        let diff = todaySteps - dailyStepsGoalInt
        if diff > 0 { return Color.Glu.successGreen }
        if diff < 0 { return .red }
        return Color.Glu.primaryBlue
    }

    // ============================================================
    // MARK: - Info Hint State
    // ============================================================

    private var hasAnyHistory: Bool {
        last90DaysData.contains { $0.steps > 0 } ||
        dailySteps365.contains { $0.steps > 0 }
    }

    var todayInfoState: StepsInfoState? { // 🟨 UPDATED
        if todaySteps > 0 {
            return nil
        }

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
            .init(label: L10n.Common.period7d, days: 7, value: averageSteps(last: 7)),
            .init(label: L10n.Common.period14d, days: 14, value: averageSteps(last: 14)),
            .init(label: L10n.Common.period30d, days: 30, value: averageSteps(last: 30)),
            .init(label: L10n.Common.period90d, days: 90, value: averageSteps(last: 90)),
            .init(label: L10n.Common.period180d, days: 180, value: averageSteps(last: 180)),
            .init(label: L10n.Common.period365d, days: 365, value: averageSteps(last: 365))
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
        else {
            return 0
        }

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
