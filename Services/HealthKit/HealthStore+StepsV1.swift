//
//  HealthStore+StepsV1.swift
//  GluVibProbe
//
//  Domain: Activity / Steps
//  Screen Type: HealthStore Metric Extension V1
//
//  Purpose
//  - Owns the read-only Apple Health steps fetch pipeline for Steps V1.
//  - Resolves read-auth issues via deterministic permission-only probe logic.
//  - Publishes today, last-90-days, monthly and 365-day step data into HealthStore.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT Published Steps Values) → ViewModels → Views
//
//  Key Connections
//  - StepsViewModelV1
//  - ActivityOverviewViewModelV1
//
//  Important
//  - stepsReadAuthIssueV1 is set EXCLUSIVELY by probeStepsReadAuthIssueV1Async().
//  - Probe is permission-only: empty results are DATA state, never permission state.
//  - All fetches are DATA ONLY and may be blocked only by a real read-auth issue.
//

import Foundation
import HealthKit
import OSLog

extension HealthStore {

    // ============================================================
    // MARK: - Auth Issue Classification
    // ============================================================

    private func _stepsIsReadAuthIssueV1(_ error: Error?) -> Bool {
        guard let ns = error as NSError? else { return false }
        guard ns.domain == HKErrorDomain else { return false }
        guard let code = HKError.Code(rawValue: ns.code) else { return false }
        return code == .errorAuthorizationDenied || code == .errorAuthorizationNotDetermined
    }

    private func _stepsResolveReadAuthIssueV1(
        error: Error?
    ) -> Bool {
        _stepsIsReadAuthIssueV1(error)
    }

    // ============================================================
    // MARK: - Deterministic Read-Query Probe (Single-Writer)
    // ============================================================

    @MainActor
    func probeStepsReadAuthIssueV1Async() async -> Bool {
        if isPreview {
            stepsReadAuthIssueV1 = false // 🟨 UPDATED
            GluLog.steps.debug("steps probe skipped | preview=true")
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = StepsProbeGateV1.cachedResultIfFresh(for: key) {
            stepsReadAuthIssueV1 = cached
            GluLog.steps.debug("steps probe cache hit | authIssue=\(cached, privacy: .public)")
            return cached
        }

        if let inFlight = StepsProbeGateV1.inFlightTask(for: key) {
            let value = await inFlight.value
            stepsReadAuthIssueV1 = value
            GluLog.steps.debug("steps probe inFlight reused | authIssue=\(value, privacy: .public)")
            return value
        }

        GluLog.steps.debug("steps probe started")

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }

            guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
                return false
            }

            let cal = Calendar.current
            let now = Date()
            let todayStart = cal.startOfDay(for: now)

