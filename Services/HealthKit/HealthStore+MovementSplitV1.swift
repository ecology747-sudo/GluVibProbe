//
//  HealthStore+MovementSplitV1.swift
//  GluVibProbe
//
//  Domain: Activity / Movement Split
//  Screen Type: HealthStore Metric Extension V1
//
//  Purpose
//  - Owns the read-only Apple Health movement-split aggregation for Movement Split V1.
//  - Publishes todayMoveMinutes, todaySedentaryMinutes, todaySleepSplitMinutes
//    and movementSplitDaily365 into HealthStore.
//  - Merges Sleep + Stand Time + Exercise Time + Workout Minutes into one day-based split.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT Published Movement Split Values) → ViewModels → Views
//
//  Key Connections
//  - MovementSplitViewModelV1
//  - ActivityOverviewViewModelV1
//  - Bootstrap async wrapper fetchMovementSplitFastSliceAsync(last:)
//
//  Important
//  - Days are computed strictly in the local 0–24h window.
//  - Sleep is split into calendar-day segments from sleepAnalysis samples.
//  - Active source priority: appleStandTime → Exercise Time → Workout Minutes.
//  - Sedentary = minutesSoFar(today) or 1440(past days) - Sleep - Active.
//  - standTimeReadAuthIssueV1 is set EXCLUSIVELY by probeStandTimeReadAuthIssueV1Async().
//  - Probe is permission-only: empty results are DATA state, never permission state.
//

import Foundation
import HealthKit
import OSLog

