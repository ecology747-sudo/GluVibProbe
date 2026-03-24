//
//  CarbsViewModelV1.swift
//  GluVibProbe
//
//  V1: Carbs ViewModel
//  - KEIN Fetch im ViewModel
//  - Single Source of Truth: HealthStore
//  - Targets aus SettingsModel
//  - V1 kompatibel
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class CarbsViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing) — V1 kompatibel
    // ============================================================

    @Published var todayCarbsGrams: Int = 0
    @Published var dailyCarbsGoalInt: Int = 0

    @Published var last90DaysData: [DailyCarbsEntry] = []
    @Published var monthlyCarbsData: [MonthlyMetricEntry] = []
    @Published var carbsDaily365: [DailyCarbsEntry] = []

    @Published var carbsReadAuthIssueV1: Bool = false

    // ============================================================
    // MARK: - Dependencies — V1 kompatibel
    // ============================================================

    private let healthStore: HealthStore
    private let settings: SettingsModel
    private var cancellables = Set<AnyCancellable>()

    // ============================================================
    // MARK: - Init — V1 kompatibel
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
    // MARK: - Bindings (SSoT → ViewModel) — V1 kompatibel
    // ============================================================

    private func bindHealthStore() {

        healthStore.$todayCarbsGrams
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todayCarbsGrams = $0 }
            .store(in: &cancellables)

        healthStore.$last90DaysCarbs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.last90DaysData = $0 }
            .store(in: &cancellables)

        healthStore.$monthlyCarbs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.monthlyCarbsData = $0 }
            .store(in: &cancellables)

        healthStore.$carbsDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.carbsDaily365 = $0 }
            .store(in: &cancellables)

        healthStore.$carbsReadAuthIssueV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.carbsReadAuthIssueV1 = $0 }
            .store(in: &cancellables)
    }

    private func bindSettings() {
        settings.$dailyCarbs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.dailyCarbsGoalInt = $0 }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        todayCarbsGrams = healthStore.todayCarbsGrams
        last90DaysData = healthStore.last90DaysCarbs
        monthlyCarbsData = healthStore.monthlyCarbs
        carbsDaily365 = healthStore.carbsDaily365
        dailyCarbsGoalInt = settings.dailyCarbs
        carbsReadAuthIssueV1 = healthStore.carbsReadAuthIssueV1
    }

    // ============================================================
    // MARK: - Availability (Today)
    // ============================================================

    private var hasTodayDatapoint: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let in90 = last90DaysData.contains {
            calendar.isDate($0.date, inSameDayAs: today)
        }

        let in365 = carbsDaily365.contains {
            calendar.isDate($0.date, inSameDayAs: today)
        }

        return in90 || in365
    }

    private var hasTodayPositiveCarbs: Bool {
        todayCarbsGrams > 0
    }

    // ============================================================
    // MARK: - KPI Formatting — V1 kompatibel
    // ============================================================

    var formattedTodayCarbs: String {
        guard hasTodayDatapoint || hasTodayPositiveCarbs else { return "–" }
        let formatted = numberFormatter.string(from: NSNumber(value: todayCarbsGrams)) ?? "\(todayCarbsGrams)"
        return "\(formatted) g"
    }

    var formattedDailyCarbsGoal: String {
        let formatted = numberFormatter.string(from: NSNumber(value: dailyCarbsGoalInt)) ?? "\(dailyCarbsGoalInt)"
        return "\(formatted) g"
    }

    var kpiDeltaText: String {
        guard hasTodayDatapoint || hasTodayPositiveCarbs else { return "–" }
        let diff = todayCarbsGrams - dailyCarbsGoalInt
        let sign: String = diff > 0 ? "+" : diff < 0 ? "−" : "±"
        let absValue = abs(diff)
        let formatted = numberFormatter.string(from: NSNumber(value: absValue)) ?? "\(absValue)"
        return "\(sign) \(formatted) g"
    }

    var kpiDeltaColor: Color {
        guard hasTodayDatapoint || hasTodayPositiveCarbs else { return Color.Glu.primaryBlue }
        let diff = todayCarbsGrams - dailyCarbsGoalInt
        if diff > 0 { return Color.Glu.successGreen }
        if diff < 0 { return .red }
        return Color.Glu.primaryBlue
    }

    // ============================================================
    // MARK: - Info Hint (Today) — Goldstandard Nutrition
    // ============================================================

    var todayInfoText: String? { // 🟨 UPDATED

        if settings.showPermissionWarnings && carbsReadAuthIssueV1 {
            return L10n.Carbs.hintNoDataOrPermission
        }

        if hasTodayDatapoint || hasTodayPositiveCarbs {
            return nil
        }

        let hasAnyHistoryPositive =
            last90DaysData.contains { $0.grams > 0 } ||
            carbsDaily365.contains { $0.grams > 0 }

        if !hasAnyHistoryPositive {
            return L10n.Carbs.hintNoDataOrPermission
        }

        return L10n.Carbs.hintNoToday
    }

    // ============================================================
    // MARK: - Period Averages — V1 kompatibel
    // ============================================================

    var periodAverages: [PeriodAverageEntry] { // 🟨 UPDATED
        [
            .init(label: L10n.Common.period7d, days: 7, value: averageCarbs(last: 7)),
            .init(label: L10n.Common.period14d, days: 14, value: averageCarbs(last: 14)),
            .init(label: L10n.Common.period30d, days: 30, value: averageCarbs(last: 30)),
            .init(label: L10n.Common.period90d, days: 90, value: averageCarbs(last: 90)),
            .init(label: L10n.Common.period180d, days: 180, value: averageCarbs(last: 180)),
            .init(label: L10n.Common.period365d, days: 365, value: averageCarbs(last: 365))
        ]
    }

    private func averageCarbs(last days: Int) -> Int {
        let source = carbsDaily365.isEmpty ? last90DaysData : carbsDaily365
        guard !source.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard
            let endDate = calendar.date(byAdding: .day, value: -1, to: today),
            let startDate = calendar.date(byAdding: .day, value: -days, to: today)
        else { return 0 }

        let filtered = source.filter {
            let d = calendar.startOfDay(for: $0.date)
            return d >= startDate && d <= endDate && $0.grams > 0
        }

        guard !filtered.isEmpty else { return 0 }
        return filtered.reduce(0) { $0 + $1.grams } / filtered.count
    }

    // ============================================================
    // MARK: - Chart Label Helper (NO units)
    // ============================================================

    private func numberOnlyLabel(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    // ============================================================
    // MARK: - Chart Scales — V1 kompatibel (NO "g" in axis/labels)
    // ============================================================

    var dailyScale: MetricScaleResult {
        let values = last90DaysData.map { Double($0.grams) }
        let base = MetricScaleHelper.scale(values, for: .grams)
        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }
        )
    }

    var periodScale: MetricScaleResult {
        let values = periodAverages.map { Double($0.value) }
        let base = MetricScaleHelper.scale(values, for: .grams)
        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }
        )
    }

    var monthlyScale: MetricScaleResult {
        let values = monthlyCarbsData.map { Double($0.value) }
        let base = MetricScaleHelper.scale(values, for: .grams)
        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }
        )
    }

    // ============================================================
    // MARK: - Formatter — V1 kompatibel
    // ============================================================

    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}
