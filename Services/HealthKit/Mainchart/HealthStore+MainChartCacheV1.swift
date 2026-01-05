//
//  HealthStore+MainChartCacheV1.swift
//  GluVibProbe
//
//  Metabolic MainChart Cache (V1)
//  - Cache-State liegt in HealthStore.swift (stored properties)
//  - Diese Extension enthält NUR Logik (read/write/prune), keine stored properties
//

import Foundation
import HealthKit

// MARK: - Cache Model

struct MainChartCacheItemV1: Identifiable {
    let id: String
    let dayStart: Date
    let profile: MainChartDayProfileV1

    init(dayStart: Date, profile: MainChartDayProfileV1) {
        self.dayStart = dayStart
        self.profile = profile
        self.id = MainChartCacheItemV1.makeID(for: dayStart)
    }

    static func makeID(for dayStart: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: dayStart)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}

// MARK: - HealthStore Cache API

extension HealthStore {

    // ============================================================
    // MARK: - Public Read
    // ============================================================

    func cachedMainChartProfileV1(dayOffset: Int) -> MainChartDayProfileV1? {
        let dayStart = mainChartDayStartV1(dayOffset: dayOffset)
        let id = MainChartCacheItemV1.makeID(for: dayStart)
        return mainChartCacheV1.first(where: { $0.id == id })?.profile
    }

    func cachedMainChartItemV1(dayOffset: Int) -> MainChartCacheItemV1? {
        let dayStart = mainChartDayStartV1(dayOffset: dayOffset)
        let id = MainChartCacheItemV1.makeID(for: dayStart)
        return mainChartCacheV1.first(where: { $0.id == id })
    }

    // ============================================================
    // MARK: - Public Write (Deterministisch nach RAW-Fetch)
    // ============================================================

    /// Baut den Cache aus den bereits vorhandenen RAW-3Days Daten neu auf
    /// - Erwartung: Die RAW Arrays (CGM/Insulin/Nutrition/Activity) sind bereits im HealthStore gesetzt.
    func rebuildMainChartCacheFromRaw3DaysV1() {
        let offsets = [0, -1, -2] // Today, Yesterday, DayBefore
        var next: [MainChartCacheItemV1] = []

        for offset in offsets {
            let dayStart = mainChartDayStartV1(dayOffset: offset)
            let profile = buildMainChartDayProfileV1_fromCurrentRawCaches(dayStart: dayStart)
            next.append(MainChartCacheItemV1(dayStart: dayStart, profile: profile))
        }

        // Merge: bestehende ältere Einträge behalten, aber 3 Tage immer “frisch”
        let idsToReplace = Set(next.map { $0.id })
        var merged = mainChartCacheV1.filter { !idsToReplace.contains($0.id) }
        merged.append(contentsOf: next)

        // Prune: maximal 10 Tage
        merged = pruneMainChartCacheV1(merged, maxDays: 10)

        // Sort: neueste zuerst
        merged.sort { $0.dayStart > $1.dayStart }

        mainChartCacheV1 = merged
        mainChartCacheLastUpdatedV1 = Date()
    }

    // ============================================================
    // MARK: - On-Demand Cache Fill (Day -3 ... -9)
    // ============================================================

    @MainActor
    func ensureMainChartCachedV1(dayOffset: Int, forceRefetch: Bool = false) async {
        if isPreview { return }

        // 0/-1/-2 bleiben RAW3DAYS → rebuild (inkl. aller Overlays aus bestehenden Arrays)
        if [0, -1, -2].contains(dayOffset) {
            rebuildMainChartCacheFromRaw3DaysV1()
            return
        }

        let dayStart = mainChartDayStartV1(dayOffset: dayOffset)
        let id = MainChartCacheItemV1.makeID(for: dayStart)

        if !forceRefetch, mainChartCacheV1.contains(where: { $0.id == id }) {
            return
        }

        // CHANGE: Ältere Tage (-3 ... -9) laden CGM + Bolus + Basal (Events) + Carbs + Protein symmetrisch per Day-Fetch
        async let cgm = fetchCGMSamplesForDayV1(dayStart: dayStart)
        async let bolus = fetchBolusEventsForDayV1(dayStart: dayStart)
        async let basal = fetchBasalEventsForDayV1(dayStart: dayStart) // CHANGE: Segments -> Events

        async let carbs = fetchCarbEventsForDayV1(dayStart: dayStart)
        async let protein = fetchProteinEventsForDayV1(dayStart: dayStart)

        let rawCarbs = await carbs
        let rawProtein = await protein

        let clusteredCarbs = clusterNutritionEventsV1(rawCarbs, windowMinutes: 10)
        let clusteredProtein = clusterNutritionEventsV1(rawProtein, windowMinutes: 10)

        let profile = MainChartDayProfileV1(
            id: UUID(),
            day: dayStart,
            builtAt: Date(),
            isToday: Calendar.current.isDate(dayStart, inSameDayAs: Date()),
            cgm: await cgm,
            bolus: await bolus,
            basal: await basal,                 // CHANGE: Basal Events
            carbs: clusteredCarbs,
            protein: clusteredProtein,
            activity: [],
            finger: []
        )

        upsertMainChartCacheItemV1(
            item: MainChartCacheItemV1(dayStart: dayStart, profile: profile),
            maxDays: 10
        )
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    func mainChartDayStartV1(dayOffset: Int) -> Date {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: dayOffset, to: todayStart) ?? todayStart
    }

