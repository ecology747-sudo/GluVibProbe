//
//  BodyInsightEngine.swift
//  GluVibProbe
//
//  Simple rule-based engine for Body overview insights
//  - TODAY-only usage happens in the ViewModel (selectedDayOffset == 0)
//  - Engine itself stays focused: no day-offset, no past-day wording, no date logic
//  - Uses weight trend, sleep vs. goal, BMI, body fat and resting HR
//  - Returns short, readable English text
//

import Foundation

// ============================================================
// MARK: - Minimal model to satisfy compilation (V1 compatible)
// ============================================================

// !!! NEW: If WeightTrendPoint is missing in the project, this provides it.
// NOTE: If you already have WeightTrendPoint elsewhere, delete THIS struct to avoid redeclaration.
struct WeightTrendPoint: Identifiable {                      // !!! NEW
    let id = UUID()                                          // !!! NEW
    let date: Date                                           // !!! NEW
    let weightKg: Double                                     // !!! NEW
}

// ============================================================
// MARK: - Trend protocol (compat: old + V1)
// ============================================================

protocol BodyWeightTrendPointing {
    var weightKg: Double { get }
}

// Make BOTH types compatible (no other file changes needed)
extension WeightTrendPoint: BodyWeightTrendPointing {}
extension BodyWeightTrendPoint: BodyWeightTrendPointing {}

// ============================================================
// MARK: - Input container (generic over trend type)
// ============================================================

struct BodyInsightInput<T: BodyWeightTrendPointing> {
    let weightTrend: [T]
    let lastNightSleepMinutes: Int
    let sleepGoalMinutes: Int
    let bmi: Double
    let bodyFatPercent: Double
    let restingHeartRateBpm: Int
}

// ============================================================
// MARK: - Engine
// ============================================================

struct BodyInsightEngine {

    func makeInsight<T: BodyWeightTrendPointing>(for input: BodyInsightInput<T>) -> String {

        // ─────────────────────────────────────────────
        // 1) Data availability
        // ─────────────────────────────────────────────

        guard
            let first = input.weightTrend.first?.weightKg,
            let last  = input.weightTrend.last?.weightKg
        else {
            return "There is not enough data yet to generate a meaningful body insight."
        }

        let diff = last - first   // positive = weight up

        // Sleep vs. goal
        let sleepRatio: Double = {
            guard input.sleepGoalMinutes > 0 else { return 0 }
            return Double(input.lastNightSleepMinutes) / Double(input.sleepGoalMinutes)
        }()

        // BMI bands
        let bmi = input.bmi
        let isHighBMI = bmi >= 25.0
        let isVeryHighBMI = bmi >= 30.0

        // Body fat / HR (kept, but used lightly → no logic explosion)
        let bodyFat = input.bodyFatPercent
        let rhr = input.restingHeartRateBpm

        // ─────────────────────────────────────────────
        // 2) Small phrasing helpers (TODAY-only wording)
        // ─────────────────────────────────────────────

        func sleepShortPhrase() -> String {
            if sleepRatio < 0.8 {
                return "Sleep has been on the short side."
            } else if sleepRatio > 1.1 {
                return "Sleep looks solid overall."
            } else {
                return "Sleep has been roughly on target."
            }
        }

        func bmiPhrasePrefix() -> String {
            if isVeryHighBMI {
                return "Given your current BMI, even small, steady changes can be helpful. "
            } else if isHighBMI {
                return "With your current BMI, gentle trends already matter. "
            } else {
                return ""
            }
        }

        func recoveryNudgeIfNeeded() -> String {
            // very lightweight: only nudge if both signals are "high-ish"
            guard rhr >= 75 || bodyFat >= 30 else { return "" }
            return " Also keep an eye on recovery and stress."
        }

        // ─────────────────────────────────────────────
        // 3) Core rules (same behavior as before)
        // ─────────────────────────────────────────────

        // 3.1 Weight roughly stable
        if abs(diff) <= 0.5 {
            if sleepRatio < 0.8 {
                return "Your weight has been fairly stable over the last days. \(sleepShortPhrase()) A bit more rest can support recovery and appetite control.\(recoveryNudgeIfNeeded())"
            } else {
                return "Your weight has been fairly stable over the last days. \(sleepShortPhrase()) Staying consistent with your current routine is a good baseline.\(recoveryNudgeIfNeeded())"
            }
        }

        // 3.2 Weight going up
        if diff > 0.5 {
            if sleepRatio < 0.8 {
                return "Your weight has slightly increased over the last days. \(sleepShortPhrase()) Earlier nights and lighter evening meals can help stabilise your weight.\(recoveryNudgeIfNeeded())"
            } else {
                return "\(bmiPhrasePrefix())Your weight has slightly increased over the last days. Paying attention to portions and evening snacks can help if this trend continues.\(recoveryNudgeIfNeeded())"
            }
        }

        // 3.3 Weight going down
        if diff < -0.5 {
            if sleepRatio < 0.8 {
                return "Your weight has slightly decreased over the last days while sleep was a bit short. Try to keep your current routine and add a little more rest where possible.\(recoveryNudgeIfNeeded())"
            } else {
                return "Your weight has slightly decreased over the last days. Keeping sleep, nutrition and activity consistent can help you maintain this healthy trend.\(recoveryNudgeIfNeeded())"
            }
        }

        return "Your recent weight and sleep pattern looks mostly stable. Small, consistent habits around sleep, movement and meals will keep things on track.\(recoveryNudgeIfNeeded())"
    }
}
