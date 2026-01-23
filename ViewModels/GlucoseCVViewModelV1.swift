//
//  GlucoseCVViewModelV1.swift
//  GluVibProbe
//
//  V1: Glucose CV (Metabolic)
//  - KEIN Fetch im ViewModel
//  - SSoT: HealthStore (dailyGlucoseStats90 + last24hGlucoseCvPercent)
//  - Averages: ignorieren Tage ohne Coverage (coverageMinutes == 0)
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class GlucoseCVViewModelV1: ObservableObject {

    @Published var last90DaysDaily: [DailyGlucoseStatsEntry] = []

    @Published var todayCVPercent: Double = 0
    @Published var last24hCVPercent: Double = 0

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
                self?.todayCVPercent = Self.todayCV(from: $0)
            }
            .store(in: &cancellables)

        healthStore.$last24hGlucoseCvPercent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in
                self?.last24hCVPercent = max(0, v ?? 0)
            }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        last90DaysDaily = healthStore.dailyGlucoseStats90
        todayCVPercent = Self.todayCV(from: healthStore.dailyGlucoseStats90)
        last24hCVPercent = max(0, healthStore.last24hGlucoseCvPercent ?? 0)
    }

    // ============================================================
    // MARK: - Formatting
    // ============================================================

    var formattedTodayCV: String {
        todayCVPercent > 0 ? String(format: "%.1f%%", todayCVPercent) : "–"
    }

    var formattedLast24hCV: String {
        last24hCVPercent > 0 ? String(format: "%.1f%%", last24hCVPercent) : "–"
    }

    var formatted90dCV: String {
        let v = averageCVPercent(last: 90)
        return v > 0 ? String(format: "%.1f%%", v) : "–"
    }

    // !!! NEW: Whole-number KPI strings (View stays slim like Bolus)
    var formattedTodayCVWhole: String {
        guard todayCVPercent > 0 else { return "–" }
        return "\(Int(todayCVPercent.rounded()))"
    }

    var formattedLast24hCVWhole: String {
        guard last24hCVPercent > 0 else { return "–" }
        return "\(Int(last24hCVPercent.rounded()))"
    }

    var formatted90dCVWhole: String {
        let v = averageCVPercent(last: 90)
        guard v > 0 else { return "–" }
        return "\(Int(v.rounded()))"
    }

    // ============================================================
    // MARK: - Report Access (SSoT passthrough)  // UPDATED
    // ============================================================

    /// Report expects a pure numeric CV text WITHOUT '%' (unit is rendered in ReportRangeSectionView).
    func cvTextForReport(windowDays: Int) -> String { // UPDATED
        let v: Double
        switch windowDays {
        case 7:  v = averageCVPercent(last: 7)
        case 14: v = averageCVPercent(last: 14)
        case 30: v = averageCVPercent(last: 30)
        case 90: v = averageCVPercent(last: 90)
        default: return "–"
        }
        return formatOneDecimalNumberOnly(v) // UPDATED
    }

    private func formatOneDecimalNumberOnly(_ value: Double) -> String { // UPDATED
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
    // MARK: - Period Averages (7/14/30/90)
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",  days: 7,  value: Int(averageCVPercent(last: 7).rounded())),
            .init(label: "14T", days: 14, value: Int(averageCVPercent(last: 14).rounded())),
            .init(label: "30T", days: 30, value: Int(averageCVPercent(last: 30).rounded())),
            .init(label: "90T", days: 90, value: Int(averageCVPercent(last: 90).rounded()))
        ]
    }

    // ============================================================
    // MARK: - Scales (Daily vs Period)  // !!! NEW
    // ============================================================

    var dailyScale: MetricScaleResult {
        let values = last90DaysDaily.map { max(0, $0.coefficientOfVariationPercent) }
        return MetricScaleHelper.scale(values, for: .glucoseCvPercent)
    }

    var periodScale: MetricScaleResult {
        let values = periodAverages.map { Double(max(0, $0.value)) }.filter { $0 > 0 }
        return MetricScaleHelper.scale(values.isEmpty ? [0] : values, for: .glucoseCvPercent)
    }

    // ============================================================
    // MARK: - Internals
    // ============================================================

    private func averageCVPercent(last days: Int) -> Double {
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
            let v = max(0, entry.coefficientOfVariationPercent)
            return d >= startDate && d <= endDate && cov > 0 && v > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0.0) { $0 + max(0, $1.coefficientOfVariationPercent) }
        return sum / Double(filtered.count)
    }

    private static func todayCV(from daily: [DailyGlucoseStatsEntry]) -> Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let e = daily.first(where: { cal.isDate($0.date, inSameDayAs: today) }) else { return 0 }
        return e.coverageMinutes > 0 ? max(0, e.coefficientOfVariationPercent) : 0
    }
}
