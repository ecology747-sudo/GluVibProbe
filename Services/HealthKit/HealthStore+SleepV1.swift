//
//  HealthStore+SleepV1.swift
//  GluVibProbe
//
//  Sleep V1 — HealthStore Read Path
//
//  Purpose
//  - Owns the read-only Apple Health sleep fetch pipeline for Sleep V1.
//  - Resolves read-auth issues via deterministic probe logic.
//  - Publishes today, last-90-days, monthly and 365-day sleep data into HealthStore.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT Published Sleep Values) → SleepViewModelV1 → SleepViewV1
//
//  Key Connections
//  - SleepViewModelV1 reads the SessionsEndingDay series for charts:
//    `last90DaysSleepSessionsEndingDay` and `sleepDaily365SessionsEndingDay`.
//  - MovementSplit uses its own sleep-analysis path and is intentionally separate.
//  - This file must therefore keep the Sleep V1 chart series aligned with the ViewModel path.
//

import Foundation
import HealthKit
import OSLog // 🟨 UPDATED

extension HealthStore {

    // ============================================================
    // MARK: - Auth Issue Classification (Goldstandard)
    // ============================================================

    private func _sleepIsReadAuthIssueV1(_ error: Error?) -> Bool {
        guard let ns = error as NSError? else { return false }
        guard ns.domain == HKErrorDomain else { return false }
        guard let code = HKError.Code(rawValue: ns.code) else { return false }
        return code == .errorAuthorizationDenied || code == .errorAuthorizationNotDetermined
    }

    private func _sleepResolveReadAuthIssueV1(
        error: Error?
    ) -> Bool {
        _sleepIsReadAuthIssueV1(error)
    }

    // ============================================================
    // MARK: - Deterministic Read-Query Probe (Single-Writer)
    // ============================================================

    @MainActor
    func probeSleepReadAuthIssueV1Async() async -> Bool {

        if isPreview {
            GluLog.sleep.debug("sleep probe skipped | preview=true") // 🟨 UPDATED
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = SleepProbeGateV1.cachedResultIfFresh(for: key) {
            sleepReadAuthIssueV1 = cached
            GluLog.sleep.debug("sleep probe cache hit | authIssue=\(cached, privacy: .public)") // 🟨 UPDATED
            return cached
        }

        if let inFlight = SleepProbeGateV1.inFlightTask(for: key) {
            let v = await inFlight.value
            sleepReadAuthIssueV1 = v
            GluLog.sleep.debug("sleep probe joined inFlight | authIssue=\(v, privacy: .public)") // 🟨 UPDATED
            return v
        }

        GluLog.sleep.notice("sleep probe started") // 🟨 UPDATED

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }

            guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
                GluLog.sleep.error("sleep probe failed | categoryTypeUnavailable=true") // 🟨 UPDATED
                return true
            }

            let cal = Calendar.current
            let now = Date()
            let todayStart = cal.startOfDay(for: now)
            let startDate = cal.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart

            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
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

                    let resolved = self._sleepResolveReadAuthIssueV1(
                        error: error
                    )

