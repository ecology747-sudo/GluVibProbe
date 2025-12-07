//
//  BodyInsightEngine.swift
//  GluVibProbe
//
//  Simple rule-based engine for Body overview insights
//  - Uses weight trend, sleep vs. goal, BMI, body fat and resting HR
//  - Returns short, readable English text
//

import Foundation

/// Input container for the Body insight engine.
struct BodyInsightInput {
    let weightTrend: [WeightTrendPoint]
    let lastNightSleepMinutes: Int
    let sleepGoalMinutes: Int
    let bmi: Double
    let bodyFatPercent: Double
    let restingHeartRateBpm: Int
}

/// Small rule-based engine that generates a short body insight text.
struct BodyInsightEngine {

    func makeInsight(for input: BodyInsightInput) -> String {

        // ─────────────────────────────────────────────
        // 1) Check data availability
        // ─────────────────────────────────────────────
        guard
            let first = input.weightTrend.first?.weightKg,
            let last  = input.weightTrend.last?.weightKg
        else {
            return "There is not enough data yet to generate a meaningful body insight."
        }

        let diff = last - first   // positive = weight up

        // Sleep vs. goal
        let sleepRatio: Double
        if input.sleepGoalMinutes > 0 {
            sleepRatio = Double(input.lastNightSleepMinutes) / Double(input.sleepGoalMinutes)
        } else {
            sleepRatio = 0
        }

        // Very rough BMI bands
        let bmi = input.bmi
        let isHighBMI = bmi >= 25.0
        let isVeryHighBMI = bmi >= 30.0

        // ─────────────────────────────────────────────
        // 2) Build text by simple rules
        //    (short, 1–2 Sätze – ähnlich zur NutritionEngine)
        // ─────────────────────────────────────────────

        // Helper closures for short phrases
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
                return "With your current BMI, gentle weight trends already matter. "
            } else {
                return ""
            }
        }

        // 2.1 Weight roughly stable
        if abs(diff) <= 0.5 {
            if sleepRatio < 0.8 {
                return "Your weight has been fairly stable over the last days. \(sleepShortPhrase()) A bit more rest can support recovery and appetite control."
            } else {
                return "Your weight has been fairly stable over the last days. \(sleepShortPhrase()) Staying consistent with your current routine is a good baseline."
            }
        }

        // 2.2 Weight going up
        if diff > 0.5 {
            if sleepRatio < 0.8 {
                // Gewicht hoch + wenig Schlaf
                return "Your weight has slightly increased over the last days. \(sleepShortPhrase()) Earlier nights and lighter evening meals can help stabilise your weight."
            } else {
                // Gewicht hoch + Schlaf ok
                return "\(bmiPhrasePrefix())Your weight has slightly increased over the last days. Paying attention to portions and evening snacks can help if this trend continues."
            }
        }

        // 2.3 Weight going down
        if diff < -0.5 {
            if sleepRatio < 0.8 {
                return "Your weight has slightly decreased over the last days while sleep was a bit short. Try to keep your current routine and add a little more rest where possible."
            } else {
                return "Your weight has slightly decreased over the last days. Keeping sleep, nutrition and activity consistent can help you maintain this healthy trend."
            }
        }

        // Fallback (sollte praktisch nicht erreicht werden)
        return "Your recent weight and sleep pattern looks mostly stable. Small, consistent habits around sleep, movement and meals will keep things on track."
    }
}
