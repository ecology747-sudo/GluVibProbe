//
//  HealthStore+WeightV1.swift
//  GluVibProbe
//
//  Domain: Body / Weight
//  Screen Type: HealthStore Metric Extension V1
//
//  Purpose
//  - Owns the read-only Apple Health weight fetch pipeline for Weight V1.
//  - Resolves read-auth issues via deterministic permission-only probe logic.
//  - Publishes today, last-90-days, monthly, 365-day and history-window weight data into HealthStore.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT Published Weight Values) → WeightViewModelV1 / BodyOverviewViewModelV1 → Views
//
//  Key Connections
//  - WeightViewModelV1
//  - BodyOverviewViewModelV1
//  - HistoryViewModelV1
//
//  Important
//  - weightReadAuthIssueV1 is set EXCLUSIVELY by probeWeightReadAuthIssueV1Async().
//  - Probe is permission-only: empty results are DATA state, never permission state.
//  - All fetches are DATA ONLY and may be blocked only by a real read-auth issue.
//

import Foundation
import HealthKit
import OSLog // 🟨 UPDATED

// ============================================================
// MARK: - History Weight Sample Model
// ============================================================

struct WeightSamplePointV1: Identifiable, Hashable {
    let id: UUID = UUID()
    let timestamp: Date
    let kg: Double
}

