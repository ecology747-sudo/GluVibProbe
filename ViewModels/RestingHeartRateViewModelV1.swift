//
//  RestingHeartRateViewModelV1.swift
//  GluVibProbe
//
//  Body V1 — Resting Heart Rate ViewModel
//
//  Purpose
//  - Maps HealthStore resting heart rate data into UI-facing KPI, chart and hint outputs.
//  - Does not fetch data.
//  - Uses localized Body-domain resting-heart-rate texts and shared period labels.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → RestingHeartRateViewModelV1 → RestingHeartRateViewV1
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class RestingHeartRateViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    @Published var todayRestingHeartRate: Int = 0
    @Published var last90DaysRaw: [RestingHeartRateEntry] = []
    @Published var monthlyRaw: [MonthlyMetricEntry] = []
    @Published var daily365Raw: [RestingHeartRateEntry] = []

    @Published var restingHeartRateReadAuthIssueV1: Bool = false

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
        syncFromStores()
    }

    // ============================================================
    // MARK: - Bindings
    // ============================================================

    private func bindHealthStore() {

        healthStore.$todayRestingHeartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.remap() }
            .store(in: &cancellables)

        healthStore.$last90DaysRestingHeartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.remap() }
            .store(in: &cancellables)

        healthStore.$monthlyRestingHeartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.remap() }
            .store(in: &cancellables)

        healthStore.$restingHeartRateDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.remap() }
            .store(in: &cancellables)

        healthStore.$restingHeartRateReadAuthIssueV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.remap() }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        remap()
    }

    // ============================================================
    // MARK: - Availability (Today)
    // ============================================================

    private var hasTodayDatapoint: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let in90 = last90DaysRaw.contains {
            calendar.isDate($0.date, inSameDayAs: today)
        }

        let in365 = daily365Raw.contains {
            calendar.isDate($0.date, inSameDayAs: today)
        }

        return in90 || in365
    }

    private var hasTodayPositiveRestingHeartRate: Bool {
        todayRestingHeartRate > 0
    }

    // ============================================================
    // MARK: - Core Mapping
    // ============================================================

    private func remap() {
        restingHeartRateReadAuthIssueV1 = healthStore.restingHeartRateReadAuthIssueV1
        todayRestingHeartRate = healthStore.todayRestingHeartRate
        last90DaysRaw = healthStore.last90DaysRestingHeartRate
        monthlyRaw = healthStore.monthlyRestingHeartRate
        daily365Raw = healthStore.restingHeartRateDaily365
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var formattedTodayRestingHR: String {
        guard hasTodayDatapoint || hasTodayPositiveRestingHeartRate else { return "–" } // 🟨 UPDATED
        return "\(todayRestingHeartRate) bpm"
    }

    // ============================================================
    // MARK: - Info Hint (Today) — Goldstandard Body
    // ============================================================

    var todayInfoText: String? {
        if settings.showPermissionWarnings && restingHeartRateReadAuthIssueV1 { // 🟨 UPDATED
            return L10n.RestingHeartRate.hintNoDataOrPermission
        }

        if hasTodayDatapoint || hasTodayPositiveRestingHeartRate {
            return nil
        }

        let hasAnyHistoryPositive =
            last90DaysRaw.contains { $0.restingHeartRate > 0 } ||
            daily365Raw.contains { $0.restingHeartRate > 0 }

        if !hasAnyHistoryPositive {
            return L10n.RestingHeartRate.hintNoDataOrPermission
        }

        return L10n.RestingHeartRate.hintNoToday
    }

    // ============================================================
    // MARK: - Chart Adapters
    // ============================================================

    var last90DaysDataForChart: [DailyStepsEntry] {
        let sorted = last90DaysRaw.sorted { $0.date < $1.date }
        let nonZero = sorted.filter { $0.restingHeartRate > 0 }
        let base = nonZero.count <= 90 ? nonZero : Array(nonZero.suffix(90))

        return base.map {
            DailyStepsEntry(date: $0.date, steps: $0.restingHeartRate)
        }
    }

    var monthlyData: [MonthlyMetricEntry] {
        monthlyRaw
    }

    // ============================================================
    // MARK: - Period Averages
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: L10n.Common.period7d, days: 7, value: averageInt(last: 7)), // 🟨 UPDATED
            .init(label: L10n.Common.period14d, days: 14, value: averageInt(last: 14)),
            .init(label: L10n.Common.period30d, days: 30, value: averageInt(last: 30)),
            .init(label: L10n.Common.period90d, days: 90, value: averageInt(last: 90)),
            .init(label: L10n.Common.period180d, days: 180, value: averageInt(last: 180)),
            .init(label: L10n.Common.period365d, days: 365, value: averageInt(last: 365))
        ]
    }

    private func averageInt(last days: Int) -> Int {

        let source: [RestingHeartRateEntry] = {
            if days > 90, !daily365Raw.isEmpty { return daily365Raw }
            return last90DaysRaw
        }()

        guard !source.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard
            let endDate = calendar.date(byAdding: .day, value: -1, to: today),
            let startDate = calendar.date(byAdding: .day, value: -days, to: today)
        else {
            return 0
        }

        let filtered = source.filter { entry in
            let day = calendar.startOfDay(for: entry.date)
            return day >= startDate && day <= endDate && entry.restingHeartRate > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0) { $0 + $1.restingHeartRate }
        return Int((Double(sum) / Double(filtered.count)).rounded())
    }

    // ============================================================
    // MARK: - Scales
    // ============================================================

    private func numberOnlyLabel(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    var dailyScale: MetricScaleResult {
        let values = last90DaysDataForChart.map { Double($0.steps) }
        let base = MetricScaleHelper.scale(values.isEmpty ? [0] : values, for: .heartRateBpm)

        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [numberOnlyLabel] tick in
                numberOnlyLabel(tick)
            }
        )
    }

    var periodScale: MetricScaleResult {
        let values = periodAverages.map { Double($0.value) }
        let base = MetricScaleHelper.scale(values.isEmpty ? [0] : values, for: .heartRateBpm)

        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [numberOnlyLabel] tick in
                numberOnlyLabel(tick)
            }
        )
    }

    var monthlyScale: MetricScaleResult {
        let values = monthlyData.map { Double($0.value) }
        let base = MetricScaleHelper.scale(values.isEmpty ? [0] : values, for: .heartRateBpm)

        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [numberOnlyLabel] tick in
                numberOnlyLabel(tick)
            }
        )
    }
}
