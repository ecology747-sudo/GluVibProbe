//
//  FatViewModelV1.swift
//  GluVibProbe
//
//  V1: Fat ViewModel
//  - KEIN Fetch im ViewModel
//  - Single Source of Truth: HealthStore
//  - Targets aus SettingsModel (dailyFat)
//  - V1 kompatibel
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class FatViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    @Published var todayFatGrams: Int = 0
    @Published var dailyFatGoalInt: Int = 0

    @Published var last90DaysData: [DailyFatEntry] = []
    @Published var monthlyFatData: [MonthlyMetricEntry] = []
    @Published var fatDaily365: [DailyFatEntry] = []

    @Published var fatReadAuthIssueV1: Bool = false // 🟨 NEW

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

        healthStore.$todayFatGrams
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todayFatGrams = $0 }
            .store(in: &cancellables)

        healthStore.$last90DaysFat
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.last90DaysData = $0 }
            .store(in: &cancellables)

        healthStore.$monthlyFat
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.monthlyFatData = $0 }
            .store(in: &cancellables)

        healthStore.$fatDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.fatDaily365 = $0 }
            .store(in: &cancellables)

        healthStore.$fatReadAuthIssueV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.fatReadAuthIssueV1 = $0 } // 🟨 NEW
            .store(in: &cancellables)
    }

    private func bindSettings() {

        settings.$dailyFat
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.dailyFatGoalInt = $0 }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        todayFatGrams = healthStore.todayFatGrams
        last90DaysData = healthStore.last90DaysFat
        monthlyFatData = healthStore.monthlyFat
        fatDaily365 = healthStore.fatDaily365
        dailyFatGoalInt = settings.dailyFat
        fatReadAuthIssueV1 = healthStore.fatReadAuthIssueV1 // 🟨 NEW
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

        let in365 = fatDaily365.contains {
            calendar.isDate($0.date, inSameDayAs: today)
        }

        return in90 || in365
    }

    private var hasTodayPositiveFat: Bool {
        todayFatGrams > 0
    }

    // ============================================================
    // MARK: - KPI Formatting (mit Einheit)
    // ============================================================

    var formattedTodayFat: String {
        guard hasTodayDatapoint || hasTodayPositiveFat else { return "–" } // 🟨 UPDATED
        let formatted = numberFormatter.string(from: NSNumber(value: todayFatGrams)) ?? "\(todayFatGrams)"
        return "\(formatted) g"
    }

    var formattedDailyFatGoal: String {
        let formatted = numberFormatter.string(from: NSNumber(value: dailyFatGoalInt)) ?? "\(dailyFatGoalInt)"
        return "\(formatted) g"
    }

    var kpiDeltaText: String {
        guard hasTodayDatapoint || hasTodayPositiveFat else { return "–" } // 🟨 UPDATED
        let diff = todayFatGrams - dailyFatGoalInt
        let sign: String = diff > 0 ? "+" : diff < 0 ? "−" : "±"
        let absValue = abs(diff)
        let formatted = numberFormatter.string(from: NSNumber(value: absValue)) ?? "\(absValue)"
        return "\(sign) \(formatted) g"
    }

    var kpiDeltaColor: Color {
        guard hasTodayDatapoint || hasTodayPositiveFat else { return Color.Glu.primaryBlue } // 🟨 UPDATED
        let diff = todayFatGrams - dailyFatGoalInt
        if diff > 0 { return Color.Glu.successGreen }
        if diff < 0 { return .red }
        return Color.Glu.primaryBlue
    }

    // ============================================================
    // MARK: - Info Hint (Today) — Goldstandard Nutrition
    // ============================================================

    var todayInfoText: String? { // 🟨 UPDATED

        if settings.showPermissionWarnings && fatReadAuthIssueV1 {
            return L10n.Fat.hintNoDataOrPermission
        }

        if hasTodayDatapoint || hasTodayPositiveFat {
            return nil
        }

        let hasAnyHistoryPositive =
            last90DaysData.contains { $0.grams > 0 } ||
            fatDaily365.contains { $0.grams > 0 }

        if !hasAnyHistoryPositive {
            return L10n.Fat.hintNoDataOrPermission
        }

        return L10n.Fat.hintNoToday
    }

    // ============================================================
    // MARK: - Period Averages
    // ============================================================

    var periodAverages: [PeriodAverageEntry] { // 🟨 UPDATED
        [
            .init(label: L10n.Common.period7d, days: 7, value: averageFat(last: 7)),
            .init(label: L10n.Common.period14d, days: 14, value: averageFat(last: 14)),
            .init(label: L10n.Common.period30d, days: 30, value: averageFat(last: 30)),
            .init(label: L10n.Common.period90d, days: 90, value: averageFat(last: 90)),
            .init(label: L10n.Common.period180d, days: 180, value: averageFat(last: 180)),
            .init(label: L10n.Common.period365d, days: 365, value: averageFat(last: 365))
        ]
    }

    private func averageFat(last days: Int) -> Int {
        let source = fatDaily365.isEmpty ? last90DaysData : fatDaily365
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
    // MARK: - Chart Label Helper (NO unit)
    // ============================================================

    private func numberOnlyLabel(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    // ============================================================
    // MARK: - Chart Scales (NO unit in charts)
    // ============================================================

    var dailyScale: MetricScaleResult {
        let base = MetricScaleHelper.scale(last90DaysData.map { Double($0.grams) }, for: .grams)
        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }
        )
    }

    var periodScale: MetricScaleResult {
        let base = MetricScaleHelper.scale(periodAverages.map { Double($0.value) }, for: .grams)
        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }
        )
    }

    var monthlyScale: MetricScaleResult {
        let base = MetricScaleHelper.scale(monthlyFatData.map { Double($0.value) }, for: .grams)
        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }
        )
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
