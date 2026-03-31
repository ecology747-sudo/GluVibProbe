//
//  NutritionInsightEngineResolverV1.swift
//  GluVibProbe
//
//  Domain: Nutrition Insight Engine
//  Layer: Internal Resolution V1
//
//  Purpose
//  - Resolves classified Nutrition signals into a closed set of stable end states
//  - Availability is resolved before nutrition interpretation
//  - Open-day vs. late-stage vs. closed-day handling follows the matrix strictly
//  - Calories are only part of main-target evaluation until 19:59
//  - Energy Balance becomes narratively relevant from 20:00 onward
//  - Carb split remains contextual only
//

import Foundation

enum NutritionInsightEngineResolverV1 {

    static func resolve(from signals: NITClassifiedSignalsV1) -> NITResolvedDecisionV1 {
        let includeCaloriesInEvaluation = shouldIncludeCaloriesInEvaluation(dayContext: signals.dayContext)
        let includeEnergyInPrimaryEvaluation = shouldIncludeEnergyInPrimaryEvaluation(dayContext: signals.dayContext)

        let combinedPrimary = resolveCombinedPrimary(
            carbs: signals.carbsProgressState,
            protein: signals.proteinProgressState,
            calories: signals.caloriesProgressState,
            fat: signals.fatProgressState,
            includeCaloriesInEvaluation: includeCaloriesInEvaluation,
            includeEnergyInEvaluation: includeEnergyInPrimaryEvaluation,
            energy: signals.energyStatus
        )

        switch signals.availabilityState {
        case .blocked:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                openDayProgressState: nil,
                closedDayEvaluationState: nil,
                outputClass: .blocked,
                confidence: .blocked,
                suppressionReason: .blocked,
                appliedRules: [.R01]
            )

        case .noData:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                openDayProgressState: nil,
                closedDayEvaluationState: nil,
                outputClass: .noData,
                confidence: .blocked,
                suppressionReason: .noData,
                appliedRules: [.R02]
            )

        case .insufficientData:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                openDayProgressState: nil,
                closedDayEvaluationState: nil,
                outputClass: .insufficientData,
                confidence: .blocked,
                suppressionReason: .insufficientData,
                appliedRules: [.R03]
            )

        case .ready:
            break
        }

        if let finalDecision = resolveFinalDecisionIfNeeded(
            signals: signals,
            combinedPrimary: combinedPrimary
        ) {
            return finalDecision
        }

        if let openDecision = resolveOpenDayDecision(
            signals: signals,
            combinedPrimary: combinedPrimary
        ) {
            return openDecision
        }

        return buildDecision(
            signals: signals,
            combinedPrimary: combinedPrimary,
            openDayProgressState: .midZone,
            closedDayEvaluationState: nil,
            outputClass: .midZone,
            confidence: midZoneConfidence(
                stage: signals.dayContext.windowStage,
                isPracticalDayClose: signals.dayContext.isPracticalDayClose
            ),
            suppressionReason: nil,
            appliedRules: carbSplitRuleAppendix(
                signals: signals,
                base: [.R22]
            )
        )
    }
}

// ============================================================
// MARK: - Final Resolution
// ============================================================

private extension NutritionInsightEngineResolverV1 {

    static func resolveFinalDecisionIfNeeded(
        signals: NITClassifiedSignalsV1,
        combinedPrimary: NITCombinedPrimaryStateV1
    ) -> NITResolvedDecisionV1? {
        guard shouldUseFinalLane(signals: signals) else { return nil }
        guard let finalState = resolveFinalEvaluationState(from: signals) else { return nil }

        let confidence = finalDecisionConfidence(from: signals)

        switch finalState {
        case .targetBalancedDay:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                openDayProgressState: nil,
                closedDayEvaluationState: .targetBalancedDay,
                outputClass: .targetBalancedDay,
                confidence: confidence,
                suppressionReason: nil,
                appliedRules: carbSplitRuleAppendix(
                    signals: signals,
                    base: [.R20, .R30]
                )
            )

        case .targetMostlyMet:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                openDayProgressState: nil,
                closedDayEvaluationState: .targetMostlyMet,
                outputClass: .targetMostlyMet,
                confidence: confidence,
                suppressionReason: nil,
                appliedRules: carbSplitRuleAppendix(
                    signals: signals,
                    base: [.R21, .R30]
                )
            )

