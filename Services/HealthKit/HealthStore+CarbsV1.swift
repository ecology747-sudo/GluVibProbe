//
//  HealthStore+CarbsV1.swift
//  GluVibProbe
//
//  Domain: Nutrition / Carbs
//  Screen Type: HealthStore Metric Extension V1
//
//  Purpose
//  - Owns the read-only Apple Health carbs fetch pipeline for Carbs V1.
//  - Resolves read-auth issues via deterministic permission-only probe logic.
//  - Publishes today, last-90-days, monthly, 365-day and raw-event carbs data into HealthStore.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT Published Carbs Values) → ViewModels → Views
//
//  Key Connections
//  - CarbsViewModelV1
//  - NutritionOverviewViewModelV1
//  - Metabolic MainChart nutrition overlay
//  - HistoryViewModelV1
//
//  Important
//  - carbsReadAuthIssueV1 is set EXCLUSIVELY by probeCarbsReadAuthIssueV1Async().
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
    func probeCarbsReadAuthIssueV1Async() async -> Bool {
        if isPreview {
            carbsReadAuthIssueV1 = false
            GluLog.healthStore.debug("carbs probe skipped | preview=true")
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = CarbsProbeGateV1.cachedResultIfFresh(for: key) {
            carbsReadAuthIssueV1 = cached
            GluLog.healthStore.debug("carbs probe cache hit | authIssue=\(cached, privacy: .public)")
            return cached
        }

        if let inFlight = CarbsProbeGateV1.inFlightTask(for: key) {
            let value = await inFlight.value
            carbsReadAuthIssueV1 = value
            GluLog.healthStore.debug("carbs probe inFlight reused | authIssue=\(value, privacy: .public)")
            return value
        }

        GluLog.healthStore.debug("carbs probe started")

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
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

        CarbsProbeGateV1.setInFlight(task, for: key)
        let result = await task.value
        CarbsProbeGateV1.finish(with: result, for: key)

        carbsReadAuthIssueV1 = result
        GluLog.healthStore.notice("carbs probe finished | authIssue=\(result, privacy: .public)")
        return result
    }

    // ============================================================
    // MARK: - Public API (Today / 90d / Monthly / 365)
    // ============================================================

    @MainActor
    func fetchCarbsTodayV1() {
        if isPreview {
            carbsReadAuthIssueV1 = false

            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())

            let value = previewDailyCarbs
                .first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
                .grams ?? 0

            todayCarbsGrams = max(0, value)
            GluLog.healthStore.debug("fetchCarbsTodayV1 skipped | preview=true")
            return
        }

        GluLog.healthStore.debug("fetchCarbsTodayV1 started")

        Task { @MainActor in
            let authIssue = await probeCarbsReadAuthIssueV1Async()
            if authIssue {
                self.todayCarbsGrams = 0
                GluLog.healthStore.notice("fetchCarbsTodayV1 skipped | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
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
                    if self.carbsReadAuthIssueV1 {
                        self.todayCarbsGrams = 0
                        GluLog.healthStore.notice("fetchCarbsTodayV1 finished | blockedByAuthIssue=true")
                        return
                    }

                    self.todayCarbsGrams = max(0, Int(value.rounded()))
                    GluLog.healthStore.notice("fetchCarbsTodayV1 finished | todayCarbs=\(self.todayCarbsGrams, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchLast90DaysCarbsV1() {
        if isPreview {
            carbsReadAuthIssueV1 = false
            let slice = Array(previewDailyCarbs.suffix(90)).sorted { $0.date < $1.date }
            last90DaysCarbs = slice
            GluLog.healthStore.debug("fetchLast90DaysCarbsV1 skipped | preview=true")
            return
        }

        GluLog.healthStore.debug("fetchLast90DaysCarbsV1 started")

        Task { @MainActor in
            let authIssue = await probeCarbsReadAuthIssueV1Async()
            if authIssue {
                self.last90DaysCarbs = []
                GluLog.healthStore.notice("fetchLast90DaysCarbsV1 skipped | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
                return
            }

            fetchDailySeriesCarbsV1(
                quantityType: type,
                unit: .gram(),
                days: 90
            ) { [weak self] entries in
                guard let self else { return }

                DispatchQueue.main.async {
                    if self.carbsReadAuthIssueV1 {
                        self.last90DaysCarbs = []
                        GluLog.healthStore.notice("fetchLast90DaysCarbsV1 finished | blockedByAuthIssue=true")
                        return
                    }

                    self.last90DaysCarbs = entries
                    GluLog.healthStore.notice("fetchLast90DaysCarbsV1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }

    @MainActor
    func fetchLast90DaysCarbsV1Async() async {
        if isPreview {
            carbsReadAuthIssueV1 = false
            let slice = Array(previewDailyCarbs.suffix(90)).sorted { $0.date < $1.date }
            last90DaysCarbs = slice
            GluLog.healthStore.debug("fetchLast90DaysCarbsV1Async skipped | preview=true")
            return
        }

        GluLog.healthStore.debug("fetchLast90DaysCarbsV1Async started")

        let authIssue = await probeCarbsReadAuthIssueV1Async()
        if authIssue {
            last90DaysCarbs = []
            GluLog.healthStore.notice("fetchLast90DaysCarbsV1Async skipped | authIssue=true")
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
            return
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            fetchDailySeriesCarbsV1(
                quantityType: type,
                unit: .gram(),
                days: 90
            ) { [weak self] entries in
                guard let self else { return }

                DispatchQueue.main.async {
                    if self.carbsReadAuthIssueV1 {
                        self.last90DaysCarbs = []
                        GluLog.healthStore.notice("fetchLast90DaysCarbsV1Async finished | blockedByAuthIssue=true")
                        continuation.resume(returning: ())
                        return
                    }

                    self.last90DaysCarbs = entries
                    GluLog.healthStore.notice("fetchLast90DaysCarbsV1Async finished | entries=\(entries.count, privacy: .public)")
                    continuation.resume(returning: ())
                }
            }
        }
    }

    @MainActor
    func fetchMonthlyCarbsV1() {
        if isPreview {
            carbsReadAuthIssueV1 = false

            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var bucket: [DateComponents: Int] = [:]
            for e in previewDailyCarbs where e.date >= startDate && e.date <= startOfToday {
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

            monthlyCarbs = result
            GluLog.healthStore.debug("fetchMonthlyCarbsV1 skipped | preview=true")
            return
        }

        GluLog.healthStore.debug("fetchMonthlyCarbsV1 started")

        Task { @MainActor in
            let authIssue = await probeCarbsReadAuthIssueV1Async()
            if authIssue {
                self.monthlyCarbs = []
                GluLog.healthStore.notice("fetchMonthlyCarbsV1 skipped | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
                return
            }

            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

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

                if self.carbsReadAuthIssueV1 {
                    DispatchQueue.main.async {
                        self.monthlyCarbs = []
                        GluLog.healthStore.notice("fetchMonthlyCarbsV1 finished | blockedByAuthIssue=true")
                    }
                    return
                }

                guard let results else {
                    DispatchQueue.main.async {
                        self.monthlyCarbs = []
                        GluLog.healthStore.notice("fetchMonthlyCarbsV1 finished | entries=0")
                    }
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
                    if self.carbsReadAuthIssueV1 {
                        self.monthlyCarbs = []
                        GluLog.healthStore.notice("fetchMonthlyCarbsV1 finished | blockedByAuthIssue=true")
                        return
                    }

                    self.monthlyCarbs = temp
                    GluLog.healthStore.notice("fetchMonthlyCarbsV1 finished | entries=\(temp.count, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchCarbsDaily365V1() {
        if isPreview {
            carbsReadAuthIssueV1 = false
            let slice = Array(previewDailyCarbs.suffix(365)).sorted { $0.date < $1.date }
            carbsDaily365 = slice
            GluLog.healthStore.debug("fetchCarbsDaily365V1 skipped | preview=true")
            return
        }

        GluLog.healthStore.debug("fetchCarbsDaily365V1 started")

        Task { @MainActor in
            let authIssue = await probeCarbsReadAuthIssueV1Async()
            if authIssue {
                self.carbsDaily365 = []
                GluLog.healthStore.notice("fetchCarbsDaily365V1 skipped | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
                return
            }

            fetchDailySeriesCarbsV1(
                quantityType: type,
                unit: .gram(),
                days: 365
            ) { [weak self] entries in
                guard let self else { return }

                DispatchQueue.main.async {
                    if self.carbsReadAuthIssueV1 {
                        self.carbsDaily365 = []
                        GluLog.healthStore.notice("fetchCarbsDaily365V1 finished | blockedByAuthIssue=true")
                        return
                    }

                    self.carbsDaily365 = entries
                    GluLog.healthStore.notice("fetchCarbsDaily365V1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }

    // ============================================================
    // MARK: - Raw Events (3 Days) — Metabolic DayProfile Overlay
    // ============================================================

    @MainActor
    func fetchCarbEvents3DaysV1() {
        if isPreview {
            carbsReadAuthIssueV1 = false

            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())

            var temp: [NutritionEvent] = []

            for dayOffset in stride(from: 2, through: 0, by: -1) {
                guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: todayStart) else { continue }
                let grams = previewDailyCarbs.first(where: { calendar.isDate($0.date, inSameDayAs: day) })?.grams ?? 0
                guard grams > 0 else { continue }

                let noon = calendar.date(byAdding: .hour, value: 12, to: day) ?? day
                temp.append(
                    NutritionEvent(
                        id: UUID(),
                        timestamp: noon,
                        grams: Double(grams),
                        kind: .carbs
                    )
                )
            }

            carbEvents3Days = temp.sorted { $0.timestamp < $1.timestamp }
            GluLog.healthStore.debug("fetchCarbEvents3DaysV1 skipped | preview=true")
            return
        }

        GluLog.healthStore.debug("fetchCarbEvents3DaysV1 started")

        Task { @MainActor in
            let authIssue = await probeCarbsReadAuthIssueV1Async()
            if authIssue {
                self.carbEvents3Days = []
                GluLog.healthStore.notice("fetchCarbEvents3DaysV1 skipped | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
                return
            }

            fetchRawCarbEventsV1(
                quantityType: type,
                unit: .gram(),
                days: 3
            ) { [weak self] events in
                guard let self else { return }

                DispatchQueue.main.async {
                    if self.carbsReadAuthIssueV1 {
                        self.carbEvents3Days = []
                        GluLog.healthStore.notice("fetchCarbEvents3DaysV1 finished | blockedByAuthIssue=true")
                        return
                    }

                    self.carbEvents3Days = events
                    GluLog.healthStore.notice("fetchCarbEvents3DaysV1 finished | events=\(events.count, privacy: .public)")
                }
            }
        }
    }

    // ============================================================
    // MARK: - Raw Events (History Window, 10 Days)
    // ============================================================

    @MainActor
    func fetchCarbEventsForHistoryWindowV1(days: Int = 10) {
        if isPreview {
            carbsReadAuthIssueV1 = false
            carbEventsHistoryWindowV1 = []
            GluLog.healthStore.debug("fetchCarbEventsForHistoryWindowV1 skipped | preview=true")
            return
        }

        GluLog.healthStore.debug("fetchCarbEventsForHistoryWindowV1 started | days=\(days, privacy: .public)")

        Task { @MainActor in
            let authIssue = await probeCarbsReadAuthIssueV1Async()
            if authIssue {
                self.carbEventsHistoryWindowV1 = []
                GluLog.healthStore.notice("fetchCarbEventsForHistoryWindowV1 skipped | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
                return
            }

            fetchRawCarbEventsV1(
                quantityType: type,
                unit: .gram(),
                days: max(1, days)
            ) { [weak self] events in
                guard let self else { return }

                DispatchQueue.main.async {
                    if self.carbsReadAuthIssueV1 {
                        self.carbEventsHistoryWindowV1 = []
                        GluLog.healthStore.notice("fetchCarbEventsForHistoryWindowV1 finished | blockedByAuthIssue=true")
                        return
                    }

                    self.carbEventsHistoryWindowV1 = events
                    GluLog.healthStore.notice("fetchCarbEventsForHistoryWindowV1 finished | events=\(events.count, privacy: .public)")
                }
            }
        }
    }
}

private extension HealthStore {

    // ============================================================
    // MARK: - Daily Series Helper
    // ============================================================

    func fetchDailySeriesCarbsV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyCarbsEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            DispatchQueue.main.async { assign([]) }
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

            if self.carbsReadAuthIssueV1 {
                DispatchQueue.main.async { assign([]) }
                return
            }

            guard let results else {
                DispatchQueue.main.async { assign([]) }
                return
            }

            var daily: [DailyCarbsEntry] = []
            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                daily.append(
                    DailyCarbsEntry(
                        date: stats.startDate,
                        grams: max(0, Int(value.rounded()))
                    )
                )
            }

            DispatchQueue.main.async {
                if self.carbsReadAuthIssueV1 {
                    assign([])
                    return
                }

                assign(daily.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - Raw Events Helper
    // ============================================================

    func fetchRawCarbEventsV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([NutritionEvent]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        let spanDays = max(1, days)
        guard let startDate = calendar.date(byAdding: .day, value: -(spanDays - 1), to: todayStart) else {
            DispatchQueue.main.async { assign([]) }
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(
            sampleType: quantityType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard let self else { return }

            if self.carbsReadAuthIssueV1 {
                DispatchQueue.main.async { assign([]) }
                return
            }

            let quantitySamples = (samples as? [HKQuantitySample]) ?? []

            let events: [NutritionEvent] = quantitySamples.map { s in
                let grams = s.quantity.doubleValue(for: unit)
                return NutritionEvent(
                    id: UUID(),
                    timestamp: s.startDate,
                    grams: max(0, grams),
                    kind: .carbs
                )
            }

            DispatchQueue.main.async {
                if self.carbsReadAuthIssueV1 {
                    assign([])
                    return
                }

                assign(events)
            }
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - File-local Probe Gate
// ============================================================

private enum CarbsProbeGateV1 {

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
