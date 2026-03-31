//
//  ActivityInsightEngineResolverV1.swift
//  GluVibProbe
//
//  Domain: Activity Insight Engine
//  Layer: Internal Resolution V1
//
//  Purpose
//  - Resolves classified Activity signals into a closed set of stable end states.
//  - Uses only Steps + Active Energy as primary interpretation inputs.
//  - Achievement is phase-independent and always has priority.
//  - Availability is resolved before activity interpretation.
//  - Prevents patch cascades by mapping nearby cases into broad stable zones.
//

import Foundation

enum ActivityInsightEngineResolverV1 {

    static func resolve(from signals: AIClassifiedSignalsV1) -> AIResolvedDecisionV1 {
        let combinedPrimary = resolveCombinedPrimary(
            steps: signals.stepsStatus,
            energy: signals.energyStatus
        )

        switch signals.availabilityState {
        case .blocked:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                outputClass: .blocked,
                confidence: .blocked,
                suppressionReason: .blocked,
                appliedRules: [.R01]
            )

        case .noData:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                outputClass: .noData,
                confidence: .blocked,
                suppressionReason: .noData,
                appliedRules: [.R02]
            )

        case .insufficientData:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                outputClass: .insufficientData,
                confidence: .blocked,
                suppressionReason: .insufficientData,
                appliedRules: [.R03]
            )

        case .ready:
            break
        }

        if let achievementDecision = resolveAchievementDecision(
            signals: signals,
            combinedPrimary: combinedPrimary
        ) {
            return achievementDecision
        }

        let stage = signals.dayContext.windowStage
        let isPracticalDayClose = signals.dayContext.isPracticalDayClose

        if qualifiesForPositiveProgress(
            signals: signals,
            combinedPrimary: combinedPrimary
        ) {
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                outputClass: .positiveProgress,
                confidence: positiveProgressConfidence(
                    stage: stage,
                    isPracticalDayClose: isPracticalDayClose
                ),
                suppressionReason: nil,
                appliedRules: isPracticalDayClose ? [.R20, .R30] : [.R20]
            )
        }

        if qualifiesForLowActivity(
            signals: signals,
            combinedPrimary: combinedPrimary
        ) {
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                outputClass: .lowActivity,
                confidence: lowActivityConfidence(
                    stage: stage,
                    isPracticalDayClose: isPracticalDayClose
                ),
                suppressionReason: nil,
                appliedRules: isPracticalDayClose ? [.R22, .R30] : [.R22]
            )
        }

        return buildDecision(
            signals: signals,
            combinedPrimary: combinedPrimary,
            outputClass: .midZone,
            confidence: midZoneConfidence(
                stage: stage,
                isPracticalDayClose: isPracticalDayClose
            ),
            suppressionReason: nil,
            appliedRules: isPracticalDayClose ? [.R21, .R30] : [.R21]
        )
    }
}

// ============================================================
// MARK: - Achievement
// ============================================================

private extension ActivityInsightEngineResolverV1 {

    // 🟨 UPDATED: strong achievement states are now resolved before normal achievements.
    static func resolveAchievementDecision(
        signals: AIClassifiedSignalsV1,
        combinedPrimary: AICombinedPrimaryStateV1
    ) -> AIResolvedDecisionV1? {
        let stage = signals.dayContext.windowStage
        let isPracticalDayClose = signals.dayContext.isPracticalDayClose

        switch signals.achievementState {
        case .strongDualAchievement:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                outputClass: .strongDualAchievement,
                confidence: .high,
                suppressionReason: nil,
                appliedRules: [.R13]
            )

        case .strongStepAchievement:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                outputClass: .strongStepAchievement,
                confidence: isPracticalDayClose ? .high : achievementConfidence(stage: stage),
                suppressionReason: nil,
                appliedRules: [.R14]
            )