        case .unevenDay:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                openDayProgressState: nil,
                closedDayEvaluationState: .unevenDay,
                outputClass: .unevenDay,
                confidence: confidence,
                suppressionReason: nil,
                appliedRules: carbSplitRuleAppendix(
                    signals: signals,
                    base: [.R23, .R30]
                )
            )

        case .overTargetDay:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                openDayProgressState: nil,
                closedDayEvaluationState: .overTargetDay,
                outputClass: .overTargetDay,
                confidence: confidence,
                suppressionReason: nil,
                appliedRules: carbSplitRuleAppendix(
                    signals: signals,
                    base: [.R24, .R30]
                )
            )

        case .underTargetDay:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                openDayProgressState: nil,
                closedDayEvaluationState: .underTargetDay,
                outputClass: .underTargetDay,
                confidence: confidence,
                suppressionReason: nil,
                appliedRules: carbSplitRuleAppendix(
                    signals: signals,
                    base: [.R25, .R30]
                )
            )
        }
    }

    static func shouldUseFinalLane(signals: NITClassifiedSignalsV1) -> Bool {
        if signals.dayContext.windowStage == .dayClosed {
            return true
        }

        return shouldEscalateLateOpenDayToFinal(signals: signals)
    }

    static func shouldEscalateLateOpenDayToFinal(
        signals: NITClassifiedSignalsV1
    ) -> Bool {
        guard signals.dayContext.minutesElapsed >= (20 * 60) else { return false }

        if signals.energyStatus == .over {
            return true
        }

        if signals.overrunMainTargetCount >= 2 {
            return true
        }

        if signals.overrunMainTargetCount >= 1 && signals.achievedMainTargetCount >= 1 {
            return true
        }

        if signals.laggingMainTargetCount >= 3 && signals.achievedMainTargetCount == 0 {
            return true
        }

        return false
    }

    static func resolveFinalEvaluationState(
        from signals: NITClassifiedSignalsV1
    ) -> NITClosedDayEvaluationStateV1? {
        guard signals.availabilityState == .ready else { return nil }

        let isLateEscalation = shouldEscalateLateOpenDayToFinal(signals: signals)
        let isClosedDay = signals.dayContext.windowStage == .dayClosed

        guard isLateEscalation || isClosedDay else { return nil }

        if signals.energyStatus == .over {
            return .overTargetDay
        }

        if signals.overrunMainTargetCount >= 2 {
            return .overTargetDay
        }

        if signals.overrunMainTargetCount >= 1 && signals.achievedMainTargetCount >= 1 {
            return .overTargetDay
        }

        if signals.laggingMainTargetCount >= 3 && signals.achievedMainTargetCount == 0 {
            return .underTargetDay
        }

        let stablePositiveCount = signals.achievedMainTargetCount + signals.onTrackMainTargetCount
        let hasNoOverrun = signals.overrunMainTargetCount == 0
        let noNegativeEnergy = signals.energyStatus != .over

        let isBalancedStructure =
            signals.macroStructureStatus == .balanced ||
            signals.macroStructureStatus == .mixed ||
            signals.macroStructureStatus == .notApplicable

        let hasNoDominantLead =
            signals.mainTargetLeadState == .none ||
            signals.mainTargetLeadState == .mixedLead

        if signals.achievedMainTargetCount >= 3 &&
            hasNoOverrun &&
            noNegativeEnergy &&
            isBalancedStructure &&
            hasNoDominantLead {
            return .targetBalancedDay
        }

        if stablePositiveCount >= 2 &&
            hasNoOverrun &&
            noNegativeEnergy {
            return .targetMostlyMet
        }

        if signals.laggingMainTargetCount >= 2 && signals.achievedMainTargetCount == 0 {
            return .underTargetDay
        }

        return .unevenDay
    }

    static func finalDecisionConfidence(
        from signals: NITClassifiedSignalsV1
    ) -> NITConfidenceV1 {
        if signals.dayContext.windowStage == .dayClosed {
            return .high
        }

        if shouldEscalateLateOpenDayToFinal(signals: signals) {
            return .medium
        }

        return .medium
    }
}

