//
//  HealthStore+FatV1.swift
//  GluVibProbe
//
//  Domain: Nutrition / Fat
//  Screen Type: HealthStore Metric Extension V1
//
//  Purpose
//  - Owns the read-only Apple Health fat fetch pipeline for Fat V1.
//  - Resolves read-auth issues via deterministic permission-only probe logic.
//  - Publishes today, last-90-days, monthly and 365-day fat data into HealthStore.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT Published Fat Values) → ViewModels → Views
//
//  Key Connections
//  - FatViewModelV1
//  - NutritionOverviewViewModelV1
//
//  Important
//  - fatReadAuthIssueV1 is set EXCLUSIVELY by probeFatReadAuthIssueV1Async().
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

    private func _isReadAuthIssueV1(_ error: Error?) -> Bool {
        guard let ns = error as NSError? else { return false }
        guard ns.domain == HKErrorDomain else { return false }
        guard let code = HKError.Code(rawValue: ns.code) else { return false }
        return code == .errorAuthorizationDenied || code == .errorAuthorizationNotDetermined
    }

    // 🟨 UPDATED
    private func _resolveReadAuthIssueV1(
        error: Error?
    ) -> Bool {
        _isReadAuthIssueV1(error)
    }

    // ============================================================
    // MARK: - Deterministic Read-Query Probe (Single-Writer)
    // ============================================================

    @MainActor
    func probeFatReadAuthIssueV1Async() async -> Bool {
        if isPreview {
            fatReadAuthIssueV1 = false
            GluLog.fat.debug("fat probe skipped | preview=true")
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = FatProbeGateV1.cachedResultIfFresh(for: key) {
            fatReadAuthIssueV1 = cached
            GluLog.fat.debug("fat probe cache hit | authIssue=\(cached, privacy: .public)")
            return cached
        }

        if let inFlight = FatProbeGateV1.inFlightTask(for: key) {
            let v = await inFlight.value
            fatReadAuthIssueV1 = v
            GluLog.fat.debug("fat probe joined inFlight | authIssue=\(v, privacy: .public)")
            return v
        }

        GluLog.fat.notice("fat probe started")

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) else {
                GluLog.fat.error("fat probe failed | quantityTypeUnavailable=true")
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
                    let resolved = self._resolveReadAuthIssueV1(error: error)
                    continuation.resume(returning: resolved)
                }

                self.healthStore.execute(query)
            }

            return isAuthIssue
        }

        FatProbeGateV1.setInFlight(task, for: key)
        let result = await task.value
        FatProbeGateV1.finish(with: result, for: key)

        fatReadAuthIssueV1 = result
        GluLog.fat.notice("fat probe finished | authIssue=\(result, privacy: .public)")
        return result
    }

    // ============================================================
    // MARK: - Public API (Today / 90d / Monthly / 365)
    // ============================================================

    @MainActor
    func fetchFatTodayV1() {
        if isPreview {
            fatReadAuthIssueV1 = false
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let value = previewDailyFat
                .first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
                .grams ?? 0
            todayFatGrams = max(0, value)
            GluLog.fat.debug("fetchFatTodayV1 preview applied | todayFat=\(self.todayFatGrams, privacy: .public)")
            return
        }

        GluLog.fat.notice("fetchFatTodayV1 started")

        Task { @MainActor in
            let authIssue = await probeFatReadAuthIssueV1Async()
            if authIssue {
                todayFatGrams = 0
                GluLog.fat.notice("fetchFatTodayV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) else {
                GluLog.fat.error("fetchFatTodayV1 failed | quantityTypeUnavailable=true")
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
                    if self.fatReadAuthIssueV1 {
                        self.todayFatGrams = 0
                        GluLog.fat.notice("fetchFatTodayV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.todayFatGrams = max(0, Int(value.rounded()))
                    GluLog.fat.notice("fetchFatTodayV1 finished | todayFat=\(self.todayFatGrams, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchLast90DaysFatV1() {
        if isPreview {
            fatReadAuthIssueV1 = false
            let slice = Array(previewDailyFat.suffix(90)).sorted { $0.date < $1.date }
            last90DaysFat = slice
            GluLog.fat.debug("fetchLast90DaysFatV1 preview applied | entries=\(slice.count, privacy: .public)")
            return
        }

        GluLog.fat.notice("fetchLast90DaysFatV1 started")

        Task { @MainActor in
            let authIssue = await probeFatReadAuthIssueV1Async()
            if authIssue {
                last90DaysFat = []
                GluLog.fat.notice("fetchLast90DaysFatV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) else {
                GluLog.fat.error("fetchLast90DaysFatV1 failed | quantityTypeUnavailable=true")
                return
            }

            fetchDailySeriesFatV1(
                quantityType: type,
                unit: .gram(),
                days: 90
            ) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.fatReadAuthIssueV1 {
                        self.last90DaysFat = []
                        GluLog.fat.notice("fetchLast90DaysFatV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.last90DaysFat = entries
                    GluLog.fat.notice("fetchLast90DaysFatV1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }

    @MainActor
    func fetchMonthlyFatV1() {
        if isPreview {
            fatReadAuthIssueV1 = false
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var bucket: [DateComponents: Int] = [:]
            for e in previewDailyFat where e.date >= startDate && e.date <= startOfToday {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                bucket[comps, default: 0] += max(0, e.grams)
            }

            let keys = bucket.keys.sorted {
                (calendar.date(from: $0) ?? .distantPast) < (calendar.date(from: $1) ?? .distantPast)
            }

            let result: [MonthlyMetricEntry] = keys.map { comps in
                let d = calendar.date(from: comps) ?? Date()
                return MonthlyMetricEntry(
                    monthShort: d.formatted(.dateTime.month(.abbreviated)),
                    value: bucket[comps] ?? 0
                )
            }

            monthlyFat = result
            GluLog.fat.debug("fetchMonthlyFatV1 preview applied | entries=\(result.count, privacy: .public)")
            return
        }

        GluLog.fat.notice("fetchMonthlyFatV1 started")

        Task { @MainActor in
            let authIssue = await probeFatReadAuthIssueV1Async()
            if authIssue {
                monthlyFat = []
                GluLog.fat.notice("fetchMonthlyFatV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) else {
                GluLog.fat.error("fetchMonthlyFatV1 failed | quantityTypeUnavailable=true")
                return
            }

            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else {
                GluLog.fat.error("fetchMonthlyFatV1 failed | startDateUnavailable=true")
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

                if self.fatReadAuthIssueV1 {
                    DispatchQueue.main.async { self.monthlyFat = [] }
                    GluLog.fat.notice("fetchMonthlyFatV1 finished | blockedByAuthIssue=true")
                    return
                }

                guard let results else {
                    DispatchQueue.main.async { self.monthlyFat = [] }
                    GluLog.fat.notice("fetchMonthlyFatV1 finished | resultsEmpty=true")
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
                    if self.fatReadAuthIssueV1 {
                        self.monthlyFat = []
                        GluLog.fat.notice("fetchMonthlyFatV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.monthlyFat = temp
                    GluLog.fat.notice("fetchMonthlyFatV1 finished | entries=\(temp.count, privacy: .public)")
                }
            }

            self.healthStore.execute(query)
        }
    }

    @MainActor
    func fetchFatDaily365V1() {
        if isPreview {
            fatReadAuthIssueV1 = false
            let slice = Array(previewDailyFat.suffix(365)).sorted { $0.date < $1.date }
            fatDaily365 = slice
            GluLog.fat.debug("fetchFatDaily365V1 preview applied | entries=\(slice.count, privacy: .public)")
            return
        }

        GluLog.fat.notice("fetchFatDaily365V1 started")

        Task { @MainActor in
            let authIssue = await probeFatReadAuthIssueV1Async()
            if authIssue {
                fatDaily365 = []
                GluLog.fat.notice("fetchFatDaily365V1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) else {
                GluLog.fat.error("fetchFatDaily365V1 failed | quantityTypeUnavailable=true")
                return
            }

            fetchDailySeriesFatV1(
                quantityType: type,
                unit: .gram(),
                days: 365
            ) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.fatReadAuthIssueV1 {
                        self.fatDaily365 = []
                        GluLog.fat.notice("fetchFatDaily365V1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.fatDaily365 = entries
                    GluLog.fat.notice("fetchFatDaily365V1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }
}

// ============================================================
// MARK: - Private Helpers
// ============================================================

private extension HealthStore {

    func fetchDailySeriesFatV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyFatEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            DispatchQueue.main.async { assign([]) }
            GluLog.fat.error("fetchDailySeriesFatV1 failed | startDateUnavailable=true")
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

            if self.fatReadAuthIssueV1 {
                DispatchQueue.main.async { assign([]) }
                GluLog.fat.notice("fetchDailySeriesFatV1 finished | blockedByAuthIssue=true")
                return
            }

            guard let results else {
                DispatchQueue.main.async { assign([]) }
                GluLog.fat.notice("fetchDailySeriesFatV1 finished | resultsEmpty=true")
                return
            }

            var daily: [DailyFatEntry] = []
            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                daily.append(
                    DailyFatEntry(
                        date: stats.startDate,
                        grams: max(0, Int(value.rounded()))
                    )
                )
            }

            let result = daily.sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                if self.fatReadAuthIssueV1 {
                    assign([])
                    GluLog.fat.notice("fetchDailySeriesFatV1 finished | blockedByAuthIssue=true")
                    return
                }
                assign(result)
                GluLog.fat.debug("fetchDailySeriesFatV1 finished | entries=\(result.count, privacy: .public)")
            }
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - File-local Probe Gate
// ============================================================

private enum FatProbeGateV1 {

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
