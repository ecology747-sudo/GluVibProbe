//
//  HealthStore+InsulinV1.swift
//  GluVibProbe
//
//  Metabolic V1 — Insulin (Bolus/Basal)
//
//  Zweck:
//  - Raw3Days: bolusEvents3Days, basalEvents3Days (MainChart DayProfile Input + rebuild hook)
//  - HistoryWindow: bolusEventsHistoryWindowV1, basalEventsHistoryWindowV1 (10 Tage, unabhängig vom MainChartCache)
//  - DailyStats90: dailyBolus90, dailyBasal90
//
//  IMPORTANT:
//  - HealthStore bleibt faktisch (SSOT)
//  - Keine UI-Clamps / keine Rolling-Logik hier
//

import Foundation
import HealthKit
import OSLog // 🟨 UPDATED

extension HealthStore {

    // ============================================================
    // MARK: - Auth Issue Classification (Read-Query first, status fallback)
    // ============================================================

    private func _isReadAuthIssueV1(_ error: Error?) -> Bool {
        guard let ns = error as NSError? else { return false }
        guard ns.domain == HKErrorDomain else { return false }
        guard let code = HKError.Code(rawValue: ns.code) else { return false }
        return code == .errorAuthorizationDenied || code == .errorAuthorizationNotDetermined
    }

    private func _resolveReadAuthIssueV1(
        type: HKObjectType,
        error: Error?,
        samplesCount: Int
    ) -> Bool {

        if _isReadAuthIssueV1(error) { return true }

        if error == nil, samplesCount == 0 {
            let status = healthStore.authorizationStatus(for: type)
            return status == .sharingDenied || status == .notDetermined
        }

        return false
    }

    // ============================================================
    // MARK: - Deterministic Read-Probes (ONLY flag writers)
    // ============================================================

    

    @MainActor
    func probeBolusReadAuthIssueV1Async() async -> Bool {
        if isPreview {
            bolusReadAuthIssueV1 = false
            GluLog.healthStore.debug("bolus probe skipped | preview=true") // 🟨 UPDATED
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = InsulinProbeGateV1.cachedBolusIfFresh(for: key) {
            bolusReadAuthIssueV1 = cached
            GluLog.healthStore.debug("bolus probe cache hit | authIssue=\(cached, privacy: .public)")
            return cached
        }

        if let inFlight = InsulinProbeGateV1.inFlightBolusTask(for: key) {
            let v = await inFlight.value
            bolusReadAuthIssueV1 = v
            GluLog.healthStore.debug("bolus probe joined inFlight | authIssue=\(v, privacy: .public)")
            return v
        }

        GluLog.healthStore.notice("bolus probe started")

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }
            guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else {
                GluLog.healthStore.error("bolus probe failed | quantityTypeUnavailable=true")
                return true
            }

            let calendar = Calendar.current
            let now = Date()
            let todayStart = calendar.startOfDay(for: now)

            let startDate = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
            let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)

