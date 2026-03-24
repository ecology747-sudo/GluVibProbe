//
//  SugarViewModelV1.swift
//  GluVibProbe
//
//  V1: Sugar ViewModel (Nutrition)
//  - KEIN Fetch im ViewModel
//  - Single Source of Truth: HealthStore
//  - Targets aus SettingsModel
//  - UI semantics: "Sugars (of Carbs)" / "davon Zucker" is handled in Views (not here).
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class SugarViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing) — V1 kompatibel
    // ============================================================

    @Published var todaySugarGrams: Int = 0
    @Published var dailySugarGoalInt: Int = 0

    @Published var last90DaysData: [DailySugarEntry] = []
    @Published var monthlySugarData: [MonthlyMetricEntry] = []
    @Published var sugarDaily365: [DailySugarEntry] = []

    @Published var sugarReadAuthIssueV1: Bool = false

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

        healthStore.$todaySugarGrams
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todaySugarGrams = $0 }
            .store(in: &cancellables)

        healthStore.$last90DaysSugar
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.last90DaysData = $0 }
            .store(in: &cancellables)

        healthStore.$monthlySugar
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.monthlySugarData = $0 }
            .store(in: &cancellables)

        healthStore.$sugarDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.sugarDaily365 = $0 }
            .store(in: &cancellables)

        healthStore.$sugarReadAuthIssueV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.sugarReadAuthIssueV1 = $0 }
            .store(in: &cancellables)
    }

    private func bindSettings() {
        settings.$dailySugar
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.dailySugarGoalInt = $0 }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        todaySugarGrams = healthStore.todaySugarGrams
        last90DaysData = healthStore.last90DaysSugar
        monthlySugarData = healthStore.monthlySugar
        sugarDaily365 = healthStore.sugarDaily365
        dailySugarGoalInt = settings.dailySugar
        sugarReadAuthIssueV1 = healthStore.sugarReadAuthIssueV1
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

        let in365 = sugarDaily365.contains {
            calendar.isDate($0.date, inSameDayAs: today)
        }

        return in90 || in365
    }

    private var hasTodayPositiveSugar: Bool {
        todaySugarGrams > 0
    }

    // ============================================================
    // MARK: - KPI Formatting — V1 kompatibel
    // ============================================================

    var formattedTodaySugar: String {
        guard hasTodayDatapoint || hasTodayPositiveSugar else { return "–" }
        let formatted = numberFormatter.string(from: NSNumber(value: todaySugarGrams)) ?? "\(todaySugarGrams)"
        return "\(formatted) g"
    }

    var formattedDailySugarGoal: String {
        let formatted = numberFormatter.string(from: NSNumber(value: dailySugarGoalInt)) ?? "\(dailySugarGoalInt)"
        return "\(formatted) g"
    }

    var kpiDeltaText: String {
        guard hasTodayDatapoint || hasTodayPositiveSugar else { return "–" }
        let diff = todaySugarGrams - dailySugarGoalInt
        let sign: String = diff > 0 ? "+" : diff < 0 ? "−" : "±"
        let absValue = abs(diff)
        let formatted = numberFormatter.string(from: NSNumber(value: absValue)) ?? "\(absValue)"
        return "\(sign) \(formatted) g"
    }

    var kpiDeltaColor: Color {
        guard hasTodayDatapoint || hasTodayPositiveSugar else { return Color.Glu.primaryBlue }
        let diff = todaySugarGrams - dailySugarGoalInt
        if diff > 0 { return Color.Glu.successGreen }
        if diff < 0 { return .red }
        return Color.Glu.primaryBlue
    }

    // ============================================================
    // MARK: - Info Hint (Today) — Goldstandard Nutrition
    // ============================================================

    var todayInfoText: String? { // 🟨 UPDATED

        if settings.showPermissionWarnings && sugarReadAuthIssueV1 {
            return L10n.Sugar.hintNoDataOrPermission
        }

        if hasTodayDatapoint || hasTodayPositiveSugar {
            return nil
        }

        let hasAnyHistoryPositive =
            last90DaysData.contains { $0.grams > 0 } ||
            sugarDaily365.contains { $0.grams > 0 }

        if !hasAnyHistoryPositive {
            return L10n.Sugar.hintNoDataOrPermission
        }

        return L10n.Sugar.hintNoToday
    }

    // ============================================================
    // MARK: - Period Averages — V1 kompatibel
    // ============================================================

    var periodAverages: [PeriodAverageEntry] { // 🟨 UPDATED
        [
            .init(label: L10n.Common.period7d, days: 7, value: averageSugar(last: 7)),
            .init(label: L10n.Common.period14d, days: 14, value: averageSugar(last: 14)),
            .init(label: L10n.Common.period30d, days: 30, value: averageSugar(last: 30)),
            .init(label: L10n.Common.period90d, days: 90, value: averageSugar(last: 90)),
            .init(label: L10n.Common.period180d, days: 180, value: averageSugar(last: 180)),
            .init(label: L10n.Common.period365d, days: 365, value: averageSugar(last: 365))
        ]
    }

    private func averageSugar(last days: Int) -> Int {
        let source = sugarDaily365.isEmpty ? last90DaysData : sugarDaily365
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
        let values = monthlySugarData.map { Double($0.value) }
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