// ============================================================
// MARK: - Open Day Resolution
// ============================================================

private extension NutritionInsightEngineResolverV1 {

    static func resolveOpenDayDecision(
        signals: NITClassifiedSignalsV1,
        combinedPrimary: NITCombinedPrimaryStateV1
    ) -> NITResolvedDecisionV1? {
        guard let openState = resolveOpenDayProgressState(from: signals) else {
            return nil
        }

        switch openState {
        case .balancedProgress:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                openDayProgressState: .balancedProgress,
                closedDayEvaluationState: nil,
                outputClass: .balancedProgress,
                confidence: balancedProgressConfidence(
                    stage: signals.dayContext.windowStage,
                    isPracticalDayClose: signals.dayContext.isPracticalDayClose
                ),
                suppressionReason: nil,
                appliedRules: carbSplitRuleAppendix(
                    signals: signals,
                    base: [.R20]
                )
            )

        case .mixedProgress:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                openDayProgressState: .mixedProgress,
                closedDayEvaluationState: nil,
                outputClass: .mixedProgress,
                confidence: mixedProgressConfidence(
                    stage: signals.dayContext.windowStage,
                    isPracticalDayClose: signals.dayContext.isPracticalDayClose
                ),
                suppressionReason: nil,
                appliedRules: carbSplitRuleAppendix(
                    signals: signals,
                    base: [.R21]
                )
            )

