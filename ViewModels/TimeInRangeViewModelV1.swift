//
//  TimeInRangeViewModelV1.swift
//  GluVibProbe
//
//  V1: Time In Range (Metabolic)
//  - KEIN Fetch im ViewModel
//  - SSOT: HealthStore (dailyTIR90 + tirTodaySummary)
//  - Target kommt aus SettingsModel (tirTargetPercent)
//  - KPI-Logik wie Steps: Goal / Today / Delta (+ Farbe)
//  - Charts: 0..100% Skala
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class TimeInRangeViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    // KPI
    @Published var todayTIRPercent: Int = 0
    @Published var tirTargetPercent: Int = 0

    // Chart Data (SSoT: dailyTIR90)
    @Published var last90DaysDaily: [DailyTIREntry] = []

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

        // Daily 90 (für Charts)
        healthStore.$dailyTIR90
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.last90DaysDaily = $0
            }
            .store(in: &cancellables)

        // Today Summary (für Today KPI)
        healthStore.$tirTodaySummary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] summary in
                self?.todayTIRPercent = Self.tirPercentValue(from: summary)
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
        tirTargetPercent = settings.tirTargetPercent
    }

    // ============================================================
    // MARK: - KPI Formatting (Steps-Pattern)
    // ============================================================

    var formattedGoalTIRPercent: String {
        tirTargetPercent > 0 ? "\(tirTargetPercent)%" : "–"
    }

    var formattedTodayTIRPercent: String {
        todayTIRPercent > 0 ? "\(todayTIRPercent)%" : "–"
    }

    var kpiDeltaText: String {
        let diff = todayTIRPercent - tirTargetPercent
        let sign: String = diff > 0 ? "+" : diff < 0 ? "−" : "±"
        return "\(sign) \(abs(diff))"
    }

    var kpiDeltaColor: Color {
        let diff = todayTIRPercent - tirTargetPercent
        if diff > 0 { return .green }
        if diff < 0 { return .red }
        return Color.Glu.primaryBlue
    }

    // ============================================================
    // MARK: - Adapter: DailyTIREntry → DailyStepsEntry (Chart expects Int)
    // - Wir speichern % als "steps" (0..100)
    // ============================================================

    var last90DaysChartData: [DailyStepsEntry] {
        last90DaysDaily.map { entry in
            DailyStepsEntry(
                date: entry.date,
                steps: Self.tirPercentValue(from: entry)
            )
        }
    }

    // ============================================================
    // MARK: - Period Averages (7/14/30/90) — als % Int
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",  days: 7,  value: averageTIRPercent(last: 7)),
            .init(label: "14T", days: 14, value: averageTIRPercent(last: 14)),
            .init(label: "30T", days: 30, value: averageTIRPercent(last: 30)),
            .init(label: "90T", days: 90, value: averageTIRPercent(last: 90))
        ]
    }

    private func averageTIRPercent(last days: Int) -> Int {
        guard !last90DaysDaily.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // wie Steps: endet gestern (letzte volle Tage)
        guard
            let endDate = calendar.date(byAdding: .day, value: -1, to: today),
            let startDate = calendar.date(byAdding: .day, value: -days, to: today)
        else { return 0 }

        let filtered = last90DaysDaily.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            let pct = Self.tirPercentValue(from: entry)
            return d >= startDate && d <= endDate && pct > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0) { $0 + Self.tirPercentValue(from: $1) }
        return Int((Double(sum) / Double(filtered.count)).rounded())
    }

    // ============================================================
    // MARK: - Chart Scales (0..100%)
    // ============================================================

    var dailyScale: MetricScaleResult {
        MetricScaleHelper.scale([100], for: .percent0to100)   // fixed 0..100 ticks
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
