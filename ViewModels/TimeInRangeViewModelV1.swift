//
//  TimeInRangeViewModelV1.swift
//  GluVibProbe
//
//  Time In Range (Metabolic) — ViewModel (V1)
//
//  Macht NUR UI-nahe Ableitungen aus HealthStore-SSoT:
//  - Today KPI aus tirTodaySummary (00:00 → now, minutenbasiert aus RAW)
//  - Perioden 7/14/30/90 aus tirXdSummary (HYBRID: (days-1) dailyTIR90 + Today RAW)
//  - Chart-Daten aus dailyTIR90 (tagesbasiert, 90 Tage)
//  - Keine Fetches, keine HealthKit-Queries
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

    // Period KPIs (HYBRID summaries → %)
    @Published private(set) var tir7dPercent: Int = 0
    @Published private(set) var tir14dPercent: Int = 0
    @Published private(set) var tir30dPercent: Int = 0
    @Published private(set) var tir90dPercent: Int = 0

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

        // !!! UPDATED: Period Averages kommen aus HYBRID-Summaries (nicht aus Daily-Filter wie Steps)
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

        // !!! UPDATED: Perioden aus HYBRID-Summaries
        tir7dPercent  = Self.tirPercentValue(from: healthStore.tir7dSummary)
        tir14dPercent = Self.tirPercentValue(from: healthStore.tir14dSummary)
        tir30dPercent = Self.tirPercentValue(from: healthStore.tir30dSummary)
        tir90dPercent = Self.tirPercentValue(from: healthStore.tir90dSummary)
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
    // MARK: - Period Averages (7/14/30/90) — HYBRID (% Int)
    // - Leere Perioden (coverage == 0) ergeben 0 und werden im Chart als "0/–" gehandhabt
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",  days: 7,  value: tir7dPercent),
            .init(label: "14T", days: 14, value: tir14dPercent),
            .init(label: "30T", days: 30, value: tir30dPercent),
            .init(label: "90T", days: 90, value: tir90dPercent)
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
        guard cov > 0 else { return 0 }                 // ✅ leere Perioden zählen nicht
        let inRange = max(0, summary.inRangeMinutes)
        let pct = Int((Double(inRange) / Double(cov) * 100.0).rounded())
        return max(0, min(100, pct))
    }

    private static func tirPercentValue(from entry: DailyTIREntry) -> Int {
        let cov = max(0, entry.coverageMinutes)
        guard cov > 0 else { return 0 }                 // ✅ leere Tage zählen nicht
        let inRange = max(0, entry.inRangeMinutes)
        let pct = Int((Double(inRange) / Double(cov) * 100.0).rounded())
        return max(0, min(100, pct))
    }
}