                    continuation.resume(returning: resolved)
                }

                self.healthStore.execute(query)
            }

            return isAuthIssue
        }

        SleepProbeGateV1.setInFlight(task, for: key)
        let result = await task.value
        SleepProbeGateV1.finish(with: result, for: key)

        sleepReadAuthIssueV1 = result
        GluLog.sleep.notice("sleep probe finished | authIssue=\(result, privacy: .public)") // 🟨 UPDATED
        return result
    }

    // ============================================================
    // MARK: - Public V1 API (Fetches) — DATA ONLY
    // ============================================================

    @MainActor
    func fetchSleepTodayV1() {
        if isPreview {
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())

            let value = previewDailySleep
                .last(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
                .minutes ?? 0

            todaySleepMinutes = max(0, value)
            GluLog.sleep.debug("fetchSleepTodayV1 preview applied | todaySleepMinutes=\(self.todaySleepMinutes, privacy: .public)") // 🟨 UPDATED
            return
        }

        GluLog.sleep.notice("fetchSleepTodayV1 started") // 🟨 UPDATED

        Task { @MainActor in
            let authIssue = await probeSleepReadAuthIssueV1Async()
            if authIssue {
                todaySleepMinutes = 0
                GluLog.sleep.notice("fetchSleepTodayV1 aborted | authIssue=true") // 🟨 UPDATED
                return
            }

            let calendar = Calendar.current
            let now = Date()
            let startOfToday = calendar.startOfDay(for: now)

            let seriesStart = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday

            fetchSleepSessionEndingDaySeriesRangeV1(startDate: seriesStart, endDate: startOfToday) { [weak self] daily in
                guard let self else { return }

                let todayMinutes = daily.last(where: { calendar.isDate($0.date, inSameDayAs: startOfToday) })?.minutes ?? 0

                DispatchQueue.main.async {
                    if self.sleepReadAuthIssueV1 {
                        self.todaySleepMinutes = 0
                        GluLog.sleep.notice("fetchSleepTodayV1 finished | blockedByAuthIssue=true") // 🟨 UPDATED
                        return
                    }
                    self.todaySleepMinutes = max(0, todayMinutes)
                    GluLog.sleep.notice("fetchSleepTodayV1 finished | todaySleepMinutes=\(self.todaySleepMinutes, privacy: .public)") // 🟨 UPDATED
                }
            }
        }
    }

    @MainActor
    func fetchLast90DaysSleepV1() {
        if isPreview {
            let slice = Array(previewDailySleep.suffix(90)).sorted { $0.date < $1.date }
            last90DaysSleep = slice
            last90DaysSleepSessionsEndingDay = slice
            GluLog.sleep.debug("fetchLast90DaysSleepV1 preview applied | entries=\(slice.count, privacy: .public)") // 🟨 UPDATED
            return
        }

        GluLog.sleep.notice("fetchLast90DaysSleepV1 started") // 🟨 UPDATED

        Task { @MainActor in
            let authIssue = await probeSleepReadAuthIssueV1Async()
            if authIssue {
                last90DaysSleep = [] // 🟨 UPDATED
                last90DaysSleepSessionsEndingDay = [] // 🟨 UPDATED
                GluLog.sleep.notice("fetchLast90DaysSleepV1 aborted | authIssue=true") // 🟨 UPDATED
                return
            }

            fetchSleepSessionEndingDaySeriesV1(last: 90) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.sleepReadAuthIssueV1 {
                        self.last90DaysSleep = [] // 🟨 UPDATED
                        self.last90DaysSleepSessionsEndingDay = [] // 🟨 UPDATED
                        GluLog.sleep.notice("fetchLast90DaysSleepV1 finished | blockedByAuthIssue=true") // 🟨 UPDATED
                        return
                    }
                    self.last90DaysSleep = entries // 🟨 UPDATED
                    self.last90DaysSleepSessionsEndingDay = entries // 🟨 UPDATED
                    GluLog.sleep.notice("fetchLast90DaysSleepV1 finished | entries=\(entries.count, privacy: .public)") // 🟨 UPDATED
                }
            }
        }
    }

    @MainActor
    func fetchMonthlySleepV1() {
        if isPreview {
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            let daily = previewDailySleep
                .filter { $0.date >= startDate && $0.date <= startOfToday }
                .sorted { $0.date < $1.date }

            var bucket: [DateComponents: Int] = [:]
            for e in daily where e.minutes > 0 {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                bucket[comps, default: 0] += e.minutes
            }

            let sortedKeys = bucket.keys.sorted { lhs, rhs in
                let l = calendar.date(from: lhs) ?? .distantPast
                let r = calendar.date(from: rhs) ?? .distantPast
                return l < r
            }

            let monthly: [MonthlyMetricEntry] = sortedKeys.map { comps in
                let d = calendar.date(from: comps) ?? Date()
                return MonthlyMetricEntry(
                    monthShort: d.formatted(.dateTime.month(.abbreviated)),
                    value: bucket[comps] ?? 0
                )
            }

            self.monthlySleep = monthly
            GluLog.sleep.debug("fetchMonthlySleepV1 preview applied | entries=\(monthly.count, privacy: .public)") // 🟨 UPDATED
            return
        }

        GluLog.sleep.notice("fetchMonthlySleepV1 started") // 🟨 UPDATED

        Task { @MainActor in
            let authIssue = await probeSleepReadAuthIssueV1Async()
            if authIssue {
                monthlySleep = []
                GluLog.sleep.notice("fetchMonthlySleepV1 aborted | authIssue=true") // 🟨 UPDATED
                return
            }

            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else {
                GluLog.sleep.error("fetchMonthlySleepV1 failed | startDateUnavailable=true") // 🟨 UPDATED
                return
            }

            fetchSleepSessionEndingDaySeriesRangeV1(startDate: startDate, endDate: startOfToday) { [weak self] daily in
                guard let self else { return }

                var bucket: [DateComponents: Int] = [:]
                for e in daily where e.minutes > 0 {
                    let comps = calendar.dateComponents([.year, .month], from: e.date)
                    bucket[comps, default: 0] += e.minutes
                }

                let sortedKeys = bucket.keys.sorted { lhs, rhs in
                    let l = calendar.date(from: lhs) ?? .distantPast
                    let r = calendar.date(from: rhs) ?? .distantPast
                    return l < r
                }

                let monthly: [MonthlyMetricEntry] = sortedKeys.map { comps in
                    let d = calendar.date(from: comps) ?? Date()
                    return MonthlyMetricEntry(
                        monthShort: d.formatted(.dateTime.month(.abbreviated)),
                        value: bucket[comps] ?? 0
                    )
                }

                DispatchQueue.main.async {
                    if self.sleepReadAuthIssueV1 {
                        self.monthlySleep = []
                        GluLog.sleep.notice("fetchMonthlySleepV1 finished | blockedByAuthIssue=true") // 🟨 UPDATED
                        return
                    }
                    self.monthlySleep = monthly
                    GluLog.sleep.notice("fetchMonthlySleepV1 finished | entries=\(monthly.count, privacy: .public)") // 🟨 UPDATED
                }
            }
        }
    }

    @MainActor
    func fetchSleepDaily365V1() {
        if isPreview {
            let slice = Array(previewDailySleep.suffix(365)).sorted { $0.date < $1.date }
            sleepDaily365 = slice
            sleepDaily365SessionsEndingDay = slice
            GluLog.sleep.debug("fetchSleepDaily365V1 preview applied | entries=\(slice.count, privacy: .public)") // 🟨 UPDATED
            return
        }

        GluLog.sleep.notice("fetchSleepDaily365V1 started") // 🟨 UPDATED

        Task { @MainActor in
            let authIssue = await probeSleepReadAuthIssueV1Async()
            if authIssue {
                sleepDaily365 = [] // 🟨 UPDATED
                sleepDaily365SessionsEndingDay = [] // 🟨 UPDATED
                GluLog.sleep.notice("fetchSleepDaily365V1 aborted | authIssue=true") // 🟨 UPDATED
                return
            }

            fetchSleepSessionEndingDaySeriesV1(last: 365) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.sleepReadAuthIssueV1 {
                        self.sleepDaily365 = [] // 🟨 UPDATED
                        self.sleepDaily365SessionsEndingDay = [] // 🟨 UPDATED
                        GluLog.sleep.notice("fetchSleepDaily365V1 finished | blockedByAuthIssue=true") // 🟨 UPDATED
                        return
                    }
                    self.sleepDaily365 = entries // 🟨 UPDATED
                    self.sleepDaily365SessionsEndingDay = entries // 🟨 UPDATED
                    GluLog.sleep.notice("fetchSleepDaily365V1 finished | entries=\(entries.count, privacy: .public)") // 🟨 UPDATED
                }
            }
        }
    }
}