            let bolusPredicate = HKQuery.predicateForObjects(
                withMetadataKey: HKMetadataKeyInsulinDeliveryReason,
                allowedValues: [HKInsulinDeliveryReason.bolus.rawValue]
            )
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, bolusPredicate])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let isAuthIssue: Bool = await withCheckedContinuation { continuation in
                let q = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: 1,
                    sortDescriptors: [sort]
                ) { [weak self] _, samples, error in
                    guard let self else {
                        continuation.resume(returning: false)
                        return
                    }
                    let count = (samples as? [HKQuantitySample])?.count ?? 0
                    continuation.resume(returning: self._resolveReadAuthIssueV1(type: type, error: error, samplesCount: count))
                }
                self.healthStore.execute(q)
            }

            return isAuthIssue
        }

        InsulinProbeGateV1.setInFlightBolus(task, for: key)
        let result = await task.value
        InsulinProbeGateV1.finishBolus(with: result, for: key)

        bolusReadAuthIssueV1 = result
        GluLog.healthStore.notice("bolus probe finished | authIssue=\(result, privacy: .public)")
        return result
    }

    @MainActor
    func probeBasalReadAuthIssueV1Async() async -> Bool {
        if isPreview {
            basalReadAuthIssueV1 = false
            GluLog.healthStore.debug("basal probe skipped | preview=true") // 🟨 UPDATED
            return false
        }

        let key = ObjectIdentifier(self)

        if let cached = InsulinProbeGateV1.cachedBasalIfFresh(for: key) {
            basalReadAuthIssueV1 = cached
            GluLog.healthStore.debug("basal probe cache hit | authIssue=\(cached, privacy: .public)")
            return cached
        }

        if let inFlight = InsulinProbeGateV1.inFlightBasalTask(for: key) {
            let v = await inFlight.value
            basalReadAuthIssueV1 = v
            GluLog.healthStore.debug("basal probe joined inFlight | authIssue=\(v, privacy: .public)")
            return v
        }

        GluLog.healthStore.notice("basal probe started")

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }
            guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else {
                GluLog.healthStore.error("basal probe failed | quantityTypeUnavailable=true")
                return true
            }

            let calendar = Calendar.current
            let now = Date()
            let todayStart = calendar.startOfDay(for: now)

            let startDate = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
            let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)

            let basalPredicate = HKQuery.predicateForObjects(
                withMetadataKey: HKMetadataKeyInsulinDeliveryReason,
                allowedValues: [HKInsulinDeliveryReason.basal.rawValue]
            )
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, basalPredicate])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let isAuthIssue: Bool = await withCheckedContinuation { continuation in
                let q = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: 1,
                    sortDescriptors: [sort]
                ) { [weak self] _, samples, error in
                    guard let self else {
                        continuation.resume(returning: false)
                        return
                    }
                    let count = (samples as? [HKQuantitySample])?.count ?? 0
                    continuation.resume(returning: self._resolveReadAuthIssueV1(type: type, error: error, samplesCount: count))
                }
                self.healthStore.execute(q)
            }

            return isAuthIssue
        }

        InsulinProbeGateV1.setInFlightBasal(task, for: key)
        let result = await task.value
        InsulinProbeGateV1.finishBasal(with: result, for: key)

        basalReadAuthIssueV1 = result
        GluLog.healthStore.notice("basal probe finished | authIssue=\(result, privacy: .public)")
        return result
    }

    // ============================================================
    // MARK: - Priming Filter (paired removal)
    // ============================================================

    private struct _InsulinSampleEvent {
        let timestamp: Date
        let units: Double
        let isUserEntered: Bool
    }

    private func _isUserEntered(_ sample: HKQuantitySample) -> Bool {
        if let v = sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool { return v }
        return false
    }

    private func _applyPrimingFilterIfEnabled(
        _ events: [_InsulinSampleEvent],
        excludePriming: Bool,
        thresholdU: Double
    ) -> [_InsulinSampleEvent] {

        guard excludePriming else { return events }
        guard thresholdU > 0 else { return events }

        let windowSeconds: TimeInterval = 120
        let sorted = events.sorted { $0.timestamp < $1.timestamp }
        if sorted.count < 2 { return sorted }

        var remove = Array(repeating: false, count: sorted.count)

        for i in sorted.indices {
            let e = sorted[i]
            guard e.units > 0, e.units <= thresholdU else { continue }

            let t0 = e.timestamp.timeIntervalSinceReferenceDate

            var j = i - 1
            while j >= 0 {
                let dt = abs(sorted[j].timestamp.timeIntervalSinceReferenceDate - t0)
                if dt > windowSeconds { break }
                if sorted[j].units > thresholdU {
                    remove[i] = true
                    break
                }
                j -= 1
            }

            if remove[i] { continue }

            var k = i + 1
            while k < sorted.count {
                let dt = abs(sorted[k].timestamp.timeIntervalSinceReferenceDate - t0)
                if dt > windowSeconds { break }
                if sorted[k].units > thresholdU {
                    remove[i] = true
                    break
                }
                k += 1
            }
        }

        var out: [_InsulinSampleEvent] = []
        out.reserveCapacity(sorted.count)
        for (idx, e) in sorted.enumerated() where remove[idx] == false {
            out.append(e)
        }
        return out
    }

    // ============================================================
    // MARK: - RAW3DAYS (DayProfile Input + Rebuild Hook)
    // ============================================================

    @MainActor
    func fetchBolusEvents3DaysV1() {
        if isPreview {
            bolusReadAuthIssueV1 = false
            GluLog.healthStore.debug("fetchBolusEvents3DaysV1 skipped | preview=true") // 🟨 UPDATED
            return
        }

        GluLog.healthStore.notice("fetchBolusEvents3DaysV1 started")

        Task { @MainActor in
            let authIssue = await probeBolusReadAuthIssueV1Async()
            if authIssue {
                bolusEvents3Days = []
                _scheduleMainChartRawRebuildFromInsulinV1()
                GluLog.healthStore.notice("fetchBolusEvents3DaysV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else {
                GluLog.healthStore.error("fetchBolusEvents3DaysV1 failed | quantityTypeUnavailable=true")
                return
            }

            let calendar = Calendar.current
            let now = Date()
            let todayStart = calendar.startOfDay(for: now)
            guard let startDate = calendar.date(byAdding: .day, value: -2, to: todayStart) else {
                GluLog.healthStore.error("fetchBolusEvents3DaysV1 failed | startDateUnavailable=true")
                return
            }

            let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            let bolusPredicate = HKQuery.predicateForObjects(
                withMetadataKey: HKMetadataKeyInsulinDeliveryReason,
                allowedValues: [HKInsulinDeliveryReason.bolus.rawValue]
            )
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, bolusPredicate])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let unit = HKUnit.internationalUnit()

            let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
                let q = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sort]
                ) { _, samples, _ in
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
                self.healthStore.execute(q)
            }

            if bolusReadAuthIssueV1 {
                bolusEvents3Days = []
                _scheduleMainChartRawRebuildFromInsulinV1()
                GluLog.healthStore.notice("fetchBolusEvents3DaysV1 finished | blockedByAuthIssue=true")
                return
            }

            let raw: [_InsulinSampleEvent] = samples.map { s in
                let u = s.quantity.doubleValue(for: unit)
                return _InsulinSampleEvent(timestamp: s.startDate, units: max(0, u), isUserEntered: _isUserEntered(s))
            }

            let settings = SettingsModel.shared
            let filtered = _applyPrimingFilterIfEnabled(
                raw,
                excludePriming: settings.excludeBolusPriming,
                thresholdU: settings.bolusPrimingThresholdU
            )

            bolusEvents3Days = filtered.map { e in
                InsulinBolusEvent(id: UUID(), timestamp: e.timestamp, units: e.units)
            }

            _scheduleMainChartRawRebuildFromInsulinV1()
            GluLog.healthStore.notice("fetchBolusEvents3DaysV1 finished | events=\(self.bolusEvents3Days.count, privacy: .public)")
        }
    }

    @MainActor
    func fetchBasalEvents3DaysV1() {
        if isPreview {
            basalReadAuthIssueV1 = false
            GluLog.healthStore.debug("fetchBasalEvents3DaysV1 skipped | preview=true") // 🟨 UPDATED
            return
        }

        GluLog.healthStore.notice("fetchBasalEvents3DaysV1 started")

        Task { @MainActor in
            let authIssue = await probeBasalReadAuthIssueV1Async()
            if authIssue {
                basalEvents3Days = []
                _scheduleMainChartRawRebuildFromInsulinV1()
                GluLog.healthStore.notice("fetchBasalEvents3DaysV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else {
                GluLog.healthStore.error("fetchBasalEvents3DaysV1 failed | quantityTypeUnavailable=true")
                return
            }

            let calendar = Calendar.current
            let now = Date()
            let todayStart = calendar.startOfDay(for: now)
            guard let startDate = calendar.date(byAdding: .day, value: -2, to: todayStart) else {
                GluLog.healthStore.error("fetchBasalEvents3DaysV1 failed | startDateUnavailable=true")
                return
            }

            let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            let basalPredicate = HKQuery.predicateForObjects(
                withMetadataKey: HKMetadataKeyInsulinDeliveryReason,
                allowedValues: [HKInsulinDeliveryReason.basal.rawValue]
            )
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, basalPredicate])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let unit = HKUnit.internationalUnit()

            let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
                let q = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sort]
                ) { _, samples, _ in
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
                self.healthStore.execute(q)
            }

            if basalReadAuthIssueV1 {
                basalEvents3Days = []
                _scheduleMainChartRawRebuildFromInsulinV1()
                GluLog.healthStore.notice("fetchBasalEvents3DaysV1 finished | blockedByAuthIssue=true")
                return
            }

            let raw: [_InsulinSampleEvent] = samples.map { s in
                let u = s.quantity.doubleValue(for: unit)
                return _InsulinSampleEvent(timestamp: s.startDate, units: max(0, u), isUserEntered: _isUserEntered(s))
            }

            let settings = SettingsModel.shared
            let filtered = _applyPrimingFilterIfEnabled(
                raw,
                excludePriming: settings.excludeBasalPriming,
                thresholdU: settings.basalPrimingThresholdU
            )

            basalEvents3Days = filtered.map { e in
                InsulinBasalEvent(id: UUID(), timestamp: e.timestamp, units: e.units)
            }

            _scheduleMainChartRawRebuildFromInsulinV1()
            GluLog.healthStore.notice("fetchBasalEvents3DaysV1 finished | events=\(self.basalEvents3Days.count, privacy: .public)")
        }
    }

    // ============================================================
    // MARK: - 🟨 NEW: HISTORY WINDOW (10 Days) — independent from MainChartCache
    // ============================================================

    @MainActor
    func fetchBolusEventsForHistoryWindowV1(days: Int = 10) {
        if isPreview {
            bolusReadAuthIssueV1 = false
            bolusEventsHistoryWindowV1 = []
            GluLog.healthStore.debug("fetchBolusEventsForHistoryWindowV1 skipped | preview=true") // 🟨 UPDATED
            return
        }

        GluLog.healthStore.notice("fetchBolusEventsForHistoryWindowV1 started | days=\(days, privacy: .public)")

        Task { @MainActor in
            let authIssue = await probeBolusReadAuthIssueV1Async()
            if authIssue {
                bolusEventsHistoryWindowV1 = []
                GluLog.healthStore.notice("fetchBolusEventsForHistoryWindowV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else {
                GluLog.healthStore.error("fetchBolusEventsForHistoryWindowV1 failed | quantityTypeUnavailable=true")
                return
            }

            let unit = HKUnit.internationalUnit()
            let spanDays = max(1, days)

            let samples = await _fetchInsulinSamplesWindowV1(
                type: type,
                reason: .bolus,
                days: spanDays
            )

            if bolusReadAuthIssueV1 {
                bolusEventsHistoryWindowV1 = []
                GluLog.healthStore.notice("fetchBolusEventsForHistoryWindowV1 finished | blockedByAuthIssue=true")
                return
            }

            let raw: [_InsulinSampleEvent] = samples.map { s in
                let u = s.quantity.doubleValue(for: unit)
                return _InsulinSampleEvent(timestamp: s.startDate, units: max(0, u), isUserEntered: _isUserEntered(s))
            }

            let settings = SettingsModel.shared
            let filtered = _applyPrimingFilterIfEnabled(
                raw,
                excludePriming: settings.excludeBolusPriming,
                thresholdU: settings.bolusPrimingThresholdU
            )

            bolusEventsHistoryWindowV1 = filtered.map { e in
                InsulinBolusEvent(id: UUID(), timestamp: e.timestamp, units: e.units)
            }

            GluLog.healthStore.notice("fetchBolusEventsForHistoryWindowV1 finished | events=\(self.bolusEventsHistoryWindowV1.count, privacy: .public)")
        }
    }

    @MainActor
    func fetchBasalEventsForHistoryWindowV1(days: Int = 10) {
        if isPreview {
            basalReadAuthIssueV1 = false
            basalEventsHistoryWindowV1 = []
            GluLog.healthStore.debug("fetchBasalEventsForHistoryWindowV1 skipped | preview=true") // 🟨 UPDATED
            return
        }

        GluLog.healthStore.notice("fetchBasalEventsForHistoryWindowV1 started | days=\(days, privacy: .public)")

        Task { @MainActor in
            let authIssue = await probeBasalReadAuthIssueV1Async()
            if authIssue {
                basalEventsHistoryWindowV1 = []
                GluLog.healthStore.notice("fetchBasalEventsForHistoryWindowV1 aborted | authIssue=true")
                return
            }

            guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else {
                GluLog.healthStore.error("fetchBasalEventsForHistoryWindowV1 failed | quantityTypeUnavailable=true")
                return
            }

            let unit = HKUnit.internationalUnit()
            let spanDays = max(1, days)

            let samples = await _fetchInsulinSamplesWindowV1(
                type: type,
                reason: .basal,
                days: spanDays
            )

            if basalReadAuthIssueV1 {
                basalEventsHistoryWindowV1 = []
                GluLog.healthStore.notice("fetchBasalEventsForHistoryWindowV1 finished | blockedByAuthIssue=true")
                return
            }

            let raw: [_InsulinSampleEvent] = samples.map { s in
                let u = s.quantity.doubleValue(for: unit)
                return _InsulinSampleEvent(timestamp: s.startDate, units: max(0, u), isUserEntered: _isUserEntered(s))
            }

            let settings = SettingsModel.shared
            let filtered = _applyPrimingFilterIfEnabled(
                raw,
                excludePriming: settings.excludeBasalPriming,
                thresholdU: settings.basalPrimingThresholdU
            )

            basalEventsHistoryWindowV1 = filtered.map { e in
                InsulinBasalEvent(id: UUID(), timestamp: e.timestamp, units: e.units)
            }

            GluLog.healthStore.notice("fetchBasalEventsForHistoryWindowV1 finished | events=\(self.basalEventsHistoryWindowV1.count, privacy: .public)")
        }
    }

    // ============================================================
    // MARK: - DAILYSTATS90 (Trends)
    // ============================================================

    @MainActor
    func fetchDailyBolus90V1() {
        if isPreview {
            bolusReadAuthIssueV1 = false
            GluLog.healthStore.debug("fetchDailyBolus90V1 skipped | preview=true") // 🟨 UPDATED
            return
        }

        GluLog.healthStore.notice("fetchDailyBolus90V1 started")

        Task { @MainActor in
            let authIssue = await probeBolusReadAuthIssueV1Async()
            if authIssue {
                dailyBolus90 = []
                GluLog.healthStore.notice("fetchDailyBolus90V1 aborted | authIssue=true")
                return
            }
            await fetchDailyBolus90V1Async()
        }
    }

    @MainActor
    func fetchDailyBasal90V1() {
        if isPreview {
            basalReadAuthIssueV1 = false
            GluLog.healthStore.debug("fetchDailyBasal90V1 skipped | preview=true") // 🟨 UPDATED
            return
        }

        GluLog.healthStore.notice("fetchDailyBasal90V1 started")

        Task { @MainActor in
            let authIssue = await probeBasalReadAuthIssueV1Async()
            if authIssue {
                dailyBasal90 = []
                GluLog.healthStore.notice("fetchDailyBasal90V1 aborted | authIssue=true")
                return
            }
            await fetchDailyBasal90V1Async()
        }
    }

    // ============================================================
    // MARK: - MainChart Cache Rebuild (RAW3DAYS completion hook)
    // ============================================================

    private func _scheduleMainChartRawRebuildFromInsulinV1() {
        MainChartRawRebuildDebounceV1.schedule {
            Task { @MainActor in
                self.rebuildMainChartCacheFromRaw3DaysV1()
            }
        }
    }
}

