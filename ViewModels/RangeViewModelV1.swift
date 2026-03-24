//
//  RangeViewModelV1.swift
//  GluVibProbe
//
//  V1: Range (Metabolic)
//  - KEIN Fetch im ViewModel
//  - SSoT: HealthStore (dailyRange90 + range*Summary + rollingGlucoseCvPercent*)
//  - RULE: NO parallel CV methods in VM (CV uses Dexcom-like rolling only)
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class RangeViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Info State
    // ============================================================

    enum RangeInfoState { // 🟨 NEW
        case noHistory
        case noTodayData
    }

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    @Published var todayInRangeMinutes: Int = 0
    @Published var todayCoverageMinutes: Int = 0

    @Published var last90DaysDaily: [DailyRangeEntry] = []

    @Published var summary7d: RangePeriodSummaryEntry? = nil
    @Published var summary14d: RangePeriodSummaryEntry? = nil
    @Published var summary30d: RangePeriodSummaryEntry? = nil
    @Published var summary90d: RangePeriodSummaryEntry? = nil

    @Published private(set) var rolling7dCVPercent: Double = 0
    @Published private(set) var rolling14dCVPercent: Double = 0
    @Published private(set) var rolling30dCVPercent: Double = 0
    @Published private(set) var rolling90dCVPercent: Double = 0

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
        syncFromStores()
    }

    // ============================================================
    // MARK: - Bindings (SSoT → ViewModel)
    // ============================================================

    private func bindHealthStore() {

        healthStore.$dailyRange90
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.last90DaysDaily = $0
            }
            .store(in: &cancellables)

        healthStore.$rangeTodaySummary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] summary in
                guard let self else { return }
                self.todayInRangeMinutes = Self.inRangeMinutes(from: summary)
                self.todayCoverageMinutes = max(0, summary?.coverageMinutes ?? 0)
            }
            .store(in: &cancellables)

        healthStore.$range7dSummary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.summary7d = $0 }
            .store(in: &cancellables)

        healthStore.$range14dSummary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.summary14d = $0 }
            .store(in: &cancellables)

        healthStore.$range30dSummary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.summary30d = $0 }
            .store(in: &cancellables)

        healthStore.$range90dSummary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.summary90d = $0 }
            .store(in: &cancellables)

        healthStore.$rollingGlucoseCvPercent7
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.rolling7dCVPercent = max(0, v ?? 0) }
            .store(in: &cancellables)

        healthStore.$rollingGlucoseCvPercent14
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.rolling14dCVPercent = max(0, v ?? 0) }
            .store(in: &cancellables)

        healthStore.$rollingGlucoseCvPercent30
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.rolling30dCVPercent = max(0, v ?? 0) }
            .store(in: &cancellables)

        healthStore.$rollingGlucoseCvPercent90
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.rolling90dCVPercent = max(0, v ?? 0) }
            .store(in: &cancellables)

        healthStore.$glucoseReadAuthIssueV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.glucoseReadAuthIssueV1 = $0
            }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        last90DaysDaily = healthStore.dailyRange90

        todayInRangeMinutes = Self.inRangeMinutes(from: healthStore.rangeTodaySummary)
        todayCoverageMinutes = max(0, healthStore.rangeTodaySummary?.coverageMinutes ?? 0)

        summary7d = healthStore.range7dSummary
        summary14d = healthStore.range14dSummary
        summary30d = healthStore.range30dSummary
        summary90d = healthStore.range90dSummary

        rolling7dCVPercent  = max(0, healthStore.rollingGlucoseCvPercent7  ?? 0)
        rolling14dCVPercent = max(0, healthStore.rollingGlucoseCvPercent14 ?? 0)
        rolling30dCVPercent = max(0, healthStore.rollingGlucoseCvPercent30 ?? 0)
        rolling90dCVPercent = max(0, healthStore.rollingGlucoseCvPercent90 ?? 0)

        glucoseReadAuthIssueV1 = healthStore.glucoseReadAuthIssueV1
    }

    // ============================================================
    // MARK: - Goldstandard Hint State
    // ============================================================

    var todayInfoState: RangeInfoState? { // 🟨 NEW

        if glucoseReadAuthIssueV1 {
            return .noHistory
        }

        if todayCoverageMinutes > 0 { return nil }

        let hasAnyHistory =
            (summary90d?.coverageMinutes ?? 0) > 0 ||
            last90DaysDaily.contains { max(0, $0.inRangeMinutes) > 0 }

        if !hasAnyHistory {
            return .noHistory
        }

        return .noTodayData
    }

    // ============================================================
    // MARK: - Adapter (optional)
    // ============================================================

    var last90DaysChartData: [DailyStepsEntry] {
        last90DaysDaily.map { entry in
            DailyStepsEntry(date: entry.date, steps: max(0, entry.inRangeMinutes))
        }
    }

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: L10n.Common.period7d,  days: 7,  value: averageInRangeMinutes(last: 7)),
            .init(label: L10n.Common.period14d, days: 14, value: averageInRangeMinutes(last: 14)),
            .init(label: L10n.Common.period30d, days: 30, value: averageInRangeMinutes(last: 30)),
            .init(label: L10n.Common.period90d, days: 90, value: averageInRangeMinutes(last: 90))
        ]
    }

    private func averageInRangeMinutes(last days: Int) -> Int {
        guard !last90DaysDaily.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard
            let endDate = calendar.date(byAdding: .day, value: -1, to: today),
            let startDate = calendar.date(byAdding: .day, value: -days, to: today)
        else { return 0 }

        let filtered = last90DaysDaily.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            let v = max(0, entry.inRangeMinutes)
            return d >= startDate && d <= endDate && v > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0) { $0 + max(0, $1.inRangeMinutes) }
        return Int((Double(sum) / Double(filtered.count)).rounded())
    }

    // ============================================================
    // MARK: - Period CV (for Range Grid "Period" row)
    // ============================================================

    func periodCVWholeText(last days: Int) -> String {
        let v: Double
        switch days {
        case 7:  v = rolling7dCVPercent
        case 14: v = rolling14dCVPercent
        case 30: v = rolling30dCVPercent
        case 90: v = rolling90dCVPercent
        default: return "–"
        }

        guard v > 0 else { return "–" }
        return "\(Int(v.rounded()))%"
    }

    // ============================================================
    // MARK: - Fixed Scale (optional)
    // ============================================================

    var dailyScale: MetricScaleResult {
        MetricScaleHelper.scale([1440], for: .minutes0to1440)
    }

    var periodScale: MetricScaleResult {
        MetricScaleHelper.scale([1440], for: .minutes0to1440)
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private static func inRangeMinutes(from summary: RangePeriodSummaryEntry?) -> Int {
        guard let summary else { return 0 }
        return max(0, summary.inRangeMinutes)
    }
}
