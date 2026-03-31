//
//  NutritionInsightEngineModelsV1.swift
//  GluVibProbe
//
//  Domain: Nutrition Insight Engine
//  Layer: Models V1
//
//  Purpose
//  - Shared model layer for Classifier, Resolver and Public Engine
//  - Defines only states, containers and shared contracts
//  - No classifier logic
//  - No resolver logic
//  - No public text logic
//

import Foundation

// ============================================================
// MARK: - Day Context
// ============================================================

enum NITWindowStageV1: String, Codable, Hashable {
    case morning
    case afternoon
    case evening
    case dayClosed
}

struct NITDayContextV1: Codable, Hashable {
    let minutesElapsed: Int
    let dayProgressFraction: Double
    let windowStage: NITWindowStageV1
    let isPracticalDayClose: Bool
    let isCaloriesEvaluationOpen: Bool
}

// ============================================================
// MARK: - Availability
// ============================================================

enum NITAvailabilityStateV1: String, Codable, Hashable {
    case blocked
    case noData
    case insufficientData
    case ready
}

// ============================================================
// MARK: - Prepared Metrics
// ============================================================

struct NITPreparedTargetMetricV1: Codable, Hashable {
    let todayValue: Double
    let targetValue: Double
    let targetRatio: Double
    let expectedRatioAtCurrentTime: Double
    let progressDeltaToExpected: Double
    let progressRelativeToExpected: Double
}

struct NITPreparedEnergyMetricV1: Codable, Hashable {
    let nutritionEnergyKcal: Double
    let activeEnergyKcal: Double
    let restingEnergyKcal: Double
    let totalBurnedKcal: Double
    let energyDeltaKcal: Double
    let balanceRatio: Double
}

struct NITPreparedMacroStructureMetricV1: Codable, Hashable {
    let totalMacroGrams: Double
    let carbsShare: Double
    let proteinShare: Double
    let fatShare: Double
    let isAssessable: Bool
}

struct NITPreparedCarbSplitMetricV1: Codable, Hashable {
    let morningGrams: Double
    let afternoonGrams: Double
    let nightGrams: Double

    let morningShare: Double
    let afternoonShare: Double
    let nightShare: Double

    let morningTargetShare: Double
    let afternoonTargetShare: Double
    let nightTargetShare: Double
    let totalTargetShare: Double

    let completedWindowsCount: Int
    let isAssessable: Bool
}

// ============================================================
// MARK: - Classifier States
// ============================================================

enum NITTargetStatusV1: String, Codable, Hashable {
    case clearlyBelow
    case below
    case nearTarget
    case onTarget
    case above
    case clearlyAbove
}

enum NITMainTargetProgressStateV1: String, Codable, Hashable {
    case lagging
    case onTrack
    case ahead
    case achieved
    case overrun
}

enum NITSignalStrengthV1: String, Codable, Hashable {
    case weak
    case moderate
    case strong
}

enum NITEnergyBalanceStatusV1: String, Codable, Hashable {
    case remaining
    case nearBalance
    case over
}

enum NITMacroStructureStatusV1: String, Codable, Hashable {
    case notApplicable
    case balanced
    case mixed
    case imbalanced
}

enum NITCarbSplitStatusV1: String, Codable, Hashable {
    case tooEarly
    case notApplicable
    case balancedSoFar
    case frontLoaded
    case midDayLoaded
    case lateLoaded
    case mixed
}

enum NITInterpretationBiasV1: String, Codable, Hashable {
    case none
    case positive
    case negative
    case mixed
}

enum NITMainCriteriaAlignmentV1: String, Codable, Hashable {
    case neutral
    case alignedPositive
    case alignedNegative
    case mixed
    case conflicting
}

enum NITAchievementStateV1: String, Codable, Hashable {
    case none
    case singleMainTargetAchieved
    case multiMainTargetsAchieved
    case strongSingleMainTargetAchievement
    case strongMultiMainTargetAchievement
}

enum NITMainTargetLeadStateV1: String, Codable, Hashable {
    case none
    case mixedLead
    case carbsLeading
    case proteinLeading
    case fatLeading
    case caloriesLeading
}

// ============================================================
// MARK: - Classifier Output Container
// ============================================================

struct NITClassifiedSignalsV1: Codable, Hashable {
    let dayContext: NITDayContextV1
    let availabilityState: NITAvailabilityStateV1

    let carbsPrepared: NITPreparedTargetMetricV1
    let sugarPrepared: NITPreparedTargetMetricV1
    let proteinPrepared: NITPreparedTargetMetricV1
    let fatPrepared: NITPreparedTargetMetricV1
    let caloriesPrepared: NITPreparedTargetMetricV1

    let energyPrepared: NITPreparedEnergyMetricV1
    let macroStructurePrepared: NITPreparedMacroStructureMetricV1
    let carbSplitPrepared: NITPreparedCarbSplitMetricV1

    let carbsStatus: NITTargetStatusV1
    let sugarStatus: NITTargetStatusV1
    let proteinStatus: NITTargetStatusV1
    let fatStatus: NITTargetStatusV1
    let caloriesStatus: NITTargetStatusV1

    let carbsProgressState: NITMainTargetProgressStateV1
    let proteinProgressState: NITMainTargetProgressStateV1
    let fatProgressState: NITMainTargetProgressStateV1
    let caloriesProgressState: NITMainTargetProgressStateV1

