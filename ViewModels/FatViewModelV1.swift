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

    // KPIs
    @Published var todayFatGrams: Int = 0
    @Published var dailyFatGoalInt: Int = 0

    // Chart Data
    @Published var last90DaysData: [DailyFatEntry] = []
    @Published var monthlyFatData: [MonthlyMetricEntry] = []
    @Published var fatDaily365: [DailyFatEntry] = []                      // !!! UPDATED (Name wie HealthStore)

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
            .sink { [weak self] in self?.fatDaily365 = $0 }               // !!! UPDATED
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
        fatDaily365 = healthStore.fatDaily365                             // !!! UPDATED
        dailyFatGoalInt = settings.dailyFat
    }

    // ============================================================
    // MARK: - KPI Formatting (mit Einheit)
    // ============================================================

    var formattedTodayFat: String {
        let formatted = numberFormatter.string(from: NSNumber(value: todayFatGrams)) ?? "\(todayFatGrams)"
        return "\(formatted) g"                                           // !!! UPDATED
    }

    var formattedDailyFatGoal: String {
        let formatted = numberFormatter.string(from: NSNumber(value: dailyFatGoalInt)) ?? "\(dailyFatGoalInt)"
        return "\(formatted) g"                                           // !!! UPDATED
    }

    var kpiDeltaText: String {
        let diff = todayFatGrams - dailyFatGoalInt
        let sign: String = diff > 0 ? "+" : diff < 0 ? "−" : "±"
        let absValue = abs(diff)
        let formatted = numberFormatter.string(from: NSNumber(value: absValue)) ?? "\(absValue)"
        return "\(sign) \(formatted) g"                                   // !!! UPDATED
    }

    var kpiDeltaColor: Color {
        let diff = todayFatGrams - dailyFatGoalInt
        if diff > 0 { return .green }
        if diff < 0 { return .red }
        return Color.Glu.primaryBlue
    }

    // ============================================================
    // MARK: - Period Averages
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: averageFat(last: 7)),
            .init(label: "14T",  days: 14,  value: averageFat(last: 14)),
            .init(label: "30T",  days: 30,  value: averageFat(last: 30)),
            .init(label: "90T",  days: 90,  value: averageFat(last: 90)),
            .init(label: "180T", days: 180, value: averageFat(last: 180)),
            .init(label: "365T", days: 365, value: averageFat(last: 365))
        ]
    }

    private func averageFat(last days: Int) -> Int {
        let source = fatDaily365.isEmpty ? last90DaysData : fatDaily365   // !!! UPDATED
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
    // MARK: - Chart Label Helper (NO unit)                      // !!! NEW
    // ============================================================

    private func numberOnlyLabel(_ value: Double) -> String {            // !!! NEW
        "\(Int(value.rounded()))"                                        // !!! NEW
    }                                                                    // !!! NEW

    // ============================================================
    // MARK: - Chart Scales (NO unit in charts)                  // !!! UPDATED
    // ============================================================

    var dailyScale: MetricScaleResult {                                   // !!! UPDATED
        let base = MetricScaleHelper.scale(last90DaysData.map { Double($0.grams) }, for: .grams) // !!! UPDATED
        return MetricScaleResult(                                          // !!! UPDATED
            yAxisTicks: base.yAxisTicks,                                   // !!! UPDATED
            yMax: base.yMax,                                               // !!! UPDATED
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }      // !!! UPDATED
        )                                                                  // !!! UPDATED
    }

    var periodScale: MetricScaleResult {                                  // !!! UPDATED
        let base = MetricScaleHelper.scale(periodAverages.map { Double($0.value) }, for: .grams) // !!! UPDATED
        return MetricScaleResult(                                          // !!! UPDATED
            yAxisTicks: base.yAxisTicks,                                   // !!! UPDATED
            yMax: base.yMax,                                               // !!! UPDATED
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }      // !!! UPDATED
        )                                                                  // !!! UPDATED
    }

    var monthlyScale: MetricScaleResult {                                 // !!! UPDATED
        let base = MetricScaleHelper.scale(monthlyFatData.map { Double($0.value) }, for: .grams) // !!! UPDATED
        return MetricScaleResult(                                          // !!! UPDATED
            yAxisTicks: base.yAxisTicks,                                   // !!! UPDATED
            yMax: base.yMax,                                               // !!! UPDATED
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }      // !!! UPDATED
        )                                                                  // !!! UPDATED
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
