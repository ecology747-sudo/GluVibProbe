//
//  GlucoseSDViewModelV1.swift
//  GluVibProbe
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class GlucoseSDViewModelV1: ObservableObject {

    enum GlucoseSDInfoState { // 🟨 NEW
        case noHistory
        case noTodayData
    }

    @Published var last90DaysDaily: [DailyGlucoseStatsEntry] = []

    @Published var todaySdMgdl: Double = 0
    @Published var last24hSdMgdl: Double = 0

    @Published var rollingSd7dMgdl: Double = 0
    @Published var rollingSd14dMgdl: Double = 0
    @Published var rollingSd30dMgdl: Double = 0
    @Published var rollingSd90dMgdl: Double = 0

    @Published var glucoseReadAuthIssueV1: Bool = false
    @Published private(set) var todayCoverageMinutes: Int = 0

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

        healthStore.$dailyGlucoseStats90
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.last90DaysDaily = $0
                self?.todaySdMgdl = Self.todaySD(from: $0)
            }
            .store(in: &cancellables)

        healthStore.$last24hGlucoseSdMgdl
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.last24hSdMgdl = max(0, value ?? 0)
            }
            .store(in: &cancellables)

        healthStore.$rollingGlucoseSdMgdl7
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.rollingSd7dMgdl = max(0, value ?? 0)
            }
            .store(in: &cancellables)

        healthStore.$rollingGlucoseSdMgdl14
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.rollingSd14dMgdl = max(0, value ?? 0)
            }
            .store(in: &cancellables)

        healthStore.$rollingGlucoseSdMgdl30
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.rollingSd30dMgdl = max(0, value ?? 0)
            }
            .store(in: &cancellables)

        healthStore.$rollingGlucoseSdMgdl90
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.rollingSd90dMgdl = max(0, value ?? 0)
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
        todaySdMgdl = Self.todaySD(from: healthStore.dailyGlucoseStats90)
        last24hSdMgdl = max(0, healthStore.last24hGlucoseSdMgdl ?? 0)

        rollingSd7dMgdl = max(0, healthStore.rollingGlucoseSdMgdl7 ?? 0)
        rollingSd14dMgdl = max(0, healthStore.rollingGlucoseSdMgdl14 ?? 0)
        rollingSd30dMgdl = max(0, healthStore.rollingGlucoseSdMgdl30 ?? 0)
        rollingSd90dMgdl = max(0, healthStore.rollingGlucoseSdMgdl90 ?? 0)

        glucoseReadAuthIssueV1 = healthStore.glucoseReadAuthIssueV1
        todayCoverageMinutes = max(0, healthStore.todayGlucoseCoverageMinutes)
    }

    // ============================================================
    // MARK: - Goldstandard Hint State
    // ============================================================

    var todayInfoState: GlucoseSDInfoState? { // 🟨 NEW

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
    // MARK: - Display Unit Helpers
    // ============================================================

    var sdDisplayUnitText: String {
        settings.glucoseUnit == .mmolL ? "mmol/L" : "mg/dL"
    }

    private func sdDisplayValue(fromMgdl mgdl: Double) -> Double {
        guard mgdl > 0 else { return 0 }
        if settings.glucoseUnit == .mmolL {
            return mgdl / 18.0182
        } else {
            return mgdl
        }
    }

    private func formattedWholeNumberOnly(_ mgdl: Double) -> String {
        guard mgdl > 0 else { return "–" }
        if settings.glucoseUnit == .mmolL {
            let value = sdDisplayValue(fromMgdl: mgdl)
            return String(format: "%.1f", value)
        } else {
            return "\(Int(mgdl.rounded()))"
        }
    }

    private func formattedOneDecimalNumberOnly(_ mgdl: Double) -> String {
        guard mgdl > 0 else { return "–" }
        if settings.glucoseUnit == .mmolL {
            let value = sdDisplayValue(fromMgdl: mgdl)
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.1f", mgdl)
        }
    }

    // ============================================================
    // MARK: - Formatting (legacy, display-ready strings)
    // ============================================================

    var formattedTodaySD: String {
        formatSdWithUnit(sdMgdl: todaySdMgdl)
    }

    var formattedLast24hSD: String {
        formatSdWithUnit(sdMgdl: last24hSdMgdl)
    }

    var formatted90dSD: String {
        let value = rollingSd90dMgdl
        return value > 0 ? formatSdWithUnit(sdMgdl: value) : "–"
    }

    private func formatSdWithUnit(sdMgdl: Double) -> String {
        guard sdMgdl > 0 else { return "–" }
        if settings.glucoseUnit == .mmolL {
            let mmol = sdMgdl / 18.0182
            return String(format: "%.1f mmol/L", mmol)
        } else {
            return "\(Int(sdMgdl.rounded())) mg/dL"
        }
    }

    // ============================================================
    // MARK: - KPI strings (Bolus-style: valueText only)
    // ============================================================

    var formattedTodaySDKPI: String {
        formattedWholeNumberOnly(todaySdMgdl)
    }

    var formattedLast24hSDKPI: String {
        formattedWholeNumberOnly(last24hSdMgdl)
    }

    var formatted90dSDKPI: String {
        formattedWholeNumberOnly(rollingSd90dMgdl)
    }

    // ============================================================
    // MARK: - Report Access (SSoT passthrough)
    // ============================================================

    func sdTextForReport(windowDays: Int) -> String {
        let valueMgdl: Double
        switch windowDays {
        case 7:  valueMgdl = rollingSd7dMgdl
        case 14: valueMgdl = rollingSd14dMgdl
        case 30: valueMgdl = rollingSd30dMgdl
        case 90: valueMgdl = rollingSd90dMgdl
        default: return "–"
        }

        if settings.glucoseUnit == .mmolL {
            return formattedOneDecimalNumberOnly(valueMgdl)
        } else {
            return formattedWholeNumberOnly(valueMgdl)
        }
    }

    // ============================================================
    // MARK: - Chart Adapter (Daily) — ALWAYS mg/dL base
    // ============================================================

    var last90DaysChartData: [DailyStepsEntry] {
        last90DaysDaily.map { entry in
            let valueMgdl = max(0, entry.standardDeviationMgdl)
            return DailyStepsEntry(date: entry.date, steps: Int(valueMgdl.rounded()))
        }
    }

    // ============================================================
    // MARK: - Period Averages — ALWAYS mg/dL base
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: L10n.Common.period7d,  days: 7,  value: Int(rollingSd7dMgdl.rounded())),
            .init(label: L10n.Common.period14d, days: 14, value: Int(rollingSd14dMgdl.rounded())),
            .init(label: L10n.Common.period30d, days: 30, value: Int(rollingSd30dMgdl.rounded())),
            .init(label: L10n.Common.period90d, days: 90, value: Int(rollingSd90dMgdl.rounded()))
        ]
    }

    // ============================================================
    // MARK: - Scales (Daily vs Period)
    // ============================================================

    var dailyScale: MetricScaleResult {
        let values = last90DaysDaily.map { max(0, $0.standardDeviationMgdl) }
        return MetricScaleHelper.scale(values, for: .glucoseSdMgdl)
    }

    var periodScale: MetricScaleResult {
        let values = [
            max(0, rollingSd7dMgdl),
            max(0, rollingSd14dMgdl),
            max(0, rollingSd30dMgdl),
            max(0, rollingSd90dMgdl)
        ].filter { $0 > 0 }

        return MetricScaleHelper.scale(values.isEmpty ? [0] : values, for: .glucoseSdMgdl)
    }

    // ============================================================
    // MARK: - Internals (kept for compatibility / fallback use)
    // ============================================================

    private func averageSDMgdl(last days: Int) -> Double {
        guard !last90DaysDaily.isEmpty else { return 0 }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        guard
            let endDate = cal.date(byAdding: .day, value: -1, to: today),
            let startDate = cal.date(byAdding: .day, value: -days, to: today)
        else { return 0 }

        let filtered = last90DaysDaily.filter { entry in
            let day = cal.startOfDay(for: entry.date)
            let coverage = max(0, entry.coverageMinutes)
            let value = max(0, entry.standardDeviationMgdl)
            return day >= startDate && day <= endDate && coverage > 0 && value > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0.0) { $0 + max(0, $1.standardDeviationMgdl) }
        return sum / Double(filtered.count)
    }

    private static func todaySD(from daily: [DailyGlucoseStatsEntry]) -> Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let entry = daily.first(where: { cal.isDate($0.date, inSameDayAs: today) }) else { return 0 }
        return entry.coverageMinutes > 0 ? max(0, entry.standardDeviationMgdl) : 0
    }
}
