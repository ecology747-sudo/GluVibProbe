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
    // MARK: - Info State
    // ============================================================

    enum GMIInfoState { // 🟨 NEW
        case noHistory
        case noTodayData
    }

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    @Published var last24hGmiPercent: Double? = nil
    @Published var todayGmiPercent: Double? = nil

    @Published var gmi7dPercent: Double? = nil
    @Published var gmi14dPercent: Double? = nil
    @Published var gmi30dPercent: Double? = nil
    @Published var gmi90dPercent: Double? = nil

    @Published var glucoseReadAuthIssueV1: Bool = false
    @Published private(set) var todayCoverageMinutes: Int = 0

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

        healthStore.$last24hGlucoseMeanMgdl
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mean in
                self?.last24hGmiPercent = Self.computeGmiPercent(fromMeanMgdl: mean)
            }
            .store(in: &cancellables)

        healthStore.$todayGlucoseMeanMgdl
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mean in
                self?.todayGmiPercent = Self.computeGmiPercent(fromMeanMgdl: mean)
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
        todayGmiPercent = Self.computeGmiPercent(fromMeanMgdl: healthStore.todayGlucoseMeanMgdl)

        glucoseReadAuthIssueV1 = healthStore.glucoseReadAuthIssueV1
        todayCoverageMinutes = max(0, healthStore.todayGlucoseCoverageMinutes)

        recomputeHybridPeriods()
    }

    // ============================================================
    // MARK: - Goldstandard Hint State
    // ============================================================

    var todayInfoState: GMIInfoState? { // 🟨 NEW

        if glucoseReadAuthIssueV1 {
            return .noHistory
        }

        if todayCoverageMinutes > 0 { return nil }

        let hasAnyHistory = healthStore.dailyGlucoseStats90.contains { $0.coverageMinutes > 0 }

        if !hasAnyHistory {
            return .noHistory
        }

        return .noTodayData
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
            .init(label: L10n.Common.period7d,  days: 7,  value: percentToInt10(gmi7dPercent)),
            .init(label: L10n.Common.period14d, days: 14, value: percentToInt10(gmi14dPercent)),
            .init(label: L10n.Common.period30d, days: 30, value: percentToInt10(gmi30dPercent)),
            .init(label: L10n.Common.period90d, days: 90, value: percentToInt10(gmi90dPercent))
        ]
    }

    // ============================================================
    // MARK: - HYBRID compute (SSoT)
    // ============================================================

    private func recomputeHybridPeriods() {
        let mean7 = computeHybridMeanMgdl(days: 7)
        let mean14 = computeHybridMeanMgdl(days: 14)
        let mean30 = computeHybridMeanMgdl(days: 30)
        let mean90 = computeHybridMeanMgdl(days: 90)

        gmi7dPercent = Self.computeGmiPercent(fromMeanMgdl: mean7)
        gmi14dPercent = Self.computeGmiPercent(fromMeanMgdl: mean14)
        gmi30dPercent = Self.computeGmiPercent(fromMeanMgdl: mean30)
        gmi90dPercent = Self.computeGmiPercent(fromMeanMgdl: mean90)
    }

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

        for entry in pastEntries {
            let coverage = max(0, entry.coverageMinutes)
            guard coverage > 0, entry.meanMgdl > 0 else { continue }
            weightedSum += entry.meanMgdl * Double(coverage)
            coverageSum += coverage
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

    private static func computeGmiPercent(fromMeanMgdl mean: Double?) -> Double? {
        guard let mean, mean > 0 else { return nil }
        return 3.31 + (0.02392 * mean)
    }
}
