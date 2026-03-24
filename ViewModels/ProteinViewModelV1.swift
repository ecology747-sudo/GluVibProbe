//
//  ProteinViewModelV1.swift
//  GluVibProbe
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class ProteinViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    @Published var todayProteinGrams: Int = 0
    @Published var dailyProteinGoalInt: Int = 0

    @Published var last90DaysData: [DailyProteinEntry] = []
    @Published var monthlyProteinData: [MonthlyMetricEntry] = []
    @Published var proteinDaily365: [DailyProteinEntry] = []

    @Published var proteinReadAuthIssueV1: Bool = false

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

        healthStore.$todayProteinGrams
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todayProteinGrams = $0 }
            .store(in: &cancellables)

        healthStore.$last90DaysProtein
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.last90DaysData = $0 }
            .store(in: &cancellables)

        healthStore.$monthlyProtein
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.monthlyProteinData = $0 }
            .store(in: &cancellables)

        healthStore.$proteinDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.proteinDaily365 = $0 }
            .store(in: &cancellables)

        healthStore.$proteinReadAuthIssueV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.proteinReadAuthIssueV1 = $0 }
            .store(in: &cancellables)
    }

    private func bindSettings() {
        settings.$dailyProtein
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.dailyProteinGoalInt = $0 }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        todayProteinGrams = healthStore.todayProteinGrams
        last90DaysData = healthStore.last90DaysProtein
        monthlyProteinData = healthStore.monthlyProtein
        proteinDaily365 = healthStore.proteinDaily365
        dailyProteinGoalInt = settings.dailyProtein
        proteinReadAuthIssueV1 = healthStore.proteinReadAuthIssueV1
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

        let in365 = proteinDaily365.contains {
            calendar.isDate($0.date, inSameDayAs: today)
        }

        return in90 || in365
    }

    private var hasTodayPositiveProtein: Bool {
        todayProteinGrams > 0
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    var formattedTodayProtein: String {
        guard hasTodayDatapoint || hasTodayPositiveProtein else { return "–" }
        let formatted = numberFormatter.string(from: NSNumber(value: todayProteinGrams)) ?? "\(todayProteinGrams)"
        return "\(formatted) g"
    }

    var formattedDailyProteinGoal: String {
        let formatted = numberFormatter.string(from: NSNumber(value: dailyProteinGoalInt)) ?? "\(dailyProteinGoalInt)"
        return "\(formatted) g"
    }

    var kpiDeltaText: String {
        guard hasTodayDatapoint || hasTodayPositiveProtein else { return "–" }
        let diff = todayProteinGrams - dailyProteinGoalInt
        let sign: String = diff > 0 ? "+" : diff < 0 ? "−" : "±"
        let absValue = abs(diff)
        let formatted = numberFormatter.string(from: NSNumber(value: absValue)) ?? "\(absValue)"
        return "\(sign) \(formatted) g"
    }

    var kpiDeltaColor: Color {
        guard hasTodayDatapoint || hasTodayPositiveProtein else { return Color.Glu.primaryBlue }
        let diff = todayProteinGrams - dailyProteinGoalInt
        if diff > 0 { return Color.Glu.successGreen }
        if diff < 0 { return .red }
        return Color.Glu.primaryBlue
    }

    // ============================================================
    // MARK: - Info Hint (Today) — Goldstandard Nutrition
    // ============================================================

    var todayInfoText: String? {

        if settings.showPermissionWarnings && proteinReadAuthIssueV1 {
            return L10n.Protein.hintNoDataOrPermission
        }

        if hasTodayDatapoint || hasTodayPositiveProtein {
            return nil
        }

        let hasAnyHistoryPositive =
            last90DaysData.contains { $0.grams > 0 } ||
            proteinDaily365.contains { $0.grams > 0 }

        if !hasAnyHistoryPositive {
            return L10n.Protein.hintNoDataOrPermission
        }

        return L10n.Protein.hintNoToday
    }

    // ============================================================
    // MARK: - Period Averages
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: L10n.Common.period7d, days: 7, value: averageProtein(last: 7)),
            .init(label: L10n.Common.period14d, days: 14, value: averageProtein(last: 14)),
            .init(label: L10n.Common.period30d, days: 30, value: averageProtein(last: 30)),
            .init(label: L10n.Common.period90d, days: 90, value: averageProtein(last: 90)),
            .init(label: L10n.Common.period180d, days: 180, value: averageProtein(last: 180)),
            .init(label: L10n.Common.period365d, days: 365, value: averageProtein(last: 365))
        ]
    }

    private func averageProtein(last days: Int) -> Int {
        let source = proteinDaily365.isEmpty ? last90DaysData : proteinDaily365

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
        let base = MetricScaleHelper.scale(monthlyProteinData.map { Double($0.value) }, for: .grams)
        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }
        )
    }
}