        case .strongEnergyAchievement:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                outputClass: .strongEnergyAchievement,
                confidence: isPracticalDayClose ? .high : achievementConfidence(stage: stage),
                suppressionReason: nil,
                appliedRules: [.R15]
            )

        case .dualGoalReached:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                outputClass: .dualAchievement,
                confidence: isPracticalDayClose ? .high : achievementConfidence(stage: stage),
                suppressionReason: nil,
                appliedRules: [.R10]
            )

        case .stepGoalReached:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                outputClass: .stepAchievement,
                confidence: isPracticalDayClose ? .high : achievementConfidence(stage: stage),
                suppressionReason: nil,
                appliedRules: [.R11]
            )

        case .energyGoalReached:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                outputClass: .energyAchievement,
                confidence: isPracticalDayClose ? .high : achievementConfidence(stage: stage),
                suppressionReason: nil,
                appliedRules: [.R12]
            )

        case .none:
            return nil
        }
    }

    static func achievementConfidence(stage: AIWindowStageV1) -> AIConfidenceV1 {
        switch stage {
        case .morning:
            return .medium
        case .afternoon, .evening, .dayClosed:
            return .high
        }
    }
}

// ============================================================
// MARK: - Broad Zones
// ============================================================

private extension ActivityInsightEngineResolverV1 {

    static func qualifiesForPositiveProgress(
        signals: AIClassifiedSignalsV1,
        combinedPrimary: AICombinedPrimaryStateV1
    ) -> Bool {
        let stage = signals.dayContext.windowStage

        if combinedPrimary == .clearlyAbove || combinedPrimary == .above {
            return true
        }

        if stage == .morning {
            if isEnergyLedMorningPositiveProgress(signals: signals) {
                return true
            }

            if isStepLedMorningPositiveProgress(signals: signals) {
                return true
            }
        }

        let stepsSupportive = isSupportivePositive(
            status: signals.stepsStatus,
            prepared: signals.stepsPrepared,
            stage: stage,
            metric: .steps
        )

        let energySupportive = isSupportivePositive(
            status: signals.energyStatus,
            prepared: signals.activeEnergyPrepared,
            stage: stage,
            metric: .energy
        )

        let hasNegativeSignal =
            isNegative(signals.stepsStatus) || isNegative(signals.energyStatus)

        if !hasNegativeSignal && (stepsSupportive || energySupportive) {
            return true
        }

        if signals.combinedBias == .mixed {
            let strongEnergy =
                signals.energyStatus == .clearlyAbove ||
                (signals.energyStatus == .above && signals.energyStrength == .strong)

            let strongSteps =
                signals.stepsStatus == .clearlyAbove ||
                (signals.stepsStatus == .above && signals.stepsStrength == .strong)

            let otherSideNotCollapsedForEnergy =
                signals.stepsStatus == .nearBaseline ||
                signals.stepsStatus == .below

            let otherSideNotCollapsedForSteps =
                signals.energyStatus == .nearBaseline ||
                signals.energyStatus == .below

            if (strongEnergy && otherSideNotCollapsedForEnergy) ||
                (strongSteps && otherSideNotCollapsedForSteps) {
                return true
            }
        }

        return false
    }

    static func qualifiesForLowActivity(
        signals: AIClassifiedSignalsV1,
        combinedPrimary: AICombinedPrimaryStateV1
    ) -> Bool {
        let stage = signals.dayContext.windowStage

        let clearlyNegative =
            combinedPrimary == .clearlyBelow ||
            combinedPrimary == .below

        let stepsVeryLow = isClearlyLowForPhase(
            status: signals.stepsStatus,
            prepared: signals.stepsPrepared,
            stage: stage,
            metric: .steps
        )

        let energyVeryLow = isClearlyLowForPhase(
            status: signals.energyStatus,
            prepared: signals.activeEnergyPrepared,
            stage: stage,
            metric: .energy
        )

        switch stage {
        case .morning:
            return clearlyNegative && stepsVeryLow && energyVeryLow

        case .afternoon:
            return (stepsVeryLow && energyVeryLow) || (clearlyNegative && energyVeryLow)

        case .evening, .dayClosed:
            return clearlyNegative || (stepsVeryLow && energyVeryLow)
        }
    }
}

// ============================================================
// MARK: - Metric Helpers
// ============================================================

private extension ActivityInsightEngineResolverV1 {

