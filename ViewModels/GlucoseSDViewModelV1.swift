//
//  GlucoseSDViewModelV1.swift
//  GluVibProbe
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class GlucoseSDViewModelV1: ObservableObject {

    @Published var last90DaysDaily: [DailyGlucoseStatsEntry] = []

    @Published var todaySdMgdl: Double = 0
    @Published var last24hSdMgdl: Double = 0

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
            .sink { [weak self] v in
                self?.last24hSdMgdl = max(0, v ?? 0)
            }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        last90DaysDaily = healthStore.dailyGlucoseStats90
        todaySdMgdl = Self.todaySD(from: healthStore.dailyGlucoseStats90)
        last24hSdMgdl = max(0, healthStore.last24hGlucoseSdMgdl ?? 0)
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
            let v = sdDisplayValue(fromMgdl: mgdl)
            return String(format: "%.1f", v)
        } else {
            return "\(Int(mgdl.rounded()))"
        }
    }

    private func formattedOneDecimalNumberOnly(_ mgdl: Double) -> String {
        guard mgdl > 0 else { return "–" }
        if settings.glucoseUnit == .mmolL {
            let v = sdDisplayValue(fromMgdl: mgdl)
            return String(format: "%.1f", v)
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
        let v = averageSDMgdl(last: 90)
        return v > 0 ? formatSdWithUnit(sdMgdl: v) : "–"
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
        let v = averageSDMgdl(last: 90)
        return formattedWholeNumberOnly(v)
    }

    // ============================================================
    // MARK: - Report Access (SSoT passthrough)  // UPDATED
    // ============================================================

    /// Report expects a numeric SD text WITHOUT unit (unit is rendered in ReportRangeSectionView via sdDisplayUnitText / layout rules).
    /// - If mmol/L: 1 decimal
    /// - If mg/dL: whole number
    func sdTextForReport(windowDays: Int) -> String { // UPDATED
        let vMgdl: Double
        switch windowDays {
        case 7:  vMgdl = averageSDMgdl(last: 7)
        case 14: vMgdl = averageSDMgdl(last: 14)
        case 30: vMgdl = averageSDMgdl(last: 30)
        case 90: vMgdl = averageSDMgdl(last: 90)
        default: return "–"
        }

        if settings.glucoseUnit == .mmolL {
            return formattedOneDecimalNumberOnly(vMgdl) // UPDATED
        } else {
            return formattedWholeNumberOnly(vMgdl) // UPDATED
        }
    }

    // ============================================================
    // MARK: - Chart Adapter (Daily) — ALWAYS mg/dL base
    // ============================================================

    var last90DaysChartData: [DailyStepsEntry] {
        last90DaysDaily.map { e in
            let vMgdl = max(0, e.standardDeviationMgdl)
            return DailyStepsEntry(date: e.date, steps: Int(vMgdl.rounded()))
        }
    }

    // ============================================================
    // MARK: - Period Averages — ALWAYS mg/dL base
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",  days: 7,  value: Int(averageSDMgdl(last: 7).rounded())),
            .init(label: "14T", days: 14, value: Int(averageSDMgdl(last: 14).rounded())),
            .init(label: "30T", days: 30, value: Int(averageSDMgdl(last: 30).rounded())),
            .init(label: "90T", days: 90, value: Int(averageSDMgdl(last: 90).rounded()))
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
        let values = periodAverages.map { Double(max(0, $0.value)) }.filter { $0 > 0 }
        return MetricScaleHelper.scale(values.isEmpty ? [0] : values, for: .glucoseSdMgdl)
    }

    // ============================================================
    // MARK: - Internals
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
            let d = cal.startOfDay(for: entry.date)
            let cov = max(0, entry.coverageMinutes)
            let v = max(0, entry.standardDeviationMgdl)
            return d >= startDate && d <= endDate && cov > 0 && v > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0.0) { $0 + max(0, $1.standardDeviationMgdl) }
        return sum / Double(filtered.count)
    }

    private static func todaySD(from daily: [DailyGlucoseStatsEntry]) -> Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let e = daily.first(where: { cal.isDate($0.date, inSameDayAs: today) }) else { return 0 }
        return e.coverageMinutes > 0 ? max(0, e.standardDeviationMgdl) : 0
    }
}
