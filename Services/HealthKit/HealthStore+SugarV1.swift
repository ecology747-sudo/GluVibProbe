//
//  HealthStore+SugarV1.swift
//  GluVibProbe
//
//  Domain: Nutrition / Sugar
//  Screen Type: HealthStore Metric Extension V1
//
//  Purpose
//  - Owns the read-only Apple Health sugar fetch pipeline for Sugar V1.
//  - Resolves read-auth issues via deterministic permission-only probe logic.
//  - Publishes today, last-90-days, monthly and 365-day sugar data into HealthStore.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT Published Sugar Values) → ViewModels → Views
//
//  Key Connections
//  - SugarViewModelV1
//  - NutritionOverviewViewModelV1
//
//  Important
//  - sugarReadAuthIssueV1 is set EXCLUSIVELY by probeSugarReadAuthIssueV1Async().
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

    private func _sugarIsReadAuthIssueV1(_ error: Error?) -> Bool {
        guard let ns = error as NSError? else { return false }
        guard ns.domain == HKErrorDomain else { return false }
        guard let code = HKError.Code(rawValue: ns.code) else { return false }
        return code == .errorAuthorizationDenied || code == .errorAuthorizationNotDetermined
    }

    // 🟨 UPDATED
    private func _sugarResolveReadAuthIssueV1(
        error: Error?
    ) -> Bool {
        _sugarIsReadAuthIssueV1(error)
    }

    // ============================================================
    // MARK: - Deterministic Read-Query Probe (Single-Writer)
    // ============================================================

    @MainActor
    func probeSugarReadAuthIssueV1Async() async -> Bool {
        if isPreview {
            sugarReadAuthIssueV1 = false
            GluLog.sugar.debug("sugar probe skipped | preview=true")
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = SugarProbeGateV1.cachedResultIfFresh(for: key) {
            sugarReadAuthIssueV1 = cached
            GluLog.sugar.debug("sugar probe cache hit | authIssue=\(cached, privacy: .public)")
            return cached
        }

        if let inFlight = SugarProbeGateV1.inFlightTask(for: key) {
            let v = await inFlight.value
            sugarReadAuthIssueV1 = v
            GluLog.sugar.debug("sugar probe joined inFlight | authIssue=\(v, privacy: .public)")
            return v
        }

        GluLog.sugar.notice("sugar probe started")

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietarySugar) else {
                GluLog.sugar.error("sugar probe failed | quantityTypeUnavailable=true")
                return true
            }

            let now = Date()

            // 🟨 UPDATED
            let predicate = HKQuery.predicateForSamples(withStart: nil, end: now, options: [])
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

                    // 🟨 UPDATED
                    let resolved = self._sugarResolveReadAuthIssueV1(error: error)
                    continuation.resume(returning: resolved)
                }

                self.healthStore.execute(query)
            }

            return isAuthIssue
        }

        SugarProbeGateV1.setInFlight(task, for: key)
        let result = await task.value
        SugarProbeGateV1.finish(with: result, for: key)

        sugarReadAuthIssueV1 = result
        GluLog.sugar.notice("sugar probe finished | authIssue=\(result, privacy: .public)")
        return result
    }

    // ============================================================
    // MARK: - Public API (Today / 90d / Monthly / 365)
    // ============================================================

    @MainActor
    func fetchSugarTodayV1() {
        if isPreview {
            sugarReadAuthIssueV1 = false
            todaySugarGrams = 0
            GluLog.sugar.debug("fetchSugarTodayV1 preview applied | todaySugar=\(self.todaySugarGrams, privacy: .public)")
            return
        }

        GluLog.sugar.notice("fetchSugarTodayV1 started")

        Task { @MainActor in
            let authIssue = await probeSugarReadAuthIssueV1Async()
            if authIssue {
                todaySugarGrams = 0
                GluLog.sugar.notice("fetchSugarTodayV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietarySugar) else {
                GluLog.sugar.error("fetchSugarTodayV1 failed | quantityTypeUnavailable=true")
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

                let value = result?.sumQuantity()?.doubleValue(for: .gram()) ?? 0

                DispatchQueue.main.async {
                    if self.sugarReadAuthIssueV1 {
                        self.todaySugarGrams = 0
                        GluLog.sugar.notice("fetchSugarTodayV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.todaySugarGrams = max(0, Int(value.rounded()))
                    GluLog.sugar.notice("fetchSugarTodayV1 finished | todaySugar=\(self.todaySugarGrams, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchLast90DaysSugarV1() {
        if isPreview {
            sugarReadAuthIssueV1 = false
            last90DaysSugar = []
            GluLog.sugar.debug("fetchLast90DaysSugarV1 preview applied | entries=0")
            return
        }

        GluLog.sugar.notice("fetchLast90DaysSugarV1 started")

        Task { @MainActor in
            let authIssue = await probeSugarReadAuthIssueV1Async()
            if authIssue {
                last90DaysSugar = []
                GluLog.sugar.notice("fetchLast90DaysSugarV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietarySugar) else {
                GluLog.sugar.error("fetchLast90DaysSugarV1 failed | quantityTypeUnavailable=true")
                return
            }

            fetchDailySeriesSugarV1(
                quantityType: type,
                unit: .gram(),
                days: 90
            ) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.sugarReadAuthIssueV1 {
                        self.last90DaysSugar = []
                        GluLog.sugar.notice("fetchLast90DaysSugarV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.last90DaysSugar = entries
                    GluLog.sugar.notice("fetchLast90DaysSugarV1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }

    @MainActor
    func fetchMonthlySugarV1() {
        if isPreview {
            sugarReadAuthIssueV1 = false
            monthlySugar = []
            GluLog.sugar.debug("fetchMonthlySugarV1 preview applied | entries=0")
            return
        }

        GluLog.sugar.notice("fetchMonthlySugarV1 started")

        Task { @MainActor in
            let authIssue = await probeSugarReadAuthIssueV1Async()
            if authIssue {
                monthlySugar = []
                GluLog.sugar.notice("fetchMonthlySugarV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietarySugar) else {
                GluLog.sugar.error("fetchMonthlySugarV1 failed | quantityTypeUnavailable=true")
                return
            }

            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else {
                GluLog.sugar.error("fetchMonthlySugarV1 failed | startDateUnavailable=true")
                return
            }

            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: startOfToday, options: .strictStartDate)
            let interval = DateComponents(month: 1)

            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { [weak self] _, results, _ in
                guard let self else { return }

                if self.sugarReadAuthIssueV1 {
                    DispatchQueue.main.async { self.monthlySugar = [] }
                    GluLog.sugar.notice("fetchMonthlySugarV1 finished | blockedByAuthIssue=true")
                    return
                }

                guard let results else {
                    DispatchQueue.main.async { self.monthlySugar = [] }
                    GluLog.sugar.notice("fetchMonthlySugarV1 finished | resultsEmpty=true")
                    return
                }

                var temp: [MonthlyMetricEntry] = []
                results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                    let value = stats.sumQuantity()?.doubleValue(for: .gram()) ?? 0
                    let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))
                    temp.append(
                        MonthlyMetricEntry(
                            monthShort: monthShort,
                            value: max(0, Int(value.rounded()))
                        )
                    )
                }

                DispatchQueue.main.async {
                    if self.sugarReadAuthIssueV1 {
                        self.monthlySugar = []
                        GluLog.sugar.notice("fetchMonthlySugarV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.monthlySugar = temp
                    GluLog.sugar.notice("fetchMonthlySugarV1 finished | entries=\(temp.count, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchSugarDaily365V1() {
        if isPreview {
            sugarReadAuthIssueV1 = false
            sugarDaily365 = []
            GluLog.sugar.debug("fetchSugarDaily365V1 preview applied | entries=0")
            return
        }

        GluLog.sugar.notice("fetchSugarDaily365V1 started")

        Task { @MainActor in
            let authIssue = await probeSugarReadAuthIssueV1Async()
            if authIssue {
                sugarDaily365 = []
                GluLog.sugar.notice("fetchSugarDaily365V1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietarySugar) else {
                GluLog.sugar.error("fetchSugarDaily365V1 failed | quantityTypeUnavailable=true")
                return
            }

            fetchDailySeriesSugarV1(
                quantityType: type,
                unit: .gram(),
                days: 365
            ) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.sugarReadAuthIssueV1 {
                        self.sugarDaily365 = []
                        GluLog.sugar.notice("fetchSugarDaily365V1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.sugarDaily365 = entries
                    GluLog.sugar.notice("fetchSugarDaily365V1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }
}

private extension HealthStore {

    // ============================================================
    // MARK: - Daily Series Helper
    // ============================================================

    func fetchDailySeriesSugarV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailySugarEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            DispatchQueue.main.async { assign([]) }
            GluLog.sugar.error("fetchDailySeriesSugarV1 failed | startDateUnavailable=true")
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let interval = DateComponents(day: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self else { return }

            if self.sugarReadAuthIssueV1 {
                DispatchQueue.main.async { assign([]) }
                GluLog.sugar.notice("fetchDailySeriesSugarV1 finished | blockedByAuthIssue=true")
                return
            }

            guard let results else {
                DispatchQueue.main.async { assign([]) }
                GluLog.sugar.notice("fetchDailySeriesSugarV1 finished | resultsEmpty=true")
                return
            }

            var daily: [DailySugarEntry] = []
            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                daily.append(
                    DailySugarEntry(
                        date: stats.startDate,
                        grams: max(0, Int(value.rounded()))
                    )
                )
            }

            let result = daily.sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                if self.sugarReadAuthIssueV1 {
                    assign([])
                    GluLog.sugar.notice("fetchDailySeriesSugarV1 finished | blockedByAuthIssue=true")
                    return
                }
                assign(result)
                GluLog.sugar.debug("fetchDailySeriesSugarV1 finished | entries=\(result.count, privacy: .public)")
            }
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - File-local Probe Gate
// ============================================================

private enum SugarProbeGateV1 {

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
