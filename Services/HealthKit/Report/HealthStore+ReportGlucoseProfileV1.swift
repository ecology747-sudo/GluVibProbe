//
//  HealthStore+ReportGlucoseProfileV1.swift
//  GluVibProbe
//
//  Report V1 — On-demand Glucose Profile Builder
//  - No Published properties
//  - No Bootstrap wiring
//  - Base unit: mg/dL
//

import Foundation
import HealthKit

extension HealthStore {

    // ============================================================
    // MARK: - Public API (On-demand)
    // ============================================================

    /// Builds a 24h percentile profile (96 slots, 15-min steps) from the last N FULL days.
    /// - Example: days=30 -> last 30 full days ending at todayStart (excludes "today partial").
    @MainActor
    func buildReportGlucoseProfileV1(days: Int) async -> ReportGlucoseProfileV1 {
        if isPreview {
            return ReportGlucoseProfileV1(
                days: max(1, days),
                points: (0..<96).map {
                    ReportGlucoseProfilePointV1(
                        slot: $0,
                        p05: nil, p25: nil, p50: nil, p75: nil, p95: nil,
                        sampleCount: 0
                    )
                },
                targetMinMgdl: Double(SettingsModel.shared.glucoseMin),
                targetMaxMgdl: Double(SettingsModel.shared.glucoseMax),
                veryLowLimitMgdl: Double(SettingsModel.shared.veryLowLimit),
                veryHighLimitMgdl: Double(SettingsModel.shared.veryHighLimit),
                distinctDaysWithAnyData: 0
            )
        }

        let nDays = max(1, days)

        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)

        // Full-day window: [start, end) where end = todayStart (excludes today partial)
        let end = todayStart
        let start = cal.date(byAdding: .day, value: -nDays, to: todayStart) ?? todayStart

        let samples = await fetchBloodGlucoseSamplesMgdlV1(start: start, end: end)

        // 96 slots (15-min)
        var slotValues: [[Double]] = Array(repeating: [], count: 96)
        slotValues.reserveCapacity(96)

        var daysWithAnyData: Set<Date> = []

        for s in samples {
            let dayStart = cal.startOfDay(for: s.timestamp)
            daysWithAnyData.insert(dayStart)

            let minutes = cal.dateComponents([.minute], from: dayStart, to: s.timestamp).minute ?? 0
            if minutes < 0 || minutes >= 1440 { continue }

            let slot = min(95, max(0, minutes / 15))
            slotValues[slot].append(s.mgdl)
        }

        let points: [ReportGlucoseProfilePointV1] = (0..<96).map { slot in
            let values = slotValues[slot]
            if values.isEmpty {
                return ReportGlucoseProfilePointV1(
                    slot: slot,
                    p05: nil, p25: nil, p50: nil, p75: nil, p95: nil,
                    sampleCount: 0
                )
            }

            let sorted = values.sorted()

            let p05 = percentile(sorted, 0.05)
            let p25 = percentile(sorted, 0.25)
            let p50 = percentile(sorted, 0.50)
            let p75 = percentile(sorted, 0.75)
            let p95 = percentile(sorted, 0.95)

            return ReportGlucoseProfilePointV1(
                slot: slot,
                p05: p05,
                p25: p25,
                p50: p50,
                p75: p75,
                p95: p95,
                sampleCount: sorted.count
            )
        }

        let s = SettingsModel.shared

        return ReportGlucoseProfileV1(
            days: nDays,
            points: points,
            targetMinMgdl: Double(s.glucoseMin),
            targetMaxMgdl: Double(s.glucoseMax),
            veryLowLimitMgdl: Double(s.veryLowLimit),
            veryHighLimitMgdl: Double(s.veryHighLimit),
            distinctDaysWithAnyData: daysWithAnyData.count
        )
    }
}

// ============================================================
// MARK: - Private Helpers
// ============================================================

private extension HealthStore {

    struct ReportGlucoseSampleV1 {
        let timestamp: Date
        let mgdl: Double
    }

    func fetchBloodGlucoseSamplesMgdlV1(start: Date, end: Date) async -> [ReportGlucoseSampleV1] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let mgdlUnit = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))

        let raw: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            self.healthStore.execute(query)
        }

        if raw.isEmpty { return [] }

        var byTimestamp: [TimeInterval: ReportGlucoseSampleV1] = [:]
        byTimestamp.reserveCapacity(raw.count)

        for s in raw {
            let key = s.startDate.timeIntervalSince1970.rounded()
            byTimestamp[key] = ReportGlucoseSampleV1(
                timestamp: s.startDate,
                mgdl: s.quantity.doubleValue(for: mgdlUnit)
            )
        }

        return byTimestamp.values.sorted { $0.timestamp < $1.timestamp }
    }

    func percentile(_ sorted: [Double], _ p: Double) -> Double {
        if sorted.isEmpty { return 0 }

        let clamped = min(1.0, max(0.0, p))
        if sorted.count == 1 { return sorted[0] }

        let pos = clamped * Double(sorted.count - 1)
        let lower = Int(floor(pos))
        let upper = Int(ceil(pos))

        if lower == upper { return sorted[lower] }

        let weight = pos - Double(lower)
        return sorted[lower] * (1.0 - weight) + sorted[upper] * weight
    }
}