    private func pruneMainChartCacheV1(_ items: [MainChartCacheItemV1], maxDays: Int) -> [MainChartCacheItemV1] {
        guard maxDays > 0 else { return [] }

        // Unique by id (falls doppelt)
        var dict: [String: MainChartCacheItemV1] = [:]
        for item in items { dict[item.id] = item }

        let sorted = dict.values.sorted { $0.dayStart > $1.dayStart }
        return Array(sorted.prefix(maxDays))
    }

    @MainActor
    private func upsertMainChartCacheItemV1(item: MainChartCacheItemV1, maxDays: Int) {
        var merged = mainChartCacheV1.filter { $0.id != item.id }
        merged.append(item)

        merged = pruneMainChartCacheV1(merged, maxDays: maxDays)
        merged.sort { $0.dayStart > $1.dayStart }

        mainChartCacheV1 = merged
        mainChartCacheLastUpdatedV1 = Date()
    }

    @MainActor
    private func buildMainChartDayProfileV1_fromCurrentRawCaches(dayStart: Date) -> MainChartDayProfileV1 {
        let cal = Calendar.current
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let todayStart = cal.startOfDay(for: Date())
        let isToday = (dayStart == todayStart)
        let end: Date = isToday ? Date() : dayEnd

        let cgm = cgmSamples3Days
            .filter { $0.timestamp >= dayStart && $0.timestamp < end }
            .sorted { $0.timestamp < $1.timestamp }

        let bolus = bolusEvents3Days
            .filter { $0.timestamp >= dayStart && $0.timestamp < end }
            .sorted { $0.timestamp < $1.timestamp }

        // CHANGE: Basal ist Event wie Bolus (timestamp), kein Segment mehr
        // CHANGE: Sub-Expressions, damit der Compiler NICHT an der Expression stirbt (“unable to type-check…”)
        let basalAll = basalEvents3Days
        let basalFiltered = basalAll.filter { $0.timestamp >= dayStart && $0.timestamp < end }
        let basal = basalFiltered.sorted { $0.timestamp < $1.timestamp }

        // Meal-Cluster (10 Min) pro Kind
        let rawCarbs = carbEvents3Days
            .filter { $0.timestamp >= dayStart && $0.timestamp < end && $0.kind == .carbs }
            .sorted { $0.timestamp < $1.timestamp }

        let rawProtein = proteinEvents3Days
            .filter { $0.timestamp >= dayStart && $0.timestamp < end && $0.kind == .protein }
            .sorted { $0.timestamp < $1.timestamp }

        let carbs = clusterNutritionEventsV1(rawCarbs, windowMinutes: 10)
        let protein = clusterNutritionEventsV1(rawProtein, windowMinutes: 10)

        let activity = activityEvents3Days
            .filter { $0.end > dayStart && $0.start < end }
            .sorted { $0.start < $1.start }

        let finger = fingerGlucoseEvents3Days
            .filter { $0.timestamp >= dayStart && $0.timestamp < end }
            .sorted { $0.timestamp < $1.timestamp }

        return MainChartDayProfileV1(
            id: UUID(),
            day: dayStart,
            builtAt: Date(),
            isToday: isToday,
            cgm: cgm,
            bolus: bolus,
            basal: basal,              // CHANGE: Basal Events
            carbs: carbs,
            protein: protein,
            activity: activity,
            finger: finger
        )
    }

    // ============================================================
    // MARK: - Nutrition Cluster Helper (Meal Window)
    // ============================================================

    private func clusterNutritionEventsV1(
        _ events: [NutritionEvent],
        windowMinutes: Int
    ) -> [NutritionEvent] {
        guard !events.isEmpty else { return [] }

        let window: TimeInterval = TimeInterval(max(1, windowMinutes) * 60)

        var result: [NutritionEvent] = []
        result.reserveCapacity(events.count)

        var currentKind: NutritionEventKind? = nil
        var currentStart: Date? = nil
        var lastTime: Date? = nil
        var sum: Double = 0

        func flushIfNeeded() {
            guard let kind = currentKind, let start = currentStart else { return }
            guard sum > 0 else { return }
            result.append(
                NutritionEvent(
                    id: UUID(),
                    timestamp: start,
                    grams: sum,
                    kind: kind
                )
            )
        }

        for e in events {
            if currentKind == nil {
                currentKind = e.kind
                currentStart = e.timestamp
                lastTime = e.timestamp
                sum = max(0, e.grams)
                continue
            }

            let sameKind = (e.kind == currentKind)
            let closeEnough = (lastTime.map { e.timestamp.timeIntervalSince($0) <= window } ?? false)

            if sameKind && closeEnough {
                sum += max(0, e.grams)
                lastTime = e.timestamp
            } else {
                flushIfNeeded()
                currentKind = e.kind
                currentStart = e.timestamp
                lastTime = e.timestamp
                sum = max(0, e.grams)
            }
        }

        flushIfNeeded()
        return result.sorted { $0.timestamp < $1.timestamp }
    }