            let startDate = cal.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let isAuthIssue: Bool = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: 1,
                    sortDescriptors: [sort]
                ) { [weak self] _, _, error in
                    guard let self else {
                        continuation.resume(returning: false)
                        return
                    }

                    let resolved = self._stepsResolveReadAuthIssueV1(error: error)
                    continuation.resume(returning: resolved)
                }

                self.healthStore.execute(query)
            }

            return isAuthIssue
        }

        StepsProbeGateV1.setInFlight(task, for: key)
        let result = await task.value
        StepsProbeGateV1.finish(with: result, for: key)

        stepsReadAuthIssueV1 = result
        GluLog.steps.notice("steps probe finished | authIssue=\(result, privacy: .public)")
        return result
    }

    // ============================================================
    // MARK: - Public API (Today / 90d / Monthly / 365)
    // ============================================================

    @MainActor
    func fetchStepsTodayV1() {
        if isPreview {
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())

            let value = previewDailySteps
                .first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
                .steps ?? 0

            todaySteps = max(0, value)
            GluLog.steps.debug("fetchStepsTodayV1 skipped | preview=true")
            return
        }

        GluLog.steps.debug("fetchStepsTodayV1 started")

        Task { @MainActor in
            let authIssue = await probeStepsReadAuthIssueV1Async()
            if authIssue {
                self.todaySteps = 0
                GluLog.steps.notice("fetchStepsTodayV1 skipped | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
                return
            }

            let start = Calendar.current.startOfDay(for: Date())
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { [weak self] _, result, _ in
                guard let self else { return }

                let value = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0

                DispatchQueue.main.async {
                    if self.stepsReadAuthIssueV1 {
                        self.todaySteps = 0
                        GluLog.steps.notice("fetchStepsTodayV1 finished | blockedByAuthIssue=true")
                        return
                    }

                    self.todaySteps = max(0, Int(value))
                    GluLog.steps.notice("fetchStepsTodayV1 finished | todaySteps=\(self.todaySteps, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchLast90DaysStepsV1() {
        if isPreview {
            last90Days = Array(previewDailySteps.suffix(90)).sorted { $0.date < $1.date }
            GluLog.steps.debug("fetchLast90DaysStepsV1 skipped | preview=true")
            return
        }

        GluLog.steps.debug("fetchLast90DaysStepsV1 started")

        Task { @MainActor in
            let authIssue = await probeStepsReadAuthIssueV1Async()
            if authIssue {
                self.last90Days = []
                GluLog.steps.notice("fetchLast90DaysStepsV1 skipped | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
                return
            }

            fetchDailySeriesStepsV1(
                quantityType: type,
                unit: .count(),
                days: 90
            ) { [weak self] entries in
                guard let self else { return }

                DispatchQueue.main.async {
                    if self.stepsReadAuthIssueV1 {
                        self.last90Days = []
                        GluLog.steps.notice("fetchLast90DaysStepsV1 finished | blockedByAuthIssue=true")
                        return
                    }

                    self.last90Days = entries
                    GluLog.steps.notice("fetchLast90DaysStepsV1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }

    @MainActor
    func fetchMonthlyStepsV1() {
        if isPreview {
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var buckets: [DateComponents: Int] = [:]
            for entry in previewDailySteps where entry.date >= startDate && entry.date <= startOfToday {
                let comps = calendar.dateComponents([.year, .month], from: entry.date)
                buckets[comps, default: 0] += max(0, entry.steps)
            }

            let keys = buckets.keys.sorted {
                (calendar.date(from: $0) ?? .distantPast) < (calendar.date(from: $1) ?? .distantPast)
            }

            monthlySteps = keys.map { comps in
                let d = calendar.date(from: comps) ?? Date()
                return MonthlyMetricEntry(
                    monthShort: d.formatted(.dateTime.month(.abbreviated)),
                    value: buckets[comps] ?? 0
                )
            }

            GluLog.steps.debug("fetchMonthlyStepsV1 skipped | preview=true")
            return
        }

        GluLog.steps.debug("fetchMonthlyStepsV1 started")

        Task { @MainActor in
            let authIssue = await probeStepsReadAuthIssueV1Async()
            if authIssue {
                self.monthlySteps = []
                GluLog.steps.notice("fetchMonthlyStepsV1 skipped | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
                return
            }

            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: startOfToday, options: .strictStartDate)

            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: DateComponents(month: 1)
            )

            query.initialResultsHandler = { [weak self] _, results, _ in
                guard let self else { return }

                if self.stepsReadAuthIssueV1 {
                    DispatchQueue.main.async {
                        self.monthlySteps = []
                        GluLog.steps.notice("fetchMonthlyStepsV1 finished | blockedByAuthIssue=true")
                    }
                    return
                }

                guard let results else {
                    DispatchQueue.main.async {
                        self.monthlySteps = []
                        GluLog.steps.notice("fetchMonthlyStepsV1 finished | entries=0")
                    }
                    return
                }

                var temp: [MonthlyMetricEntry] = []
                results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                    let value = stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    temp.append(
                        MonthlyMetricEntry(
                            monthShort: stats.startDate.formatted(.dateTime.month(.abbreviated)),
                            value: max(0, Int(value))
                        )
                    )
                }

                DispatchQueue.main.async {
                    if self.stepsReadAuthIssueV1 {
                        self.monthlySteps = []
                        GluLog.steps.notice("fetchMonthlyStepsV1 finished | blockedByAuthIssue=true")
                        return
                    }

                    self.monthlySteps = temp
                    GluLog.steps.notice("fetchMonthlyStepsV1 finished | entries=\(temp.count, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchStepsDaily365V1() {
        if isPreview {
            stepsDaily365 = Array(previewDailySteps.suffix(365)).sorted { $0.date < $1.date }
            GluLog.steps.debug("fetchStepsDaily365V1 skipped | preview=true")
            return
        }

        GluLog.steps.debug("fetchStepsDaily365V1 started")

        Task { @MainActor in
            let authIssue = await probeStepsReadAuthIssueV1Async()
            if authIssue {
                self.stepsDaily365 = []
                GluLog.steps.notice("fetchStepsDaily365V1 skipped | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
                return
            }

            fetchDailySeriesStepsV1(
                quantityType: type,
                unit: .count(),
                days: 365
            ) { [weak self] entries in
                guard let self else { return }

                DispatchQueue.main.async {
                    if self.stepsReadAuthIssueV1 {
                        self.stepsDaily365 = []
                        GluLog.steps.notice("fetchStepsDaily365V1 finished | blockedByAuthIssue=true")
                        return
                    }

                    self.stepsDaily365 = entries
                    GluLog.steps.notice("fetchStepsDaily365V1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }
}

// ============================================================
// MARK: - Private Helpers
// ============================================================

private extension HealthStore {

    func fetchDailySeriesStepsV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyStepsEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            DispatchQueue.main.async { assign([]) }
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self else { return }

            if self.stepsReadAuthIssueV1 {
                DispatchQueue.main.async { assign([]) }
                return
            }

            guard let results else {
                DispatchQueue.main.async { assign([]) }
                return
            }

            var daily: [DailyStepsEntry] = []
            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                daily.append(
                    DailyStepsEntry(
                        date: stats.startDate,
                        steps: max(0, Int(value))
                    )
                )
            }

            DispatchQueue.main.async {
                if self.stepsReadAuthIssueV1 {
                    assign([])
                    return
                }

                assign(daily.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - File-local Probe Gate
// ============================================================

private enum StepsProbeGateV1 {

    private static let ttl: TimeInterval = 10

    private static var lastRun: [ObjectIdentifier: Date] = [:]
    private static var lastResult: [ObjectIdentifier: Bool] = [:]
    private static var inFlight: [ObjectIdentifier: Task<Bool, Never>] = [:]

    static func cachedResultIfFresh(for key: ObjectIdentifier) -> Bool? {
        guard let last = lastRun[key], let v = lastResult[key] else { return nil }
        return (Date().timeIntervalSince(last) <= ttl) ? v : nil
    }

    static func inFlightTask(for key: ObjectIdentifier) -> Task<Bool, Never>? {
        inFlight[key]
    }

    static func setInFlight(_ task: Task<Bool, Never>, for key: ObjectIdentifier) {
        inFlight[key] = task
    }

    static func finish(with result: Bool, for key: ObjectIdentifier) {
        inFlight[key] = nil
        lastRun[key] = Date()
        lastResult[key] = result
    }
}
