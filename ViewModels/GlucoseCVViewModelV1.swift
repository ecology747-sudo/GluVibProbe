//
//  GlucoseCVViewModelV1.swift
//  GluVibProbe
//
//  V1: Glucose CV (Metabolic)
//  - KEIN Fetch im ViewModel
//  - SSoT: HealthStore
//    - dailyGlucoseStats90 (Daily chart series only)
//    - last24hGlucoseCvPercent (rolling 24h, end = last CGM sample)
//    - rollingGlucoseCvPercent7/14/30/90 (Dexcom-like rolling windows, end = last CGM sample)
//  - RULE: NO parallel CV methods in VM (no daily averaging for KPIs/Periods/Report)
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class GlucoseCVViewModelV1: ObservableObject {

    enum GlucoseCVInfoState { // 🟨 NEW
        case noHistory
        case noTodayData
    }

    // Daily chart series (ok to stay daily-based)
    @Published var last90DaysDaily: [DailyGlucoseStatsEntry] = []

    // KPI tiles (Last 24h / Current / Last 90d)
    @Published var last24hCVPercent: Double = 0
    @Published var currentCVPercent: Double = 0
    @Published var last90dCVPercent: Double = 0

    // Rolling windows for Period chart (Dexcom-like)
    @Published private(set) var rolling7dCVPercent: Double = 0
    @Published private(set) var rolling14dCVPercent: Double = 0
    @Published private(set) var rolling30dCVPercent: Double = 0
    @Published private(set) var rolling90dCVPercent: Double = 0

    @Published var glucoseReadAuthIssueV1: Bool = false
    @Published private(set) var todayCoverageMinutes: Int = 0 // 🟨 NEW

    private let healthStore: HealthStore
    private let settings: SettingsModel
    private var cancellables = Set<AnyCancellable>()

    init(
        healthStore: HealthStore = .shared,
        settings: SettingsModel = .shared
    ) {
        self.healthStore = healthStore
        self.settings = settings

        bindHealthStore()
        syncFromStores()
    }

    private func bindHealthStore() {

        // Daily series (chart)
        healthStore.$dailyGlucoseStats90
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.last90DaysDaily = $0
            }
            .store(in: &cancellables)

        // KPI: Last 24h (rolling)
        healthStore.$last24hGlucoseCvPercent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in
                self?.last24hCVPercent = max(0, v ?? 0)
            }
            .store(in: &cancellables)

        // Dexcom-like rolling windows (end = last CGM sample)
        healthStore.$rollingGlucoseCvPercent7
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in
                let value = max(0, v ?? 0)
                self?.rolling7dCVPercent = value
                self?.currentCVPercent = value
            }
            .store(in: &cancellables)

        healthStore.$rollingGlucoseCvPercent14
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in
                self?.rolling14dCVPercent = max(0, v ?? 0)
            }
            .store(in: &cancellables)

        healthStore.$rollingGlucoseCvPercent30
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in
                self?.rolling30dCVPercent = max(0, v ?? 0)
            }
            .store(in: &cancellables)

        healthStore.$rollingGlucoseCvPercent90
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in
                let value = max(0, v ?? 0)
                self?.rolling90dCVPercent = value
                self?.last90dCVPercent = value
            }
            .store(in: &cancellables)

        healthStore.$glucoseReadAuthIssueV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.glucoseReadAuthIssueV1 = $0
            }
            .store(in: &cancellables)

        healthStore.$todayGlucoseCoverageMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.todayCoverageMinutes = max(0, $0)
            }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        last90DaysDaily = healthStore.dailyGlucoseStats90

        last24hCVPercent = max(0, healthStore.last24hGlucoseCvPercent ?? 0)

        rolling7dCVPercent  = max(0, healthStore.rollingGlucoseCvPercent7  ?? 0)
        rolling14dCVPercent = max(0, healthStore.rollingGlucoseCvPercent14 ?? 0)
        rolling30dCVPercent = max(0, healthStore.rollingGlucoseCvPercent30 ?? 0)
        rolling90dCVPercent = max(0, healthStore.rollingGlucoseCvPercent90 ?? 0)

        currentCVPercent = rolling7dCVPercent
        last90dCVPercent = rolling90dCVPercent

        glucoseReadAuthIssueV1 = healthStore.glucoseReadAuthIssueV1
        todayCoverageMinutes = max(0, healthStore.todayGlucoseCoverageMinutes)
    }

    // ============================================================
    // MARK: - Goldstandard Hint State
    // ============================================================

    var todayInfoState: GlucoseCVInfoState? { // 🟨 NEW

        if glucoseReadAuthIssueV1 {
            return .noHistory
        }

        if todayCoverageMinutes > 0 { return nil }

        let hasAnyHistory =
            rolling90dCVPercent > 0 ||
            last90DaysDaily.contains { max(0, $0.coefficientOfVariationPercent) > 0 }

        if !hasAnyHistory {
            return .noHistory
        }

        return .noTodayData
    }

    // ============================================================
    // MARK: - KPI Formatting (Whole numbers)
    // ============================================================

    var formattedLast24hCVWhole: String {
        guard last24hCVPercent > 0 else { return "–" }
        return "\(Int(last24hCVPercent.rounded()))"
    }

    var formattedCurrentCVWhole: String {
        guard currentCVPercent > 0 else { return "–" }
        return "\(Int(currentCVPercent.rounded()))"
    }

    var formatted90dCVWhole: String {
        guard last90dCVPercent > 0 else { return "–" }
        return "\(Int(last90dCVPercent.rounded()))"
    }

    // ============================================================
    // MARK: - Report Access (Dexcom-like Rolling)
    // ============================================================

    func cvTextForReport(windowDays: Int) -> String {
        let v: Double
        switch windowDays {
        case 7:  v = rolling7dCVPercent
        case 14: v = rolling14dCVPercent
        case 30: v = rolling30dCVPercent
        case 90: v = rolling90dCVPercent
        default: return "–"
        }
        return formatOneDecimalNumberOnly(v)
    }

    private func formatOneDecimalNumberOnly(_ value: Double) -> String {
        guard value > 0 else { return "–" }
        return String(format: "%.1f", value)
    }

    // ============================================================
    // MARK: - Chart Adapter (Daily)
    // ============================================================

    var last90DaysChartData: [DailyStepsEntry] {
        last90DaysDaily.map { e in
            let v = max(0, e.coefficientOfVariationPercent)
            return DailyStepsEntry(date: e.date, steps: Int(v.rounded()))
        }
    }

    // ============================================================
    // MARK: - Period Averages (Dexcom-like Rolling)
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: L10n.Common.period7d,  days: 7,  value: Int(rolling7dCVPercent.rounded())),
            .init(label: L10n.Common.period14d, days: 14, value: Int(rolling14dCVPercent.rounded())),
            .init(label: L10n.Common.period30d, days: 30, value: Int(rolling30dCVPercent.rounded())),
            .init(label: L10n.Common.period90d, days: 90, value: Int(rolling90dCVPercent.rounded()))
        ]
    }

    // ============================================================
    // MARK: - Scales (Daily vs Period)
    // ============================================================

    var dailyScale: MetricScaleResult {
        let values = last90DaysDaily.map { max(0, $0.coefficientOfVariationPercent) }
        return MetricScaleHelper.scale(values, for: .glucoseCvPercent)
    }

    var periodScale: MetricScaleResult {
        let values = [
            rolling7dCVPercent,
            rolling14dCVPercent,
            rolling30dCVPercent,
            rolling90dCVPercent
        ].filter { $0 > 0 }

        return MetricScaleHelper.scale(values.isEmpty ? [0] : values, for: .glucoseCvPercent)
    }
}
