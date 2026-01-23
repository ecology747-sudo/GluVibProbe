//
//  GMIViewModelV1.swift
//  GluVibProbe
//
//  Metabolic V1 — GMI ViewModel (HYBRID, read-only)
//
//  Was diese Datei macht (kurz):
//  - GMI für Last24h & Today direkt aus HealthStore-KPI-State (RAW-derived)
//  - GMI für 7/14/30/90 als HYBRID-Mittelwert:
//      (days-1) aus dailyGlucoseStats90 (Tageswerte) + Today aus todayGlucoseMeanMgdl (RAW, 00:00→now)
//  - Kein Fetch im ViewModel, SSoT bleibt HealthStore
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class GMIViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    @Published var last24hGmiPercent: Double? = nil
    @Published var todayGmiPercent: Double? = nil

    @Published var gmi7dPercent: Double? = nil
    @Published var gmi14dPercent: Double? = nil
    @Published var gmi30dPercent: Double? = nil
    @Published var gmi90dPercent: Double? = nil

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    private let healthStore: HealthStore
    private var cancellables = Set<AnyCancellable>()

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore

        bindHealthStore()
        syncFromStores()
    }

    // ============================================================
    // MARK: - Bindings (SSoT → ViewModel)
    // ============================================================

    private func bindHealthStore() {

        // Last 24h (RAW KPI)
        healthStore.$last24hGlucoseMeanMgdl
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mean in
                self?.last24hGmiPercent = Self.computeGmiPercent(fromMeanMgdl: mean)
            }
            .store(in: &cancellables)

        // Today (RAW KPI; 00:00 → now)
        healthStore.$todayGlucoseMeanMgdl
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mean in
                self?.todayGmiPercent = Self.computeGmiPercent(fromMeanMgdl: mean)
            }
            .store(in: &cancellables)

        // HYBRID Periods derive from (dailyGlucoseStats90 + today RAW)
        Publishers.CombineLatest3(
            healthStore.$dailyGlucoseStats90,
            healthStore.$todayGlucoseMeanMgdl,
            healthStore.$todayGlucoseCoverageMinutes
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            guard let self else { return }
            self.recomputeHybridPeriods()
        }
        .store(in: &cancellables)
    }

    private func syncFromStores() {
        last24hGmiPercent = Self.computeGmiPercent(fromMeanMgdl: healthStore.last24hGlucoseMeanMgdl)
        todayGmiPercent   = Self.computeGmiPercent(fromMeanMgdl: healthStore.todayGlucoseMeanMgdl)
        recomputeHybridPeriods()
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var formattedLast24hGMI: String { formatPercent1(last24hGmiPercent) }
    var formattedTodayGMI: String { formatPercent1(todayGmiPercent) }
    var formatted90dGMI: String { formatPercent1(gmi90dPercent) }

    // ============================================================
    // MARK: - Period Averages (for AveragePeriodsScaledBarChart)
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",  days: 7,  value: percentToInt10(gmi7dPercent)),
            .init(label: "14T", days: 14, value: percentToInt10(gmi14dPercent)),
            .init(label: "30T", days: 30, value: percentToInt10(gmi30dPercent)),
            .init(label: "90T", days: 90, value: percentToInt10(gmi90dPercent))
        ]
    }

    // ============================================================
    // MARK: - HYBRID compute (SSoT)
    // ============================================================

    private func recomputeHybridPeriods() {
        let mean7  = computeHybridMeanMgdl(days: 7)
        let mean14 = computeHybridMeanMgdl(days: 14)
        let mean30 = computeHybridMeanMgdl(days: 30)
        let mean90 = computeHybridMeanMgdl(days: 90)

        gmi7dPercent  = Self.computeGmiPercent(fromMeanMgdl: mean7)
        gmi14dPercent = Self.computeGmiPercent(fromMeanMgdl: mean14)
        gmi30dPercent = Self.computeGmiPercent(fromMeanMgdl: mean30)
        gmi90dPercent = Self.computeGmiPercent(fromMeanMgdl: mean90)
    }

    /// HYBRID mean mg/dL:
    /// - (days-1) full days from dailyGlucoseStats90 (coverage-weighted mean)
    /// - + today (00:00→now) from todayGlucoseMeanMgdl * todayCoverage
    private func computeHybridMeanMgdl(days: Int) -> Double? {
        guard days >= 1 else { return nil }

        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)

        let pastDays = max(0, days - 1)
        let pastStart = cal.date(byAdding: .day, value: -pastDays, to: todayStart) ?? todayStart

        let pastEntries = healthStore.dailyGlucoseStats90
            .filter { $0.date >= pastStart && $0.date < todayStart }
            .sorted { $0.date < $1.date }

        var weightedSum: Double = 0
        var coverageSum: Int = 0

        for e in pastEntries {
            let c = max(0, e.coverageMinutes)
            guard c > 0, e.meanMgdl > 0 else { continue }
            weightedSum += e.meanMgdl * Double(c)
            coverageSum += c
        }

        if let todayMean = healthStore.todayGlucoseMeanMgdl, todayMean > 0 {
            let todayCoverage = max(0, healthStore.todayGlucoseCoverageMinutes)
            if todayCoverage > 0 {
                weightedSum += todayMean * Double(todayCoverage)
                coverageSum += todayCoverage
            }
        }

        guard coverageSum > 0 else { return nil }
        return weightedSum / Double(coverageSum)
    }

    // ============================================================
    // MARK: - Report Access (SSoT passthrough)
    // ============================================================

    /// Exposes the exact same HYBRID mean used for GMI.
    /// Report must call THIS – no own computation.
    func hybridMeanMgdl(days: Int) -> Double? {
        computeHybridMeanMgdl(days: days)
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private func percentToInt10(_ p: Double?) -> Int {
        guard let p, p > 0 else { return 0 }
        return Int((p * 10.0).rounded())
    }

    private func formatPercent1(_ p: Double?) -> String {
        guard let p else { return "–" }
        return "\(formatNumber1(p))%"
    }

    private func formatNumber1(_ value: Double) -> String {
        numberFormatter1.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private let numberFormatter1: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 1
        return f
    }()

    // Standard: GMI% = 3.31 + 0.02392 * mean(mg/dL)
    private static func computeGmiPercent(fromMeanMgdl mean: Double?) -> Double? {
        guard let mean, mean > 0 else { return nil }
        return 3.31 + (0.02392 * mean)
    }
}
