//
//  HealthStore+ProteinV1.swift
//  GluVibProbe
//
//  Domain: Nutrition / Protein
//  Screen Type: HealthStore Metric Extension V1
//
//  Purpose
//  - Owns the read-only Apple Health protein fetch pipeline for Protein V1.
//  - Resolves read-auth issues via deterministic permission-only probe logic.
//  - Publishes today, last-90-days, monthly, 365-day and raw-3-days protein data into HealthStore.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT Published Protein Values) → ViewModels → Views
//
//  Key Connections
//  - ProteinViewModelV1
//  - NutritionOverviewViewModelV1
//  - Metabolic MainChart nutrition overlay
//
//  Important
//  - proteinReadAuthIssueV1 is set EXCLUSIVELY by probeProteinReadAuthIssueV1Async().
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
    func probeProteinReadAuthIssueV1Async() async -> Bool {
        if isPreview {
            proteinReadAuthIssueV1 = false
            GluLog.protein.debug("protein probe skipped | preview=true")
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = ProteinProbeGateV1.cachedResultIfFresh(for: key) {
            proteinReadAuthIssueV1 = cached
            GluLog.protein.debug("protein probe cache hit | authIssue=\(cached, privacy: .public)")
            return cached
        }

        if let inFlight = ProteinProbeGateV1.inFlightTask(for: key) {
            let v = await inFlight.value
            proteinReadAuthIssueV1 = v
            GluLog.protein.debug("protein probe joined inFlight | authIssue=\(v, privacy: .public)")
            return v
        }

        GluLog.protein.notice("protein probe started")

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) else {
                GluLog.protein.error("protein probe failed | quantityTypeUnavailable=true")
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

        ProteinProbeGateV1.setInFlight(task, for: key)
        let result = await task.value
        ProteinProbeGateV1.finish(with: result, for: key)

        proteinReadAuthIssueV1 = result
        GluLog.protein.notice("protein probe finished | authIssue=\(result, privacy: .public)")
        return result
    }

    // ============================================================
    // MARK: - Public API (Today / 90d / Monthly / 365 / RAW3DAYS)
    // ============================================================

    @MainActor
    func fetchProteinTodayV1() {
        if isPreview {
            proteinReadAuthIssueV1 = false
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let value = previewDailyProtein
                .first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
                .grams ?? 0
            todayProteinGrams = max(0, value)
            GluLog.protein.debug("fetchProteinTodayV1 preview applied | todayProtein=\(self.todayProteinGrams, privacy: .public)")
            return
        }

        GluLog.protein.notice("fetchProteinTodayV1 started")

        Task { @MainActor in
            let authIssue = await probeProteinReadAuthIssueV1Async()
            if authIssue {
                todayProteinGrams = 0
                GluLog.protein.notice("fetchProteinTodayV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) else {
                GluLog.protein.error("fetchProteinTodayV1 failed | quantityTypeUnavailable=true")
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
                    if self.proteinReadAuthIssueV1 {
                        self.todayProteinGrams = 0
                        GluLog.protein.notice("fetchProteinTodayV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.todayProteinGrams = max(0, Int(value.rounded()))
                    GluLog.protein.notice("fetchProteinTodayV1 finished | todayProtein=\(self.todayProteinGrams, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchLast90DaysProteinV1() {
        if isPreview {
            proteinReadAuthIssueV1 = false
            let slice = Array(previewDailyProtein.suffix(90)).sorted { $0.date < $1.date }
            last90DaysProtein = slice
            GluLog.protein.debug("fetchLast90DaysProteinV1 preview applied | entries=\(slice.count, privacy: .public)")
            return
        }

        GluLog.protein.notice("fetchLast90DaysProteinV1 started")

        Task { @MainActor in
            let authIssue = await probeProteinReadAuthIssueV1Async()
            if authIssue {
                last90DaysProtein = []
                GluLog.protein.notice("fetchLast90DaysProteinV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) else {
                GluLog.protein.error("fetchLast90DaysProteinV1 failed | quantityTypeUnavailable=true")
                return
            }

            fetchDailySeriesProteinV1(
                quantityType: type,
                unit: .gram(),
                days: 90
            ) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.proteinReadAuthIssueV1 {
                        self.last90DaysProtein = []
                        GluLog.protein.notice("fetchLast90DaysProteinV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.last90DaysProtein = entries
                    GluLog.protein.notice("fetchLast90DaysProteinV1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }

    @MainActor
    func fetchMonthlyProteinV1() {
        if isPreview {
            proteinReadAuthIssueV1 = false
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var bucket: [DateComponents: Int] = [:]
            for e in previewDailyProtein where e.date >= startDate && e.date <= startOfToday {
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

            monthlyProtein = result
            GluLog.protein.debug("fetchMonthlyProteinV1 preview applied | entries=\(result.count, privacy: .public)")
            return
        }

        GluLog.protein.notice("fetchMonthlyProteinV1 started")

        Task { @MainActor in
            let authIssue = await probeProteinReadAuthIssueV1Async()
            if authIssue {
                monthlyProtein = []
                GluLog.protein.notice("fetchMonthlyProteinV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) else {
                GluLog.protein.error("fetchMonthlyProteinV1 failed | quantityTypeUnavailable=true")
                return
            }

            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else {
                GluLog.protein.error("fetchMonthlyProteinV1 failed | startDateUnavailable=true")
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

                if self.proteinReadAuthIssueV1 {
                    DispatchQueue.main.async { self.monthlyProtein = [] }
                    GluLog.protein.notice("fetchMonthlyProteinV1 finished | blockedByAuthIssue=true")
                    return
                }

                guard let results else {
                    DispatchQueue.main.async { self.monthlyProtein = [] }
                    GluLog.protein.notice("fetchMonthlyProteinV1 finished | resultsEmpty=true")
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
                    if self.proteinReadAuthIssueV1 {
                        self.monthlyProtein = []
                        GluLog.protein.notice("fetchMonthlyProteinV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.monthlyProtein = temp
                    GluLog.protein.notice("fetchMonthlyProteinV1 finished | entries=\(temp.count, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchProteinDaily365V1() {
        if isPreview {
            proteinReadAuthIssueV1 = false
            let slice = Array(previewDailyProtein.suffix(365)).sorted { $0.date < $1.date }
            proteinDaily365 = slice
            GluLog.protein.debug("fetchProteinDaily365V1 preview applied | entries=\(slice.count, privacy: .public)")
            return
        }

        GluLog.protein.notice("fetchProteinDaily365V1 started")

        Task { @MainActor in
            let authIssue = await probeProteinReadAuthIssueV1Async()
            if authIssue {
                proteinDaily365 = []
                GluLog.protein.notice("fetchProteinDaily365V1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) else {
                GluLog.protein.error("fetchProteinDaily365V1 failed | quantityTypeUnavailable=true")
                return
            }

            fetchDailySeriesProteinV1(
                quantityType: type,
                unit: .gram(),
                days: 365
            ) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.proteinReadAuthIssueV1 {
                        self.proteinDaily365 = []
                        GluLog.protein.notice("fetchProteinDaily365V1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.proteinDaily365 = entries
                    GluLog.protein.notice("fetchProteinDaily365V1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }

    @MainActor
    func fetchProteinEvents3DaysV1() {
        if isPreview {
            proteinReadAuthIssueV1 = false

            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())

            var temp: [NutritionEvent] = []

            for dayOffset in stride(from: 2, through: 0, by: -1) {
                guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: todayStart) else { continue }
                let grams = previewDailyProtein.first(where: { calendar.isDate($0.date, inSameDayAs: day) })?.grams ?? 0
                guard grams > 0 else { continue }

                let noon = calendar.date(byAdding: .hour, value: 12, to: day) ?? day
                temp.append(
                    NutritionEvent(
                        id: UUID(),
                        timestamp: noon,
                        grams: Double(grams),
                        kind: .protein
                    )
                )
            }

            proteinEvents3Days = temp.sorted { $0.timestamp < $1.timestamp }
            GluLog.protein.debug("fetchProteinEvents3DaysV1 preview applied | events=\(self.proteinEvents3Days.count, privacy: .public)")
            return
        }

        GluLog.protein.notice("fetchProteinEvents3DaysV1 started")

        Task { @MainActor in
            let authIssue = await probeProteinReadAuthIssueV1Async()
            if authIssue {
                proteinEvents3Days = []
                GluLog.protein.notice("fetchProteinEvents3DaysV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) else {
                GluLog.protein.error("fetchProteinEvents3DaysV1 failed | quantityTypeUnavailable=true")
                return
            }

            fetchRawProteinEvents3DaysV1(
                quantityType: type,
                unit: .gram()
            ) { [weak self] events in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.proteinReadAuthIssueV1 {
                        self.proteinEvents3Days = []
                        GluLog.protein.notice("fetchProteinEvents3DaysV1 finished | blockedByAuthIssue=true")
                        return
                    }
                    self.proteinEvents3Days = events
                    GluLog.protein.notice("fetchProteinEvents3DaysV1 finished | events=\(events.count, privacy: .public)")
                }
            }
        }
    }
}

// ============================================================
// MARK: - Private Helpers
// ============================================================

private extension HealthStore {

    func fetchDailySeriesProteinV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyProteinEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            DispatchQueue.main.async { assign([]) }
            GluLog.protein.error("fetchDailySeriesProteinV1 failed | startDateUnavailable=true")
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

            if self.proteinReadAuthIssueV1 {
                DispatchQueue.main.async { assign([]) }
                GluLog.protein.notice("fetchDailySeriesProteinV1 finished | blockedByAuthIssue=true")
                return
            }

            guard let results else {
                DispatchQueue.main.async { assign([]) }
                GluLog.protein.notice("fetchDailySeriesProteinV1 finished | resultsEmpty=true")
                return
            }

            var daily: [DailyProteinEntry] = []
            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                daily.append(
                    DailyProteinEntry(
                        date: stats.startDate,
                        grams: max(0, Int(value.rounded()))
                    )
                )
            }

            let result = daily.sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                if self.proteinReadAuthIssueV1 {
                    assign([])
                    GluLog.protein.notice("fetchDailySeriesProteinV1 finished | blockedByAuthIssue=true")
                    return
                }
                assign(result)
                GluLog.protein.debug("fetchDailySeriesProteinV1 finished | entries=\(result.count, privacy: .public)")
            }
        }

        healthStore.execute(query)
    }

    func fetchRawProteinEvents3DaysV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        assign: @escaping ([NutritionEvent]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -2, to: todayStart) else {
            DispatchQueue.main.async { assign([]) }
            GluLog.protein.error("fetchRawProteinEvents3DaysV1 failed | startDateUnavailable=true")
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

            if self.proteinReadAuthIssueV1 {
                DispatchQueue.main.async { assign([]) }
                GluLog.protein.notice("fetchRawProteinEvents3DaysV1 finished | blockedByAuthIssue=true")
                return
            }

            let quantitySamples = (samples as? [HKQuantitySample]) ?? []

            let events: [NutritionEvent] = quantitySamples.map { s in
                let grams = s.quantity.doubleValue(for: unit)
                return NutritionEvent(
                    id: UUID(),
                    timestamp: s.startDate,
                    grams: max(0, grams),
                    kind: .protein
                )
            }

            DispatchQueue.main.async {
                if self.proteinReadAuthIssueV1 {
                    assign([])
                    GluLog.protein.notice("fetchRawProteinEvents3DaysV1 finished | blockedByAuthIssue=true")
                    return
                }
                assign(events)
                GluLog.protein.debug("fetchRawProteinEvents3DaysV1 finished | events=\(events.count, privacy: .public)")
            }
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - File-local Probe Gate
// ============================================================

private enum ProteinProbeGateV1 {

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