    // ============================================================
    // MARK: - HealthKit Fetch (per-day)
    // ============================================================

    private func fetchCGMSamplesForDayV1(dayStart: Date) async -> [CGMSamplePoint] {
        if isPreview { return [] }
        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return [] }

        let cal = Calendar.current
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let mgdlUnit = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))

        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let quantitySamples = (samples as? [HKQuantitySample]) ?? []

                var byTimestamp: [TimeInterval: CGMSamplePoint] = [:]
                byTimestamp.reserveCapacity(quantitySamples.count)

                for s in quantitySamples {
                    let key = s.startDate.timeIntervalSince1970.rounded()
                    byTimestamp[key] = CGMSamplePoint(
                        id: UUID(),
                        timestamp: s.startDate,
                        glucoseMgdl: s.quantity.doubleValue(for: mgdlUnit)
                    )
                }

                let points = byTimestamp.values.sorted { $0.timestamp < $1.timestamp }
                continuation.resume(returning: points)
            }

            self.healthStore.execute(query)
        }
    }

    private func fetchBolusEventsForDayV1(dayStart: Date) async -> [InsulinBolusEvent] {
        if isPreview { return [] }
        guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else { return [] }

        let cal = Calendar.current
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let datePredicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
        let bolusPredicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyInsulinDeliveryReason,
            allowedValues: [HKInsulinDeliveryReason.bolus.rawValue]
        )
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, bolusPredicate])

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let unit = HKUnit.internationalUnit()

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let quantitySamples = (samples as? [HKQuantitySample]) ?? []

                let events: [InsulinBolusEvent] = quantitySamples.map { s in
                    InsulinBolusEvent(
                        id: UUID(),
                        timestamp: s.startDate,
                        units: max(0, s.quantity.doubleValue(for: unit))
                    )
                }

                continuation.resume(returning: events)
            }

            self.healthStore.execute(query)
        }
    }

    // CHANGE: Basal = Event (wie Bolus), kein Segment-Fetch mehr
    private func fetchBasalEventsForDayV1(dayStart: Date) async -> [InsulinBasalEvent] {
        if isPreview { return [] }
        guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else { return [] }

        let cal = Calendar.current
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let datePredicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
        let basalPredicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyInsulinDeliveryReason,
            allowedValues: [HKInsulinDeliveryReason.basal.rawValue]
        )
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, basalPredicate])

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let unit = HKUnit.internationalUnit()

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let quantitySamples = (samples as? [HKQuantitySample]) ?? []

                let events: [InsulinBasalEvent] = quantitySamples.map { s in
                    InsulinBasalEvent(
                        id: UUID(),
                        timestamp: s.startDate,
                        units: max(0, s.quantity.doubleValue(for: unit))
                    )
                }

                continuation.resume(returning: events)
            }

            self.healthStore.execute(query)
        }
    }

    // ============================================================
    // MARK: - Nutrition Fetch (per-day) – Carbs / Protein
    // ============================================================

    private func fetchCarbEventsForDayV1(dayStart: Date) async -> [NutritionEvent] {
        if isPreview { return [] }
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else { return [] }

        let cal = Calendar.current
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let quantitySamples = (samples as? [HKQuantitySample]) ?? []
                let events: [NutritionEvent] = quantitySamples.map { s in
                    let grams = s.quantity.doubleValue(for: .gram())
                    return NutritionEvent(
                        id: UUID(),
                        timestamp: s.startDate,
                        grams: max(0, grams),
                        kind: .carbs
                    )
                }
                continuation.resume(returning: events)
            }

            self.healthStore.execute(query)
        }
    }

    private func fetchProteinEventsForDayV1(dayStart: Date) async -> [NutritionEvent] {
        if isPreview { return [] }
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) else { return [] }

        let cal = Calendar.current
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let quantitySamples = (samples as? [HKQuantitySample]) ?? []
                let events: [NutritionEvent] = quantitySamples.map { s in
                    let grams = s.quantity.doubleValue(for: .gram())
                    return NutritionEvent(
                        id: UUID(),
                        timestamp: s.startDate,
                        grams: max(0, grams),
                        kind: .protein
                    )
                }
                continuation.resume(returning: events)
            }

            self.healthStore.execute(query)
        }
    }
}
