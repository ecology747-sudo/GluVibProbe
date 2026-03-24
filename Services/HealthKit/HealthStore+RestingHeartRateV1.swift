//
//  HealthStore+RestingHeartRateV1.swift
//  GluVibProbe
//
//  Domain: Body / Resting Heart Rate
//  Screen Type: HealthStore Metric Extension V1
//
//  Purpose
//  - Owns the read-only Apple Health resting-heart-rate fetch pipeline for Resting Heart Rate V1.
//  - Resolves read-auth issues via deterministic permission-only probe logic.
//  - Publishes today, last-90-days, monthly and 365-day resting-heart-rate data into HealthStore.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT Published RHR Values) → ViewModels → Views
//
//  Key Connections
//  - BodyOverviewViewModelV1
//  - RestingHeartRateViewModelV1
//
//  Important
//  - restingHeartRateReadAuthIssueV1 is set EXCLUSIVELY by probeRestingHeartRateReadAuthIssueV1Async().
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

    private func _rhrIsReadAuthIssueV1(_ error: Error?) -> Bool {
        guard let ns = error as NSError? else { return false }
        guard ns.domain == HKErrorDomain else { return false }
        guard let code = HKError.Code(rawValue: ns.code) else { return false }
        return code == .errorAuthorizationDenied || code == .errorAuthorizationNotDetermined
    }

    // 🟨 UPDATED
    private func _rhrResolveReadAuthIssueV1(
        error: Error?
    ) -> Bool {
        _rhrIsReadAuthIssueV1(error)
    }

    // ============================================================
    // MARK: - Deterministic Read-Query Probe (Single-Writer)
    // ============================================================

    @MainActor
    func probeRestingHeartRateReadAuthIssueV1Async() async -> Bool {

        if isPreview {
            restingHeartRateReadAuthIssueV1 = false // 🟨 UPDATED
            GluLog.restingHeartRate.debug("rhr probe skipped | preview=true")
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = RestingHRProbeGateV1.cachedResultIfFresh(for: key) {
            restingHeartRateReadAuthIssueV1 = cached
            GluLog.restingHeartRate.debug("rhr probe cache hit | authIssue=\(cached, privacy: .public)")
            return cached
        }

        if let inFlight = RestingHRProbeGateV1.inFlightTask(for: key) {
            let v = await inFlight.value
            restingHeartRateReadAuthIssueV1 = v
            GluLog.restingHeartRate.debug("rhr probe joined inFlight | authIssue=\(v, privacy: .public)")
            return v
        }

        GluLog.restingHeartRate.notice("rhr probe started")

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }

            guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
                GluLog.restingHeartRate.error("rhr probe failed | quantityTypeUnavailable=true")
                return true
            }

            let now = Date()

            // 🟨 UPDATED
            let predicate = HKQuery.predicateForSamples(withStart: nil, end: now, options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

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
                    let resolved = self._rhrResolveReadAuthIssueV1(error: error)
                    continuation.resume(returning: resolved)
                }

                self.healthStore.execute(query)
            }

            return isAuthIssue
        }

        RestingHRProbeGateV1.setInFlight(task, for: key)
        let result = await task.value
        RestingHRProbeGateV1.finish(with: result, for: key)

        restingHeartRateReadAuthIssueV1 = result
        GluLog.restingHeartRate.notice("rhr probe finished | authIssue=\(result, privacy: .public)")
        return result
    }

    // ============================================================
    // MARK: - Public API (Today / 90d / Monthly / 365)
    // ============================================================

    @MainActor
    func fetchRestingHeartRateTodayV1() {
        if isPreview {
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())

            let value = previewDailyRestingHeartRate
                .last(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
                .restingHeartRate ?? 0

            todayRestingHeartRate = max(0, value)
            GluLog.restingHeartRate.debug("fetchRestingHeartRateTodayV1 preview applied | todayRHR=\(self.todayRestingHeartRate, privacy: .public)")
            return
        }

        GluLog.restingHeartRate.notice("fetchRestingHeartRateTodayV1 started")

        Task { @MainActor in
            let authIssue = await probeRestingHeartRateReadAuthIssueV1Async()
            if authIssue {
                todayRestingHeartRate = 0
                GluLog.restingHeartRate.notice("fetchRestingHeartRateTodayV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
                GluLog.restingHeartRate.error("fetchRestingHeartRateTodayV1 failed | quantityTypeUnavailable=true")
                return
            }

            let predicate = HKQuery.predicateForSamples(withStart: nil, end: Date(), options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { [weak self] _, samples, _ in
                guard
                    let self,
                    let sample = samples?.first as? HKQuantitySample
                else {
                    GluLog.restingHeartRate.notice("fetchRestingHeartRateTodayV1 finished | noSample=true")
                    return
                }

                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = sample.quantity.doubleValue(for: unit)

                DispatchQueue.main.async {
                    if self.restingHeartRateReadAuthIssueV1 {
                        self.todayRestingHeartRate = 0
                        GluLog.restingHeartRate.notice("fetchRestingHeartRateTodayV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.todayRestingHeartRate = max(0, Int(round(bpm)))
                    GluLog.restingHeartRate.notice("fetchRestingHeartRateTodayV1 finished | todayRHR=\(self.todayRestingHeartRate, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchLast90DaysRestingHeartRateV1() {
        if isPreview {
            let slice = Array(previewDailyRestingHeartRate.suffix(90)).sorted { $0.date < $1.date }
            last90DaysRestingHeartRate = slice
            GluLog.restingHeartRate.debug("fetchLast90DaysRestingHeartRateV1 preview applied | entries=\(slice.count, privacy: .public)")
            return
        }

        GluLog.restingHeartRate.notice("fetchLast90DaysRestingHeartRateV1 started")

        Task { @MainActor in
            let authIssue = await probeRestingHeartRateReadAuthIssueV1Async()
            if authIssue {
                last90DaysRestingHeartRate = []
                GluLog.restingHeartRate.notice("fetchLast90DaysRestingHeartRateV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
                GluLog.restingHeartRate.error("fetchLast90DaysRestingHeartRateV1 failed | quantityTypeUnavailable=true")
                return
            }

            fetchDailySeriesRestingHRV1(quantityType: type, days: 90) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.restingHeartRateReadAuthIssueV1 {
                        self.last90DaysRestingHeartRate = []
                        GluLog.restingHeartRate.notice("fetchLast90DaysRestingHeartRateV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.last90DaysRestingHeartRate = entries
                    GluLog.restingHeartRate.notice("fetchLast90DaysRestingHeartRateV1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }

    @MainActor
    func fetchMonthlyRestingHeartRateV1() {
        if isPreview {
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var bucket: [DateComponents: (sum: Int, count: Int)] = [:]
            for e in previewDailyRestingHeartRate where e.date >= startDate && e.date <= startOfToday && e.restingHeartRate > 0 {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                var b = bucket[comps] ?? (0, 0)
                b.sum += e.restingHeartRate
                b.count += 1
                bucket[comps] = b
            }

            let keys = bucket.keys.sorted {
                (calendar.date(from: $0) ?? .distantPast) < (calendar.date(from: $1) ?? .distantPast)
            }

            let out: [MonthlyMetricEntry] = keys.map { comps in
                let d = calendar.date(from: comps) ?? Date()
                let b = bucket[comps] ?? (0, 0)
                let avg = b.count > 0 ? Int(round(Double(b.sum) / Double(b.count))) : 0
                return MonthlyMetricEntry(monthShort: d.formatted(.dateTime.month(.abbreviated)), value: max(0, avg))
            }

            monthlyRestingHeartRate = out
            GluLog.restingHeartRate.debug("fetchMonthlyRestingHeartRateV1 preview applied | entries=\(out.count, privacy: .public)")
            return
        }

        GluLog.restingHeartRate.notice("fetchMonthlyRestingHeartRateV1 started")

        Task { @MainActor in
            let authIssue = await probeRestingHeartRateReadAuthIssueV1Async()
            if authIssue {
                monthlyRestingHeartRate = []
                GluLog.restingHeartRate.notice("fetchMonthlyRestingHeartRateV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
                GluLog.restingHeartRate.error("fetchMonthlyRestingHeartRateV1 failed | quantityTypeUnavailable=true")
                return
            }

            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else {
                GluLog.restingHeartRate.error("fetchMonthlyRestingHeartRateV1 failed | startDateUnavailable=true")
                return
            }

            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: startOfToday, options: .strictStartDate)

            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: startDate,
                intervalComponents: DateComponents(month: 1)
            )

            query.initialResultsHandler = { [weak self] _, results, _ in
                guard let self, let results else {
                    GluLog.restingHeartRate.notice("fetchMonthlyRestingHeartRateV1 finished | resultsEmpty=true")
                    return
                }

                if self.restingHeartRateReadAuthIssueV1 {
                    DispatchQueue.main.async { self.monthlyRestingHeartRate = [] }
                    GluLog.restingHeartRate.notice("fetchMonthlyRestingHeartRateV1 finished | blockedByAuthIssue=true")
                    return
                }

                var temp: [MonthlyMetricEntry] = []
                results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                    let unit = HKUnit.count().unitDivided(by: .minute())
                    let bpm = stats.averageQuantity()?.doubleValue(for: unit) ?? 0
                    let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))
                    temp.append(MonthlyMetricEntry(monthShort: monthShort, value: max(0, Int(round(bpm)))))
                }

                DispatchQueue.main.async {
                    if self.restingHeartRateReadAuthIssueV1 {
                        self.monthlyRestingHeartRate = []
                        GluLog.restingHeartRate.notice("fetchMonthlyRestingHeartRateV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.monthlyRestingHeartRate = temp
                    GluLog.restingHeartRate.notice("fetchMonthlyRestingHeartRateV1 finished | entries=\(temp.count, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchRestingHeartRateDaily365V1() {
        if isPreview {
            let slice = Array(previewDailyRestingHeartRate.suffix(365)).sorted { $0.date < $1.date }
            restingHeartRateDaily365 = slice
            GluLog.restingHeartRate.debug("fetchRestingHeartRateDaily365V1 preview applied | entries=\(slice.count, privacy: .public)")
            return
        }

        GluLog.restingHeartRate.notice("fetchRestingHeartRateDaily365V1 started")

        Task { @MainActor in
            let authIssue = await probeRestingHeartRateReadAuthIssueV1Async()
            if authIssue {
                restingHeartRateDaily365 = []
                GluLog.restingHeartRate.notice("fetchRestingHeartRateDaily365V1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
                GluLog.restingHeartRate.error("fetchRestingHeartRateDaily365V1 failed | quantityTypeUnavailable=true")
                return
            }

            fetchDailySeriesRestingHRV1(quantityType: type, days: 365) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.restingHeartRateReadAuthIssueV1 {
                        self.restingHeartRateDaily365 = []
                        GluLog.restingHeartRate.notice("fetchRestingHeartRateDaily365V1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.restingHeartRateDaily365 = entries
                    GluLog.restingHeartRate.notice("fetchRestingHeartRateDaily365V1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }
}

// ============================================================
// MARK: - Private Helpers
// ============================================================

private extension HealthStore {

    func fetchDailySeriesRestingHRV1(
        quantityType: HKQuantityType,
        days: Int,
        assign: @escaping ([RestingHeartRateEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            DispatchQueue.main.async { assign([]) }
            GluLog.restingHeartRate.error("fetchDailySeriesRestingHRV1 failed | startDateUnavailable=true")
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let interval = DateComponents(day: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results else {
                DispatchQueue.main.async { assign([]) }
                GluLog.restingHeartRate.notice("fetchDailySeriesRestingHRV1 finished | resultsEmpty=true")
                return
            }

            var daily: [RestingHeartRateEntry] = []
            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = stats.averageQuantity()?.doubleValue(for: unit) ?? 0
                daily.append(
                    RestingHeartRateEntry(
                        date: stats.startDate,
                        restingHeartRate: max(0, Int(round(bpm)))
                    )
                )
            }

            let result = daily.sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                assign(result)
                GluLog.restingHeartRate.debug("fetchDailySeriesRestingHRV1 finished | entries=\(result.count, privacy: .public)")
            }
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - File-local Probe Gate
// ============================================================

private enum RestingHRProbeGateV1 {

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
