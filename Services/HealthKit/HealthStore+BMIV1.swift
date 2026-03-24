//
//  HealthStore+BMIV1.swift
//  GluVibProbe
//

import Foundation
import HealthKit
import OSLog // 🟨 UPDATED

extension HealthStore {

    // ============================================================
    // MARK: - Auth Issue Classification (Goldstandard)
    // ============================================================

    private func _bmiIsReadAuthIssueV1(_ error: Error?) -> Bool {
        guard let ns = error as NSError? else { return false }
        guard ns.domain == HKErrorDomain else { return false }
        guard let code = HKError.Code(rawValue: ns.code) else { return false }
        return code == .errorAuthorizationDenied || code == .errorAuthorizationNotDetermined
    }

    private func _bmiResolveReadAuthIssueV1(
        error: Error?
    ) -> Bool {
        _bmiIsReadAuthIssueV1(error)
    }

    // ============================================================
    // MARK: - Deterministic Read-Query Probe (Single-Writer)
    // ============================================================

    @MainActor
    func probeBMIReadAuthIssueV1Async() async -> Bool {

        if isPreview {
            GluLog.healthStore.debug("bmi probe skipped | preview=true") // 🟨 UPDATED
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = BMIProbeGateV1.cachedResultIfFresh(for: key) {
            bmiReadAuthIssueV1 = cached
            GluLog.healthStore.debug("bmi probe cache hit | authIssue=\(cached, privacy: .public)") // 🟨 UPDATED
            return cached
        }

        if let inFlight = BMIProbeGateV1.inFlightTask(for: key) {
            let v = await inFlight.value
            bmiReadAuthIssueV1 = v
            GluLog.healthStore.debug("bmi probe joined inFlight | authIssue=\(v, privacy: .public)") // 🟨 UPDATED
            return v
        }

        GluLog.healthStore.notice("bmi probe started") // 🟨 UPDATED

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }

            guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) else {
                GluLog.healthStore.error("bmi probe failed | quantityTypeUnavailable=true") // 🟨 UPDATED
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

                    let resolved = self._bmiResolveReadAuthIssueV1(
                        error: error
                    )

                    continuation.resume(returning: resolved)
                }