    enum AIMetricKind {
        case steps
        case energy
    }

    static func isSupportivePositive(
        status: AIRelativeStatusV1?,
        prepared: AIPreparedRelativeMetricV1,
        stage: AIWindowStageV1,
        metric: AIMetricKind
    ) -> Bool {
        if status == .above || status == .clearlyAbove {
            return true
        }

        guard status == .nearBaseline else { return false }

        guard
            let expected = prepared.expectedBaselineAtProgress,
            expected > 0
        else {
            return false
        }

        let ratio = prepared.todayValue / expected

        switch metric {
        case .steps:
            switch stage {
            case .morning:
                return ratio >= 0.98
            case .afternoon:
                return ratio >= 1.00
            case .evening, .dayClosed:
                return ratio >= 1.02
            }

        case .energy:
            switch stage {
            case .morning:
                return ratio >= 1.08
            case .afternoon:
                return ratio >= 1.05
            case .evening, .dayClosed:
                return ratio >= 1.03
            }
        }
    }

    static func isClearlyLowForPhase(
        status: AIRelativeStatusV1?,
        prepared: AIPreparedRelativeMetricV1,
        stage: AIWindowStageV1,
        metric: AIMetricKind
    ) -> Bool {
        if status == .clearlyBelow {
            return true
        }

        guard
            let expected = prepared.expectedBaselineAtProgress,
            expected > 0
        else {
            return false
        }

        let ratio = prepared.todayValue / expected

        switch metric {
        case .steps:
            switch stage {
            case .morning:
                return ratio < 0.70
            case .afternoon:
                return ratio < 0.78
            case .evening, .dayClosed:
                return ratio < 0.85
            }

        case .energy:
            switch stage {
            case .morning:
                return ratio < 0.70
            case .afternoon:
                return ratio < 0.80
            case .evening, .dayClosed:
                return ratio < 0.88
            }
        }
    }

    static func isEnergyLedMorningPositiveProgress(
        signals: AIClassifiedSignalsV1
    ) -> Bool {
        guard signals.dayContext.windowStage == .morning else { return false }

        guard
            let expectedEnergy = signals.activeEnergyPrepared.expectedBaselineAtProgress,
            expectedEnergy > 0
        else {
            return false
        }

        let energyRatio = signals.activeEnergyPrepared.todayValue / expectedEnergy
        let strongEnergyStatus =
            signals.energyStatus == .above || signals.energyStatus == .clearlyAbove
        let strongEnergyStrength =
            signals.energyStrength == .moderate || signals.energyStrength == .strong

        return strongEnergyStatus && strongEnergyStrength && energyRatio >= 1.35
    }

    static func isStepLedMorningPositiveProgress(
        signals: AIClassifiedSignalsV1
    ) -> Bool {
        guard signals.dayContext.windowStage == .morning else { return false }

        let strongStepStatus =
            signals.stepsStatus == .above || signals.stepsStatus == .clearlyAbove
        let strongStepStrength =
            signals.stepsStrength == .moderate || signals.stepsStrength == .strong

        let nearGoalByRatio: Bool = {
            guard let goalRatio = signals.goalPrepared.goalRatio else { return false }
            return goalRatio >= 0.85
        }()

        let farAheadOfExpected: Bool = {
            guard
                let expectedSteps = signals.stepsPrepared.expectedBaselineAtProgress,
                expectedSteps > 0
            else {
                return false
            }

            let stepRatio = signals.stepsPrepared.todayValue / expectedSteps
            return stepRatio >= 1.30
        }()

        return (strongStepStatus && strongStepStrength && nearGoalByRatio) || farAheadOfExpected
    }
}

// ============================================================
// MARK: - Confidence
// ============================================================

private extension ActivityInsightEngineResolverV1 {

    static func positiveProgressConfidence(
        stage: AIWindowStageV1,
        isPracticalDayClose: Bool
    ) -> AIConfidenceV1 {
        if isPracticalDayClose { return .high }

        switch stage {
        case .morning:
            return .medium
        case .afternoon:
            return .medium
        case .evening, .dayClosed:
            return .high
        }
    }