private extension HealthStore {

    // ============================================================
    // MARK: - Shared Raw Sample Fetch (Window)
    // ============================================================

    func _fetchInsulinSamplesWindowV1(
        type: HKQuantityType,
        reason: HKInsulinDeliveryReason,
        days: Int
    ) async -> [HKQuantitySample] {

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        let spanDays = max(1, days)
        guard let startDate = calendar.date(byAdding: .day, value: -(spanDays - 1), to: todayStart) else { return [] }

        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)

        let reasonPredicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyInsulinDeliveryReason,
            allowedValues: [reason.rawValue]
        )

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, reasonPredicate])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            self.healthStore.execute(q)
        }
    }
}

// ============================================================
// MARK: - Async Wrappers (wait for HealthKit completion)
// ============================================================

extension HealthStore {

    @MainActor
    func fetchDailyBolus90V1Async() async {
        if isPreview {
            bolusReadAuthIssueV1 = false
            GluLog.healthStore.debug("fetchDailyBolus90V1Async skipped | preview=true") // 🟨 UPDATED
            return
        }

        GluLog.healthStore.notice("fetchDailyBolus90V1Async started")

        let authIssue = await probeBolusReadAuthIssueV1Async()
        if authIssue {
            dailyBolus90 = []
            GluLog.healthStore.notice("fetchDailyBolus90V1Async aborted | authIssue=true")
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else {
            dailyBolus90 = []
            GluLog.healthStore.error("fetchDailyBolus90V1Async failed | quantityTypeUnavailable=true")
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(90 - 1), to: todayStart) else {
            dailyBolus90 = []
            GluLog.healthStore.error("fetchDailyBolus90V1Async failed | startDateUnavailable=true")
            return
        }

        let bolusPredicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyInsulinDeliveryReason,
            allowedValues: [HKInsulinDeliveryReason.bolus.rawValue]
        )

        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, bolusPredicate])

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let unit = HKUnit.internationalUnit()

        let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let q = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            self.healthStore.execute(q)
        }

        if bolusReadAuthIssueV1 {
            dailyBolus90 = []
            GluLog.healthStore.notice("fetchDailyBolus90V1Async finished | blockedByAuthIssue=true")
            return
        }

        let raw: [_InsulinSampleEvent] = samples.map { s in
            let u = s.quantity.doubleValue(for: unit)
            return _InsulinSampleEvent(timestamp: s.startDate, units: max(0, u), isUserEntered: _isUserEntered(s))
        }

        let settings = SettingsModel.shared
        let filtered = _applyPrimingFilterIfEnabled(
            raw,
            excludePriming: settings.excludeBolusPriming,
            thresholdU: settings.bolusPrimingThresholdU
        )

        var sumsByDay: [Date: Double] = [:]
        sumsByDay.reserveCapacity(90)
        for e in filtered {
            let day = calendar.startOfDay(for: e.timestamp)
            sumsByDay[day, default: 0] += e.units
        }

        var daily: [DailyBolusEntry] = []
        daily.reserveCapacity(90)

        for i in 0..<90 {
            guard let day = calendar.date(byAdding: .day, value: i, to: startDate) else { continue }
            let sum = sumsByDay[day] ?? 0
            daily.append(DailyBolusEntry(id: UUID(), date: day, bolusUnits: max(0, sum)))
        }

        dailyBolus90 = daily.sorted { $0.date < $1.date }
        GluLog.healthStore.notice("fetchDailyBolus90V1Async finished | entries=\(self.dailyBolus90.count, privacy: .public)")
    }

    @MainActor
    func fetchDailyBasal90V1Async() async {
        if isPreview {
            basalReadAuthIssueV1 = false
            GluLog.healthStore.debug("fetchDailyBasal90V1Async skipped | preview=true") // 🟨 UPDATED
            return
        }

        GluLog.healthStore.notice("fetchDailyBasal90V1Async started")

        let authIssue = await probeBasalReadAuthIssueV1Async()
        if authIssue {
            dailyBasal90 = []
            GluLog.healthStore.notice("fetchDailyBasal90V1Async aborted | authIssue=true")
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else {
            dailyBasal90 = []
            GluLog.healthStore.error("fetchDailyBasal90V1Async failed | quantityTypeUnavailable=true")
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(90 - 1), to: todayStart) else {
            dailyBasal90 = []
            GluLog.healthStore.error("fetchDailyBasal90V1Async failed | startDateUnavailable=true")
            return
        }

        let basalPredicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyInsulinDeliveryReason,
            allowedValues: [HKInsulinDeliveryReason.basal.rawValue]
        )

        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, basalPredicate])

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let unit = HKUnit.internationalUnit()

        let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let q = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            self.healthStore.execute(q)
        }

        if basalReadAuthIssueV1 {
            dailyBasal90 = []
            GluLog.healthStore.notice("fetchDailyBasal90V1Async finished | blockedByAuthIssue=true")
            return
        }

        let raw: [_InsulinSampleEvent] = samples.map { s in
            let u = s.quantity.doubleValue(for: unit)
            return _InsulinSampleEvent(timestamp: s.startDate, units: max(0, u), isUserEntered: _isUserEntered(s))
        }

        let settings = SettingsModel.shared
        let filtered = _applyPrimingFilterIfEnabled(
            raw,
            excludePriming: settings.excludeBasalPriming,
            thresholdU: settings.basalPrimingThresholdU
        )

        var sumsByDay: [Date: Double] = [:]
        sumsByDay.reserveCapacity(90)
        for e in filtered {
            let day = calendar.startOfDay(for: e.timestamp)
            sumsByDay[day, default: 0] += e.units
        }

        var daily: [DailyBasalEntry] = []
        daily.reserveCapacity(90)

        for i in 0..<90 {
            guard let day = calendar.date(byAdding: .day, value: i, to: startDate) else { continue }
            let sum = sumsByDay[day] ?? 0
            daily.append(DailyBasalEntry(id: UUID(), date: day, basalUnits: max(0, sum)))
        }

        dailyBasal90 = daily.sorted { $0.date < $1.date }
        GluLog.healthStore.notice("fetchDailyBasal90V1Async finished | entries=\(self.dailyBasal90.count, privacy: .public)")
    }
}

