//
//  ProteinViewModelV1.swift
//  GluVibProbe
//
//  V1: Protein ViewModel
//  - KEIN Fetch im ViewModel
//  - Single Source of Truth: HealthStore
//  - Targets aus SettingsModel (dailyProtein)
//  - V1 kompatibel
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class ProteinViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    // KPIs
    @Published var todayProteinGrams: Int = 0
    @Published var dailyProteinGoalInt: Int = 0

    // Chart Data
    @Published var last90DaysData: [DailyProteinEntry] = []
    @Published var monthlyProteinData: [MonthlyMetricEntry] = []
    @Published var proteinDaily365: [DailyProteinEntry] = []          // !!! NEW

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

        healthStore.$proteinDaily365                                       // !!! NEW
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.proteinDaily365 = $0 }
            .store(in: &cancellables)
    }

    private func bindSettings() {

        settings.$dailyProtein                                             // !!! UPDATED
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.dailyProteinGoalInt = $0 }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        todayProteinGrams = healthStore.todayProteinGrams
        last90DaysData = healthStore.last90DaysProtein
        monthlyProteinData = healthStore.monthlyProtein
        proteinDaily365 = healthStore.proteinDaily365                      // !!! NEW
        dailyProteinGoalInt = settings.dailyProtein                         // !!! UPDATED
    }

    // ============================================================
    // MARK: - KPI Formatting (WITH unit)
    // ============================================================

    private let numberFormatter: NumberFormatter = {                        // !!! NEW
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()                                                                     // !!! NEW

    var formattedTodayProtein: String {
        let formatted = numberFormatter.string(from: NSNumber(value: todayProteinGrams)) ?? "\(todayProteinGrams)" // !!! UPDATED
        return "\(formatted) g"                                             // !!! UPDATED
    }

    var formattedDailyProteinGoal: String {
        let formatted = numberFormatter.string(from: NSNumber(value: dailyProteinGoalInt)) ?? "\(dailyProteinGoalInt)" // !!! UPDATED
        return "\(formatted) g"                                             // !!! UPDATED
    }

    var kpiDeltaText: String {
        let diff = todayProteinGrams - dailyProteinGoalInt
        let sign: String = diff > 0 ? "+" : diff < 0 ? "−" : "±"
        let absValue = abs(diff)
        let formatted = numberFormatter.string(from: NSNumber(value: absValue)) ?? "\(absValue)" // !!! UPDATED
        return "\(sign) \(formatted) g"                                     // !!! UPDATED
    }

    var kpiDeltaColor: Color {
        let diff = todayProteinGrams - dailyProteinGoalInt
        if diff > 0 { return .green }
        if diff < 0 { return .red }
        return Color.Glu.primaryBlue
    }

    // ============================================================
    // MARK: - Period Averages
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: averageProtein(last: 7)),
            .init(label: "14T",  days: 14,  value: averageProtein(last: 14)),
            .init(label: "30T",  days: 30,  value: averageProtein(last: 30)),
            .init(label: "90T",  days: 90,  value: averageProtein(last: 90)),
            .init(label: "180T", days: 180, value: averageProtein(last: 180)),
            .init(label: "365T", days: 365, value: averageProtein(last: 365))
        ]
    }

    private func averageProtein(last days: Int) -> Int {
        let source: [DailyProteinEntry] = {                                 // !!! UPDATED
            if days > 90, !proteinDaily365.isEmpty { return proteinDaily365 } // !!! UPDATED
            return last90DaysData                                            // !!! UPDATED
        }()                                                                  // !!! UPDATED

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

        let sum = filtered.reduce(0) { $0 + $1.grams }
        let avg = Double(sum) / Double(filtered.count)
        return Int(avg.rounded())
    }

    // ============================================================
    // MARK: - Chart Label Helper (NO unit)
    // ============================================================

    private func numberOnlyLabel(_ value: Double) -> String {               // !!! NEW
        "\(Int(value.rounded()))"                                           // !!! NEW
    }                                                                       // !!! NEW

    // ============================================================
    // MARK: - Chart Scales (NO unit in charts)
    // ============================================================

    var dailyScale: MetricScaleResult {
        let base = MetricScaleHelper.scale(last90DaysData.map { Double($0.grams) }, for: .grams) // !!! UPDATED
        return MetricScaleResult(                                            // !!! UPDATED
            yAxisTicks: base.yAxisTicks,                                      // !!! UPDATED
            yMax: base.yMax,                                                  // !!! UPDATED
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }         // !!! UPDATED (no "g")
        )                                                                      // !!! UPDATED
    }

    var periodScale: MetricScaleResult {
        let base = MetricScaleHelper.scale(periodAverages.map { Double($0.value) }, for: .grams) // !!! UPDATED
        return MetricScaleResult(                                            // !!! UPDATED
            yAxisTicks: base.yAxisTicks,                                      // !!! UPDATED
            yMax: base.yMax,                                                  // !!! UPDATED
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }         // !!! UPDATED (no "g")
        )                                                                      // !!! UPDATED
    }

    var monthlyScale: MetricScaleResult {
        let base = MetricScaleHelper.scale(monthlyProteinData.map { Double($0.value) }, for: .grams) // !!! UPDATED
        return MetricScaleResult(                                            // !!! UPDATED
            yAxisTicks: base.yAxisTicks,                                      // !!! UPDATED
            yMax: base.yMax,                                                  // !!! UPDATED
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }         // !!! UPDATED (no "g")
        )                                                                      // !!! UPDATED
    }
}