    static func midZoneConfidence(
        stage: AIWindowStageV1,
        isPracticalDayClose: Bool
    ) -> AIConfidenceV1 {
        if isPracticalDayClose { return .medium }

        switch stage {
        case .morning:
            return .low
        case .afternoon:
            return .medium
        case .evening, .dayClosed:
            return .medium
        }
    }

    static func lowActivityConfidence(
        stage: AIWindowStageV1,
        isPracticalDayClose: Bool
    ) -> AIConfidenceV1 {
        if isPracticalDayClose { return .high }

        switch stage {
        case .morning:
            return .low
        case .afternoon:
            return .medium
        case .evening, .dayClosed:
            return .high
        }
    }
}

// ============================================================
// MARK: - Combined Primary
// ============================================================

private extension ActivityInsightEngineResolverV1 {

    static func resolveCombinedPrimary(
        steps: AIRelativeStatusV1?,
        energy: AIRelativeStatusV1?
    ) -> AICombinedPrimaryStateV1 {
        guard let steps, let energy else {
            if let single = steps ?? energy {
                switch single {
                case .clearlyAbove: return .clearlyAbove
                case .above: return .above
                case .nearBaseline: return .neutral
                case .below: return .below
                case .clearlyBelow: return .clearlyBelow
                }
            }
            return .neutral
        }

        if isPositive(steps) && isNegative(energy) { return .mixedPrimary }
        if isNegative(steps) && isPositive(energy) { return .mixedPrimary }

        if steps == .nearBaseline && energy == .nearBaseline {
            return .neutral
        }

        if (steps == .clearlyAbove && isPositiveOrNear(energy)) ||
            (energy == .clearlyAbove && isPositiveOrNear(steps)) {
            return .clearlyAbove
        }

        if (steps == .clearlyBelow && isNegativeOrNear(energy)) ||
            (energy == .clearlyBelow && isNegativeOrNear(steps)) {
            return .clearlyBelow
        }

        if isPositive(steps) && isPositive(energy) {
            return .above
        }

        if isNegative(steps) && isNegative(energy) {
            return .below
        }

        if (isPositive(steps) && energy == .nearBaseline) ||
            (isPositive(energy) && steps == .nearBaseline) {
            return .above
        }

        if (isNegative(steps) && energy == .nearBaseline) ||
            (isNegative(energy) && steps == .nearBaseline) {
            return .below
        }

        return .neutral
    }
}

// ============================================================
// MARK: - Decision Builder
// ============================================================

private extension ActivityInsightEngineResolverV1 {

    static func buildDecision(
        signals: AIClassifiedSignalsV1,
        combinedPrimary: AICombinedPrimaryStateV1,
        outputClass: AIOutputClassV1,
        confidence: AIConfidenceV1,
        suppressionReason: AISuppressionReasonV1?,
        appliedRules: [AIRuleV1]
    ) -> AIResolvedDecisionV1 {
        AIResolvedDecisionV1(
            windowStage: signals.dayContext.windowStage,
            isPracticalDayClose: signals.dayContext.isPracticalDayClose,
            availabilityState: signals.availabilityState,
            stepsStatus: signals.stepsStatus,
            energyStatus: signals.energyStatus,
            combinedPrimary: combinedPrimary,
            combinedBias: signals.combinedBias,
            goalStatus: signals.goalStatus,
            achievementState: signals.achievementState,
            outputClass: outputClass,
            confidence: confidence,
            suppressionReason: suppressionReason,
            appliedRules: appliedRules
        )
    }

    static func isPositive(_ status: AIRelativeStatusV1?) -> Bool {
        status == .above || status == .clearlyAbove
    }

    static func isNegative(_ status: AIRelativeStatusV1?) -> Bool {
        status == .below || status == .clearlyBelow
    }

    static func isPositiveOrNear(_ status: AIRelativeStatusV1) -> Bool {
        status == .nearBaseline || status == .above || status == .clearlyAbove
    }

    static func isNegativeOrNear(_ status: AIRelativeStatusV1) -> Bool {
        status == .nearBaseline || status == .below || status == .clearlyBelow
    }
}