                self.healthStore.execute(query)
            }

            return isAuthIssue
        }

        BMIProbeGateV1.setInFlight(task, for: key)
        let result = await task.value
        BMIProbeGateV1.finish(with: result, for: key)

        bmiReadAuthIssueV1 = result
        GluLog.healthStore.notice("bmi probe finished | authIssue=\(result, privacy: .public)") // 🟨 UPDATED
        return result
    }

    // ============================================================
    // MARK: - TODAY KPI (latest sample) — DATA ONLY
    // ============================================================

    @MainActor
    func fetchBMITodayV1() {
        if isPreview {
            let value = previewDailyBMI.sorted { $0.date < $1.date }.last?.bmi ?? 0
            todayBMI = max(0, value)
            GluLog.healthStore.debug("fetchBMITodayV1 preview applied | todayBMI=\(self.todayBMI, privacy: .public)") // 🟨 UPDATED
            return
        }

        GluLog.healthStore.notice("fetchBMITodayV1 started") // 🟨 UPDATED

        Task { @MainActor in
            let authIssue = await probeBMIReadAuthIssueV1Async()
            if authIssue {
                todayBMI = 0
                GluLog.healthStore.notice("fetchBMITodayV1 aborted | authIssue=true") // 🟨 UPDATED
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) else {
                GluLog.healthStore.error("fetchBMITodayV1 failed | quantityTypeUnavailable=true") // 🟨 UPDATED
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

                let sample = samples?.first as? HKQuantitySample
                let bmi = sample?.quantity.doubleValue(for: .count()) ?? 0

                DispatchQueue.main.async {
                    if self.bmiReadAuthIssueV1 {
                        self.todayBMI = 0
                        GluLog.healthStore.notice("fetchBMITodayV1 finished | blockedByAuthIssue=true") // 🟨 UPDATED
                        return
                    }
                    self.todayBMI = max(0, bmi)
                    GluLog.healthStore.notice("fetchBMITodayV1 finished | todayBMI=\(self.todayBMI, privacy: .public)") // 🟨 UPDATED
                }
            }

            healthStore.execute(query)
        }
    }

    // ============================================================
    // MARK: - 90 DAYS (measured days only) — DATA ONLY
    // ============================================================

    @MainActor
    func fetchLast90DaysBMIV1() {
        if isPreview {
            let slice = Array(previewDailyBMI.suffix(90)).sorted { $0.date < $1.date }
            last90DaysBMI = slice
            GluLog.healthStore.debug("fetchLast90DaysBMIV1 preview applied | entries=\(slice.count, privacy: .public)") // 🟨 UPDATED
            return
        }

        GluLog.healthStore.notice("fetchLast90DaysBMIV1 started") // 🟨 UPDATED

        Task { @MainActor in
            let authIssue = await probeBMIReadAuthIssueV1Async()
            if authIssue {
                last90DaysBMI = []
                GluLog.healthStore.notice("fetchLast90DaysBMIV1 aborted | authIssue=true") // 🟨 UPDATED
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) else {
                GluLog.healthStore.error("fetchLast90DaysBMIV1 failed | quantityTypeUnavailable=true") // 🟨 UPDATED
                return
            }

            fetchDailySeriesAverageBMI_RawV1(
                quantityType: type,
                unit: .count(),
                days: 90
            ) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.bmiReadAuthIssueV1 {
                        self.last90DaysBMI = []
                        GluLog.healthStore.notice("fetchLast90DaysBMIV1 finished | blockedByAuthIssue=true") // 🟨 UPDATED
                        return
                    }
                    self.last90DaysBMI = entries
                    GluLog.healthStore.notice("fetchLast90DaysBMIV1 finished | entries=\(entries.count, privacy: .public)") // 🟨 UPDATED
                }
            }
        }
    }

    // ============================================================
    // MARK: - MONTHLY (avg per month; last ~5 months) — DATA ONLY
    // ============================================================

    @MainActor
    func fetchMonthlyBMIV1() {
        if isPreview {
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)

            guard
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
            else { return }

            var bucket: [DateComponents: (sum: Double, count: Int)] = [:]
            for e in previewDailyBMI where e.date >= startDate && e.date <= startOfToday && e.bmi > 0 {
                let comps = calendar.dateComponents([.year, .month], from: e.date)
                var b = bucket[comps] ?? (0, 0)
                b.sum += e.bmi
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

            monthlyBMI = result
            GluLog.healthStore.debug("fetchMonthlyBMIV1 preview applied | entries=\(result.count, privacy: .public)") // 🟨 UPDATED
            return
        }

        GluLog.healthStore.notice("fetchMonthlyBMIV1 started") // 🟨 UPDATED

        Task { @MainActor in
            let authIssue = await probeBMIReadAuthIssueV1Async()
            if authIssue {
                monthlyBMI = []
                GluLog.healthStore.notice("fetchMonthlyBMIV1 aborted | authIssue=true") // 🟨 UPDATED
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) else {
                GluLog.healthStore.error("fetchMonthlyBMIV1 failed | quantityTypeUnavailable=true") // 🟨 UPDATED
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
                guard let self, let results else {
                    GluLog.healthStore.notice("fetchMonthlyBMIV1 finished | resultsEmpty=true") // 🟨 UPDATED
                    return
                }

                if self.bmiReadAuthIssueV1 {
                    DispatchQueue.main.async {
                        self.monthlyBMI = []
                        GluLog.healthStore.notice("fetchMonthlyBMIV1 finished | blockedByAuthIssue=true") // 🟨 UPDATED
                    }
                    return
                }

                var daily: [BMIEntry] = []
                results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                    guard let q = stats.averageQuantity() else { return }
                    let bmi = q.doubleValue(for: .count())
                    guard bmi > 0 else { return }
                    daily.append(BMIEntry(date: stats.startDate, bmi: bmi))
                }

                var perMonth: [DateComponents: (sum: Double, count: Int)] = [:]
                for e in daily {
                    let comps = calendar.dateComponents([.year, .month], from: e.date)
                    var b = perMonth[comps] ?? (0, 0)
                    b.sum += e.bmi
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
                    if self.bmiReadAuthIssueV1 {
                        self.monthlyBMI = []
                        GluLog.healthStore.notice("fetchMonthlyBMIV1 finished | blockedByAuthIssue=true") // 🟨 UPDATED
                        return
                    }
                    self.monthlyBMI = result
                    GluLog.healthStore.notice("fetchMonthlyBMIV1 finished | entries=\(result.count, privacy: .public)") // 🟨 UPDATED
                }
            }

            healthStore.execute(query)
        }
    }

    // ============================================================
    // MARK: - 365 DAYS (measured days only) — DATA ONLY
    // ============================================================

    @MainActor
    func fetchBMIDaily365V1() {
        if isPreview {
            let slice = Array(previewDailyBMI.suffix(365)).sorted { $0.date < $1.date }
            bmiDaily365 = slice
            GluLog.healthStore.debug("fetchBMIDaily365V1 preview applied | entries=\(slice.count, privacy: .public)") // 🟨 UPDATED
            return
        }

        GluLog.healthStore.notice("fetchBMIDaily365V1 started") // 🟨 UPDATED

        Task { @MainActor in
            let authIssue = await probeBMIReadAuthIssueV1Async()
            if authIssue {
                bmiDaily365 = []
                GluLog.healthStore.notice("fetchBMIDaily365V1 aborted | authIssue=true") // 🟨 UPDATED
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) else {
                GluLog.healthStore.error("fetchBMIDaily365V1 failed | quantityTypeUnavailable=true") // 🟨 UPDATED
                return
            }

            fetchDailySeriesAverageBMI_RawV1(
                quantityType: type,
                unit: .count(),
                days: 365
            ) { [weak self] entries in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.bmiReadAuthIssueV1 {
                        self.bmiDaily365 = []
                        GluLog.healthStore.notice("fetchBMIDaily365V1 finished | blockedByAuthIssue=true") // 🟨 UPDATED
                        return
                    }
                    self.bmiDaily365 = entries
                    GluLog.healthStore.notice("fetchBMIDaily365V1 finished | entries=\(entries.count, privacy: .public)") // 🟨 UPDATED
                }
            }
        }
    }
}

// ============================================================
// MARK: - Private Helpers (BMI V1 only)
// ============================================================

private extension HealthStore {

    func fetchDailySeriesAverageBMI_RawV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([BMIEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            GluLog.healthStore.error("fetchDailySeriesAverageBMI_RawV1 failed | startDateUnavailable=true") // 🟨 UPDATED
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
                GluLog.healthStore.debug("fetchDailySeriesAverageBMI_RawV1 finished | resultsEmpty=true") // 🟨 UPDATED
                DispatchQueue.main.async { assign([]) }
                return
            }

            var measured: [BMIEntry] = []
            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                guard let q = stats.averageQuantity() else { return }
                let bmi = q.doubleValue(for: unit)
                guard bmi > 0 else { return }
                measured.append(BMIEntry(date: stats.startDate, bmi: bmi))
            }

            DispatchQueue.main.async {
                GluLog.healthStore.debug("fetchDailySeriesAverageBMI_RawV1 finished | entries=\(measured.count, privacy: .public)") // 🟨 UPDATED
                assign(measured.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - File-local Probe Gate (TTL + inFlight)
// ============================================================

private enum BMIProbeGateV1 {

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
