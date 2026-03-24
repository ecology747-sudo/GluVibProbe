//
//  HealthStore+BodyFatV1.swift
//  GluVibProbe
//
//  Domain: Body / Body Fat
//  Screen Type: HealthStore Metric Extension V1
//
//  Purpose
//  - Owns the read-only Apple Health body-fat fetch pipeline for Body Fat V1.
//  - Resolves read-auth issues via deterministic permission-only probe logic.
//  - Publishes today, last-90-days, monthly and 365-day body-fat data into HealthStore.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT Published Body Fat Values) → ViewModels → Views
//
//  Key Connections
//  - BodyOverviewViewModelV1
//  - BodyFatViewModelV1
//
//  Important
//  - bodyFatReadAuthIssueV1 is set EXCLUSIVELY by probeBodyFatReadAuthIssueV1Async().
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

    private func _bodyFatIsReadAuthIssueV1(_ error: Error?) -> Bool {
        guard let ns = error as NSError? else { return false }
        guard ns.domain == HKErrorDomain else { return false }
        guard let code = HKError.Code(rawValue: ns.code) else { return false }
        return code == .errorAuthorizationDenied || code == .errorAuthorizationNotDetermined
    }

    // 🟨 UPDATED
    private func _bodyFatResolveReadAuthIssueV1(
        error: Error?
    ) -> Bool {
        _bodyFatIsReadAuthIssueV1(error)
    }

    // ============================================================
    // MARK: - Deterministic Read-Query Probe (Single-Writer)
    // ============================================================

    @MainActor
    func probeBodyFatReadAuthIssueV1Async() async -> Bool {

        if isPreview {
            bodyFatReadAuthIssueV1 = false // 🟨 UPDATED
            GluLog.bodyFat.debug("bodyFat probe skipped | preview=true")
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = BodyFatProbeGateV1.cachedResultIfFresh(for: key) {
            bodyFatReadAuthIssueV1 = cached
            GluLog.bodyFat.debug("bodyFat probe cache hit | authIssue=\(cached, privacy: .public)")
            return cached
        }

        if let inFlight = BodyFatProbeGateV1.inFlightTask(for: key) {
            let v = await inFlight.value
            bodyFatReadAuthIssueV1 = v
            GluLog.bodyFat.debug("bodyFat probe joined inFlight | authIssue=\(v, privacy: .public)")
            return v
        }

        GluLog.bodyFat.notice("bodyFat probe started")

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }

            guard let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
                GluLog.bodyFat.error("bodyFat probe failed | quantityTypeUnavailable=true")
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
                    let resolved = self._bodyFatResolveReadAuthIssueV1(error: error)
                    continuation.resume(returning: resolved)
                }

                self.healthStore.execute(query)
            }

            return isAuthIssue
        }

        BodyFatProbeGateV1.setInFlight(task, for: key)
        let result = await task.value
        BodyFatProbeGateV1.finish(with: result, for: key)

        bodyFatReadAuthIssueV1 = result
        GluLog.bodyFat.notice("bodyFat probe finished | authIssue=\(result, privacy: .public)")
        return result
    }

    // ============================================================
    // MARK: - Public API (Today / 90d / Monthly / 365)
    // ============================================================

    @MainActor
    func fetchBodyFatTodayV1() {
        if isPreview {
            let value = previewDailyBodyFat.sorted { $0.date < $1.date }.last?.bodyFatPercent ?? 0
            todayBodyFatPercent = max(0, value)
            GluLog.bodyFat.debug("fetchBodyFatTodayV1 preview applied | todayBodyFatPercent=\(self.todayBodyFatPercent, privacy: .public)")
            return
        }

        GluLog.bodyFat.notice("fetchBodyFatTodayV1 started")

        Task { @MainActor in
            let authIssue = await probeBodyFatReadAuthIssueV1Async()
            if authIssue {
                todayBodyFatPercent = 0
                GluLog.bodyFat.notice("fetchBodyFatTodayV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
                GluLog.bodyFat.error("fetchBodyFatTodayV1 failed | quantityTypeUnavailable=true")
                return
            }

            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let predicate = HKQuery.predicateForSamples(withStart: nil, end: Date(), options: [])

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
                    GluLog.bodyFat.notice("fetchBodyFatTodayV1 finished | noSample=true")
                    return
                }

                let raw01 = sample.quantity.doubleValue(for: .percent())
                let pct100 = raw01 * 100.0

                DispatchQueue.main.async {
                    if self.bodyFatReadAuthIssueV1 {
                        self.todayBodyFatPercent = 0
                        GluLog.bodyFat.notice("fetchBodyFatTodayV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.todayBodyFatPercent = max(0, pct100)
                    GluLog.bodyFat.notice("fetchBodyFatTodayV1 finished | todayBodyFatPercent=\(self.todayBodyFatPercent, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchLast90DaysBodyFatV1() {
        if isPreview {
            let slice = Array(previewDailyBodyFat.suffix(90)).sorted { $0.date < $1.date }
            last90DaysBodyFat = slice
            GluLog.bodyFat.debug("fetchLast90DaysBodyFatV1 preview applied | entries=\(slice.count, privacy: .public)")
            return
        }

        GluLog.bodyFat.notice("fetchLast90DaysBodyFatV1 started")

        Task { @MainActor in
            let authIssue = await probeBodyFatReadAuthIssueV1Async()
            if authIssue {
                last90DaysBodyFat = []
                GluLog.bodyFat.notice("fetchLast90DaysBodyFatV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
                GluLog.bodyFat.error("fetchLast90DaysBodyFatV1 failed | quantityTypeUnavailable=true")
                return
            }

            fetchDailySeriesAverageBodyFat_RawV1(
                quantityType: type,
                days: 90
            ) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.bodyFatReadAuthIssueV1 {
                        self.last90DaysBodyFat = []
                        GluLog.bodyFat.notice("fetchLast90DaysBodyFatV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.last90DaysBodyFat = entries
                    GluLog.bodyFat.notice("fetchLast90DaysBodyFatV1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }

    @MainActor
    func fetchMonthlyBodyFatV1() {
        if isPreview {
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var bucket: [DateComponents: (sum: Double, count: Int)] = [:]
            for e in previewDailyBodyFat where e.date >= startDate && e.date <= startOfToday && e.bodyFatPercent > 0 {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                var b = bucket[comps] ?? (0, 0)
                b.sum += e.bodyFatPercent
                b.count += 1
                bucket[comps] = b
            }

            let keys = bucket.keys.sorted {
                (calendar.date(from: $0) ?? .distantPast) < (calendar.date(from: $1) ?? .distantPast)
            }

            let result: [MonthlyMetricEntry] = keys.map { comps in
                let d = calendar.date(from: comps) ?? Date()
                let b = bucket[comps] ?? (0, 1)
                let avg = b.count > 0 ? (b.sum / Double(b.count)) : 0
                return MonthlyMetricEntry(
                    monthShort: d.formatted(.dateTime.month(.abbreviated)),
                    value: Int(round(max(0, avg)))
                )
            }

            monthlyBodyFat = result
            GluLog.bodyFat.debug("fetchMonthlyBodyFatV1 preview applied | entries=\(result.count, privacy: .public)")
            return
        }

        GluLog.bodyFat.notice("fetchMonthlyBodyFatV1 started")

        Task { @MainActor in
            let authIssue = await probeBodyFatReadAuthIssueV1Async()
            if authIssue {
                monthlyBodyFat = []
                GluLog.bodyFat.notice("fetchMonthlyBodyFatV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
                GluLog.bodyFat.error("fetchMonthlyBodyFatV1 failed | quantityTypeUnavailable=true")
                return
            }

            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else {
                GluLog.bodyFat.error("fetchMonthlyBodyFatV1 failed | startDateUnavailable=true")
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
                    GluLog.bodyFat.notice("fetchMonthlyBodyFatV1 finished | resultsEmpty=true")
                    return
                }

                if self.bodyFatReadAuthIssueV1 {
                    DispatchQueue.main.async {
                        self.monthlyBodyFat = []
                        GluLog.bodyFat.notice("fetchMonthlyBodyFatV1 finished | blockedByAuthIssue=true")
                    }
                    return
                }

                var temp: [MonthlyMetricEntry] = []
                results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                    let raw01 = stats.averageQuantity()?.doubleValue(for: .percent()) ?? 0
                    let pct100 = raw01 * 100.0
                    let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))
                    temp.append(
                        MonthlyMetricEntry(
                            monthShort: monthShort,
                            value: max(0, Int(round(pct100)))
                        )
                    )
                }

                DispatchQueue.main.async {
                    if self.bodyFatReadAuthIssueV1 {
                        self.monthlyBodyFat = []
                        GluLog.bodyFat.notice("fetchMonthlyBodyFatV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.monthlyBodyFat = temp
                    GluLog.bodyFat.notice("fetchMonthlyBodyFatV1 finished | entries=\(temp.count, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchBodyFatDaily365V1() {
        if isPreview {
            let slice = Array(previewDailyBodyFat.suffix(365)).sorted { $0.date < $1.date }
            bodyFatDaily365 = slice
            GluLog.bodyFat.debug("fetchBodyFatDaily365V1 preview applied | entries=\(slice.count, privacy: .public)")
            return
        }

        GluLog.bodyFat.notice("fetchBodyFatDaily365V1 started")

        Task { @MainActor in
            let authIssue = await probeBodyFatReadAuthIssueV1Async()
            if authIssue {
                bodyFatDaily365 = []
                GluLog.bodyFat.notice("fetchBodyFatDaily365V1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
                GluLog.bodyFat.error("fetchBodyFatDaily365V1 failed | quantityTypeUnavailable=true")
                return
            }

            fetchDailySeriesAverageBodyFat_RawV1(
                quantityType: type,
                days: 365
            ) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.bodyFatReadAuthIssueV1 {
                        self.bodyFatDaily365 = []
                        GluLog.bodyFat.notice("fetchBodyFatDaily365V1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.bodyFatDaily365 = entries
                    GluLog.bodyFat.notice("fetchBodyFatDaily365V1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }
}

// ============================================================
// MARK: - Private Helpers
// ============================================================

private extension HealthStore {

    func fetchDailySeriesAverageBodyFat_RawV1(
        quantityType: HKQuantityType,
        days: Int,
        assign: @escaping ([BodyFatEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            DispatchQueue.main.async { assign([]) }
            GluLog.bodyFat.error("fetchDailySeriesAverageBodyFat_RawV1 failed | startDateUnavailable=true")
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
                GluLog.bodyFat.notice("fetchDailySeriesAverageBodyFat_RawV1 finished | resultsEmpty=true")
                return
            }

            var measured: [BodyFatEntry] = []
            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                guard let q = stats.averageQuantity() else { return }
                let raw01 = q.doubleValue(for: .percent())
                let pct100 = raw01 * 100.0
                guard pct100 > 0 else { return }
                measured.append(BodyFatEntry(date: stats.startDate, bodyFatPercent: pct100))
            }

            DispatchQueue.main.async {
                let result = measured.sorted { $0.date < $1.date }
                assign(result)
                GluLog.bodyFat.debug("fetchDailySeriesAverageBodyFat_RawV1 finished | entries=\(result.count, privacy: .public)")
            }
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - File-local Probe Gate
// ============================================================

private enum BodyFatProbeGateV1 {

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