// ============================================================
// MARK: - HealthStore + Movement Split
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - Stand Time Auth Issue Classification
    // ============================================================

    private func _standTimeIsReadAuthIssueV1(_ error: Error?) -> Bool {
        guard let ns = error as NSError? else { return false }
        guard ns.domain == HKErrorDomain else { return false }
        guard let code = HKError.Code(rawValue: ns.code) else { return false }
        return code == .errorAuthorizationDenied || code == .errorAuthorizationNotDetermined
    }

    // 🟨 UPDATED
    private func _standTimeResolveReadAuthIssueV1(
        error: Error?
    ) -> Bool {
        _standTimeIsReadAuthIssueV1(error)
    }

    // ============================================================
    // MARK: - Deterministic Read-Query Probe (Single-Writer)
    // ============================================================

    @MainActor
    func probeStandTimeReadAuthIssueV1Async() async -> Bool {
        if isPreview {
            standTimeReadAuthIssueV1 = false // 🟨 UPDATED
            GluLog.healthStore.debug("standTime probe skipped | preview=true")
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = StandTimeProbeGateV1.cachedResultIfFresh(for: key) {
            standTimeReadAuthIssueV1 = cached
            GluLog.healthStore.debug("standTime probe cache hit | authIssue=\(cached, privacy: .public)")
            return cached
        }

        if let inFlight = StandTimeProbeGateV1.inFlightTask(for: key) {
            let value = await inFlight.value
            standTimeReadAuthIssueV1 = value
            GluLog.healthStore.debug("standTime probe joined inFlight | authIssue=\(value, privacy: .public)")
            return value
        }

        GluLog.healthStore.notice("standTime probe started")

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }

            guard let type = HKQuantityType.quantityType(forIdentifier: .appleStandTime) else {
                GluLog.healthStore.error("standTime probe failed | quantityTypeUnavailable=true")
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
                    let resolved = self._standTimeResolveReadAuthIssueV1(error: error)
                    continuation.resume(returning: resolved)
                }

                self.healthStore.execute(query)
            }

            return isAuthIssue
        }

        StandTimeProbeGateV1.setInFlight(task, for: key)
        let result = await task.value
        StandTimeProbeGateV1.finish(with: result, for: key)

        standTimeReadAuthIssueV1 = result
        GluLog.healthStore.notice("standTime probe finished | authIssue=\(result, privacy: .public)")
        return result
    }

    // ============================================================
    // MARK: - Public API
    // ============================================================

    func fetchMovementSplitTodayV1() {
        GluLog.healthStore.notice("fetchMovementSplitTodayV1 started")
        fetchMovementSplitDaily365V1(last: 1, completion: nil)
    }

    func fetchMovementSplitDaily365V1(
        last days: Int = 365,
        completion: (() -> Void)? = nil
    ) {

        GluLog.healthStore.notice("fetchMovementSplitDaily365V1 started | days=\(days, privacy: .public)")

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        // ---------------------------------------
        // MARK: - Preview
        // ---------------------------------------

        if isPreview {
            let slice = Array(previewDailyMovementSplit.suffix(days))
            DispatchQueue.main.async {

                self.movementSplitDaily365 = slice

                if let today = slice.last(where: { calendar.isDate($0.date, inSameDayAs: todayStart) }) {
                    self.todayMoveMinutes = today.activeMinutes
                    self.todaySleepSplitMinutes = today.sleepMorningMinutes + today.sleepEveningMinutes

                    let minutesSoFar = Int(now.timeIntervalSince(todayStart) / 60.0)
                    self.todaySedentaryMinutes = max(
                        0,
                        minutesSoFar - self.todaySleepSplitMinutes - self.todayMoveMinutes
                    )

                    self.movementSplitActiveSourceTodayV1 = (today.activeMinutes > 0 ? .standTime : .none)
                } else {
                    self.todayMoveMinutes = 0
                    self.todaySleepSplitMinutes = 0
                    self.todaySedentaryMinutes = 0
                    self.movementSplitActiveSourceTodayV1 = .none
                }

                GluLog.healthStore.debug(
                    "fetchMovementSplitDaily365V1 preview applied | entries=\(self.movementSplitDaily365.count, privacy: .public) todayMove=\(self.todayMoveMinutes, privacy: .public) todaySleep=\(self.todaySleepSplitMinutes, privacy: .public) todaySedentary=\(self.todaySedentaryMinutes, privacy: .public) source=\(self.movementSplitActiveSourceTodayV1.rawValue, privacy: .public)"
                )

                completion?()
            }
            return
        }

        Task { @MainActor in
            _ = await self.probeSleepReadAuthIssueV1Async()
            _ = await self.probeStandTimeReadAuthIssueV1Async()
            _ = await self.probeExerciseTimeReadAuthIssueV1Async()
            _ = await self.probeWorkoutMinutesReadAuthIssueV1Async()

            GluLog.healthStore.debug(
                "fetchMovementSplitDaily365V1 probes finished | sleepAuthIssue=\(self.sleepReadAuthIssueV1, privacy: .public) standAuthIssue=\(self.standTimeReadAuthIssueV1, privacy: .public) exerciseAuthIssue=\(self.exerciseTimeReadAuthIssueV1, privacy: .public) workoutAuthIssue=\(self.workoutMinutesReadAuthIssueV1, privacy: .public)"
            )

            self.fetchSleepSplitDailyV1(last: days) { [weak self] sleepPerDay in
                guard let self else { return }

                self.fetchStandMinutesDailyV1(last: days) { standPerDay in

                    self.fetchExerciseMinutesDailyV1(last: days) { exercisePerDay in

                        self.fetchWorkoutMinutesDailyV1(last: days) { workoutPerDay in

                            var out: [DailyMovementSplitEntry] = []
                            out.reserveCapacity(days)

                            var todaySource: MovementSplitActiveSourceTodayV1 = .none

                            for offset in stride(from: days - 1, through: 0, by: -1) {
                                guard let date = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
                                let dayKey = calendar.startOfDay(for: date)

                                let sleep = sleepPerDay[dayKey] ?? (morning: 0, evening: 0, total: 0)
                                let stand = standPerDay[dayKey] ?? 0
                                let ex    = exercisePerDay[dayKey] ?? 0
                                let wo    = workoutPerDay[dayKey] ?? 0

                                let active: Int
                                let source: MovementSplitActiveSourceTodayV1

                                if stand > 0 {
                                    active = stand
                                    source = .standTime
                                } else if ex > 0 {
                                    active = ex
                                    source = .exerciseMinutes
                                } else if wo > 0 {
                                    active = wo
                                    source = .workoutMinutes
                                } else {
                                    active = 0
                                    source = .none
                                }

                                let isToday = calendar.isDate(dayKey, inSameDayAs: todayStart)
                                let minutesWindow = isToday ? Int(now.timeIntervalSince(todayStart) / 60.0) : 1440
                                let sedentary = max(0, minutesWindow - sleep.total - active)

                                out.append(
                                    DailyMovementSplitEntry(
                                        date: date,
                                        sleepMorningMinutes: sleep.morning,
                                        sleepEveningMinutes: sleep.evening,
                                        sedentaryMinutes: sedentary,
                                        activeMinutes: active
                                    )
                                )

                                if isToday {
                                    todaySource = source
                                }
                            }

                            DispatchQueue.main.async {
                                self.movementSplitDaily365 = out

                                if let today = out.last(where: { calendar.isDate($0.date, inSameDayAs: todayStart) }) {
                                    self.todayMoveMinutes = today.activeMinutes
                                    self.todaySleepSplitMinutes = today.sleepMorningMinutes + today.sleepEveningMinutes

                                    let minutesSoFar = Int(now.timeIntervalSince(todayStart) / 60.0)
                                    self.todaySedentaryMinutes = max(
                                        0,
                                        minutesSoFar - self.todaySleepSplitMinutes - self.todayMoveMinutes
                                    )

                                    self.movementSplitActiveSourceTodayV1 = todaySource
                                } else {
                                    self.todayMoveMinutes = 0
                                    self.todaySleepSplitMinutes = 0
                                    self.todaySedentaryMinutes = 0
                                    self.movementSplitActiveSourceTodayV1 = .none
                                }

                                GluLog.healthStore.notice(
                                    "fetchMovementSplitDaily365V1 finished | entries=\(self.movementSplitDaily365.count, privacy: .public) todayMove=\(self.todayMoveMinutes, privacy: .public) todaySleep=\(self.todaySleepSplitMinutes, privacy: .public) todaySedentary=\(self.todaySedentaryMinutes, privacy: .public) source=\(self.movementSplitActiveSourceTodayV1.rawValue, privacy: .public)"
                                )

                                completion?()
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // MARK: - Sleep Split
    // ============================================================

    private func fetchSleepSplitDailyV1(
        last days: Int,
        completion: @escaping ([Date: (morning: Int, evening: Int, total: Int)]) -> Void
    ) {
        guard sleepReadAuthIssueV1 == false else {
            GluLog.healthStore.debug("fetchSleepSplitDailyV1 skipped | authIssue=true")
            completion([:])
            return
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            GluLog.healthStore.error("fetchSleepSplitDailyV1 failed | sleepTypeUnavailable=true")
            completion([:])
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            GluLog.healthStore.error("fetchSleepSplitDailyV1 failed | startDateUnavailable=true")
            completion([:])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        var result: [Date: (morning: Int, evening: Int, total: Int)] = [:]

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in

            let allSamples = (samples as? [HKCategorySample]) ?? []
            let filteredSamples = allSamples.filter { Self.isAsleepSample($0) }

            guard !filteredSamples.isEmpty else {
                DispatchQueue.main.async { completion(result) }
                GluLog.healthStore.debug("fetchSleepSplitDailyV1 finished | asleepSamples=0 days=0")
                return
            }

            for sample in filteredSamples {
                let sampleStart = max(sample.startDate, startDate)
                let sampleEnd   = min(sample.endDate, now)
                if sampleEnd <= sampleStart { continue }

                var current = sampleStart

                while current < sampleEnd {
                    let dayStart = calendar.startOfDay(for: current)
                    guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }

                    let segmentEnd = min(sampleEnd, dayEnd)
                    if segmentEnd <= current { break }

                    let segmentMinutes = Int(segmentEnd.timeIntervalSince(current) / 60.0)

                    let morningStart = dayStart
                    let morningEnd = calendar.date(byAdding: .hour, value: 12, to: dayStart)!

                    let eveningStart = calendar.date(byAdding: .hour, value: 18, to: dayStart)!
                    let eveningEnd = dayEnd

                    var addMorning = 0
                    var addEvening = 0

                    let mStart = max(current, morningStart)
                    let mEnd   = min(segmentEnd, morningEnd)
                    if mEnd > mStart { addMorning = Int(mEnd.timeIntervalSince(mStart) / 60.0) }

                    let eStart = max(current, eveningStart)
                    let eEnd   = min(segmentEnd, eveningEnd)
                    if eEnd > eStart { addEvening = Int(eEnd.timeIntervalSince(eStart) / 60.0) }

                    var entry = result[dayStart] ?? (morning: 0, evening: 0, total: 0)
                    entry.morning += addMorning
                    entry.evening += addEvening
                    entry.total   += segmentMinutes
                    result[dayStart] = entry

                    current = segmentEnd
                }
            }

            DispatchQueue.main.async { completion(result) }
            GluLog.healthStore.debug("fetchSleepSplitDailyV1 finished | asleepSamples=\(filteredSamples.count, privacy: .public) days=\(result.count, privacy: .public)")
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - Stand Time (Priority #1)
    // ============================================================

    private func fetchStandMinutesDailyV1(
        last days: Int,
        completion: @escaping ([Date: Int]) -> Void
    ) {
        guard standTimeReadAuthIssueV1 == false else {
            GluLog.healthStore.debug("fetchStandMinutesDailyV1 skipped | authIssue=true")
            completion([:])
            return
        }

        guard let standType = HKQuantityType.quantityType(forIdentifier: .appleStandTime) else {
            GluLog.healthStore.error("fetchStandMinutesDailyV1 failed | standTypeUnavailable=true")
            completion([:])
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            GluLog.healthStore.error("fetchStandMinutesDailyV1 failed | startDateUnavailable=true")
            completion([:])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let interval = DateComponents(day: 1)

        var values: [Date: Int] = [:]

        let query = HKStatisticsCollectionQuery(
            quantityType: standType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results else {
                DispatchQueue.main.async { completion(values) }
                GluLog.healthStore.debug("fetchStandMinutesDailyV1 finished | entries=0 resultsEmpty=true")
                return
            }

            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let minutes = stats.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                let day = calendar.startOfDay(for: stats.startDate)
                values[day] = Int(minutes.rounded())
            }

            DispatchQueue.main.async { completion(values) }
            GluLog.healthStore.debug("fetchStandMinutesDailyV1 finished | entries=\(values.count, privacy: .public)")
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - Exercise Time (Priority #2)
    // ============================================================

    private func fetchExerciseMinutesDailyV1(
        last days: Int,
        completion: @escaping ([Date: Int]) -> Void
    ) {
        guard exerciseTimeReadAuthIssueV1 == false else {
            GluLog.healthStore.debug("fetchExerciseMinutesDailyV1 skipped | authIssue=true")
            completion([:])
            return
        }

        guard let exType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
            GluLog.healthStore.error("fetchExerciseMinutesDailyV1 failed | exerciseTypeUnavailable=true")
            completion([:])
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            GluLog.healthStore.error("fetchExerciseMinutesDailyV1 failed | startDateUnavailable=true")
            completion([:])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let interval = DateComponents(day: 1)

        var values: [Date: Int] = [:]

        let query = HKStatisticsCollectionQuery(
            quantityType: exType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results else {
                DispatchQueue.main.async { completion(values) }
                GluLog.healthStore.debug("fetchExerciseMinutesDailyV1 finished | entries=0 resultsEmpty=true")
                return
            }

            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let minutes = stats.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                let day = calendar.startOfDay(for: stats.startDate)
                values[day] = Int(minutes.rounded())
            }

            DispatchQueue.main.async { completion(values) }
            GluLog.healthStore.debug("fetchExerciseMinutesDailyV1 finished | entries=\(values.count, privacy: .public)")
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - Workout Minutes (Priority #3)
    // ============================================================

    private func fetchWorkoutMinutesDailyV1(
        last days: Int,
        completion: @escaping ([Date: Int]) -> Void
    ) {
        guard workoutMinutesReadAuthIssueV1 == false else {
            GluLog.healthStore.debug("fetchWorkoutMinutesDailyV1 skipped | authIssue=true")
            completion([:])
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            GluLog.healthStore.error("fetchWorkoutMinutesDailyV1 failed | startDateUnavailable=true")
            completion([:])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        var values: [Date: Int] = [:]

        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                DispatchQueue.main.async { completion(values) }
                GluLog.healthStore.debug("fetchWorkoutMinutesDailyV1 finished | workouts=0 entries=0")
                return
            }

            for w in workouts {
                let workoutStart = max(w.startDate, startDate)
                let workoutEnd   = min(w.endDate, now)
                if workoutEnd <= workoutStart { continue }

                var current = workoutStart
                while current < workoutEnd {
                    let dayStart = calendar.startOfDay(for: current)
                    guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }

                    let segmentEnd = min(workoutEnd, dayEnd)
                    if segmentEnd <= current { break }

                    let minutes = Int(segmentEnd.timeIntervalSince(current) / 60.0)
                    values[dayStart, default: 0] += max(0, minutes)

                    current = segmentEnd
                }
            }

            DispatchQueue.main.async { completion(values) }
            GluLog.healthStore.debug("fetchWorkoutMinutesDailyV1 finished | workouts=\(workouts.count, privacy: .public) entries=\(values.count, privacy: .public)")
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - File-local Probe Gate
// ============================================================

private enum StandTimeProbeGateV1 {

    private static let ttl: TimeInterval = 10

    private static var lastRun: [ObjectIdentifier: Date] = [:]
    private static var lastResult: [ObjectIdentifier: Bool] = [:]
    private static var inFlight: [ObjectIdentifier: Task<Bool, Never>] = [:]

    static func cachedResultIfFresh(for key: ObjectIdentifier) -> Bool? {
        guard let last = lastRun[key], let value = lastResult[key] else { return nil }
        return (Date().timeIntervalSince(last) <= ttl) ? value : nil
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
