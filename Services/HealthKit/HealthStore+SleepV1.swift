//
//  HealthStore+SleepV1.swift
//  GluVibProbe
//
//  Sleep V1 (Body Domain)
//  - Fetch-only
//  - SSoT assign (today / 90d / monthly / 365 secondary)
//  - Source: HKCategoryTypeIdentifier.sleepAnalysis
//
//  IMPORTANT RULES:
//  - Movement Split has its OWN sleep calculation (do not touch).
//  - Sleep KPI + Overview Sleep tile + Sleep charts must use:
//      "Last sleep session ending that day" (session ending day logic).
//

import Foundation
import HealthKit

// ============================================================
// MARK: - HealthStore + Sleep (V1)
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - Public V1 API (Fetches)
    // ============================================================

    /// TODAY KPI → writes `todaySleepMinutes`
    /// ✅ "Last sleep session ending TODAY" (not 00:00..now)
    func fetchSleepTodayV1() {
        if isPreview {
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())

            let value = previewDailySleep
                .last(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
                .minutes ?? 0

            DispatchQueue.main.async {
                self.todaySleepMinutes = max(0, value)
            }
            return
        }

        // !!! UPDATED: Today KPI must mirror the SAME "session-ending-day" series source as charts.
        // Build a tiny series covering yesterday+today, then pick today's entry.
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        let seriesStart = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday

        fetchSleepSessionEndingDaySeriesRangeV1(startDate: seriesStart, endDate: startOfToday) { [weak self] daily in
            guard let self else { return }

            let todayMinutes = daily.last(where: { calendar.isDate($0.date, inSameDayAs: startOfToday) })?.minutes ?? 0

            DispatchQueue.main.async {
                self.todaySleepMinutes = max(0, todayMinutes)
            }
        }
    }

    /// LAST 90 DAYS (session-ending-day) → writes `last90DaysSleep`
    func fetchLast90DaysSleepV1() {
        fetchSleepSessionEndingDaySeriesV1(last: 90) { [weak self] entries in
            self?.last90DaysSleep = entries
        }
    }

    /// MONTHLY (sum of daily "session-ending-day" minutes; last ~5 months) → writes `monthlySleep`
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

            DispatchQueue.main.async { self.monthlySleep = monthly }
            return
        }

        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        guard
            let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
            let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
        else { return }

        // Build daily (session-ending-day) series for this range, then bucket into months
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

            DispatchQueue.main.async { self.monthlySleep = monthly }
        }
    }

    /// SECONDARY 365 (session-ending-day) → writes `sleepDaily365`
    func fetchSleepDaily365V1() {
        fetchSleepSessionEndingDaySeriesV1(last: 365) { [weak self] entries in
            self?.sleepDaily365 = entries
        }
    }
}

// ============================================================
// MARK: - Private Helpers (Sleep V1)
// ============================================================

private extension HealthStore {

    // ============================================================
    // MARK: - Series Builders (Session Ending Day)
    // ============================================================

    func fetchSleepSessionEndingDaySeriesV1(
        last days: Int,
        completion: @escaping ([DailySleepEntry]) -> Void
    ) {
        if isPreview {
            let slice = Array(previewDailySleep.suffix(max(1, days))).sorted { $0.date < $1.date }
            DispatchQueue.main.async { completion(slice) }
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            DispatchQueue.main.async { completion([]) }
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

            DispatchQueue.main.async { completion(daily) }
            return
        }

        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        // IMPORTANT: query one day earlier to capture sessions that start before startDay but end on startDay
        let queryStart = calendar.date(byAdding: .day, value: -1, to: startDay) ?? startDay

        // !!! UPDATED: widen queryEnd to reliably capture sessions that end on endDay,
        // and allow overlap (predicate fixed below). Use +2 days to be robust.
        let queryEnd = calendar.date(byAdding: .day, value: 2, to: endDay) ?? endDay   // !!! UPDATED

        fetchSleepSamples(
            type: type,
            start: queryStart,
            end: queryEnd
        ) { samples in

            // Build sessions from asleep samples (gap-merge heuristic)
            let sessions = Self.buildSleepSessions(from: samples, maxGapSeconds: 90 * 60)

            // For each day: pick the LAST session that ends within that day
            var perDayMinutes: [Date: Int] = [:]
            perDayMinutes.reserveCapacity(400)

            var cursor = startDay
            while cursor <= endDay {
                let dayStart = cursor
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

                let minutes = Self.lastSleepSessionMinutesEndingOnDayFromSessions(
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

            DispatchQueue.main.async {
                completion(out.sorted { $0.date < $1.date })
            }
        }
    }

    // ============================================================
    // MARK: - HK Query
    // ============================================================

    func fetchSleepSamples(
        type: HKCategoryType,
        start: Date,
        end: Date,
        completion: @escaping ([HKCategorySample]) -> Void
    ) {
        // !!! UPDATED: MUST allow overlapping samples. `.strictStartDate` can cut sessions at midnight.
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: []) // !!! UPDATED
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: sort
        ) { _, samples, _ in
            let all = (samples as? [HKCategorySample]) ?? []
            let asleep = all.filter { Self.isAsleepSample($0) }
            completion(asleep)
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - Static Session Helpers
// ============================================================

private extension HealthStore {

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

    // A "session" is a cluster of asleep samples where gaps between samples are not too large.
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

                // start new
                currentStart = s.startDate
                currentEnd = s.endDate
                currentSamples = [s]
            }
        }

        let minutes = sumSleepMinutes(in: currentSamples, clampStart: currentStart, clampEnd: currentEnd)
        sessions.append(SleepSession(start: currentStart, end: currentEnd, minutes: max(0, minutes)))

        return sessions
    }

    static func lastSleepSessionMinutesEndingOnDay(
        in samples: [HKCategorySample],
        dayStart: Date,
        dayEnd: Date,
        calendar: Calendar
    ) -> Int {
        let sessions = buildSleepSessions(from: samples, maxGapSeconds: 90 * 60)
        return lastSleepSessionMinutesEndingOnDayFromSessions(sessions, dayStart: dayStart, dayEnd: dayEnd)
    }

    static func lastSleepSessionMinutesEndingOnDayFromSessions(
        _ sessions: [SleepSession],
        dayStart: Date,
        dayEnd: Date
    ) -> Int {
        // pick the session with the latest END inside [dayStart, dayEnd)
        let candidates = sessions.filter { $0.end >= dayStart && $0.end < dayEnd }
        guard let last = candidates.max(by: { $0.end < $1.end }) else { return 0 }
        return max(0, last.minutes)
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