// ============================================================
// MARK: - HealthStore + Weight
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - Auth Issue Classification
    // ============================================================

    private func _weightIsReadAuthIssueV1(_ error: Error?) -> Bool {
        guard let ns = error as NSError? else { return false }
        guard ns.domain == HKErrorDomain else { return false }
        guard let code = HKError.Code(rawValue: ns.code) else { return false }
        return code == .errorAuthorizationDenied || code == .errorAuthorizationNotDetermined
    }

    // 🟨 UPDATED
    private func _weightResolveReadAuthIssueV1(
        error: Error?
    ) -> Bool {
        _weightIsReadAuthIssueV1(error)
    }

    // ============================================================
    // MARK: - Deterministic Read-Query Probe (Single-Writer)
    // ============================================================

    @MainActor
    func probeWeightReadAuthIssueV1Async() async -> Bool {

        if isPreview {
            weightReadAuthIssueV1 = false
            GluLog.healthStore.debug("weight probe skipped | preview=true")
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = WeightProbeGateV1.cachedResultIfFresh(for: key) {
            weightReadAuthIssueV1 = cached
            GluLog.healthStore.debug("weight probe cache hit | authIssue=\(cached, privacy: .public)")
            return cached
        }

        if let inFlight = WeightProbeGateV1.inFlightTask(for: key) {
            let value = await inFlight.value
            weightReadAuthIssueV1 = value
            GluLog.healthStore.debug("weight probe inFlight reused | authIssue=\(value, privacy: .public)")
            return value
        }

        GluLog.healthStore.debug("weight probe started")

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }

            guard let qType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
                return true
            }

            let now = Date()

            // 🟨 UPDATED
            let predicate = HKQuery.predicateForSamples(withStart: nil, end: now, options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

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
                    let resolved = self._weightResolveReadAuthIssueV1(error: error)
                    continuation.resume(returning: resolved)
                }

                self.healthStore.execute(query)
            }

            return isAuthIssue
        }

        WeightProbeGateV1.setInFlight(task, for: key)
        let result = await task.value
        WeightProbeGateV1.finish(with: result, for: key)

        weightReadAuthIssueV1 = result
        GluLog.healthStore.notice("weight probe finished | authIssue=\(result, privacy: .public)")
        return result
    }

    // ============================================================
    // MARK: - Public API (Today / 90d / Monthly / 365 / History)
    // ============================================================

    @MainActor
    func fetchWeightTodayV1() {
        if isPreview {
            let value = previewDailyWeight.sorted { $0.date < $1.date }.last?.kg ?? 0
            todayWeightKgRaw = max(0, value)
            GluLog.healthStore.debug("fetchWeightTodayV1 skipped | preview=true")
            return
        }

        GluLog.healthStore.debug("fetchWeightTodayV1 started")

        Task { @MainActor in
            let authIssue = await probeWeightReadAuthIssueV1Async()
            if authIssue {
                self.todayWeightKgRaw = 0
                GluLog.healthStore.notice("fetchWeightTodayV1 skipped | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
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
                guard let self else { return }

                guard let sample = samples?.first as? HKQuantitySample else {
                    DispatchQueue.main.async {
                        self.todayWeightKgRaw = 0
                        GluLog.healthStore.notice("fetchWeightTodayV1 finished | noSample=true")
                    }
                    return
                }

                let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))

                DispatchQueue.main.async {
                    if self.weightReadAuthIssueV1 {
                        self.todayWeightKgRaw = 0
                        GluLog.healthStore.notice("fetchWeightTodayV1 finished | blockedByAuthIssue=true")
                        return
                    }

                    self.todayWeightKgRaw = max(0, kg)
                    GluLog.healthStore.notice("fetchWeightTodayV1 finished | todayWeightKg=\(self.todayWeightKgRaw, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchLast90DaysWeightV1() {
        if isPreview {
            let slice = Array(previewDailyWeight.suffix(90)).sorted { $0.date < $1.date }
            last90DaysWeight = slice
            GluLog.healthStore.debug("fetchLast90DaysWeightV1 skipped | preview=true")
            return
        }

        GluLog.healthStore.debug("fetchLast90DaysWeightV1 started")

        Task { @MainActor in
            let authIssue = await probeWeightReadAuthIssueV1Async()
            if authIssue {
                self.last90DaysWeight = []
                GluLog.healthStore.notice("fetchLast90DaysWeightV1 skipped | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
                return
            }

            fetchDailySeriesAverageRawV1(
                quantityType: type,
                unit: .gramUnit(with: .kilo),
                days: 90
            ) { [weak self] entries in
                guard let self else { return }

                DispatchQueue.main.async {
                    if self.weightReadAuthIssueV1 {
                        self.last90DaysWeight = []
                        GluLog.healthStore.notice("fetchLast90DaysWeightV1 finished | blockedByAuthIssue=true")
                        return
                    }

                    self.last90DaysWeight = entries
                    GluLog.healthStore.notice("fetchLast90DaysWeightV1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }

    @MainActor
    func fetchMonthlyWeightV1() {
        if isPreview {
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var bucket: [DateComponents: (sum: Double, count: Int)] = [:]

            for e in previewDailyWeight where e.date >= startDate && e.date <= startOfToday && e.kg > 0 {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                var b = bucket[comps] ?? (0, 0)
                b.sum += e.kg
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

            monthlyWeight = result
            GluLog.healthStore.debug("fetchMonthlyWeightV1 skipped | preview=true")
            return
        }

        GluLog.healthStore.debug("fetchMonthlyWeightV1 started")

        Task { @MainActor in
            let authIssue = await probeWeightReadAuthIssueV1Async()
            if authIssue {
                self.monthlyWeight = []
                GluLog.healthStore.notice("fetchMonthlyWeightV1 skipped | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
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
            let interval = DateComponents(day: 1)

            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: startDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { [weak self] _, results, _ in
                guard let self else { return }

                if self.weightReadAuthIssueV1 {
                    DispatchQueue.main.async {
                        self.monthlyWeight = []
                        GluLog.healthStore.notice("fetchMonthlyWeightV1 finished | blockedByAuthIssue=true")
                    }
                    return
                }

                guard let results else {
                    DispatchQueue.main.async {
                        self.monthlyWeight = []
                        GluLog.healthStore.notice("fetchMonthlyWeightV1 finished | entries=0")
                    }
                    return
                }

                var daily: [DailyWeightEntry] = []
                results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                    guard let q = stats.averageQuantity() else { return }
                    let kg = q.doubleValue(for: .gramUnit(with: .kilo))
                    guard kg > 0 else { return }
                    daily.append(DailyWeightEntry(date: stats.startDate, kg: kg))
                }

                var perMonth: [DateComponents: (sum: Double, count: Int)] = [:]
                for e in daily {
                    let comps = calendar.dateComponents([.year, .month], from: e.date)
                    var b = perMonth[comps] ?? (0, 0)
                    b.sum += e.kg
                    b.count += 1
                    perMonth[comps] = b
                }

                let keys = perMonth.keys.sorted {
                    (calendar.date(from: $0) ?? .distantPast) < (calendar.date(from: $1) ?? .distantPast)
                }

                let result: [MonthlyMetricEntry] = keys.map { comps in
                    let d = calendar.date(from: comps) ?? Date()
                    let b = perMonth[comps] ?? (0, 1)
                    let avg = b.count > 0 ? (b.sum / Double(b.count)) : 0
                    return MonthlyMetricEntry(
                        monthShort: d.formatted(.dateTime.month(.abbreviated)),
                        value: Int(round(max(0, avg)))
                    )
                }

                DispatchQueue.main.async {
                    if self.weightReadAuthIssueV1 {
                        self.monthlyWeight = []
                        GluLog.healthStore.notice("fetchMonthlyWeightV1 finished | blockedByAuthIssue=true")
                        return
                    }

                    self.monthlyWeight = result
                    GluLog.healthStore.notice("fetchMonthlyWeightV1 finished | entries=\(result.count, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }

    @MainActor
    func fetchWeightDaily365RawV1() {
        if isPreview {
            let slice = Array(previewDailyWeight.suffix(365)).sorted { $0.date < $1.date }
            weightDaily365Raw = slice
            GluLog.healthStore.debug("fetchWeightDaily365RawV1 skipped | preview=true")
            return
        }

        GluLog.healthStore.debug("fetchWeightDaily365RawV1 started")

        Task { @MainActor in
            let authIssue = await probeWeightReadAuthIssueV1Async()
            if authIssue {
                self.weightDaily365Raw = []
                GluLog.healthStore.notice("fetchWeightDaily365RawV1 skipped | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
                return
            }

            fetchDailySeriesAverageRawV1(
                quantityType: type,
                unit: .gramUnit(with: .kilo),
                days: 365
            ) { [weak self] entries in
                guard let self else { return }

                DispatchQueue.main.async {
                    if self.weightReadAuthIssueV1 {
                        self.weightDaily365Raw = []
                        GluLog.healthStore.notice("fetchWeightDaily365RawV1 finished | blockedByAuthIssue=true")
                        return
                    }

                    self.weightDaily365Raw = entries
                    GluLog.healthStore.notice("fetchWeightDaily365RawV1 finished | entries=\(entries.count, privacy: .public)")
                }
            }
        }
    }

    @MainActor
    func fetchRecentWeightSamplesForHistoryWindowV1(days: Int = 10) {
        if isPreview {
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) ?? todayStart

            let points = previewDailyWeight
                .filter { $0.date >= start && $0.kg > 0 }
                .map { e in
                    WeightSamplePointV1(
                        timestamp: e.date.addingTimeInterval(7 * 3600 + 15 * 60),
                        kg: e.kg
                    )
                }
                .sorted { $0.timestamp > $1.timestamp }

            recentWeightSamplesForHistoryV1 = points
            GluLog.healthStore.debug("fetchRecentWeightSamplesForHistoryWindowV1 skipped | preview=true")
            return
        }

        GluLog.healthStore.debug("fetchRecentWeightSamplesForHistoryWindowV1 started | days=\(days, privacy: .public)")

        Task { @MainActor in
            let authIssue = await probeWeightReadAuthIssueV1Async()
            if authIssue {
                self.recentWeightSamplesForHistoryV1 = []
                GluLog.healthStore.notice("fetchRecentWeightSamplesForHistoryWindowV1 skipped | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
                return
            }

            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) ?? todayStart

            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { [weak self] _, samples, _ in
                guard let self else { return }

                let points: [WeightSamplePointV1] = (samples as? [HKQuantitySample] ?? [])
                    .map { s in
                        let kg = s.quantity.doubleValue(for: .gramUnit(with: .kilo))
                        return WeightSamplePointV1(timestamp: s.endDate, kg: max(0, kg))
                    }
                    .filter { $0.kg > 0 }
                    .sorted { $0.timestamp > $1.timestamp }

                DispatchQueue.main.async {
                    if self.weightReadAuthIssueV1 {
                        self.recentWeightSamplesForHistoryV1 = []
                        GluLog.healthStore.notice("fetchRecentWeightSamplesForHistoryWindowV1 finished | blockedByAuthIssue=true")
                        return
                    }

                    self.recentWeightSamplesForHistoryV1 = points
                    GluLog.healthStore.notice("fetchRecentWeightSamplesForHistoryWindowV1 finished | samples=\(points.count, privacy: .public)")
                }
            }

            healthStore.execute(query)
        }
    }
}

// ============================================================
// MARK: - Private Helpers (Weight V1 only) — DATA ONLY
// ============================================================

private extension HealthStore {

    func fetchDailySeriesAverageRawV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyWeightEntry]) -> Void
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
            options: .discreteAverage,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results else {
                DispatchQueue.main.async { assign([]) }
                return
            }

            var measured: [DailyWeightEntry] = []
            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                guard let q = stats.averageQuantity() else { return }
                let kg = q.doubleValue(for: unit)
                guard kg > 0 else { return }
                measured.append(DailyWeightEntry(date: stats.startDate, kg: kg))
            }

            DispatchQueue.main.async {
                assign(measured.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - File-local Probe Gate (TTL + inFlight)
// ============================================================

private enum WeightProbeGateV1 {

    private static let ttl: TimeInterval = 10 // seconds

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
