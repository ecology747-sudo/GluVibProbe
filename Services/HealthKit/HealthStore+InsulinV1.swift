//
//  HealthStore+InsulinV1.swift
//  GluVibProbe
//
//  Metabolic V1 — Insulin (Bolus/Basal)
//
//  Zweck:
//  - Raw3Days: bolusEvents3Days, basalEvents3Days
//  - DailyStats90: dailyBolus90, dailyBasal90
//
//  IMPORTANT:
//  - HealthStore bleibt faktisch (SSOT)
//  - Keine UI-Clamps / keine Rolling-Logik hier
//

import Foundation
import HealthKit

extension HealthStore {

    // ============================================================
    // MARK: - RAW3DAYS (DayProfile)
    // ============================================================

    /// Bolus Events (Today/Yesterday/DayBefore) — REAL
    @MainActor
    func fetchBolusEvents3DaysV1() {
        if isPreview { return }

        guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else { return }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -2, to: todayStart) else { return }

        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)

        let bolusPredicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyInsulinDeliveryReason,
            allowedValues: [HKInsulinDeliveryReason.bolus.rawValue]
        )

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, bolusPredicate])

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard let self else { return }

            let quantitySamples = (samples as? [HKQuantitySample]) ?? []
            let unit = HKUnit.internationalUnit()

            let events: [InsulinBolusEvent] = quantitySamples.map { s in
                let units = s.quantity.doubleValue(for: unit)
                return InsulinBolusEvent(
                    id: UUID(),
                    timestamp: s.startDate,
                    units: max(0, units)
                )
            }

            DispatchQueue.main.async {
                self.bolusEvents3Days = events
            }
        }

        healthStore.execute(query)
    }

    /// Basal Events (Today/Yesterday/DayBefore) — REAL
    @MainActor
    func fetchBasalEvents3DaysV1() {
        if isPreview { return }

        guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else { return }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -2, to: todayStart) else { return }

        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)

        let basalPredicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyInsulinDeliveryReason,
            allowedValues: [HKInsulinDeliveryReason.basal.rawValue]
        )

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, basalPredicate])

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard let self else { return }

            let quantitySamples = (samples as? [HKQuantitySample]) ?? []
            let unit = HKUnit.internationalUnit()

            // CHANGE: Basal ist Event (wie Bolus), kein Segment mehr
            let events: [InsulinBasalEvent] = quantitySamples.map { s in
                let units = s.quantity.doubleValue(for: unit)
                return InsulinBasalEvent(                         // CHANGE
                    id: UUID(),
                    timestamp: s.startDate,
                    units: max(0, units)
                )
            }

            DispatchQueue.main.async {
                self.basalEvents3Days = events                    // CHANGE
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - DAILYSTATS90 (Trends)
    // ============================================================

    /// Daily Bolus Sum (≥90 Tage) — REAL
    @MainActor
    func fetchDailyBolus90V1() {
        if isPreview { return }

        guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else { return }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(90 - 1), to: todayStart) else {
            DispatchQueue.main.async { [weak self] in self?.dailyBolus90 = [] }
            return
        }

        let bolusPredicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyInsulinDeliveryReason,
            allowedValues: [HKInsulinDeliveryReason.bolus.rawValue]
        )

        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, bolusPredicate])

        let interval = DateComponents(day: 1)
        let unit = HKUnit.internationalUnit()

        var daily: [DailyBolusEntry] = []

        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self, let results else { return }

            daily.removeAll(keepingCapacity: true)

            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let sum = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                daily.append(
                    DailyBolusEntry(
                        id: UUID(),
                        date: stats.startDate,
                        bolusUnits: max(0, sum)
                    )
                )
            }

            DispatchQueue.main.async {
                self.dailyBolus90 = daily.sorted { $0.date < $1.date }
            }
        }

        healthStore.execute(query)
    }

    /// Daily Basal Sum (≥90 Tage) — REAL
    @MainActor
    func fetchDailyBasal90V1() {
        if isPreview { return }

        guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else { return }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(90 - 1), to: todayStart) else {
            DispatchQueue.main.async { [weak self] in self?.dailyBasal90 = [] }
            return
        }

        let basalPredicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyInsulinDeliveryReason,
            allowedValues: [HKInsulinDeliveryReason.basal.rawValue]
        )

        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, basalPredicate])

        let interval = DateComponents(day: 1)
        let unit = HKUnit.internationalUnit()

        var daily: [DailyBasalEntry] = []

        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self, let results else { return }

            daily.removeAll(keepingCapacity: true)

            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let sum = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                daily.append(
                    DailyBasalEntry(
                        id: UUID(),
                        date: stats.startDate,
                        basalUnits: max(0, sum)
                    )
                )
            }

            DispatchQueue.main.async {
                self.dailyBasal90 = daily.sorted { $0.date < $1.date }
            }
        }

        healthStore.execute(query)
    }
}

// ============================================================
// MARK: - Async Wrappers (FIX: wait for HealthKit completion)
// ============================================================

extension HealthStore {

    @MainActor
    func fetchDailyBolus90V1Async() async {
        if isPreview { return }

        guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else {
            self.dailyBolus90 = []
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(90 - 1), to: todayStart) else {
            self.dailyBolus90 = []
            return
        }

        let bolusPredicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyInsulinDeliveryReason,
            allowedValues: [HKInsulinDeliveryReason.bolus.rawValue]
        )

        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, bolusPredicate])

        let interval = DateComponents(day: 1)
        let unit = HKUnit.internationalUnit()

        let out: [DailyBolusEntry] = await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                guard let results else {
                    continuation.resume(returning: [])
                    return
                }

                var daily: [DailyBolusEntry] = []
                daily.reserveCapacity(90)

                results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                    let sum = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                    daily.append(
                        DailyBolusEntry(
                            id: UUID(),
                            date: stats.startDate,
                            bolusUnits: max(0, sum)
                        )
                    )
                }

                continuation.resume(returning: daily.sorted { $0.date < $1.date })
            }

            self.healthStore.execute(query)
        }

        self.dailyBolus90 = out
    }

    @MainActor
    func fetchDailyBasal90V1Async() async {
        if isPreview { return }

        guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else {
            self.dailyBasal90 = []
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(90 - 1), to: todayStart) else {
            self.dailyBasal90 = []
            return
        }

        let basalPredicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyInsulinDeliveryReason,
            allowedValues: [HKInsulinDeliveryReason.basal.rawValue]
        )

        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, basalPredicate])

        let interval = DateComponents(day: 1)
        let unit = HKUnit.internationalUnit()

        let out: [DailyBasalEntry] = await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                guard let results else {
                    continuation.resume(returning: [])
                    return
                }

                var daily: [DailyBasalEntry] = []
                daily.reserveCapacity(90)

                results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                    let sum = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                    daily.append(
                        DailyBasalEntry(
                            id: UUID(),
                            date: stats.startDate,
                            basalUnits: max(0, sum)
                        )
                    )
                }

                continuation.resume(returning: daily.sorted { $0.date < $1.date })
            }

            self.healthStore.execute(query)
        }

        self.dailyBasal90 = out
    }
}
