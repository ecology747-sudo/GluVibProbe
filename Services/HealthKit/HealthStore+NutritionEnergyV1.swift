//
//  HealthStore+NutritionEnergyV1.swift
//  GluVibProbe
//
//  Domain: Nutrition / Energy
//  Screen Type: HealthStore Metric Extension V1
//
//  Purpose
//  - Owns the read-only Apple Health nutrition energy fetch pipeline for Nutrition Energy V1.
//  - Resolves read-auth issues via deterministic permission-only probe logic.
//  - Publishes today, last-90-days, monthly and 365-day nutrition energy data into HealthStore.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT Published Nutrition Energy Values) → ViewModels → Views
//
//  Key Connections
//  - NutritionEnergyViewModelV1
//  - NutritionOverviewViewModelV1
//
//  Important
//  - nutritionEnergyReadAuthIssueV1 is set EXCLUSIVELY by probeNutritionEnergyReadAuthIssueV1Async().
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
    func probeNutritionEnergyReadAuthIssueV1Async() async -> Bool {
        if isPreview {
            nutritionEnergyReadAuthIssueV1 = false
            GluLog.nutritionEnergy.debug("nutritionEnergy probe skipped | preview=true")
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = NutritionEnergyProbeGateV1.cachedResultIfFresh(for: key) {
            nutritionEnergyReadAuthIssueV1 = cached
            GluLog.nutritionEnergy.debug("nutritionEnergy probe cache hit | authIssue=\(cached, privacy: .public)")
            return cached
        }

        if let inFlight = NutritionEnergyProbeGateV1.inFlightTask(for: key) {
            let v = await inFlight.value
            nutritionEnergyReadAuthIssueV1 = v
            GluLog.nutritionEnergy.debug("nutritionEnergy probe joined inFlight | authIssue=\(v, privacy: .public)")
            return v
        }

        GluLog.nutritionEnergy.notice("nutritionEnergy probe started")

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
                GluLog.nutritionEnergy.error("nutritionEnergy probe failed | quantityTypeUnavailable=true")
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

        NutritionEnergyProbeGateV1.setInFlight(task, for: key)
        let result = await task.value
        NutritionEnergyProbeGateV1.finish(with: result, for: key)

        nutritionEnergyReadAuthIssueV1 = result
        GluLog.nutritionEnergy.notice("nutritionEnergy probe finished | authIssue=\(result, privacy: .public)")
        return result
    }

    // ============================================================
    // MARK: - Public API (Today / 90d / Monthly / 365)
    // ============================================================

    @MainActor
    func fetchNutritionEnergyTodayV1() {
        if isPreview {
            nutritionEnergyReadAuthIssueV1 = false
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())

            let value = previewDailyNutritionEnergy
                .first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
                .energyKcal ?? 0

            todayNutritionEnergyKcal = max(0, value)
            GluLog.nutritionEnergy.debug("fetchNutritionEnergyTodayV1 preview applied | todayKcal=\(self.todayNutritionEnergyKcal, privacy: .public)")
            return
        }

        GluLog.nutritionEnergy.notice("fetchNutritionEnergyTodayV1 started")

        Task { @MainActor in
            let authIssue = await probeNutritionEnergyReadAuthIssueV1Async()
            if authIssue {
                todayNutritionEnergyKcal = 0
                GluLog.nutritionEnergy.notice("fetchNutritionEnergyTodayV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
                GluLog.nutritionEnergy.error("fetchNutritionEnergyTodayV1 failed | quantityTypeUnavailable=true")
                return
            }

            let calendar = Calendar.current
            let start = calendar.startOfDay(for: Date())
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { [weak self] _, result, _ in
                guard let self else { return }
                let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0

                DispatchQueue.main.async {
                    if self.nutritionEnergyReadAuthIssueV1 {
                        self.todayNutritionEnergyKcal = 0
                        GluLog.nutritionEnergy.notice("fetchNutritionEnergyTodayV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.todayNutritionEnergyKcal = max(0, Int(value.rounded()))
                    GluLog.nutritionEnergy.notice("fetchNutritionEnergyTodayV1 finished | todayKcal=\(self.todayNutritionEnergyKcal, privacy: .public)")
                }
            }

            self.healthStore.execute(query)
        }
    }

    @MainActor
    func fetchLast90DaysNutritionEnergyV1() {
        if isPreview {
            nutritionEnergyReadAuthIssueV1 = false
            let slice = Array(previewDailyNutritionEnergy.suffix(90)).sorted { $0.date < $1.date }
            last90DaysNutritionEnergy = slice
            GluLog.nutritionEnergy.debug("fetchLast90DaysNutritionEnergyV1 preview applied | entries=\(slice.count, privacy: .public)")
            return
        }

        GluLog.nutritionEnergy.notice("fetchLast90DaysNutritionEnergyV1 started")

        Task { @MainActor in
            let authIssue = await probeNutritionEnergyReadAuthIssueV1Async()
            if authIssue {
                last90DaysNutritionEnergy = []
                GluLog.nutritionEnergy.notice("fetchLast90DaysNutritionEnergyV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
                GluLog.nutritionEnergy.error("fetchLast90DaysNutritionEnergyV1 failed | quantityTypeUnavailable=true")
                return
            }

            fetchDailySeriesNutritionEnergyV1(
                quantityType: type,
                unit: .kilocalorie(),
                days: 90
            ) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.nutritionEnergyReadAuthIssueV1 {
                        self.last90DaysNutritionEnergy = []
                        GluLog.nutritionEnergy.notice("fetchLast90DaysNutritionEnergyV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.last90DaysNutritionEnergy = entries
                    GluLog.nutritionEnergy.notice("fetchLast90DaysNutritionEnergyV1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }

    @MainActor
    func fetchMonthlyNutritionEnergyV1() {
        if isPreview {
            nutritionEnergyReadAuthIssueV1 = false
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var bucket: [DateComponents: Int] = [:]
            for e in previewDailyNutritionEnergy where e.date >= startDate && e.date <= startOfToday {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                bucket[comps, default: 0] += max(0, e.energyKcal)
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

            monthlyNutritionEnergy = result
            GluLog.nutritionEnergy.debug("fetchMonthlyNutritionEnergyV1 preview applied | entries=\(result.count, privacy: .public)")
            return
        }

        GluLog.nutritionEnergy.notice("fetchMonthlyNutritionEnergyV1 started")

        Task { @MainActor in
            let authIssue = await probeNutritionEnergyReadAuthIssueV1Async()
            if authIssue {
                monthlyNutritionEnergy = []
                GluLog.nutritionEnergy.notice("fetchMonthlyNutritionEnergyV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
                GluLog.nutritionEnergy.error("fetchMonthlyNutritionEnergyV1 failed | quantityTypeUnavailable=true")
                return
            }

            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else {
                GluLog.nutritionEnergy.error("fetchMonthlyNutritionEnergyV1 failed | startDateUnavailable=true")
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

                if self.nutritionEnergyReadAuthIssueV1 {
                    DispatchQueue.main.async { self.monthlyNutritionEnergy = [] }
                    GluLog.nutritionEnergy.notice("fetchMonthlyNutritionEnergyV1 finished | blockedByAuthIssue=true")
                    return
                }

                guard let results else {
                    DispatchQueue.main.async { self.monthlyNutritionEnergy = [] }
                    GluLog.nutritionEnergy.notice("fetchMonthlyNutritionEnergyV1 finished | resultsEmpty=true")
                    return
                }

                var temp: [MonthlyMetricEntry] = []
                temp.reserveCapacity(5)

                results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                    let value = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                    let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))
                    temp.append(
                        MonthlyMetricEntry(
                            monthShort: monthShort,
                            value: max(0, Int(value.rounded()))
                        )
                    )
                }

                DispatchQueue.main.async {
                    if self.nutritionEnergyReadAuthIssueV1 {
                        self.monthlyNutritionEnergy = []
                        GluLog.nutritionEnergy.notice("fetchMonthlyNutritionEnergyV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.monthlyNutritionEnergy = temp
                    GluLog.nutritionEnergy.notice("fetchMonthlyNutritionEnergyV1 finished | entries=\(temp.count, privacy: .public)")
                }
            }

            self.healthStore.execute(query)
        }
    }

    @MainActor
    func fetchNutritionEnergyDaily365V1() {
        if isPreview {
            nutritionEnergyReadAuthIssueV1 = false
            let slice = Array(previewDailyNutritionEnergy.suffix(365)).sorted { $0.date < $1.date }
            nutritionEnergyDaily365 = slice
            GluLog.nutritionEnergy.debug("fetchNutritionEnergyDaily365V1 preview applied | entries=\(slice.count, privacy: .public)")
            return
        }

        GluLog.nutritionEnergy.notice("fetchNutritionEnergyDaily365V1 started")

        Task { @MainActor in
            let authIssue = await probeNutritionEnergyReadAuthIssueV1Async()
            if authIssue {
                nutritionEnergyDaily365 = []
                GluLog.nutritionEnergy.notice("fetchNutritionEnergyDaily365V1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
                GluLog.nutritionEnergy.error("fetchNutritionEnergyDaily365V1 failed | quantityTypeUnavailable=true")
                return
            }

            fetchDailySeriesNutritionEnergyV1(
                quantityType: type,
                unit: .kilocalorie(),
                days: 365
            ) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.nutritionEnergyReadAuthIssueV1 {
                        self.nutritionEnergyDaily365 = []
                        GluLog.nutritionEnergy.notice("fetchNutritionEnergyDaily365V1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.nutritionEnergyDaily365 = entries
                    GluLog.nutritionEnergy.notice("fetchNutritionEnergyDaily365V1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }
}

// ============================================================
// MARK: - Private Helpers
// ============================================================

private extension HealthStore {

    func fetchDailySeriesNutritionEnergyV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyNutritionEnergyEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            DispatchQueue.main.async { assign([]) }
            GluLog.nutritionEnergy.error("fetchDailySeriesNutritionEnergyV1 failed | startDateUnavailable=true")
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

            if self.nutritionEnergyReadAuthIssueV1 {
                DispatchQueue.main.async { assign([]) }
                GluLog.nutritionEnergy.notice("fetchDailySeriesNutritionEnergyV1 finished | blockedByAuthIssue=true")
                return
            }

            guard let results else {
                DispatchQueue.main.async { assign([]) }
                GluLog.nutritionEnergy.notice("fetchDailySeriesNutritionEnergyV1 finished | resultsEmpty=true")
                return
            }

            var daily: [DailyNutritionEnergyEntry] = []
            daily.reserveCapacity(days)

            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                daily.append(
                    DailyNutritionEnergyEntry(
                        date: stats.startDate,
                        energyKcal: max(0, Int(value.rounded()))
                    )
                )
            }

            let result = daily.sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                if self.nutritionEnergyReadAuthIssueV1 {
                    assign([])
                    GluLog.nutritionEnergy.notice("fetchDailySeriesNutritionEnergyV1 finished | blockedByAuthIssue=true")
                    return
                }
                assign(result)
                GluLog.nutritionEnergy.debug("fetchDailySeriesNutritionEnergyV1 finished | entries=\(result.count, privacy: .public)")
            }
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - File-local Probe Gate
// ============================================================

private enum NutritionEnergyProbeGateV1 {

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
