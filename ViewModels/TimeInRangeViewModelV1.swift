//
//  TimeInRangeViewModelV1.swift
//  GluVibProbe
//
//  Time In Range (Metabolic) — ViewModel (V1)
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class TimeInRangeViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Info State
    // ============================================================

    enum TimeInRangeInfoState { // 🟨 NEW
        case noHistory
        case noTodayData
    }

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    @Published var todayTIRPercent: Int = 0
    @Published var tirTargetPercent: Int = 0

    @Published private(set) var todayCoverageMinutes: Int = 0

    @Published var last90DaysDaily: [DailyTIREntry] = []

    @Published private(set) var tir7dPercent: Int = 0
    @Published private(set) var tir14dPercent: Int = 0
    @Published private(set) var tir30dPercent: Int = 0
    @Published private(set) var tir90dPercent: Int = 0

    @Published var glucoseReadAuthIssueV1: Bool = false

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

        healthStore.$dailyTIR90
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.last90DaysDaily = $0
            }
            .store(in: &cancellables)

        healthStore.$tirTodaySummary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] summary in
                self?.todayTIRPercent = Self.tirPercentValue(from: summary)
                self?.todayCoverageMinutes = max(0, summary?.coverageMinutes ?? 0)
            }
            .store(in: &cancellables)

        healthStore.$tir7dSummary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] summary in
                self?.tir7dPercent = Self.tirPercentValue(from: summary)
            }
            .store(in: &cancellables)

        healthStore.$tir14dSummary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] summary in
                self?.tir14dPercent = Self.tirPercentValue(from: summary)
            }
            .store(in: &cancellables)

        healthStore.$tir30dSummary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] summary in
                self?.tir30dPercent = Self.tirPercentValue(from: summary)
            }
            .store(in: &cancellables)

        healthStore.$tir90dSummary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] summary in
                self?.tir90dPercent = Self.tirPercentValue(from: summary)
            }
            .store(in: &cancellables)

        healthStore.$glucoseReadAuthIssueV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.glucoseReadAuthIssueV1 = $0
            }
            .store(in: &cancellables)
    }

    private func bindSettings() {
        settings.$tirTargetPercent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.tirTargetPercent = $0 }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        last90DaysDaily = healthStore.dailyTIR90
        todayTIRPercent = Self.tirPercentValue(from: healthStore.tirTodaySummary)
        todayCoverageMinutes = max(0, healthStore.tirTodaySummary?.coverageMinutes ?? 0)

        tirTargetPercent = settings.tirTargetPercent

        tir7dPercent = Self.tirPercentValue(from: healthStore.tir7dSummary)
        tir14dPercent = Self.tirPercentValue(from: healthStore.tir14dSummary)
        tir30dPercent = Self.tirPercentValue(from: healthStore.tir30dSummary)
        tir90dPercent = Self.tirPercentValue(from: healthStore.tir90dSummary)

        glucoseReadAuthIssueV1 = healthStore.glucoseReadAuthIssueV1
    }

    // ============================================================
    // MARK: - KPI Formatting (Steps-Pattern)
    // ============================================================

    var formattedGoalTIRPercent: String {
        tirTargetPercent > 0 ? "\(tirTargetPercent)%" : "–"
    }

    var formattedTodayTIRPercent: String {
        todayCoverageMinutes > 0 ? "\(todayTIRPercent)%" : "–"
    }

    var kpiDeltaText: String {
        let diff = todayTIRPercent - tirTargetPercent
        let sign: String = diff > 0 ? "+" : diff < 0 ? "−" : "±"
        return "\(sign) \(abs(diff))"
    }

    var kpiDeltaColor: Color {
        let diff = todayTIRPercent - tirTargetPercent
        if diff > 0 { return Color.Glu.successGreen }
        if diff < 0 { return .red }
        return Color.Glu.primaryBlue
    }

    // ============================================================
    // MARK: - Goldstandard Hint State
    // ============================================================

    var todayInfoState: TimeInRangeInfoState? { // 🟨 NEW

        if glucoseReadAuthIssueV1 {
            return .noHistory
        }

        if todayCoverageMinutes > 0 { return nil }

        let hasAnyHistory = last90DaysDaily.contains { $0.coverageMinutes > 0 }

        if !hasAnyHistory {
            return .noHistory
        }

        return .noTodayData
    }

    // ============================================================
    // MARK: - Adapter: DailyTIREntry → DailyStepsEntry
    // ============================================================

    var last90DaysChartData: [DailyStepsEntry] {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())

        return last90DaysDaily
            .filter { cal.startOfDay(for: $0.date) < todayStart }
            .map { entry in
                DailyStepsEntry(
                    date: entry.date,
                    steps: Self.tirPercentValue(from: entry)
                )
            }
    }

    // ============================================================
    // MARK: - Period Averages (7/14/30/90)
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: L10n.Common.period7d,  days: 7,  value: tir7dPercent),
            .init(label: L10n.Common.period14d, days: 14, value: tir14dPercent),
            .init(label: L10n.Common.period30d, days: 30, value: tir30dPercent),
            .init(label: L10n.Common.period90d, days: 90, value: tir90dPercent)
        ]
    }

    // ============================================================
    // MARK: - Chart Scales (0..100%)
    // ============================================================

    var dailyScale: MetricScaleResult {
        MetricScaleHelper.scale([100], for: .percent0to100)
    }

    var periodScale: MetricScaleResult {
        MetricScaleHelper.scale([100], for: .percent0to100)
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private static func tirPercentValue(from summary: TIRPeriodSummaryEntry?) -> Int {
        guard let summary else { return 0 }
        let cov = max(0, summary.coverageMinutes)
        guard cov > 0 else { return 0 }
        let inRange = max(0, summary.inRangeMinutes)
        let pct = Int((Double(inRange) / Double(cov) * 100.0).rounded())
        return max(0, min(100, pct))
    }

    private static func tirPercentValue(from entry: DailyTIREntry) -> Int {
        let cov = max(0, entry.coverageMinutes)
        guard cov > 0 else { return 0 }
        let inRange = max(0, entry.inRangeMinutes)
        let pct = Int((Double(inRange) / Double(cov) * 100.0).rounded())
        return max(0, min(100, pct))
    }
}
