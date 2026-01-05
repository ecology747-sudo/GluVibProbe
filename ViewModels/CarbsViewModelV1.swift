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

    // KPIs
    @Published var todayCarbsGrams: Int = 0
    @Published var dailyCarbsGoalInt: Int = 0

    // Chart Data
    @Published var last90DaysData: [DailyCarbsEntry] = []
    @Published var monthlyCarbsData: [MonthlyMetricEntry] = []
    @Published var carbsDaily365: [DailyCarbsEntry] = []

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

        // SSoT (heavy / Secondary)
        healthStore.$carbsDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.carbsDaily365 = $0 }
            .store(in: &cancellables)
    }

    private func bindSettings() {

        // ✅ SettingsModel: dailyCarbs (Nutrition Targets)
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
    }

    // ============================================================
    // MARK: - KPI Formatting — V1 kompatibel
    // ============================================================

    var formattedTodayCarbs: String {
        let formatted = numberFormatter.string(from: NSNumber(value: todayCarbsGrams)) ?? "\(todayCarbsGrams)"
        return "\(formatted) g"
    }

    var formattedDailyCarbsGoal: String {
        let formatted = numberFormatter.string(from: NSNumber(value: dailyCarbsGoalInt)) ?? "\(dailyCarbsGoalInt)"
        return "\(formatted) g"
    }

    var kpiDeltaText: String {
        let diff = todayCarbsGrams - dailyCarbsGoalInt
        let sign: String = diff > 0 ? "+" : diff < 0 ? "−" : "±"
        let absValue = abs(diff)
        let formatted = numberFormatter.string(from: NSNumber(value: absValue)) ?? "\(absValue)"
        return "\(sign) \(formatted) g"
    }

    var kpiDeltaColor: Color {
        let diff = todayCarbsGrams - dailyCarbsGoalInt
        if diff > 0 { return .green }
        if diff < 0 { return .red }
        return Color.Glu.primaryBlue
    }

    // ============================================================
    // MARK: - Period Averages — V1 kompatibel
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: averageCarbs(last: 7)),
            .init(label: "14T",  days: 14,  value: averageCarbs(last: 14)),
            .init(label: "30T",  days: 30,  value: averageCarbs(last: 30)),
            .init(label: "90T",  days: 90,  value: averageCarbs(last: 90)),
            .init(label: "180T", days: 180, value: averageCarbs(last: 180)),
            .init(label: "365T", days: 365, value: averageCarbs(last: 365))
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
    // MARK: - Chart Label Helper (NO units)                      // !!! NEW
    // ============================================================

    private func numberOnlyLabel(_ value: Double) -> String {    // !!! NEW
        "\(Int(value.rounded()))"                                 // !!! NEW
    }                                                             // !!! NEW

    // ============================================================
    // MARK: - Chart Scales — V1 kompatibel (NO "g" in axis/labels) // !!! UPDATED
    // ============================================================

    var dailyScale: MetricScaleResult {
        let values = last90DaysData.map { Double($0.grams) }
        let base = MetricScaleHelper.scale(values, for: .grams)   // !!! UPDATED: base helper
        return MetricScaleResult(                                  // !!! UPDATED: labels ohne "g"
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }
        )
    }

    var periodScale: MetricScaleResult {
        let values = periodAverages.map { Double($0.value) }
        let base = MetricScaleHelper.scale(values, for: .grams)   // !!! UPDATED
        return MetricScaleResult(                                  // !!! UPDATED
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }
        )
    }

    var monthlyScale: MetricScaleResult {
        let values = monthlyCarbsData.map { Double($0.value) }
        let base = MetricScaleHelper.scale(values, for: .grams)   // !!! UPDATED
        return MetricScaleResult(                                  // !!! UPDATED
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