        case .leadProgress:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                openDayProgressState: .leadProgress,
                closedDayEvaluationState: nil,
                outputClass: .leadProgress,
                confidence: leadProgressConfidence(
                    stage: signals.dayContext.windowStage,
                    isPracticalDayClose: signals.dayContext.isPracticalDayClose
                ),
                suppressionReason: nil,
                appliedRules: carbSplitRuleAppendix(
                    signals: signals,
                    base: [.R24]
                )
            )

        case .laggingProgress:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                openDayProgressState: .laggingProgress,
                closedDayEvaluationState: nil,
                outputClass: .laggingProgress,
                confidence: laggingProgressConfidence(
                    stage: signals.dayContext.windowStage,
                    isPracticalDayClose: signals.dayContext.isPracticalDayClose
                ),
                suppressionReason: nil,
                appliedRules: carbSplitRuleAppendix(
                    signals: signals,
                    base: [.R25]
                )
            )

        case .midZone:
            return buildDecision(
                signals: signals,
                combinedPrimary: combinedPrimary,
                openDayProgressState: .midZone,
                closedDayEvaluationState: nil,
                outputClass: .midZone,
                confidence: midZoneConfidence(
                    stage: signals.dayContext.windowStage,
                    isPracticalDayClose: signals.dayContext.isPracticalDayClose
                ),
                suppressionReason: nil,
                appliedRules: carbSplitRuleAppendix(
                    signals: signals,
                    base: [.R22]
                )
            )
        }
    }

    static func resolveOpenDayProgressState(
        from signals: NITClassifiedSignalsV1
    ) -> NITOpenDayProgressStateV1? {
        guard signals.availabilityState == .ready else { return nil }
        guard signals.dayContext.windowStage != .dayClosed else { return nil }
        guard !shouldEscalateLateOpenDayToFinal(signals: signals) else { return nil }

        let hasClearLeadSignal =
            signals.mainTargetLeadState != .none &&
            signals.mainTargetLeadState != .mixedLead // 🟨 UPDATED

        if signals.laggingMainTargetCount >= 2 &&
            (signals.onTrackMainTargetCount > 0 ||
             signals.achievedMainTargetCount > 0 ||
             signals.aheadMainTargetCount > 0) {
            return .mixedProgress
        }

        if signals.laggingMainTargetCount >= 2 && hasClearLeadSignal { // 🟨 UPDATED
            return .mixedProgress
        }

        if signals.overrunMainTargetCount >= 1 &&
            (signals.onTrackMainTargetCount > 0 ||
             signals.achievedMainTargetCount > 0 ||
             signals.aheadMainTargetCount > 0) {
            return .mixedProgress
        }

        if signals.overrunMainTargetCount >= 1 && hasClearLeadSignal { // 🟨 UPDATED
            return .mixedProgress
        }

        if signals.laggingMainTargetCount >= 2 {
            return .laggingProgress
        }

        if signals.aheadMainTargetCount >= 1 &&
            signals.mainTargetLeadState != .none &&
            signals.mainTargetLeadState != .mixedLead {
            return .leadProgress
        }

        if signals.achievedMainTargetCount >= 1 &&
            signals.laggingMainTargetCount == 0 &&
            signals.overrunMainTargetCount == 0 {
            return .balancedProgress
        }

        if signals.onTrackMainTargetCount >= 2 &&
            signals.laggingMainTargetCount == 0 &&
            signals.overrunMainTargetCount == 0 {
            return .balancedProgress
        }

        if signals.laggingMainTargetCount == 1 &&
            signals.onTrackMainTargetCount == 0 &&
            signals.achievedMainTargetCount == 0 &&
            signals.aheadMainTargetCount == 0 {
            return .laggingProgress
        }

        if signals.achievedMainTargetCount > 0 ||
            signals.onTrackMainTargetCount > 0 ||
            signals.aheadMainTargetCount > 0 ||
            signals.laggingMainTargetCount > 0 {
            return .midZone
        }

        return .midZone
    }
}

// ============================================================
// MARK: - Confidence
// ============================================================

private extension NutritionInsightEngineResolverV1 {

