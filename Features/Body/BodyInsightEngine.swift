//
//  BodyInsightEngine.swift
//  GluVibProbe
//
//  Body Overview — Insight Engine
//
//  Purpose
//  - Creates short, rule-based insight text for the Body overview.
//  - TODAY-only usage is handled by the ViewModel.
//  - Engine stays focused on interpreting already prepared values.
//  - Uses weight trend, sleep vs. goal, BMI, body fat and resting HR.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → BodyOverviewViewModelV1 → BodyInsightEngine
//

import Foundation

// ============================================================
// MARK: - Minimal model to satisfy compilation (V1 compatible)
// ============================================================

struct WeightTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weightKg: Double
}

// ============================================================
// MARK: - Trend protocol (compat: old + V1)
// ============================================================

protocol BodyWeightTrendPointing {
    var weightKg: Double { get }
}

extension WeightTrendPoint: BodyWeightTrendPointing {}
extension BodyWeightTrendPoint: BodyWeightTrendPointing {}

// ============================================================
// MARK: - Input container
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

        // ------------------------------------------------------------
        // MARK: Data availability
        // ------------------------------------------------------------

        guard
            let first = input.weightTrend.first?.weightKg,
            let last = input.weightTrend.last?.weightKg
        else {
            return L10n.BodyOverviewInsight.notEnoughData
        }

        let diff = last - first

        let sleepRatio: Double = {
            guard input.sleepGoalMinutes > 0 else { return 0 }
            return Double(input.lastNightSleepMinutes) / Double(input.sleepGoalMinutes)
        }()

        let bmi = input.bmi
        let isHighBMI = bmi >= 25.0
        let isVeryHighBMI = bmi >= 30.0

        let bodyFat = input.bodyFatPercent
        let rhr = input.restingHeartRateBpm

        // ------------------------------------------------------------
        // MARK: Phrase helpers
        // ------------------------------------------------------------

        func sleepShortPhrase() -> String {
            if sleepRatio < 0.8 {
                return L10n.BodyOverviewInsight.sleepShort
            } else if sleepRatio > 1.1 {
                return L10n.BodyOverviewInsight.sleepSolid
            } else {
                return L10n.BodyOverviewInsight.sleepOnTarget
            }
        }

        func bmiPhrasePrefix() -> String {
            if isVeryHighBMI {
                return L10n.BodyOverviewInsight.bmiPrefixVeryHigh
            } else if isHighBMI {
                return L10n.BodyOverviewInsight.bmiPrefixHigh
            } else {
                return ""
            }
        }

        func recoveryNudgeIfNeeded() -> String {
            guard rhr >= 75 || bodyFat >= 30 else { return "" }
            return L10n.BodyOverviewInsight.recoveryNudge
        }

        // ------------------------------------------------------------
        // MARK: Core rules
        // ------------------------------------------------------------

        if abs(diff) <= 0.5 {
            if sleepRatio < 0.8 {
                return String(
                    localized: "overview.body.insight.weight_stable_sleep_short",
                    defaultValue: "%1$@ %2$@ A bit more rest can support recovery and appetite control.%3$@",
                    comment: "Body overview insight when weight is stable and sleep is short"
                )
                .replacingOccurrences(of: "%1$@", with: L10n.BodyOverviewInsight.weightStable)
                .replacingOccurrences(of: "%2$@", with: sleepShortPhrase())
                .replacingOccurrences(of: "%3$@", with: recoveryNudgeIfNeeded())
            } else {
                return String(
                    localized: "overview.body.insight.weight_stable_sleep_ok",
                    defaultValue: "%1$@ %2$@ Staying consistent with your current routine is a good baseline.%3$@",
                    comment: "Body overview insight when weight is stable and sleep is okay"
                )
                .replacingOccurrences(of: "%1$@", with: L10n.BodyOverviewInsight.weightStable)
                .replacingOccurrences(of: "%2$@", with: sleepShortPhrase())
                .replacingOccurrences(of: "%3$@", with: recoveryNudgeIfNeeded())
            }
        }

        if diff > 0.5 {
            if sleepRatio < 0.8 {
                return String(
                    localized: "overview.body.insight.weight_up_sleep_short",
                    defaultValue: "%1$@ %2$@ Earlier nights and lighter evening meals can help stabilise your weight.%3$@",
                    comment: "Body overview insight when weight is up and sleep is short"
                )
                .replacingOccurrences(of: "%1$@", with: L10n.BodyOverviewInsight.weightUp)
                .replacingOccurrences(of: "%2$@", with: sleepShortPhrase())
                .replacingOccurrences(of: "%3$@", with: recoveryNudgeIfNeeded())
            } else {
                return String(
                    localized: "overview.body.insight.weight_up_sleep_ok",
                    defaultValue: "%1$@%2$@ Paying attention to portions and evening snacks can help if this trend continues.%3$@",
                    comment: "Body overview insight when weight is up and sleep is okay"
                )
                .replacingOccurrences(of: "%1$@", with: bmiPhrasePrefix())
                .replacingOccurrences(of: "%2$@", with: L10n.BodyOverviewInsight.weightUp)
                .replacingOccurrences(of: "%3$@", with: recoveryNudgeIfNeeded())
            }
        }

        if diff < -0.5 {
            if sleepRatio < 0.8 {
                return String(
                    localized: "overview.body.insight.weight_down_sleep_short",
                    defaultValue: "%1$@ while sleep was a bit short. Try to keep your current routine and add a little more rest where possible.%2$@",
                    comment: "Body overview insight when weight is down and sleep is short"
                )
                .replacingOccurrences(of: "%1$@", with: L10n.BodyOverviewInsight.weightDown)
                .replacingOccurrences(of: "%2$@", with: recoveryNudgeIfNeeded())
            } else {
                return String(
                    localized: "overview.body.insight.weight_down_sleep_ok",
                    defaultValue: "%1$@ Keeping sleep, nutrition and activity consistent can help you maintain this healthy trend.%2$@",
                    comment: "Body overview insight when weight is down and sleep is okay"
                )
                .replacingOccurrences(of: "%1$@", with: L10n.BodyOverviewInsight.weightDown)
                .replacingOccurrences(of: "%2$@", with: recoveryNudgeIfNeeded())
            }
        }

        return String(
            localized: "overview.body.insight.fallback",
            defaultValue: "Your recent weight and sleep pattern looks mostly stable. Small, consistent habits around sleep, movement and meals will keep things on track.%@",
            comment: "Fallback body overview insight text"
        )
        .replacingOccurrences(of: "%@", with: recoveryNudgeIfNeeded()) // 🟨 UPDATED
    }
}
