//
//  WeightViewModelV1.swift
//  GluVibProbe
//
//  Body V1 — Weight ViewModel
//  - No fetch in ViewModel
//  - Single Source of Truth: HealthStore
//  - Target from SettingsModel
//  - Goldstandard body hint / KPI / chart mapping
//

import Foundation
import Combine
import SwiftUI

struct DailyDoubleEntry: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let value: Double
}

@MainActor
final class WeightViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    @Published var todayWeightKg: Double = 0
    @Published var targetWeightKg: Double = 0

    @Published var last90DaysData: [DailyWeightEntry] = []
    @Published var monthlyWeightData: [MonthlyMetricEntry] = []
    @Published var weightDaily365Raw: [DailyWeightEntry] = []

    @Published var weightReadAuthIssueV1: Bool = false

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

        healthStore.$todayWeightKgRaw
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todayWeightKg = max(0, $0) }
            .store(in: &cancellables)

        healthStore.$last90DaysWeight
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.last90DaysData = $0 }
            .store(in: &cancellables)

        healthStore.$monthlyWeight
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.monthlyWeightData = $0 }
            .store(in: &cancellables)

        healthStore.$weightDaily365Raw
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.weightDaily365Raw = $0 }
            .store(in: &cancellables)

        healthStore.$weightReadAuthIssueV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.weightReadAuthIssueV1 = $0 }
            .store(in: &cancellables)
    }

    private func bindSettings() {
        settings.$targetWeightKg
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.targetWeightKg = Double($0) }
            .store(in: &cancellables)

        settings.$weightUnit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        todayWeightKg = max(0, healthStore.todayWeightKgRaw)
        last90DaysData = healthStore.last90DaysWeight
        monthlyWeightData = healthStore.monthlyWeight
        weightDaily365Raw = healthStore.weightDaily365Raw
        targetWeightKg = Double(settings.targetWeightKg)
        weightReadAuthIssueV1 = healthStore.weightReadAuthIssueV1
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

        let in365 = weightDaily365Raw.contains {
            calendar.isDate($0.date, inSameDayAs: today)
        }

        return in90 || in365
    }

    private var hasTodayPositiveWeight: Bool {
        todayWeightKg > 0
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var currentText: String {
        guard hasTodayDatapoint || hasTodayPositiveWeight else { return "–" }
        return settings.weightUnit.formatted(fromKg: todayWeightKg, fractionDigits: 1)
    }

    var targetText: String {
        settings.weightUnit.formatted(fromKg: targetWeightKg, fractionDigits: 1)
    }

    var deltaText: String {
        guard hasTodayDatapoint || hasTodayPositiveWeight else { return "–" }

        let delta = todayWeightKg - targetWeightKg
        let sign: String = delta > 0 ? "+" : delta < 0 ? "−" : "±"
        let absString = settings.weightUnit.formattedNumber(
            fromKg: abs(delta),
            fractionDigits: 1
        )
        return "\(sign) \(absString) \(settings.weightUnit.label)"
    }

    var deltaColor: Color {
        guard hasTodayDatapoint || hasTodayPositiveWeight else { return Color.Glu.primaryBlue }

        let delta = todayWeightKg - targetWeightKg
        if delta > 0 { return .red }
        if delta < 0 { return Color.Glu.successGreen }
        return Color.Glu.primaryBlue
    }

    // ============================================================
    // MARK: - Info Hint (Today) — Goldstandard Body
    // ============================================================

    var todayInfoText: String? { // 🟨 UPDATED

        if settings.showPermissionWarnings && weightReadAuthIssueV1 {
            return L10n.Weight.hintNoDataOrPermission
        }

        if hasTodayDatapoint || hasTodayPositiveWeight {
            return nil
        }

        let hasAnyHistoryPositive =
            last90DaysData.contains { $0.kg > 0 } ||
            weightDaily365Raw.contains { $0.kg > 0 }

        if !hasAnyHistoryPositive {
            return L10n.Weight.hintNoDataOrPermission
        }

        return L10n.Weight.hintNoToday
    }

    // ============================================================
    // MARK: - Chart Mapping
    // ============================================================

    var last90DaysForChart: [DailyDoubleEntry] {
        last90DaysData.map {
            DailyDoubleEntry(
                date: $0.date,
                value: max(0, settings.weightUnit.convertedValue(fromKg: $0.kg))
            )
        }
    }

    var monthlyForChart: [MonthlyMetricEntry] {
        monthlyWeightData
    }

    // ============================================================
    // MARK: - Period Averages
    // ============================================================

    var periodAverages: [PeriodAverageEntry] { // 🟨 UPDATED
        [
            .init(label: L10n.Common.period7d, days: 7, value: averageWeight(last: 7)),
            .init(label: L10n.Common.period14d, days: 14, value: averageWeight(last: 14)),
            .init(label: L10n.Common.period30d, days: 30, value: averageWeight(last: 30)),
            .init(label: L10n.Common.period90d, days: 90, value: averageWeight(last: 90)),
            .init(label: L10n.Common.period180d, days: 180, value: averageWeight(last: 180)),
            .init(label: L10n.Common.period365d, days: 365, value: averageWeight(last: 365))
        ]
    }

    private func averageWeight(last days: Int) -> Int {
        let source = weightDaily365Raw.isEmpty ? last90DaysData : weightDaily365Raw
        guard !source.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard
            let endDate = calendar.date(byAdding: .day, value: -1, to: today),
            let startDate = calendar.date(byAdding: .day, value: -days, to: today)
        else { return 0 }

        let filtered = source.filter {
            let d = calendar.startOfDay(for: $0.date)
            return d >= startDate && d <= endDate && $0.kg > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let avgKg = filtered.reduce(0.0) { $0 + $1.kg } / Double(filtered.count)
        return Int(round(settings.weightUnit.convertedValue(fromKg: avgKg)))
    }

    // ============================================================
    // MARK: - Chart Label Helper (NO units)
    // ============================================================

    private func numberOnlyLabel(_ value: Double) -> String {
        if settings.weightUnit == .kg {
            return String(format: "%.1f", value)
        } else {
            return "\(Int(value.rounded()))"
        }
    }

    // ============================================================
    // MARK: - Chart Scales (NO units in axis/labels)
    // ============================================================

    var dailyScale: MetricScaleResult {
        let values = last90DaysForChart.map(\.value)
        let base = MetricScaleHelper.scale(values, for: .weightKg)
        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }
        )
    }

    var periodScale: MetricScaleResult {
        let values = periodAverages.map { Double($0.value) }
        let base = MetricScaleHelper.scale(values, for: .weightKg)
        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }
        )
    }

    var monthlyScale: MetricScaleResult {
        let values = monthlyForChart.map { Double($0.value) }
        let base = MetricScaleHelper.scale(values, for: .weightKg)
        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [numberOnlyLabel] v in numberOnlyLabel(v) }
        )
    }
}
