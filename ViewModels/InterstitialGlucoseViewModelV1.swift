//
//  InterstitialGlucoseViewModelV1.swift
//  GluVibProbe
//
//  Interstitial Glucose (Metabolic) — ViewModel (V1)
//
//  SSoT-only (Daily 90):
//  - Chart-Daten aus dailyGlucoseStats90 (mean mg/dL)
//  - Perioden 7/14/30/90 aus dailyGlucoseStats90 (kein HYBRID)
//
//  Keine Fetches, keine HealthKit-Queries
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class InterstitialGlucoseViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    @Published var todayMeanMgdl: Int = 0
    @Published var last90DaysDaily: [DailyGlucoseStatsEntry] = []

    @Published private(set) var ig24hMeanMgdl: Int = 0              // !!! NEW
    @Published private(set) var ig7dMeanMgdl: Int = 0
    @Published private(set) var ig14dMeanMgdl: Int = 0
    @Published private(set) var ig30dMeanMgdl: Int = 0
    @Published private(set) var ig90dMeanMgdl: Int = 0

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
        healthStore.$dailyGlucoseStats90
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                guard let self else { return }
                self.last90DaysDaily = entries
                self.recomputeFromDaily(entries)
            }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        last90DaysDaily = healthStore.dailyGlucoseStats90
        recomputeFromDaily(last90DaysDaily)
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var formattedTodayIG: String {
        todayMeanMgdl > 0 ? "\(todayMeanMgdl)" : "–"
    }

    var formattedIG24h: String { ig24hMeanMgdl > 0 ? "\(ig24hMeanMgdl)" : "–" }   // !!! NEW

    var formattedIG7d: String { ig7dMeanMgdl > 0 ? "\(ig7dMeanMgdl)" : "–" }
    var formattedIG14d: String { ig14dMeanMgdl > 0 ? "\(ig14dMeanMgdl)" : "–" }
    var formattedIG30d: String { ig30dMeanMgdl > 0 ? "\(ig30dMeanMgdl)" : "–" }
    var formattedIG90d: String { ig90dMeanMgdl > 0 ? "\(ig90dMeanMgdl)" : "–" }

    // ============================================================
    // MARK: - Adapter: DailyGlucoseStatsEntry → DailyStepsEntry (Chart expects Int)
    // ============================================================

    var last90DaysChartData: [DailyStepsEntry] {
        last90DaysDaily.map { e in
            DailyStepsEntry(
                date: e.date,
                steps: Int(max(0, e.meanMgdl).rounded())
            )
        }
    }

    // ============================================================
    // MARK: - Period Averages (7/14/30/90) — Daily-based (Int mg/dL)
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",  days: 7,  value: ig7dMeanMgdl),
            .init(label: "14T", days: 14, value: ig14dMeanMgdl),
            .init(label: "30T", days: 30, value: ig30dMeanMgdl),
            .init(label: "90T", days: 90, value: ig90dMeanMgdl)
        ]
    }

    // ============================================================
    // MARK: - Chart Scales (mg/dL base)
    // ============================================================

    var dailyScale: MetricScaleResult {
        let vals = last90DaysDaily.map { max(0, $0.meanMgdl) }
        return MetricScaleHelper.scale(vals, for: .glucoseMeanMgdl)
    }

    var periodScale: MetricScaleResult {
        let vals: [Double] = [
            Double(ig24hMeanMgdl),                                    // !!! NEW
            Double(ig7dMeanMgdl),
            Double(ig14dMeanMgdl),
            Double(ig30dMeanMgdl),
            Double(ig90dMeanMgdl)
        ]
        return MetricScaleHelper.scale(vals, for: .glucoseMeanMgdl)
    }

    // ============================================================
    // MARK: - Internals
    // ============================================================

    private func recomputeFromDaily(_ entries: [DailyGlucoseStatsEntry]) {
        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart)!   // !!! NEW

        // Today KPI: today entry if present + has coverage
        if let todayEntry = entries.last(where: { cal.isDate($0.date, inSameDayAs: todayStart) || cal.isDate($0.date, inSameDayAs: now) }) {
            todayMeanMgdl = todayEntry.coverageMinutes > 0 ? Int(max(0, todayEntry.meanMgdl).rounded()) : 0
        } else {
            todayMeanMgdl = 0
        }

        // Last 24h KPI (Daily-based approximation):
        // = weighted mean of yesterday (full) + today (partial), using coverageMinutes as weights.   // !!! NEW
        let todayDaily = entries.first(where: { cal.isDate($0.date, inSameDayAs: todayStart) && $0.coverageMinutes > 0 })
        let yesterdayDaily = entries.first(where: { cal.isDate($0.date, inSameDayAs: yesterdayStart) && $0.coverageMinutes > 0 })

        ig24hMeanMgdl = Self.weightedMeanMgdl(today: todayDaily, yesterday: yesterdayDaily)          // !!! NEW

        // Period averages: FULL days only (exclude today), coverage>0
        let fullDays = entries
            .filter { $0.coverageMinutes > 0 }
            .filter { cal.startOfDay(for: $0.date) < todayStart }
            .sorted { $0.date < $1.date }

        ig7dMeanMgdl  = Self.meanOfLast(days: 7,  in: fullDays)
        ig14dMeanMgdl = Self.meanOfLast(days: 14, in: fullDays)
        ig30dMeanMgdl = Self.meanOfLast(days: 30, in: fullDays)
        ig90dMeanMgdl = Self.meanOfLast(days: 90, in: fullDays)
    }

    private static func weightedMeanMgdl(
        today: DailyGlucoseStatsEntry?,
        yesterday: DailyGlucoseStatsEntry?
    ) -> Int {
        let tCov = max(0, today?.coverageMinutes ?? 0)
        let yCov = max(0, yesterday?.coverageMinutes ?? 0)
        let denom = tCov + yCov
        guard denom > 0 else { return 0 }

        let tMean = max(0, today?.meanMgdl ?? 0)
        let yMean = max(0, yesterday?.meanMgdl ?? 0)

        let sum = (tMean * Double(tCov)) + (yMean * Double(yCov))
        let mean = sum / Double(denom)

        return max(0, Int(mean.rounded()))
    }

    private static func meanOfLast(days: Int, in entries: [DailyGlucoseStatsEntry]) -> Int {
        guard days > 0 else { return 0 }
        let slice = entries.suffix(days)
        guard !slice.isEmpty else { return 0 }

        let values = slice.map { max(0, $0.meanMgdl) }
        let sum = values.reduce(0.0, +)
        let mean = sum / Double(values.count)

        let out = Int(mean.rounded())
        return max(0, out)
    }
}
