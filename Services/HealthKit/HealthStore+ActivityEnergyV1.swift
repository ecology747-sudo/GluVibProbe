//
//  HealthStore+ActivityEnergyV1.swift
//  GluVibProbe
//
//  Domain: Activity / Active Energy
//  Screen Type: HealthStore Metric Extension V1
//
//  Purpose
//  - Owns the read-only Apple Health active-energy fetch pipeline for Active Energy V1.
//  - Resolves read-auth issues via deterministic permission-only probe logic.
//  - Publishes today, last-90-days, monthly and 365-day active-energy data into HealthStore.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT Published Active Energy Values) → ViewModels → Views
//
//  Key Connections
//  - ActivityEnergyViewModelV1
//  - ActivityOverviewViewModelV1
//  - PremiumOverviewViewV1
//
//  Important
//  - activeEnergyReadAuthIssueV1 is set EXCLUSIVELY by probeActiveEnergyReadAuthIssueV1Async().
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

    private func _activeEnergyIsReadAuthIssueV1(_ error: Error?) -> Bool {
        guard let ns = error as NSError? else { return false }
        guard ns.domain == HKErrorDomain else { return false }
        guard let code = HKError.Code(rawValue: ns.code) else { return false }
        return code == .errorAuthorizationDenied || code == .errorAuthorizationNotDetermined
    }

    // 🟨 UPDATED
    private func _activeEnergyResolveReadAuthIssueV1(
        error: Error?
    ) -> Bool {
        _activeEnergyIsReadAuthIssueV1(error)
    }

    // ============================================================
    // MARK: - Deterministic Read-Query Probe (Single-Writer)
    // ============================================================

    @MainActor
    func probeActiveEnergyReadAuthIssueV1Async() async -> Bool {

        if isPreview {
            activeEnergyReadAuthIssueV1 = false // 🟨 UPDATED
            GluLog.healthStore.debug("activeEnergy probe skipped | preview=true")
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = ActiveEnergyProbeGateV1.cachedResultIfFresh(for: key) {
            activeEnergyReadAuthIssueV1 = cached
            GluLog.healthStore.debug("activeEnergy probe cache hit | authIssue=\(cached, privacy: .public)")
            return cached
        }

        if let inFlight = ActiveEnergyProbeGateV1.inFlightTask(for: key) {
            let v = await inFlight.value
            activeEnergyReadAuthIssueV1 = v
            GluLog.healthStore.debug("activeEnergy probe joined inFlight | authIssue=\(v, privacy: .public)")
            return v
        }

        GluLog.healthStore.notice("activeEnergy probe started")

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }

            guard let qType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
                GluLog.healthStore.error("activeEnergy probe failed | quantityTypeUnavailable=true")
                return true
            }

            let now = Date()

            // 🟨 UPDATED
            let predicate = HKQuery.predicateForSamples(withStart: nil, end: now, options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let isAuthIssue: Bool = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: qType,
                    predicate: predicate,
                    limit: 1,
                    sortDescriptors: [sort]
                ) { [weak self] _, _, error in
                    guard let self else {
                        continuation.resume(returning: false)
                        return
                    }

                    // 🟨 UPDATED
                    let resolved = self._activeEnergyResolveReadAuthIssueV1(error: error)
                    continuation.resume(returning: resolved)
                }

                self.healthStore.execute(query)
            }

            return isAuthIssue
        }

        ActiveEnergyProbeGateV1.setInFlight(task, for: key)
        let result = await task.value
        ActiveEnergyProbeGateV1.finish(with: result, for: key)

        activeEnergyReadAuthIssueV1 = result
        GluLog.healthStore.notice("activeEnergy probe finished | authIssue=\(result, privacy: .public)")
        return result
    }

    // ============================================================
    // MARK: - Public API (Today / 90d / Monthly / 365)
    // ============================================================

    @MainActor
    func fetchActiveEnergyTodayV1() {
        if isPreview {
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())

            let value = previewDailyActiveEnergy
                .first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
                .activeEnergy ?? 0

            todayActiveEnergy = max(0, value)
            GluLog.healthStore.debug("fetchActiveEnergyTodayV1 preview applied | todayActiveEnergy=\(self.todayActiveEnergy, privacy: .public)")
            return
        }

        GluLog.healthStore.notice("fetchActiveEnergyTodayV1 started")

        Task { @MainActor in
            let authIssue = await probeActiveEnergyReadAuthIssueV1Async()
            if authIssue {
                todayActiveEnergy = 0
                GluLog.healthStore.notice("fetchActiveEnergyTodayV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
                GluLog.healthStore.error("fetchActiveEnergyTodayV1 failed | quantityTypeUnavailable=true")
                return
            }

            let start = Calendar.current.startOfDay(for: Date())
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: Date(),
                options: .strictStartDate
            )

            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { [weak self] _, result, _ in
                guard let self else { return }
                let value = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0

                DispatchQueue.main.async {
                    if self.activeEnergyReadAuthIssueV1 {
                        self.todayActiveEnergy = 0
                        GluLog.healthStore.notice("fetchActiveEnergyTodayV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.todayActiveEnergy = max(0, Int(value))
                    GluLog.healthStore.notice("fetchActiveEnergyTodayV1 finished | todayActiveEnergy=\(self.todayActiveEnergy, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchLast90DaysActiveEnergyV1() {
        if isPreview {
            let slice = Array(previewDailyActiveEnergy.suffix(90))
                .sorted { $0.date < $1.date }
            last90DaysActiveEnergy = slice
            GluLog.healthStore.debug("fetchLast90DaysActiveEnergyV1 preview applied | entries=\(slice.count, privacy: .public)")
            return
        }

        GluLog.healthStore.notice("fetchLast90DaysActiveEnergyV1 started")

        Task { @MainActor in
            let authIssue = await probeActiveEnergyReadAuthIssueV1Async()
            if authIssue {
                last90DaysActiveEnergy = []
                GluLog.healthStore.notice("fetchLast90DaysActiveEnergyV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
                GluLog.healthStore.error("fetchLast90DaysActiveEnergyV1 failed | quantityTypeUnavailable=true")
                return
            }

            fetchDailySeriesActiveEnergyV1(
                quantityType: type,
                unit: HKUnit.kilocalorie(),
                days: 90
            ) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.activeEnergyReadAuthIssueV1 {
                        self.last90DaysActiveEnergy = []
                        GluLog.healthStore.notice("fetchLast90DaysActiveEnergyV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.last90DaysActiveEnergy = entries
                    GluLog.healthStore.notice("fetchLast90DaysActiveEnergyV1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }

    @MainActor
    func fetchMonthlyActiveEnergyV1() {
        if isPreview {
            let months = ["Jul", "Aug", "Sep", "Okt", "Nov"]
            let values = months.map { _ in Int.random(in: 0...2_800) }
            monthlyActiveEnergy = zip(months, values).map { MonthlyMetricEntry(monthShort: $0.0, value: $0.1) }
            GluLog.healthStore.debug("fetchMonthlyActiveEnergyV1 preview applied | entries=\(self.monthlyActiveEnergy.count, privacy: .public)")
            return
        }

        GluLog.healthStore.notice("fetchMonthlyActiveEnergyV1 started")

        Task { @MainActor in
            let authIssue = await probeActiveEnergyReadAuthIssueV1Async()
            if authIssue {
                monthlyActiveEnergy = []
                GluLog.healthStore.notice("fetchMonthlyActiveEnergyV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
                GluLog.healthStore.error("fetchMonthlyActiveEnergyV1 failed | quantityTypeUnavailable=true")
                return
            }

            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else {
                GluLog.healthStore.error("fetchMonthlyActiveEnergyV1 failed | dateWindowUnavailable=true")
                return
            }

            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: startOfToday,
                options: .strictStartDate
            )

            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: DateComponents(month: 1)
            )

            query.initialResultsHandler = { [weak self] _, results, _ in
                guard let self else { return }

                if self.activeEnergyReadAuthIssueV1 {
                    DispatchQueue.main.async {
                        self.monthlyActiveEnergy = []
                        GluLog.healthStore.notice("fetchMonthlyActiveEnergyV1 finished | blockedByAuthIssue=true")
                    }
                    return
                }

                guard let results else {
                    DispatchQueue.main.async {
                        self.monthlyActiveEnergy = []
                        GluLog.healthStore.notice("fetchMonthlyActiveEnergyV1 finished | resultsEmpty=true")
                    }
                    return
                }

                var temp: [MonthlyMetricEntry] = []

                results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                    let value = stats.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                    let month = stats.startDate.formatted(.dateTime.month(.abbreviated))
                    temp.append(
                        MonthlyMetricEntry(
                            monthShort: month,
                            value: max(0, Int(value))
                        )
                    )
                }

                DispatchQueue.main.async {
                    if self.activeEnergyReadAuthIssueV1 {
                        self.monthlyActiveEnergy = []
                        GluLog.healthStore.notice("fetchMonthlyActiveEnergyV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.monthlyActiveEnergy = temp
                    GluLog.healthStore.notice("fetchMonthlyActiveEnergyV1 finished | entries=\(temp.count, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchActiveEnergyDaily365V1() {
        if isPreview {
            let slice = Array(previewDailyActiveEnergy.suffix(365))
                .sorted { $0.date < $1.date }
            activeEnergyDaily365 = slice
            GluLog.healthStore.debug("fetchActiveEnergyDaily365V1 preview applied | entries=\(slice.count, privacy: .public)")
            return
        }

        GluLog.healthStore.notice("fetchActiveEnergyDaily365V1 started")

        Task { @MainActor in
            let authIssue = await probeActiveEnergyReadAuthIssueV1Async()
            if authIssue {
                activeEnergyDaily365 = []
                GluLog.healthStore.notice("fetchActiveEnergyDaily365V1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
                GluLog.healthStore.error("fetchActiveEnergyDaily365V1 failed | quantityTypeUnavailable=true")
                return
            }

            fetchDailySeriesActiveEnergyV1(
                quantityType: type,
                unit: HKUnit.kilocalorie(),
                days: 365
            ) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.activeEnergyReadAuthIssueV1 {
                        self.activeEnergyDaily365 = []
                        GluLog.healthStore.notice("fetchActiveEnergyDaily365V1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.activeEnergyDaily365 = entries
                    GluLog.healthStore.notice("fetchActiveEnergyDaily365V1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }
}

// ============================================================
// MARK: - Private Helpers
// ============================================================

private extension HealthStore {

    func fetchDailySeriesActiveEnergyV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([ActivityEnergyEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(
            byAdding: .day,
            value: -(days - 1),
            to: startOfToday
        ) else {
            DispatchQueue.main.async {
                assign([])
            }
            GluLog.healthStore.error("fetchDailySeriesActiveEnergyV1 failed | startDateUnavailable=true")
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: []
        )

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results else {
                DispatchQueue.main.async {
                    assign([])
                }
                GluLog.healthStore.notice("fetchDailySeriesActiveEnergyV1 finished | resultsEmpty=true")
                return
            }

            var daily: [ActivityEnergyEntry] = []
            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                daily.append(
                    ActivityEnergyEntry(
                        date: stats.startDate,
                        activeEnergy: max(0, Int(value))
                    )
                )
            }

            let result = daily.sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                assign(result)
            }

            GluLog.healthStore.debug("fetchDailySeriesActiveEnergyV1 finished | entries=\(result.count, privacy: .public)")
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - File-local Probe Gate
// ============================================================

private enum ActiveEnergyProbeGateV1 {

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