// ============================================================
// MARK: - Private Helpers (Sleep V1) — unchanged logic
// ============================================================

extension HealthStore {

    func fetchSleepSessionEndingDaySeriesV1(
        last days: Int,
        completion: @escaping ([DailySleepEntry]) -> Void
    ) {
        if isPreview {
            let slice = Array(previewDailySleep.suffix(max(1, days))).sorted { $0.date < $1.date }
            DispatchQueue.main.async {
                completion(slice)
                GluLog.sleep.debug("fetchSleepSessionEndingDaySeriesV1 preview applied | entries=\(slice.count, privacy: .public)") // 🟨 UPDATED
            }
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            DispatchQueue.main.async { completion([]) }
            GluLog.sleep.error("fetchSleepSessionEndingDaySeriesV1 failed | startDateUnavailable=true") // 🟨 UPDATED
            return
        }

        fetchSleepSessionEndingDaySeriesRangeV1(startDate: startDate, endDate: todayStart, completion: completion)
    }

    func fetchSleepSessionEndingDaySeriesRangeV1(
        startDate: Date,
        endDate: Date,
        completion: @escaping ([DailySleepEntry]) -> Void
    ) {
        if isPreview {
            let calendar = Calendar.current
            let startDay = calendar.startOfDay(for: startDate)
            let endDay = calendar.startOfDay(for: endDate)

            let daily = previewDailySleep
                .filter { $0.date >= startDay && $0.date <= endDay }
                .sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                completion(daily)
                GluLog.sleep.debug("fetchSleepSessionEndingDaySeriesRangeV1 preview applied | entries=\(daily.count, privacy: .public)") // 🟨 UPDATED
            }
            return
        }

        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            DispatchQueue.main.async { completion([]) }
            GluLog.sleep.error("fetchSleepSessionEndingDaySeriesRangeV1 failed | categoryTypeUnavailable=true") // 🟨 UPDATED
            return
        }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        let queryStart = calendar.date(byAdding: .day, value: -1, to: startDay) ?? startDay
        let queryEnd = calendar.date(byAdding: .day, value: 2, to: endDay) ?? endDay

        fetchSleepSamples(
            type: type,
            start: queryStart,
            end: queryEnd
        ) { samples in

            let sessions = Self.buildSleepSessions(from: samples, maxGapSeconds: 90 * 60)

            var perDayMinutes: [Date: Int] = [:]
            perDayMinutes.reserveCapacity(400)

            var cursor = startDay
            while cursor <= endDay {
                let dayStart = cursor
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

                let minutes = Self.primarySleepSessionMinutesEndingOnDayFromSessions(
                    sessions,
                    dayStart: dayStart,
                    dayEnd: dayEnd
                )

                perDayMinutes[dayStart] = max(0, minutes)

                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }

            var out: [DailySleepEntry] = []
            out.reserveCapacity(400)

            cursor = startDay
            while cursor <= endDay {
                out.append(DailySleepEntry(date: cursor, minutes: perDayMinutes[cursor] ?? 0))
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }

            let result = out.sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                completion(result)
                GluLog.sleep.debug("fetchSleepSessionEndingDaySeriesRangeV1 finished | samples=\(samples.count, privacy: .public) entries=\(result.count, privacy: .public)") // 🟨 UPDATED
            }
        }
    }

    func fetchSleepSamples(
        type: HKCategoryType,
        start: Date,
        end: Date,
        completion: @escaping ([HKCategorySample]) -> Void
    ) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: sort
        ) { _, samples, _ in
            let all = (samples as? [HKCategorySample]) ?? []
            let asleep = all.filter { Self.isAsleepSample($0) }

            GluLog.sleep.debug("fetchSleepSamples finished | rawSamples=\(all.count, privacy: .public) asleepSamples=\(asleep.count, privacy: .public)") // 🟨 UPDATED
            completion(asleep)
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - Static Session Helpers (unchanged)
// ============================================================

extension HealthStore {

    static func isAsleepSample(_ s: HKCategorySample) -> Bool {
        if #available(iOS 16.0, *) {
            return s.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                || s.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                || s.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                || s.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
        } else {
            return s.value == HKCategoryValueSleepAnalysis.asleep.rawValue
        }
    }

    struct SleepSession {
        let start: Date
        let end: Date
        let minutes: Int
    }

    static func buildSleepSessions(from samples: [HKCategorySample], maxGapSeconds: TimeInterval) -> [SleepSession] {
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        guard !sorted.isEmpty else { return [] }

        var sessions: [SleepSession] = []
        sessions.reserveCapacity(50)

        var currentStart = sorted[0].startDate
        var currentEnd = sorted[0].endDate
        var currentSamples: [HKCategorySample] = [sorted[0]]

        for s in sorted.dropFirst() {
            let gap = s.startDate.timeIntervalSince(currentEnd)

            if gap <= maxGapSeconds {
                currentSamples.append(s)
                currentEnd = max(currentEnd, s.endDate)
            } else {
                let minutes = sumSleepMinutes(in: currentSamples, clampStart: currentStart, clampEnd: currentEnd)
                sessions.append(SleepSession(start: currentStart, end: currentEnd, minutes: max(0, minutes)))

                currentStart = s.startDate
                currentEnd = s.endDate
                currentSamples = [s]
            }
        }

        let minutes = sumSleepMinutes(in: currentSamples, clampStart: currentStart, clampEnd: currentEnd)
        sessions.append(SleepSession(start: currentStart, end: currentEnd, minutes: max(0, minutes)))

        return sessions
    }

    static func primarySleepSessionMinutesEndingOnDayFromSessions(
        _ sessions: [SleepSession],
        dayStart: Date,
        dayEnd: Date
    ) -> Int {
        let candidates = sessions.filter { $0.end >= dayStart && $0.end < dayEnd }
        guard !candidates.isEmpty else { return 0 }

        let best = candidates.max { a, b in
            if a.minutes != b.minutes { return a.minutes < b.minutes }
            return a.end < b.end
        }

        return max(0, best?.minutes ?? 0)
    }

    static func sumSleepMinutes(
        in samples: [HKCategorySample],
        clampStart: Date,
        clampEnd: Date
    ) -> Int {
        var seconds: TimeInterval = 0

        for s in samples {
            let a = max(s.startDate, clampStart)
            let b = min(s.endDate, clampEnd)
            let d = b.timeIntervalSince(a)
            if d > 0 { seconds += d }
        }

        return Int((seconds / 60.0).rounded(.towardZero))
    }
}

// ============================================================
// MARK: - File-local Probe Gate (TTL + inFlight)
// ============================================================

private enum SleepProbeGateV1 {

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