    static func balancedProgressConfidence(
        stage: NITWindowStageV1,
        isPracticalDayClose: Bool
    ) -> NITConfidenceV1 {
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

    static func mixedProgressConfidence(
        stage: NITWindowStageV1,
        isPracticalDayClose: Bool
    ) -> NITConfidenceV1 {
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

    static func leadProgressConfidence(
        stage: NITWindowStageV1,
        isPracticalDayClose: Bool
    ) -> NITConfidenceV1 {
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

    static func laggingProgressConfidence(
        stage: NITWindowStageV1,
        isPracticalDayClose: Bool
    ) -> NITConfidenceV1 {
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

    static func midZoneConfidence(
        stage: NITWindowStageV1,
        isPracticalDayClose: Bool
    ) -> NITConfidenceV1 {
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
}

// ============================================================
// MARK: - Combined Primary
// ============================================================

private extension NutritionInsightEngineResolverV1 {

    static func resolveCombinedPrimary(
        carbs: NITMainTargetProgressStateV1,
        protein: NITMainTargetProgressStateV1,
        calories: NITMainTargetProgressStateV1,
        fat: NITMainTargetProgressStateV1,
        includeCaloriesInEvaluation: Bool,
        includeEnergyInEvaluation: Bool,
        energy: NITEnergyBalanceStatusV1
    ) -> NITCombinedPrimaryStateV1 {
        let states: [NITMainTargetProgressStateV1] = includeCaloriesInEvaluation
            ? [carbs, protein, fat, calories]
            : [carbs, protein, fat]

        let positiveCount =
            states.filter { isPositive($0) }.count +
            ((includeEnergyInEvaluation && energy == .nearBalance) ? 1 : 0)

        let negativeCount =
            states.filter { isNegative($0) }.count +
            ((includeEnergyInEvaluation && energy == .over) ? 1 : 0)

        let totalCount = states.count + (includeEnergyInEvaluation ? 1 : 0)

        if positiveCount > 0 && negativeCount > 0 {
            return .mixedPrimary
        }

        if positiveCount >= max(totalCount, 3) {
            return .clearlyPositive
        }

        if positiveCount >= 2 {
            return .positive
        }

        if negativeCount >= max(totalCount, 3) {
            return .clearlyNegative
        }

        if negativeCount >= 2 {
            return .negative
        }

        return .neutral
    }

    static func isPositive(_ state: NITMainTargetProgressStateV1) -> Bool {
        state == .onTrack || state == .achieved
    }

    static func isNegative(_ state: NITMainTargetProgressStateV1) -> Bool {
        state == .lagging || state == .overrun
    }
}

// ============================================================
// MARK: - Structured Narrative Mapping
// ============================================================

private extension NutritionInsightEngineResolverV1 {

    static func resolvePrimaryNarrativeMode(
        outputClass: NITOutputClassV1
    ) -> NITPrimaryNarrativeModeV1 {
        switch outputClass {
        case .blocked, .noData, .insufficientData:
            return .availability

        case .balancedProgress, .mixedProgress, .leadProgress, .laggingProgress, .midZone:
            return .openDayProgress

        case .targetBalancedDay, .targetMostlyMet, .unevenDay, .overTargetDay, .underTargetDay:
            return .closedDayEvaluation
        }
    }

    static func resolveTargetSummary(
        signals: NITClassifiedSignalsV1
    ) -> NITResolvedTargetSummaryV1 {
        NITResolvedTargetSummaryV1(
            aboveTarget: aboveTargetKinds(from: signals),
            covered: coveredTargetKinds(from: signals),
            belowTarget: belowTargetKinds(from: signals)
        )
    }

    static func resolveEnergyNarrative(
        signals: NITClassifiedSignalsV1
    ) -> NITEnergyNarrativeStateV1 {
        guard shouldIncludeEnergyInPrimaryEvaluation(dayContext: signals.dayContext) else {
            return .none
        }

        switch signals.energyStatus {
        case .nearBalance:
            return .nearBalance
        case .over:
            return .intakeAboveTotalBurn
        case .remaining:
            return .intakeBelowTotalBurn
        }
    }

    static func aboveTargetKinds(from signals: NITClassifiedSignalsV1) -> [NITMainTargetKindV1] {
        var result: [NITMainTargetKindV1] = []

        if signals.carbsProgressState == .overrun {
            result.append(.carbs)
        }
        if signals.proteinProgressState == .overrun {
            result.append(.protein)
        }
        if signals.fatProgressState == .overrun {
            result.append(.fat)
        }
        if shouldIncludeCaloriesInEvaluation(dayContext: signals.dayContext) &&
            signals.caloriesProgressState == .overrun {
            result.append(.calories)
        }

        return result
    }

    static func coveredTargetKinds(from signals: NITClassifiedSignalsV1) -> [NITMainTargetKindV1] {
        var result: [NITMainTargetKindV1] = []

        if signals.carbsProgressState == .achieved || signals.carbsProgressState == .overrun {
            result.append(.carbs)
        }
        if signals.proteinProgressState == .achieved || signals.proteinProgressState == .overrun {
            result.append(.protein)
        }
        if signals.fatProgressState == .achieved || signals.fatProgressState == .overrun {
            result.append(.fat)
        }
        if shouldIncludeCaloriesInEvaluation(dayContext: signals.dayContext) &&
            (signals.caloriesProgressState == .achieved || signals.caloriesProgressState == .overrun) {
            result.append(.calories)
        }

        return result
    }

    static func belowTargetKinds(from signals: NITClassifiedSignalsV1) -> [NITMainTargetKindV1] {
        var result: [NITMainTargetKindV1] = []

        if signals.carbsProgressState == .lagging {
            result.append(.carbs)
        }
        if signals.proteinProgressState == .lagging {
            result.append(.protein)
        }
        if signals.fatProgressState == .lagging {
            result.append(.fat)
        }
        if shouldIncludeCaloriesInEvaluation(dayContext: signals.dayContext) &&
            signals.caloriesProgressState == .lagging {
            result.append(.calories)
        }

        return result
    }
}

// ============================================================
// MARK: - Decision Builder
// ============================================================

private extension NutritionInsightEngineResolverV1 {

    static func buildDecision(
        signals: NITClassifiedSignalsV1,
        combinedPrimary: NITCombinedPrimaryStateV1,
        openDayProgressState: NITOpenDayProgressStateV1?,
        closedDayEvaluationState: NITClosedDayEvaluationStateV1?,
        outputClass: NITOutputClassV1,
        confidence: NITConfidenceV1,
        suppressionReason: NITSuppressionReasonV1?,
        appliedRules: [NITRuleV1]
    ) -> NITResolvedDecisionV1 {
        NITResolvedDecisionV1(
            windowStage: signals.dayContext.windowStage,
            isPracticalDayClose: signals.dayContext.isPracticalDayClose,
            availabilityState: signals.availabilityState,

            carbsStatus: signals.carbsStatus,
            proteinStatus: signals.proteinStatus,
            caloriesStatus: signals.caloriesStatus,
            energyStatus: signals.energyStatus,
            fatStatus: signals.fatStatus,

            carbsProgressState: signals.carbsProgressState,
            proteinProgressState: signals.proteinProgressState,
            fatProgressState: signals.fatProgressState,
            caloriesProgressState: signals.caloriesProgressState,

            macroStructureStatus: signals.macroStructureStatus,
            carbSplitStatus: signals.carbSplitStatus,

            combinedPrimary: combinedPrimary,
            combinedBias: signals.combinedBias,
            mainCriteriaAlignment: signals.mainCriteriaAlignment,
            achievementState: signals.achievementState,

            achievedMainTargetCount: signals.achievedMainTargetCount,
            strongAchievedMainTargetCount: signals.strongAchievedMainTargetCount,
            laggingMainTargetCount: signals.laggingMainTargetCount,
            onTrackMainTargetCount: signals.onTrackMainTargetCount,
            aheadMainTargetCount: signals.aheadMainTargetCount,
            overrunMainTargetCount: signals.overrunMainTargetCount,
            mainTargetLeadState: signals.mainTargetLeadState,

            openDayProgressState: openDayProgressState,
            closedDayEvaluationState: closedDayEvaluationState,

            primaryNarrativeMode: resolvePrimaryNarrativeMode(outputClass: outputClass),
            targetSummary: resolveTargetSummary(signals: signals),
            energyNarrative: resolveEnergyNarrative(signals: signals),

            outputClass: outputClass,
            confidence: confidence,
            suppressionReason: suppressionReason,
            appliedRules: appliedRules
        )
    }

    static func carbSplitRuleAppendix(
        signals: NITClassifiedSignalsV1,
        base: [NITRuleV1]
    ) -> [NITRuleV1] {
        switch signals.carbSplitStatus {
        case .notApplicable, .tooEarly:
            return base + [.R41]
        case .balancedSoFar, .frontLoaded, .midDayLoaded, .lateLoaded, .mixed:
            return base + [.R40]
        }
    }

    static func shouldIncludeCaloriesInEvaluation(dayContext: NITDayContextV1) -> Bool {
        dayContext.minutesElapsed < (20 * 60)
    }

    static func shouldIncludeEnergyInPrimaryEvaluation(dayContext: NITDayContextV1) -> Bool {
        dayContext.minutesElapsed >= (20 * 60)
    }
}
