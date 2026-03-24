//
//  HealthStore+ExerciseTimeV1.swift
//  GluVibProbe
//
//  Domain: Activity / Exercise Time
//  Screen Type: HealthStore Metric Extension V1
//
//  Purpose
//  - Owns the read-only Apple Health exercise-time fetch pipeline for Exercise Time V1.
//  - Resolves read-auth issues via deterministic permission-only probe logic.
//  - Publishes raw daily exercise-time series into HealthStore.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT Published Exercise Time Values) → ViewModels / Bootstrap → Views
//
//  Key Connections
//  - activeTimeDaily365 (kept intentionally for compatibility)
//  - ActivityOverviewViewModelV1
//  - Bootstrap async wrappers
//
//  Important
//  - exerciseTimeReadAuthIssueV1 is set EXCLUSIVELY by probeExerciseTimeReadAuthIssueV1Async().
//  - Probe is permission-only: empty results are DATA state, never permission state.
//  - All fetches are DATA ONLY and may be blocked only by a real read-auth issue.
//

import Foundation
import HealthKit

// ============================================================
// MARK: - HealthStore + Exercise Time
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - Auth Issue Classification
    // ============================================================

    private func _exerciseTimeIsReadAuthIssueV1(_ error: Error?) -> Bool {
        guard let ns = error as NSError? else { return false }
        guard ns.domain == HKErrorDomain else { return false }
        guard let code = HKError.Code(rawValue: ns.code) else { return false }
        return code == .errorAuthorizationDenied || code == .errorAuthorizationNotDetermined
    }

    // 🟨 UPDATED
    private func _exerciseTimeResolveReadAuthIssueV1(
        error: Error?
    ) -> Bool {
        _exerciseTimeIsReadAuthIssueV1(error)
    }

    // ============================================================
    // MARK: - Deterministic Read-Query Probe (Single-Writer)
    // ============================================================

    @MainActor
    func probeExerciseTimeReadAuthIssueV1Async() async -> Bool {

        if isPreview {
            exerciseTimeReadAuthIssueV1 = false // 🟨 UPDATED
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = ExerciseTimeProbeGateV1.cachedResultIfFresh(for: key) {
            exerciseTimeReadAuthIssueV1 = cached
            return cached
        }

        if let inFlight = ExerciseTimeProbeGateV1.inFlightTask(for: key) {
            let value = await inFlight.value
            exerciseTimeReadAuthIssueV1 = value
            return value
        }

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }

            guard let type = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
                return true
            }

            let now = Date()

            // 🟨 UPDATED
            let predicate = HKQuery.predicateForSamples(
                withStart: nil,
                end: now,
                options: []
            )
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
                    let resolved = self._exerciseTimeResolveReadAuthIssueV1(error: error)
                    continuation.resume(returning: resolved)
                }

                self.healthStore.execute(query)
            }

            return isAuthIssue
        }

        ExerciseTimeProbeGateV1.setInFlight(task, for: key)
        let result = await task.value
        ExerciseTimeProbeGateV1.finish(with: result, for: key)

        exerciseTimeReadAuthIssueV1 = result
        return result
    }

    // ============================================================
    // MARK: - Public API (Entry Point)
    // ============================================================

    /// Loads Exercise Minutes (appleExerciseTime) for the last 365 days
    /// and writes them into the existing property `activeTimeDaily365`.
    ///
    /// Naming note:
    /// - Function intentionally uses ExerciseTime naming
    /// - Property intentionally stays `activeTimeDaily365`
    ///   until a later controlled refactor step
    func fetchExerciseTimeDaily365V1() {

        if isPreview {
            let slice = Array(previewDailyExerciseMinutes.suffix(365))
            DispatchQueue.main.async {
                self.activeTimeDaily365 = slice
            }
            return
        }

        Task { @MainActor in
            await self.loadExerciseTimeDaily365V1Async()
        }
    }

    // ============================================================
    // MARK: - True Async Loader
    // ============================================================

    @MainActor
    func loadExerciseTimeDaily365V1Async() async {

        if isPreview {
            let slice = Array(previewDailyExerciseMinutes.suffix(365))
            self.activeTimeDaily365 = slice
            return
        }

        let authIssue = await probeExerciseTimeReadAuthIssueV1Async()
        if authIssue {
            self.activeTimeDaily365 = []
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
            self.activeTimeDaily365 = []
            return
        }

        let entries = await fetchDailyExerciseMinutesSeriesV1Async(
            quantityType: type,
            unit: .minute(),
            days: 365
        )

        if exerciseTimeReadAuthIssueV1 {
            self.activeTimeDaily365 = []
            return
        }

        self.activeTimeDaily365 = entries
    }

    // ============================================================
    // MARK: - Private Helpers (Async / Legacy)
    // ============================================================

    private func fetchDailyExerciseMinutesSeriesV1Async(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int
    ) async -> [DailyExerciseMinutesEntry] {

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: []
        )

        let interval = DateComponents(day: 1)

        return await withCheckedContinuation { continuation in

            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                guard error == nil, let results else {
                    continuation.resume(returning: [])
                    return
                }

                var daily: [DailyExerciseMinutesEntry] = []
                daily.reserveCapacity(days)

                results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                    let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                    daily.append(
                        DailyExerciseMinutesEntry(
                            date: stats.startDate,
                            minutes: Int(value.rounded())
                        )
                    )
                }

                continuation.resume(returning: daily.sorted { $0.date < $1.date })
            }

            self.healthStore.execute(query)
        }
    }

    private func fetchDailyExerciseMinutesSeriesV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyExerciseMinutesEntry]) -> Void
    ) {

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(
            byAdding: .day,
            value: -(days - 1),
            to: todayStart
        ) else {
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: []
        )

        var daily: [DailyExerciseMinutesEntry] = []
        let interval = DateComponents(day: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            results?.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0

                daily.append(
                    DailyExerciseMinutesEntry(
                        date: stats.startDate,
                        minutes: Int(value.rounded())
                    )
                )
            }

            DispatchQueue.main.async {
                assign(
                    daily.sorted { $0.date < $1.date }
                )
            }
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - File-local Probe Gate
// ============================================================

private enum ExerciseTimeProbeGateV1 {

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
