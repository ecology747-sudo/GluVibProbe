//
//  HealthStore+WorkoutMinutesV1.swift
//  GluVibProbe
//
//  Domain: Activity / Workout Minutes
//  Screen Type: HealthStore Metric Extension V1
//
//  Purpose
//  - Owns the read-only Apple Health workout-minutes fetch pipeline for Workout Minutes V1.
//  - Resolves read-auth issues via deterministic permission-only probe logic.
//  - Publishes today, last-90-days, monthly, 365-day and raw-3-days workout data into HealthStore.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT Published Workout Minutes Values) → ViewModels → Views
//
//  Key Connections
//  - WorkoutMinutesViewModelV1
//  - ActivityOverviewViewModelV1
//  - Metabolic MainChart activity overlay
//
//  Important
//  - workoutMinutesReadAuthIssueV1 is set EXCLUSIVELY by probeWorkoutMinutesReadAuthIssueV1Async().
//  - Probe is permission-only: empty results are DATA state, never permission state.
//  - All fetches are DATA ONLY and may be blocked only by a real read-auth issue.
//

import Foundation
import HealthKit
import OSLog

// ============================================================
// MARK: - Model
// ============================================================

struct DailyWorkoutMinutesEntry: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Int
}

// ============================================================
// MARK: - HealthStore + Workout Minutes
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - Auth Issue Classification
    // ============================================================

    private func _workoutMinutesIsReadAuthIssueV1(_ error: Error?) -> Bool {
        guard let ns = error as NSError? else { return false }
        guard ns.domain == HKErrorDomain else { return false }
        guard let code = HKError.Code(rawValue: ns.code) else { return false }
        return code == .errorAuthorizationDenied || code == .errorAuthorizationNotDetermined
    }

    // 🟨 UPDATED
    private func _workoutMinutesResolveReadAuthIssueV1(
        error: Error?
    ) -> Bool {
        _workoutMinutesIsReadAuthIssueV1(error)
    }

    // ============================================================
    // MARK: - Deterministic Read-Query Probe (Single-Writer)
    // ============================================================

    @MainActor
    func probeWorkoutMinutesReadAuthIssueV1Async() async -> Bool {

        if isPreview {
            workoutMinutesReadAuthIssueV1 = false // 🟨 UPDATED
            GluLog.healthStore.debug("workoutMinutes probe skipped | preview=true")
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = WorkoutMinutesProbeGateV1.cachedResultIfFresh(for: key) {
            workoutMinutesReadAuthIssueV1 = cached
            GluLog.healthStore.debug("workoutMinutes probe cache hit | authIssue=\(cached, privacy: .public)")
            return cached
        }

        if let inFlight = WorkoutMinutesProbeGateV1.inFlightTask(for: key) {
            let v = await inFlight.value
            workoutMinutesReadAuthIssueV1 = v
            GluLog.healthStore.debug("workoutMinutes probe joined inFlight | authIssue=\(v, privacy: .public)")
            return v
        }

        GluLog.healthStore.notice("workoutMinutes probe started")

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }

            let type: HKObjectType = HKObjectType.workoutType()
            let now = Date()

            // 🟨 UPDATED
            let predicate = HKQuery.predicateForSamples(withStart: nil, end: now, options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let isAuthIssue: Bool = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: HKObjectType.workoutType(),
                    predicate: predicate,
                    limit: 1,
                    sortDescriptors: [sort]
                ) { [weak self] _, _, error in
                    guard let self else {
                        continuation.resume(returning: false)
                        return
                    }

                    // 🟨 UPDATED
                    let resolved = self._workoutMinutesResolveReadAuthIssueV1(error: error)
                    continuation.resume(returning: resolved)
                }

                self.healthStore.execute(query)
            }

            return isAuthIssue
        }

        WorkoutMinutesProbeGateV1.setInFlight(task, for: key)
        let result = await task.value
        WorkoutMinutesProbeGateV1.finish(with: result, for: key)

        workoutMinutesReadAuthIssueV1 = result
        GluLog.healthStore.notice("workoutMinutes probe finished | authIssue=\(result, privacy: .public)")
        return result
    }

    // ============================================================
    // MARK: - Public API (Today / 90d / Monthly / 365 / RAW3DAYS)
    // ============================================================

    @MainActor
    func fetchWorkoutMinutesTodayV1() {
        if isPreview {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            let value = previewDailyWorkoutMinutes
                .first(where: { calendar.isDate($0.date, inSameDayAs: today) })?
                .minutes ?? 0

            todayWorkoutMinutes = max(0, value)
            GluLog.healthStore.debug("fetchWorkoutMinutesTodayV1 preview applied | todayWorkoutMinutes=\(self.todayWorkoutMinutes, privacy: .public)")
            return
        }

        GluLog.healthStore.notice("fetchWorkoutMinutesTodayV1 started")

        Task { @MainActor in
            let authIssue = await probeWorkoutMinutesReadAuthIssueV1Async()
            if authIssue {
                todayWorkoutMinutes = 0
                GluLog.healthStore.notice("fetchWorkoutMinutesTodayV1 aborted | authIssue=true")
                return
            }

            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)

            let predicate = HKQuery.predicateForSamples(
                withStart: startOfDay,
                end: now,
                options: .strictStartDate
            )

            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { [weak self] _, samples, _ in
                guard let self else { return }
                let workouts = (samples as? [HKWorkout]) ?? []
                let minutes = workouts.reduce(0) { $0 + Int(($1.duration / 60.0).rounded()) }

                DispatchQueue.main.async {
                    if self.workoutMinutesReadAuthIssueV1 {
                        self.todayWorkoutMinutes = 0
                        GluLog.healthStore.notice("fetchWorkoutMinutesTodayV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.todayWorkoutMinutes = max(0, minutes)
                    GluLog.healthStore.notice("fetchWorkoutMinutesTodayV1 finished | todayWorkoutMinutes=\(self.todayWorkoutMinutes, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchLast90DaysWorkoutMinutesV1() {
        if isPreview {
            last90DaysWorkoutMinutes = Array(previewDailyWorkoutMinutes.suffix(90)).sorted { $0.date < $1.date }
            GluLog.healthStore.debug("fetchLast90DaysWorkoutMinutesV1 preview applied | entries=\(self.last90DaysWorkoutMinutes.count, privacy: .public)")
            return
        }

        GluLog.healthStore.notice("fetchLast90DaysWorkoutMinutesV1 started")

        Task { @MainActor in
            let authIssue = await probeWorkoutMinutesReadAuthIssueV1Async()
            if authIssue {
                last90DaysWorkoutMinutes = []
                GluLog.healthStore.notice("fetchLast90DaysWorkoutMinutesV1 aborted | authIssue=true")
                return
            }

            fetchWorkoutMinutesDailySeriesV1(last: 90) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.workoutMinutesReadAuthIssueV1 {
                        self.last90DaysWorkoutMinutes = []
                        GluLog.healthStore.notice("fetchLast90DaysWorkoutMinutesV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.last90DaysWorkoutMinutes = entries
                    GluLog.healthStore.notice("fetchLast90DaysWorkoutMinutesV1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }

    @MainActor
    func fetchMonthlyWorkoutMinutesV1() {
        if isPreview {
            let months = ["Jul", "Aug", "Sep", "Okt", "Nov"]
            let values = months.map { _ in Int.random(in: 0...1_200) }
            monthlyWorkoutMinutes = zip(months, values).map { MonthlyMetricEntry(monthShort: $0.0, value: $0.1) }
            GluLog.healthStore.debug("fetchMonthlyWorkoutMinutesV1 preview applied | entries=\(self.monthlyWorkoutMinutes.count, privacy: .public)")
            return
        }

        GluLog.healthStore.notice("fetchMonthlyWorkoutMinutesV1 started")

        Task { @MainActor in
            let authIssue = await probeWorkoutMinutesReadAuthIssueV1Async()
            if authIssue {
                monthlyWorkoutMinutes = []
                GluLog.healthStore.notice("fetchMonthlyWorkoutMinutesV1 aborted | authIssue=true")
                return
            }

            fetchMonthlyWorkoutMinutesSeriesV1 { [weak self] monthly in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.workoutMinutesReadAuthIssueV1 {
                        self.monthlyWorkoutMinutes = []
                        GluLog.healthStore.notice("fetchMonthlyWorkoutMinutesV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.monthlyWorkoutMinutes = monthly
                    GluLog.healthStore.notice("fetchMonthlyWorkoutMinutesV1 finished | entries=\(monthly.count, privacy: .public)")
                }
            }
        }
    }

    @MainActor
    func fetchWorkoutMinutesDaily365V1() {
        if isPreview {
            workoutMinutesDaily365 = Array(previewDailyWorkoutMinutes.suffix(365)).sorted { $0.date < $1.date }
            GluLog.healthStore.debug("fetchWorkoutMinutesDaily365V1 preview applied | entries=\(self.workoutMinutesDaily365.count, privacy: .public)")
            return
        }

        GluLog.healthStore.notice("fetchWorkoutMinutesDaily365V1 started")

        Task { @MainActor in
            let authIssue = await probeWorkoutMinutesReadAuthIssueV1Async()
            if authIssue {
                workoutMinutesDaily365 = []
                GluLog.healthStore.notice("fetchWorkoutMinutesDaily365V1 aborted | authIssue=true")
                return
            }

            fetchWorkoutMinutesDailySeriesV1(last: 365) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.workoutMinutesReadAuthIssueV1 {
                        self.workoutMinutesDaily365 = []
                        GluLog.healthStore.notice("fetchWorkoutMinutesDaily365V1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.workoutMinutesDaily365 = entries
                    GluLog.healthStore.notice("fetchWorkoutMinutesDaily365V1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }

    @MainActor
    func fetchActivityEvents3DaysV1() {
        if isPreview {
            let cal = Calendar.current
            let now = Date()
            let todayStart = cal.startOfDay(for: now)
            let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart

            let mock: [ActivityOverlayEvent] = [
                .init(id: UUID(), start: cal.date(byAdding: .hour, value: 7, to: todayStart) ?? now,
                      end: cal.date(byAdding: .hour, value: 8, to: todayStart) ?? now, kind: .workout),
                .init(id: UUID(), start: cal.date(byAdding: .hour, value: 18, to: todayStart) ?? now,
                      end: cal.date(byAdding: .hour, value: 19, to: todayStart) ?? now, kind: .workout),
                .init(id: UUID(), start: cal.date(byAdding: .hour, value: 12, to: yesterdayStart) ?? now,
                      end: cal.date(byAdding: .hour, value: 13, to: yesterdayStart) ?? now, kind: .workout)
            ]

            activityEvents3Days = mock.sorted { $0.start < $1.start }
            GluLog.healthStore.debug("fetchActivityEvents3DaysV1 preview applied | events=\(self.activityEvents3Days.count, privacy: .public)")
            return
        }

        GluLog.healthStore.notice("fetchActivityEvents3DaysV1 started")

        Task { @MainActor in
            let authIssue = await probeWorkoutMinutesReadAuthIssueV1Async()
            if authIssue {
                activityEvents3Days = []
                GluLog.healthStore.notice("fetchActivityEvents3DaysV1 aborted | authIssue=true")
                return
            }

            let cal = Calendar.current
            let now = Date()
            let todayStart = cal.startOfDay(for: now)
            let dayBeforeStart = cal.date(byAdding: .day, value: -2, to: todayStart) ?? todayStart

            let predicate = HKQuery.predicateForSamples(withStart: dayBeforeStart, end: now, options: [])
            let sort = [
                NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            ]

            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sort
            ) { [weak self] _, samples, _ in
                guard let self else { return }

                let workouts = (samples as? [HKWorkout]) ?? []

                let mapped: [ActivityOverlayEvent] = workouts.map { w in
                    ActivityOverlayEvent(
                        id: UUID(),
                        start: w.startDate,
                        end: w.endDate,
                        kind: .workout
                    )
                }

                DispatchQueue.main.async {
                    if self.workoutMinutesReadAuthIssueV1 {
                        self.activityEvents3Days = []
                        GluLog.healthStore.notice("fetchActivityEvents3DaysV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.activityEvents3Days = mapped.sorted { $0.start < $1.start }
                    GluLog.healthStore.notice("fetchActivityEvents3DaysV1 finished | events=\(self.activityEvents3Days.count, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    // ============================================================
    // MARK: - Private Helpers (Daily Series / Monthly)
    // ============================================================

    private func fetchWorkoutMinutesDailySeriesV1(
        last days: Int,
        assign: @escaping ([DailyWorkoutMinutesEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            DispatchQueue.main.async { assign([]) }
            GluLog.healthStore.error("fetchWorkoutMinutesDailySeriesV1 failed | startDateUnavailable=true")
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])

        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, _ in

            let workouts = (samples as? [HKWorkout]) ?? []
            var bucket: [Date: Int] = [:]

            for w in workouts {
                let day = calendar.startOfDay(for: w.startDate)
                let m = Int((w.duration / 60.0).rounded())
                bucket[day, default: 0] += max(0, m)
            }

            var result: [DailyWorkoutMinutesEntry] = []
            result.reserveCapacity(days)

            for offset in 0..<days {
                guard let d = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
                let day = calendar.startOfDay(for: d)
                result.append(.init(date: day, minutes: bucket[day] ?? 0))
            }

            let sorted = result.sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                assign(sorted)
            }

            GluLog.healthStore.debug("fetchWorkoutMinutesDailySeriesV1 finished | entries=\(sorted.count, privacy: .public)")
        }

        healthStore.execute(query)
    }

    private func fetchMonthlyWorkoutMinutesSeriesV1(
        assign: @escaping ([MonthlyMetricEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        guard
            let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: startOfToday)),
            let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
        else {
            DispatchQueue.main.async { assign([]) }
            GluLog.healthStore.error("fetchMonthlyWorkoutMinutesSeriesV1 failed | dateWindowUnavailable=true")
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: startOfToday, options: .strictStartDate)

        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, _ in

            let workouts = (samples as? [HKWorkout]) ?? []
            var bucket: [Date: Int] = [:]

            for w in workouts {
                let comps = calendar.dateComponents([.year, .month], from: w.startDate)
                guard let monthAnchor = calendar.date(from: comps) else { continue }
                let m = Int((w.duration / 60.0).rounded())
                bucket[monthAnchor, default: 0] += max(0, m)
            }

            var monthly: [MonthlyMetricEntry] = []
            monthly.reserveCapacity(5)

            for i in 0...4 {
                guard let d = calendar.date(byAdding: .month, value: i, to: startDate) else { continue }
                let monthAnchor = calendar.date(from: calendar.dateComponents([.year, .month], from: d)) ?? d
                let label = monthAnchor.formatted(.dateTime.month(.abbreviated))
                monthly.append(.init(monthShort: label, value: bucket[monthAnchor] ?? 0))
            }

            DispatchQueue.main.async {
                assign(monthly)
            }

            GluLog.healthStore.debug("fetchMonthlyWorkoutMinutesSeriesV1 finished | entries=\(monthly.count, privacy: .public)")
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - File-local Probe Gate
// ============================================================

private enum WorkoutMinutesProbeGateV1 {

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
