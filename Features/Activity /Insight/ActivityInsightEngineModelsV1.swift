//
//  ActivityInsightEngineModelsV1.swift
//  GluVibProbe
//
//  Domain: Activity Insight Engine
//  Layer: Internal Models V1
//
//  Purpose
//  - Internal type system for ActivityInsightEngine.
//  - Keeps preparation, classification and resolution separated.
//  - Uses a closed end-state model so new edge cases do not create new output classes.
//

import Foundation

// ============================================================
// MARK: - Time / Stage
// ============================================================

// 🟨 UPDATED: simplified time model for Today Activity.
// The engine now works with three operational phases plus one practical day-close state.
enum AIWindowStageV1: String {
    case morning
    case afternoon
    case evening
    case dayClosed = "day_closed"
}

struct AIDayContextV1 {
    let minutesElapsed: Int
    let dayProgressFraction: Double
    let windowStage: AIWindowStageV1
    let isPracticalDayClose: Bool
}

// ============================================================
// MARK: - Availability / Data State
// ============================================================

// 🟨 UPDATED: availability is now explicit and always evaluated before activity interpretation.
enum AIAvailabilityStateV1: String {
    case ready
    case insufficientData = "insufficient_data"
    case noData = "no_data"
    case blocked
}

// ============================================================
// MARK: - Relative Signals
// ============================================================

enum AIRelativeStatusV1: String {
    case clearlyBelow = "clearly_below"
    case below
    case nearBaseline = "near_baseline"
    case above
    case clearlyAbove = "clearly_above"
}

enum AISignalStrengthV1: String {
    case weak
    case moderate
    case strong
}

enum AICombinedPrimaryStateV1: String {
    case clearlyAbove = "clearly_above"
    case above
    case neutral
    case below
    case clearlyBelow = "clearly_below"
    case mixedPrimary = "mixed_primary"
}

// ============================================================
// MARK: - Goal / Achievement
// ============================================================

enum AIGoalStatusV1: String {
    case farBelowGoal = "far_below_goal"
    case belowGoal = "below_goal"
    case nearGoal = "near_goal"
    case goalMet = "goal_met"
    case goalExceeded = "goal_exceeded"
}

// 🟨 UPDATED: achievement layer now distinguishes between
// normal goal reach and clearly overfulfilled / standout achievement.
enum AIAchievementStateV1: String {
    case none

    case stepGoalReached = "step_goal_reached"
    case energyGoalReached = "energy_goal_reached"
    case dualGoalReached = "dual_goal_reached"

    case strongStepAchievement = "strong_step_achievement"
    case strongEnergyAchievement = "strong_energy_achievement"
    case strongDualAchievement = "strong_dual_achievement"
}

// ============================================================
// MARK: - Internal Resolution Support
// ============================================================

// 🟨 UPDATED: lightweight internal bias model.
// This is not a public end-state. It only helps the resolver keep similar cases together.
enum AIInterpretationBiasV1: String {
    case none
    case positive
    case negative
    case mixed
}

// ============================================================
// MARK: - Closed End-State Model
// ============================================================

// 🟨 UPDATED: closed resolver outputs now include a strong-achievement layer.
// No additional final output classes should be added later.
enum AIOutputClassV1: String {
    case blocked
    case noData = "no_data"
    case insufficientData = "insufficient_data"

    case dualAchievement = "dual_achievement"
    case stepAchievement = "step_achievement"
    case energyAchievement = "energy_achievement"

    case strongDualAchievement = "strong_dual_achievement"
    case strongStepAchievement = "strong_step_achievement"
    case strongEnergyAchievement = "strong_energy_achievement"

    case positiveProgress = "positive_progress"
    case midZone = "mid_zone"
    case lowActivity = "low_activity"
}

enum AIConfidenceV1: String {
    case low
    case medium
    case high
    case blocked
}

enum AISuppressionReasonV1: String {
    case blocked
    case noData = "no_data"
    case insufficientData = "insufficient_data"
}

// ============================================================
// MARK: - Applied Rules
// ============================================================

// 🟨 UPDATED: reduced rule surface for the simplified resolver architecture.
enum AIRuleV1: String {
    case R01 // availability blocked
    case R02 // no data
    case R03 // insufficient data

    case R10 // dual achievement
    case R11 // step achievement
    case R12 // energy achievement

    case R13 // strong dual achievement
    case R14 // strong step achievement
    case R15 // strong energy achievement

    case R20 // positive progress
    case R21 // mid zone
    case R22 // low activity

    case R30 // practical day close handling
}

// ============================================================
// MARK: - Prepared Metrics
// ============================================================

struct AIPreparedRelativeMetricV1 {
    let todayValue: Double
    let baselineDayAverage: Double?
    let expectedBaselineAtProgress: Double?
    let deviationPercent: Double?
}

struct AIPreparedGoalMetricV1 {
    let todayValue: Double
    let goalValue: Double?
    let goalRatio: Double?
}

// ============================================================
// MARK: - Classified Signals
// ============================================================

struct AIClassifiedSignalsV1 {
    let dayContext: AIDayContextV1

    let availabilityState: AIAvailabilityStateV1

    let stepsPrepared: AIPreparedRelativeMetricV1
    let activeEnergyPrepared: AIPreparedRelativeMetricV1
    let goalPrepared: AIPreparedGoalMetricV1

    let stepsStatus: AIRelativeStatusV1?
    let energyStatus: AIRelativeStatusV1?
    let stepsStrength: AISignalStrengthV1?
    let energyStrength: AISignalStrengthV1?

    let combinedBias: AIInterpretationBiasV1
    let goalStatus: AIGoalStatusV1?

    let isStepGoalReached: Bool
    let isEnergyAchievementReached: Bool
    let achievementState: AIAchievementStateV1
}

// ============================================================
// MARK: - Final Resolved Decision
// ============================================================

struct AIResolvedDecisionV1 {
    let windowStage: AIWindowStageV1
    let isPracticalDayClose: Bool

    let availabilityState: AIAvailabilityStateV1

    let stepsStatus: AIRelativeStatusV1?
    let energyStatus: AIRelativeStatusV1?
    let combinedPrimary: AICombinedPrimaryStateV1
    let combinedBias: AIInterpretationBiasV1

    let goalStatus: AIGoalStatusV1?
    let achievementState: AIAchievementStateV1

    let outputClass: AIOutputClassV1
    let confidence: AIConfidenceV1
    let suppressionReason: AISuppressionReasonV1?

    let appliedRules: [AIRuleV1]
}