// ============================================================
// MARK: - Debounce Helper (file-local)
// ============================================================

private enum MainChartRawRebuildDebounceV1 {
    private static var work: DispatchWorkItem?

    static func schedule(_ block: @escaping () -> Void) {
        work?.cancel()
        let item = DispatchWorkItem(block: block)
        work = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: item)
    }
}

// ============================================================
// MARK: - File-local Probe Gate (TTL + inFlight)
// ============================================================

private enum InsulinProbeGateV1 {

    private static let ttl: TimeInterval = 10 // seconds (collapse same-refresh storms)

    private static var lastBolus: [ObjectIdentifier: Date] = [:]
    private static var lastBolusResult: [ObjectIdentifier: Bool] = [:]
    private static var inFlightBolus: [ObjectIdentifier: Task<Bool, Never>] = [:]

    private static var lastBasal: [ObjectIdentifier: Date] = [:]
    private static var lastBasalResult: [ObjectIdentifier: Bool] = [:]
    private static var inFlightBasal: [ObjectIdentifier: Task<Bool, Never>] = [:]

    static func cachedBolusIfFresh(for key: ObjectIdentifier) -> Bool? {
        guard let last = lastBolus[key], let v = lastBolusResult[key] else { return nil }
        return (Date().timeIntervalSince(last) <= ttl) ? v : nil
    }

    static func cachedBasalIfFresh(for key: ObjectIdentifier) -> Bool? {
        guard let last = lastBasal[key], let v = lastBasalResult[key] else { return nil }
        return (Date().timeIntervalSince(last) <= ttl) ? v : nil
    }

    static func inFlightBolusTask(for key: ObjectIdentifier) -> Task<Bool, Never>? { inFlightBolus[key] }
    static func inFlightBasalTask(for key: ObjectIdentifier) -> Task<Bool, Never>? { inFlightBasal[key] }

    static func setInFlightBolus(_ task: Task<Bool, Never>, for key: ObjectIdentifier) { inFlightBolus[key] = task }
    static func setInFlightBasal(_ task: Task<Bool, Never>, for key: ObjectIdentifier) { inFlightBasal[key] = task }

    static func finishBolus(with result: Bool, for key: ObjectIdentifier) {
        inFlightBolus[key] = nil
        lastBolus[key] = Date()
        lastBolusResult[key] = result
    }

    static func finishBasal(with result: Bool, for key: ObjectIdentifier) {
        inFlightBasal[key] = nil
        lastBasal[key] = Date()
        lastBasalResult[key] = result
    }
}
