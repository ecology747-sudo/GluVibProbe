//
//  BodyFatViewModelV1.swift
//  GluVibProbe
//
//  Body V1 — Body Fat ViewModel
//
//  Purpose
//  - Maps HealthStore body fat data into UI-facing KPI, chart and hint outputs.
//  - Does not fetch data.
//  - Uses localized Body-domain body-fat texts and shared period labels.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → BodyFatViewModelV1 → BodyFatViewV1
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class BodyFatViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    @Published var todayBodyFatPercent: Double = 0
    @Published var last90DaysBodyFatRaw: [BodyFatEntry] = []
    @Published var monthlyBodyFatData: [MonthlyMetricEntry] = []
    @Published var bodyFatDaily365Raw: [BodyFatEntry] = []

    @Published var bodyFatReadAuthIssueV1: Bool = false

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

        healthStore.$todayBodyFatPercent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.remap() }
            .store(in: &cancellables)

        healthStore.$last90DaysBodyFat
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.remap() }
            .store(in: &cancellables)

        healthStore.$monthlyBodyFat
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.remap() }
            .store(in: &cancellables)

        healthStore.$bodyFatDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.remap() }
            .store(in: &cancellables)

        healthStore.$bodyFatReadAuthIssueV1
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

        let in90 = last90DaysBodyFatRaw.contains {
            calendar.isDate($0.date, inSameDayAs: today)
        }

        let in365 = bodyFatDaily365Raw.contains {
            calendar.isDate($0.date, inSameDayAs: today)
        }

        return in90 || in365
    }

    private var hasTodayPositiveBodyFat: Bool {
        todayBodyFatPercent > 0
    }

    // ============================================================
    // MARK: - Core Mapping
    // ============================================================

    private func remap() {

        bodyFatReadAuthIssueV1 = healthStore.bodyFatReadAuthIssueV1
        last90DaysBodyFatRaw = healthStore.last90DaysBodyFat
        monthlyBodyFatData = healthStore.monthlyBodyFat
        bodyFatDaily365Raw = healthStore.bodyFatDaily365

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        if let todayEntry = last90DaysBodyFatRaw.last(where: { calendar.isDate($0.date, inSameDayAs: todayStart) }) {
            todayBodyFatPercent = max(0, todayEntry.bodyFatPercent)
        } else if let todayEntry365 = bodyFatDaily365Raw.last(where: { calendar.isDate($0.date, inSameDayAs: todayStart) }) {
            todayBodyFatPercent = max(0, todayEntry365.bodyFatPercent)
        } else {
            todayBodyFatPercent = max(0, healthStore.todayBodyFatPercent) // 🟨 UPDATED
        }
    }

    // ============================================================
    // MARK: - Info Hint (Today) — Goldstandard Body
    // ============================================================

    var todayInfoText: String? {
        if settings.showPermissionWarnings && bodyFatReadAuthIssueV1 { // 🟨 UPDATED
            return L10n.BodyFat.hintNoDataOrPermission
        }

        if hasTodayDatapoint || hasTodayPositiveBodyFat {
            return nil
        }

        let hasAnyHistoryPositive =
            last90DaysBodyFatRaw.contains { $0.bodyFatPercent > 0 } ||
            bodyFatDaily365Raw.contains { $0.bodyFatPercent > 0 }

        if !hasAnyHistoryPositive {
            return L10n.BodyFat.hintNoDataOrPermission
        }

        return L10n.BodyFat.hintNoToday
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var formattedTodayBodyFat: String {
        guard hasTodayDatapoint || hasTodayPositiveBodyFat else { return "–" }
        let value = oneDecimalFormatter.string(from: NSNumber(value: todayBodyFatPercent)) ?? "\(todayBodyFatPercent)"
        return "\(value) %"
    }

    // ============================================================
    // MARK: - Chart Adapters (Int*10)
    // ============================================================

    var last90DaysDataForChart: [DailyStepsEntry] {
        let sorted = last90DaysBodyFatRaw.sorted { $0.date < $1.date }
        let nonZero = sorted.filter { $0.bodyFatPercent > 0 }
        let base = nonZero.count <= 90 ? nonZero : Array(nonZero.suffix(90))

        return base.map { entry in
            DailyStepsEntry(
                date: entry.date,
                steps: Int((entry.bodyFatPercent * 10.0).rounded())
            )
        }
    }

    var monthlyBodyFatDataForChart: [MonthlyMetricEntry] {
        monthlyBodyFatData
    }

    // ============================================================
    // MARK: - Period Averages
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: L10n.Common.period7d, days: 7, value: averageBodyFatInt10(last: 7)), // 🟨 UPDATED
            .init(label: L10n.Common.period14d, days: 14, value: averageBodyFatInt10(last: 14)),
            .init(label: L10n.Common.period30d, days: 30, value: averageBodyFatInt10(last: 30)),
            .init(label: L10n.Common.period90d, days: 90, value: averageBodyFatInt10(last: 90)),
            .init(label: L10n.Common.period180d, days: 180, value: averageBodyFatInt10(last: 180)),
            .init(label: L10n.Common.period365d, days: 365, value: averageBodyFatInt10(last: 365))
        ]
    }

    private func averageBodyFatInt10(last days: Int) -> Int {

        let source: [BodyFatEntry] = {
            if days > 90, !bodyFatDaily365Raw.isEmpty { return bodyFatDaily365Raw }
            return last90DaysBodyFatRaw
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
            return day >= startDate && day <= endDate && entry.bodyFatPercent > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0.0) { $0 + $1.bodyFatPercent }
        let avg = sum / Double(filtered.count)

        return Int((avg * 10.0).rounded())
    }

    // ============================================================
    // MARK: - Scales (Int*10)
    // ============================================================

    var dailyScale: MetricScaleResult {
        let values = last90DaysDataForChart.map { Double($0.steps) }
        return scalePercentInt10(values.isEmpty ? [0] : values)
    }

    var periodScale: MetricScaleResult {
        let values = periodAverages.map { Double($0.value) }
        return scalePercentInt10(values.isEmpty ? [0] : values)
    }

    var monthlyScale: MetricScaleResult {
        let values = monthlyBodyFatDataForChart.map { Double($0.value * 10) }
        return scalePercentInt10(values.isEmpty ? [0] : values)
    }

    private func scalePercentInt10(_ values: [Double]) -> MetricScaleResult {
        let base = MetricScaleHelper.scale(values, for: .percentInt10)

        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { tick in
                let value = tick / 10.0
                let text = self.oneDecimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
                return text
            }
        )
    }

    // ============================================================
    // MARK: - Formatter
    // ============================================================

    private let oneDecimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}
