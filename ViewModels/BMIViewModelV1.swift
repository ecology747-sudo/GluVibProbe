//
//  BMIViewModelV1.swift
//  GluVibProbe
//
//  Body V1 — BMI ViewModel
//
//  Purpose
//  - Maps HealthStore BMI data into UI-facing KPI, chart and hint outputs.
//  - Does not fetch data.
//  - Uses localized Body-domain BMI texts and shared period labels.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → BMIViewModelV1 → BMIViewV1
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class BMIViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    @Published var todayBMI: Double = 0
    @Published var last90DaysBMIRaw: [BMIEntry] = []
    @Published var bmiDaily365Raw: [BMIEntry] = []
    @Published var monthlyForChart: [MonthlyMetricEntry] = []

    @Published var bmiReadAuthIssueV1: Bool = false

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

        healthStore.$todayBMI
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todayBMI = $0 }
            .store(in: &cancellables)

        healthStore.$last90DaysBMI
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.last90DaysBMIRaw = $0 }
            .store(in: &cancellables)

        healthStore.$bmiDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.bmiDaily365Raw = $0 }
            .store(in: &cancellables)

        healthStore.$monthlyBMI
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.monthlyForChart = $0 }
            .store(in: &cancellables)

        healthStore.$bmiReadAuthIssueV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.bmiReadAuthIssueV1 = $0 }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        todayBMI = healthStore.todayBMI
        last90DaysBMIRaw = healthStore.last90DaysBMI
        bmiDaily365Raw = healthStore.bmiDaily365
        monthlyForChart = healthStore.monthlyBMI
        bmiReadAuthIssueV1 = healthStore.bmiReadAuthIssueV1
    }

    // ============================================================
    // MARK: - Availability (Today)
    // ============================================================

    private var hasTodayDatapoint: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let in90 = last90DaysBMIRaw.contains {
            calendar.isDate($0.date, inSameDayAs: today)
        }

        let in365 = bmiDaily365Raw.contains {
            calendar.isDate($0.date, inSameDayAs: today)
        }

        return in90 || in365
    }

    private var hasTodayPositiveBMI: Bool {
        todayBMI > 0
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var currentText: String {
        guard hasTodayDatapoint || hasTodayPositiveBMI else { return "–" }
        return formatOneDecimal(todayBMI)
    }

    // ============================================================
    // MARK: - Info Hint (Today) — Goldstandard Body
    // ============================================================

    var todayInfoText: String? {
        if settings.showPermissionWarnings && bmiReadAuthIssueV1 { // 🟨 UPDATED
            return L10n.BMI.hintNoDataOrPermission
        }

        if hasTodayDatapoint || hasTodayPositiveBMI {
            return nil
        }

        let hasAnyHistoryPositive =
            last90DaysBMIRaw.contains { $0.bmi > 0 } ||
            bmiDaily365Raw.contains { $0.bmi > 0 }

        if !hasAnyHistoryPositive {
            return L10n.BMI.hintNoDataOrPermission
        }

        return L10n.BMI.hintNoToday
    }

    // ============================================================
    // MARK: - Chart Adapters
    // ============================================================

    var last90DaysForChart: [DailyDoubleEntry] {
        last90DaysBMIRaw
            .filter { $0.bmi > 0 }
            .sorted { $0.date < $1.date }
            .map { DailyDoubleEntry(date: $0.date, value: $0.bmi) }
    }

    // ============================================================
    // MARK: - Period Averages
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: L10n.Common.period7d, days: 7, value: int10(averageBMI(last: 7))), // 🟨 UPDATED
            .init(label: L10n.Common.period14d, days: 14, value: int10(averageBMI(last: 14))),
            .init(label: L10n.Common.period30d, days: 30, value: int10(averageBMI(last: 30))),
            .init(label: L10n.Common.period90d, days: 90, value: int10(averageBMI(last: 90))),
            .init(label: L10n.Common.period180d, days: 180, value: int10(averageBMI(last: 180))),
            .init(label: L10n.Common.period365d, days: 365, value: int10(averageBMI(last: 365)))
        ]
    }

    private func averageBMI(last days: Int) -> Double {
        let source = days > 90 && !bmiDaily365Raw.isEmpty
            ? bmiDaily365Raw
            : last90DaysBMIRaw

        guard !source.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard
            let endDate = calendar.date(byAdding: .day, value: -1, to: today),
            let startDate = calendar.date(byAdding: .day, value: -days, to: today)
        else { return 0 }

        let values = source
            .filter {
                let d = calendar.startOfDay(for: $0.date)
                return d >= startDate && d <= endDate && $0.bmi > 0
            }
            .map(\.bmi)

        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func int10(_ value: Double) -> Int {
        Int((value * 10).rounded())
    }

    // ============================================================
    // MARK: - Scales
    // ============================================================

    var dailyScale: MetricScaleResult {
        let values = last90DaysForChart.map(\.value)
        return MetricScaleHelper.scale(values.isEmpty ? [0] : values, for: .weightKg)
    }

    var periodScale: MetricScaleResult {
        let values = periodAverages.map { Double($0.value) / 10.0 }
        return MetricScaleHelper.scale(values.isEmpty ? [0] : values, for: .weightKg)
    }

    var monthlyScale: MetricScaleResult {
        let values = monthlyForChart.map { Double($0.value) }
        return MetricScaleHelper.scale(values.isEmpty ? [0] : values, for: .weightKg)
    }

    // ============================================================
    // MARK: - Formatting Helper
    // ============================================================

    private func formatOneDecimal(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