    let proteinStrength: NITSignalStrengthV1
    let caloriesStrength: NITSignalStrengthV1

    let energyStatus: NITEnergyBalanceStatusV1
    let macroStructureStatus: NITMacroStructureStatusV1
    let carbSplitStatus: NITCarbSplitStatusV1

    let combinedBias: NITInterpretationBiasV1
    let mainCriteriaAlignment: NITMainCriteriaAlignmentV1
    let achievementState: NITAchievementStateV1

    let achievedMainTargetCount: Int
    let strongAchievedMainTargetCount: Int
    let laggingMainTargetCount: Int
    let onTrackMainTargetCount: Int
    let aheadMainTargetCount: Int
    let overrunMainTargetCount: Int

    let mainTargetLeadState: NITMainTargetLeadStateV1

    let openDayProgressState: NITOpenDayProgressStateV1?
    let closedDayEvaluationState: NITClosedDayEvaluationStateV1?
}

// ============================================================
// MARK: - Resolver States
// ============================================================

enum NITOpenDayProgressStateV1: String, Codable, Hashable {
    case balancedProgress
    case mixedProgress
    case leadProgress
    case laggingProgress
    case midZone
}

enum NITClosedDayEvaluationStateV1: String, Codable, Hashable {
    case targetBalancedDay
    case targetMostlyMet
    case unevenDay
    case overTargetDay
    case underTargetDay
}

enum NITOutputClassV1: String, Codable, Hashable {
    case blocked
    case noData
    case insufficientData

    case balancedProgress
    case mixedProgress
    case leadProgress
    case laggingProgress
    case midZone

    case targetBalancedDay
    case targetMostlyMet
    case unevenDay
    case overTargetDay
    case underTargetDay
}

enum NITCombinedPrimaryStateV1: String, Codable, Hashable {
    case neutral
    case positive
    case clearlyPositive
    case negative
    case clearlyNegative
    case mixedPrimary
}

enum NITConfidenceV1: String, Codable, Hashable {
    case blocked
    case low
    case medium
    case high
}

enum NITSuppressionReasonV1: String, Codable, Hashable {
    case blocked
    case noData
    case insufficientData
}

enum NITRuleV1: String, Codable, Hashable {
    case R01
    case R02
    case R03
    case R20
    case R21
    case R22
    case R23
    case R24
    case R25
    case R30
    case R40
    case R41
}

// ============================================================
// MARK: - Narrative Mapping Types
// ============================================================

enum NITPrimaryNarrativeModeV1: String, Codable, Hashable {
    case availability
    case openDayProgress
    case closedDayEvaluation
}

enum NITMainTargetKindV1: String, Codable, Hashable {
    case carbs
    case protein
    case fat
    case calories
}

struct NITResolvedTargetSummaryV1: Codable, Hashable {
    let aboveTarget: [NITMainTargetKindV1]
    let covered: [NITMainTargetKindV1]
    let belowTarget: [NITMainTargetKindV1]
}

enum NITEnergyNarrativeStateV1: String, Codable, Hashable {
    case none
    case nearBalance
    case intakeAboveTotalBurn
    case intakeBelowTotalBurn
}

// ============================================================
// MARK: - Resolver Output Container
// ============================================================

struct NITResolvedDecisionV1: Codable, Hashable {
    let windowStage: NITWindowStageV1
    let isPracticalDayClose: Bool
    let availabilityState: NITAvailabilityStateV1

    let carbsStatus: NITTargetStatusV1
    let proteinStatus: NITTargetStatusV1
    let caloriesStatus: NITTargetStatusV1
    let energyStatus: NITEnergyBalanceStatusV1
    let fatStatus: NITTargetStatusV1

    let carbsProgressState: NITMainTargetProgressStateV1
    let proteinProgressState: NITMainTargetProgressStateV1
    let fatProgressState: NITMainTargetProgressStateV1
    let caloriesProgressState: NITMainTargetProgressStateV1

    let macroStructureStatus: NITMacroStructureStatusV1
    let carbSplitStatus: NITCarbSplitStatusV1

    let combinedPrimary: NITCombinedPrimaryStateV1
    let combinedBias: NITInterpretationBiasV1
    let mainCriteriaAlignment: NITMainCriteriaAlignmentV1
    let achievementState: NITAchievementStateV1

    let achievedMainTargetCount: Int
    let strongAchievedMainTargetCount: Int
    let laggingMainTargetCount: Int
    let onTrackMainTargetCount: Int
    let aheadMainTargetCount: Int
    let overrunMainTargetCount: Int
    let mainTargetLeadState: NITMainTargetLeadStateV1

    let openDayProgressState: NITOpenDayProgressStateV1?
    let closedDayEvaluationState: NITClosedDayEvaluationStateV1?

    let primaryNarrativeMode: NITPrimaryNarrativeModeV1
    let targetSummary: NITResolvedTargetSummaryV1
    let energyNarrative: NITEnergyNarrativeStateV1

    let outputClass: NITOutputClassV1
    let confidence: NITConfidenceV1
    let suppressionReason: NITSuppressionReasonV1?
    let appliedRules: [NITRuleV1]
}
