//
//  HealthStore+MetabolicDailyStatsV1.swift
//  GluVibProbe
//
//  Metabolic V1 — DailyStats90 (≥90 Tage)
//
//  SSOT:
//  Apple Health → HealthStore → Published Arrays (DailyStats90)
//
//  !!! UPDATED (Race-Condition Fix):
//  - await fetchLast90DaysCarbsV1Async() bevor mirror + derived
//

import Foundation

extension HealthStore {

    // ============================================================
    // MARK: - Metabolic V1 DailyStats90 — Public API
    // ============================================================

    @MainActor
    func refreshMetabolicDailyStats90V1(refreshSource: String) async {
        if isPreview { return }

        // --------------------------------------------------------
        // 1) Carbs Daily (90) — ✅ deterministisch await
        // --------------------------------------------------------
        await fetchLast90DaysCarbsV1Async()                        // !!! UPDATED
        mirrorNutritionCarbs90IntoMetabolicV1()                    // !!! UPDATED (now safe)

        // --------------------------------------------------------
        // 2) Insulin Daily (90) — REAL via HealthStore+InsulinV1
        // --------------------------------------------------------
        await fetchDailyBolus90V1Async()                           // !!! UPDATED
        await fetchDailyBasal90V1Async()                           // !!! UPDATED

        // --------------------------------------------------------
        // 3) Derived Ratios (no refetch) — ✅ stable now
        // --------------------------------------------------------
        recomputeMetabolicDerivedDailyArraysV1()                   // !!! UPDATED

        // !!! TODO (später):
        // - Fetch glucose stats (mean/sd/cv + coverage)
        // - Compute daily TIR (threshold-based) from cached CGM samples
    }

    @MainActor
    func recomputeMetabolicDailyStats90AfterThresholdChangeV1() {
        if isPreview { return }
        // !!! TODO (später): Recompute dailyTIR90 from cached CGM samples + thresholds
    }

    /// Recompute der Derived Daily Arrays (Ratios etc.) ohne Refetch.
    @MainActor
    func recomputeMetabolicDerivedDailyArraysV1() {
        if isPreview { return }

        recomputeBolusBasalRatio90V1()
        recomputeCarbBolusRatio90V1()
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    @MainActor
    func mirrorNutritionCarbs90IntoMetabolicV1() {
        dailyCarbs90 = last90DaysCarbs
    }

    // ------------------------------------------------------------
    // Derived Ratio Helpers
    // ------------------------------------------------------------

    /// dailyBolusBasalRatio90: bolusUnits / basalUnits (per day)
    @MainActor
    func recomputeBolusBasalRatio90V1() {
        let calendar = Calendar.current

        var basalByDay: [Date: Double] = [:]
        for b in dailyBasal90 {
            let day = calendar.startOfDay(for: b.date)
            basalByDay[day] = b.basalUnits
        }

        var out: [DailyBolusBasalRatioEntry] = []
        out.reserveCapacity(dailyBolus90.count)

        for bolus in dailyBolus90 {
            let day = calendar.startOfDay(for: bolus.date)
            let basal = basalByDay[day] ?? 0

            let ratio: Double
            if basal > 0 {
                ratio = bolus.bolusUnits / basal
            } else {
                ratio = 0
            }

            out.append(
                DailyBolusBasalRatioEntry(
                    id: UUID(),
                    date: day,
                    ratio: ratio
                )
            )
        }

        dailyBolusBasalRatio90 = out.sorted { $0.date < $1.date }
    }

    /// dailyCarbBolusRatio90: carbsGrams / bolusUnits (per day)
    @MainActor
    func recomputeCarbBolusRatio90V1() {
        let calendar = Calendar.current

        var carbsByDay: [Date: Double] = [:]
        for c in dailyCarbs90 {
            let day = calendar.startOfDay(for: c.date)
            carbsByDay[day] = Double(max(0, c.grams))
        }

        var out: [DailyCarbBolusRatioEntry] = []
        out.reserveCapacity(dailyBolus90.count)

        for bolus in dailyBolus90 {
            let day = calendar.startOfDay(for: bolus.date)
            let carbs = carbsByDay[day] ?? 0

            let gramsPerUnit: Double
            if bolus.bolusUnits > 0 {
                gramsPerUnit = carbs / bolus.bolusUnits
            } else {
                gramsPerUnit = 0
            }

            out.append(
                DailyCarbBolusRatioEntry(
                    id: UUID(),
                    date: day,
                    gramsPerUnit: gramsPerUnit
                )
            )
        }

        dailyCarbBolusRatio90 = out.sorted { $0.date < $1.date }
    }

    @MainActor
    func clearMetabolicDailyStats90CacheV1() {
        dailyGlucoseStats90 = []
        dailyTIR90 = []
        dailyBolus90 = []
        dailyBasal90 = []
        dailyBolusBasalRatio90 = []
        dailyCarbs90 = []
        dailyCarbBolusRatio90 = []
    }
}
