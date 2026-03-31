//
//  NutritionInsightEngineClassifierV1.swift
//  GluVibProbe
//
//  Domain: Nutrition Insight Engine
//  Layer: Internal Classification V1
//
//  Purpose
//  - Builds the day context strictly from the matrix
//  - Prepares normalized target, energy, macro-structure and carb-split signals
//  - Classifies availability, target progress states and counts
//  - Keeps calories as main target only until 19:59
//  - Keeps energy balance relevant from 20:00 onward
//  - Does NOT produce final resolver end classes
//  - Does NOT produce public presentation text
//

import Foundation

enum NutritionInsightEngineClassifierV1 {

    static func classify(from input: NutritionInsightEngineV1.Input) -> NITClassifiedSignalsV1 {
        let dayContext = makeDayContext(now: input.now, calendar: input.calendar)

        let includeCaloriesAsMainTarget = shouldIncludeCaloriesAsMainTarget(dayContext: dayContext)
        let includeEnergyInInterpretation = shouldIncludeEnergyInInterpretation(dayContext: dayContext)

        let carbsPrepared = makeTargetPreparedMetric(
            todayValue: input.carbsGrams,
            targetValue: input.targetCarbsGrams,
            dayContext: dayContext
        )

        let sugarPrepared = makeTargetPreparedMetric(
            todayValue: input.sugarGrams,
            targetValue: input.targetSugarGrams,
            dayContext: dayContext
        )

        let proteinPrepared = makeTargetPreparedMetric(
            todayValue: input.proteinGrams,
            targetValue: input.targetProteinGrams,
            dayContext: dayContext
        )

        let fatPrepared = makeTargetPreparedMetric(
            todayValue: input.fatGrams,
            targetValue: input.targetFatGrams,
            dayContext: dayContext
        )

        let caloriesPrepared = makeTargetPreparedMetric(
            todayValue: input.nutritionEnergyKcal,
            targetValue: input.targetCalories,
            dayContext: dayContext
        )

        let energyPrepared = makeEnergyPreparedMetric(
            nutritionEnergyKcal: input.nutritionEnergyKcal,
            activeEnergyKcal: input.activeEnergyKcal,
            restingEnergyKcal: input.restingEnergyKcal
        )

        let macroStructurePrepared = makeMacroStructurePreparedMetric(
            carbsGrams: input.carbsGrams,
            proteinGrams: input.proteinGrams,
            fatGrams: input.fatGrams
        )

        let carbSplitPrepared = makeCarbSplitPreparedMetric(
            morningGrams: input.carbsMorningGrams,
            afternoonGrams: input.carbsAfternoonGrams,
            nightGrams: input.carbsNightGrams,
            targetCarbsGrams: input.targetCarbsGrams,
            dayContext: dayContext
        )

        let availabilityState = classifyAvailabilityState(
            input: input,
            macroStructurePrepared: macroStructurePrepared,
            energyPrepared: energyPrepared
        )

        let carbsStatus = classifyTargetStatus(from: carbsPrepared)
        let sugarStatus = classifyTargetStatus(from: sugarPrepared)
        let proteinStatus = classifyTargetStatus(from: proteinPrepared)
        let fatStatus = classifyTargetStatus(from: fatPrepared)

        let rawCaloriesStatus = classifyTargetStatus(from: caloriesPrepared)
        let caloriesStatus: NITTargetStatusV1 = includeCaloriesAsMainTarget ? rawCaloriesStatus : .nearTarget

        let carbsProgressState = classifyMainTargetProgressState(
            from: carbsPrepared,
            stage: dayContext.windowStage
        )

        let proteinProgressState = classifyMainTargetProgressState(
            from: proteinPrepared,
            stage: dayContext.windowStage
        )

        let fatProgressState = classifyMainTargetProgressState(
            from: fatPrepared,
            stage: dayContext.windowStage
        )

        let caloriesProgressState: NITMainTargetProgressStateV1 = includeCaloriesAsMainTarget
            ? classifyMainTargetProgressState(from: caloriesPrepared, stage: dayContext.windowStage)
            : .onTrack

        let proteinStrength = classifyStrength(from: proteinPrepared.targetRatio)
        let caloriesStrength = includeCaloriesAsMainTarget
            ? classifyStrength(from: caloriesPrepared.targetRatio)
            : .weak

        let energyStatus = classifyEnergyBalanceStatus(from: energyPrepared)
        let macroStructureStatus = classifyMacroStructureStatus(from: macroStructurePrepared)
        let carbSplitStatus = classifyCarbSplitStatus(
            from: carbSplitPrepared,
            stage: dayContext.windowStage
        )

        let achievedMainTargetCount = classifyAchievedMainTargetCount(
            carbsProgressState: carbsProgressState,
            proteinProgressState: proteinProgressState,
            fatProgressState: fatProgressState,
            caloriesProgressState: caloriesProgressState,
            includeCaloriesInEvaluation: includeCaloriesAsMainTarget
        )

        let strongAchievedMainTargetCount = classifyStrongAchievedMainTargetCount(
            carbsPrepared: carbsPrepared,
            proteinPrepared: proteinPrepared,
            fatPrepared: fatPrepared,
            caloriesPrepared: caloriesPrepared,
            includeCaloriesInEvaluation: includeCaloriesAsMainTarget
        )

        let laggingMainTargetCount = classifyLaggingMainTargetCount(
            carbsProgressState: carbsProgressState,
            proteinProgressState: proteinProgressState,
            fatProgressState: fatProgressState,
            caloriesProgressState: caloriesProgressState,
            includeCaloriesInEvaluation: includeCaloriesAsMainTarget
        )

        let onTrackMainTargetCount = classifyOnTrackMainTargetCount(
            carbsProgressState: carbsProgressState,
            proteinProgressState: proteinProgressState,
            fatProgressState: fatProgressState,
            caloriesProgressState: caloriesProgressState,
            includeCaloriesInEvaluation: includeCaloriesAsMainTarget
        )

        let aheadMainTargetCount = classifyAheadMainTargetCount(
            carbsProgressState: carbsProgressState,
            proteinProgressState: proteinProgressState,
            fatProgressState: fatProgressState,
            caloriesProgressState: caloriesProgressState,
            includeCaloriesInEvaluation: includeCaloriesAsMainTarget
        )

        let overrunMainTargetCount = classifyOverrunMainTargetCount(
            carbsProgressState: carbsProgressState,
            proteinProgressState: proteinProgressState,
            fatProgressState: fatProgressState,
            caloriesProgressState: caloriesProgressState,
            includeCaloriesInEvaluation: includeCaloriesAsMainTarget
        )

        let mainTargetLeadState = classifyMainTargetLeadState(
            carbsPrepared: carbsPrepared,
            proteinPrepared: proteinPrepared,
            fatPrepared: fatPrepared,
            caloriesPrepared: caloriesPrepared,
            includeCaloriesInEvaluation: includeCaloriesAsMainTarget,
            stage: dayContext.windowStage
        )

        let achievementState = classifyAchievementState(
            achievedMainTargetCount: achievedMainTargetCount,
            strongAchievedMainTargetCount: strongAchievedMainTargetCount,
            overrunMainTargetCount: overrunMainTargetCount
        )

        let combinedBias = classifyCombinedBias(
            carbsProgressState: carbsProgressState,
            proteinProgressState: proteinProgressState,
            fatProgressState: fatProgressState,
            caloriesProgressState: caloriesProgressState,
            includeCaloriesInEvaluation: includeCaloriesAsMainTarget,
            includeEnergyInInterpretation: includeEnergyInInterpretation,
            energyStatus: energyStatus
        )

        let mainCriteriaAlignment = classifyMainCriteriaAlignment(
            carbsProgressState: carbsProgressState,
            proteinProgressState: proteinProgressState,
            fatProgressState: fatProgressState,
            caloriesProgressState: caloriesProgressState,
            includeCaloriesInEvaluation: includeCaloriesAsMainTarget,
            includeEnergyInInterpretation: includeEnergyInInterpretation,
            energyStatus: energyStatus
        )

        return NITClassifiedSignalsV1(
            dayContext: dayContext,
            availabilityState: availabilityState,
            carbsPrepared: carbsPrepared,
            sugarPrepared: sugarPrepared,
            proteinPrepared: proteinPrepared,
            fatPrepared: fatPrepared,
            caloriesPrepared: caloriesPrepared,
            energyPrepared: energyPrepared,
            macroStructurePrepared: macroStructurePrepared,
            carbSplitPrepared: carbSplitPrepared,
            carbsStatus: carbsStatus,
            sugarStatus: sugarStatus,
            proteinStatus: proteinStatus,
            fatStatus: fatStatus,
            caloriesStatus: caloriesStatus,
            carbsProgressState: carbsProgressState,
            proteinProgressState: proteinProgressState,
            fatProgressState: fatProgressState,
            caloriesProgressState: caloriesProgressState,
            proteinStrength: proteinStrength,
            caloriesStrength: caloriesStrength,
            energyStatus: energyStatus,
            macroStructureStatus: macroStructureStatus,
            carbSplitStatus: carbSplitStatus,
            combinedBias: combinedBias,
            mainCriteriaAlignment: mainCriteriaAlignment,
            achievementState: achievementState,
            achievedMainTargetCount: achievedMainTargetCount,
            strongAchievedMainTargetCount: strongAchievedMainTargetCount,
            laggingMainTargetCount: laggingMainTargetCount,
            onTrackMainTargetCount: onTrackMainTargetCount,
            aheadMainTargetCount: aheadMainTargetCount,
            overrunMainTargetCount: overrunMainTargetCount,
            mainTargetLeadState: mainTargetLeadState,
            openDayProgressState: nil,
            closedDayEvaluationState: nil
        )
    }
}

// ============================================================
// MARK: - Day Context
// ============================================================

private extension NutritionInsightEngineClassifierV1 {

    static func makeDayContext(now: Date, calendar: Calendar) -> NITDayContextV1 {
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        let minutesElapsed = max(0, min(hour * 60 + minute, 1440))
        let progress = Double(minutesElapsed) / 1440.0

        let isPracticalDayClose = minutesElapsed >= (20 * 60)
        let isHardDayClosed = minutesElapsed >= (23 * 60 + 45)

        let stage: NITWindowStageV1
        if isHardDayClosed {
            stage = .dayClosed
        } else if minutesElapsed < (12 * 60) {
            stage = .morning
        } else if minutesElapsed < (18 * 60) {
            stage = .afternoon
        } else {
            stage = .evening
        }

        return NITDayContextV1(
            minutesElapsed: minutesElapsed,
            dayProgressFraction: progress,
            windowStage: stage,
            isPracticalDayClose: isPracticalDayClose,
            isCaloriesEvaluationOpen: isPracticalDayClose
        )
    }

    static func shouldIncludeCaloriesAsMainTarget(dayContext: NITDayContextV1) -> Bool {
        dayContext.minutesElapsed < (20 * 60)
    }

    static func shouldIncludeEnergyInInterpretation(dayContext: NITDayContextV1) -> Bool {
        dayContext.minutesElapsed >= (20 * 60)
    }
}

// ============================================================
// MARK: - Prepared Metrics
// ============================================================

private extension NutritionInsightEngineClassifierV1 {

    static func makeTargetPreparedMetric(
        todayValue: Int,
        targetValue: Int,
        dayContext: NITDayContextV1
    ) -> NITPreparedTargetMetricV1 {
        let safeToday = Double(max(0, todayValue))
        let safeTarget = Double(max(0, targetValue))
        let ratio = safeTarget > 0 ? safeToday / safeTarget : 0

        let expectedRatioAtCurrentTime = expectedTargetRatio(
            for: dayContext.windowStage,
            dayProgressFraction: dayContext.dayProgressFraction
        )

        let progressDeltaToExpected = ratio - expectedRatioAtCurrentTime
        let progressRelativeToExpected = expectedRatioAtCurrentTime > 0
            ? ratio / expectedRatioAtCurrentTime
            : 0

        return NITPreparedTargetMetricV1(
            todayValue: safeToday,
            targetValue: safeTarget,
            targetRatio: ratio,
            expectedRatioAtCurrentTime: expectedRatioAtCurrentTime,
            progressDeltaToExpected: progressDeltaToExpected,
            progressRelativeToExpected: progressRelativeToExpected
        )
    }

    static func expectedTargetRatio(
        for stage: NITWindowStageV1,
        dayProgressFraction: Double
    ) -> Double {
        let clampedProgress = min(max(dayProgressFraction, 0), 1)

        switch stage {
        case .morning:
            return max(0.12, clampedProgress * 0.90)
        case .afternoon:
            return max(0.38, clampedProgress * 0.98)
        case .evening:
            return max(0.62, clampedProgress * 1.00)
        case .dayClosed:
            return 1.0
        }
    }

    static func makeEnergyPreparedMetric(
        nutritionEnergyKcal: Int,
        activeEnergyKcal: Int,
        restingEnergyKcal: Int
    ) -> NITPreparedEnergyMetricV1 {
        let intake = Double(max(0, nutritionEnergyKcal))
        let active = Double(max(0, activeEnergyKcal))
        let resting = Double(max(0, restingEnergyKcal))
        let totalBurned = active + resting
        let energyDelta = intake - totalBurned
        let balanceRatio = totalBurned > 0 ? intake / totalBurned : 0

        return NITPreparedEnergyMetricV1(
            nutritionEnergyKcal: intake,
            activeEnergyKcal: active,
            restingEnergyKcal: resting,
            totalBurnedKcal: totalBurned,
            energyDeltaKcal: energyDelta,
            balanceRatio: balanceRatio
        )
    }

    static func makeMacroStructurePreparedMetric(
        carbsGrams: Int,
        proteinGrams: Int,
        fatGrams: Int
    ) -> NITPreparedMacroStructureMetricV1 {
        let carbs = Double(max(0, carbsGrams))
        let protein = Double(max(0, proteinGrams))
        let fat = Double(max(0, fatGrams))
        let total = carbs + protein + fat

        guard total > 0 else {
            return NITPreparedMacroStructureMetricV1(
                totalMacroGrams: 0,
                carbsShare: 0,
                proteinShare: 0,
                fatShare: 0,
                isAssessable: false
            )
        }

        return NITPreparedMacroStructureMetricV1(
            totalMacroGrams: total,
            carbsShare: carbs / total,
            proteinShare: protein / total,
            fatShare: fat / total,
            isAssessable: total >= 40
        )
    }

    static func makeCarbSplitPreparedMetric(
        morningGrams: Int,
        afternoonGrams: Int,
        nightGrams: Int,
        targetCarbsGrams: Int,
        dayContext: NITDayContextV1
    ) -> NITPreparedCarbSplitMetricV1 {
        let morning = Double(max(0, morningGrams))
        let afternoon = Double(max(0, afternoonGrams))
        let night = Double(max(0, nightGrams))
        let total = morning + afternoon + night

        let morningShare = total > 0 ? morning / total : 0
        let afternoonShare = total > 0 ? afternoon / total : 0
        let nightShare = total > 0 ? night / total : 0

        let safeTarget = Double(max(0, targetCarbsGrams))
        let morningTargetShare = safeTarget > 0 ? morning / safeTarget : 0
        let afternoonTargetShare = safeTarget > 0 ? afternoon / safeTarget : 0
        let nightTargetShare = safeTarget > 0 ? night / safeTarget : 0
        let totalTargetShare = safeTarget > 0 ? total / safeTarget : 0

        let completedWindowsCount: Int
        switch dayContext.windowStage {
        case .morning:
            completedWindowsCount = 0
        case .afternoon:
            completedWindowsCount = 1
        case .evening:
            completedWindowsCount = 2
        case .dayClosed:
            completedWindowsCount = 3
        }

        let hasTargetContext = safeTarget > 0
        let hasMeaningfulCarbSignal = total >= 30 || totalTargetShare >= 0.15

        return NITPreparedCarbSplitMetricV1(
            morningGrams: morning,
            afternoonGrams: afternoon,
            nightGrams: night,
            morningShare: morningShare,
            afternoonShare: afternoonShare,
            nightShare: nightShare,
            morningTargetShare: morningTargetShare,
            afternoonTargetShare: afternoonTargetShare,
            nightTargetShare: nightTargetShare,
            totalTargetShare: totalTargetShare,
            completedWindowsCount: completedWindowsCount,
            isAssessable: hasTargetContext && hasMeaningfulCarbSignal && completedWindowsCount > 0
        )
    }
}

// ============================================================
// MARK: - Availability
// ============================================================

private extension NutritionInsightEngineClassifierV1 {

    static func classifyAvailabilityState(
        input: NutritionInsightEngineV1.Input,
        macroStructurePrepared: NITPreparedMacroStructureMetricV1,
        energyPrepared: NITPreparedEnergyMetricV1
    ) -> NITAvailabilityStateV1 {
        if input.isDataAccessBlocked {
            return .blocked
        }

        let hasMacroData = macroStructurePrepared.totalMacroGrams > 0
        let hasNutritionEnergyData = input.nutritionEnergyKcal > 0
        let hasEnergyContext = energyPrepared.totalBurnedKcal > 0

        if !hasMacroData && !hasNutritionEnergyData && !hasEnergyContext {
            return .noData
        }

        let hasEnoughSignal =
            hasMacroData ||
            hasNutritionEnergyData ||
            hasEnergyContext

        return hasEnoughSignal ? .ready : .insufficientData
    }
}

// ============================================================
// MARK: - Target Status / Progress
// ============================================================

private extension NutritionInsightEngineClassifierV1 {

    static func classifyTargetStatus(from prepared: NITPreparedTargetMetricV1) -> NITTargetStatusV1 {
        let ratio = prepared.targetRatio

        switch ratio {
        case ..<0.50:
            return .clearlyBelow
        case ..<0.85:
            return .below
        case ..<1.00:
            return .nearTarget
        case ..<1.15:
            return .onTarget
        case ..<1.35:
            return .above
        default:
            return .clearlyAbove
        }
    }

    static func classifyMainTargetProgressState(
        from prepared: NITPreparedTargetMetricV1,
        stage: NITWindowStageV1
    ) -> NITMainTargetProgressStateV1 {
        let ratio = prepared.targetRatio
        let relativeToExpected = prepared.progressRelativeToExpected
        let deltaToExpected = prepared.progressDeltaToExpected

        if ratio >= 1.18 {
            return .overrun
        }

        if ratio >= 0.98 {
            return .achieved
        }

        switch stage {
        case .morning:
            if relativeToExpected >= 1.80 || deltaToExpected >= 0.22 {
                return .ahead
            }
            if relativeToExpected >= 0.90 || deltaToExpected >= -0.05 {
                return .onTrack
            }
            return .lagging

        case .afternoon:
            if relativeToExpected >= 1.45 || deltaToExpected >= 0.18 {
                return .ahead
            }
            if relativeToExpected >= 0.88 || deltaToExpected >= -0.08 {
                return .onTrack
            }
            return .lagging

        case .evening:
            if relativeToExpected >= 1.20 || deltaToExpected >= 0.12 {
                return .ahead
            }
            if relativeToExpected >= 0.92 || deltaToExpected >= -0.08 {
                return .onTrack
            }
            return .lagging

        case .dayClosed:
            if ratio >= 0.90 {
                return .achieved
            }
            return .lagging
        }
    }

    static func classifyStrength(from ratio: Double) -> NITSignalStrengthV1 {
        let deviation = abs(ratio - 1.0)

        switch deviation {
        case ..<0.15:
            return .weak
        case ..<0.35:
            return .moderate
        default:
            return .strong
        }
    }
}

// ============================================================
// MARK: - Energy Balance
// ============================================================

private extension NutritionInsightEngineClassifierV1 {

    static func classifyEnergyBalanceStatus(from prepared: NITPreparedEnergyMetricV1) -> NITEnergyBalanceStatusV1 {
        let intake = prepared.nutritionEnergyKcal
        let burned = prepared.totalBurnedKcal

        guard intake > 0 || burned > 0 else {
            return .remaining
        }

        let tolerance = max(150.0, max(intake, burned) * 0.08)
        let delta = prepared.energyDeltaKcal

        if abs(delta) <= tolerance {
            return .nearBalance
        }

        return delta > 0 ? .over : .remaining
    }
}

// ============================================================
// MARK: - Macro Structure
// ============================================================

private extension NutritionInsightEngineClassifierV1 {

    static func classifyMacroStructureStatus(from prepared: NITPreparedMacroStructureMetricV1) -> NITMacroStructureStatusV1 {
        guard prepared.isAssessable else {
            return .notApplicable
        }

        let carbs = prepared.carbsShare
        let protein = prepared.proteinShare
        let fat = prepared.fatShare

        let maxShare = max(carbs, protein, fat)

        if carbs >= 0.30 && carbs <= 0.50 &&
            protein >= 0.20 && protein <= 0.35 &&
            fat >= 0.20 && fat <= 0.40 {
            return .balanced
        }

        if maxShare >= 0.60 {
            return .imbalanced
        }

        return .mixed
    }
}

// ============================================================
// MARK: - Carb Split
// ============================================================

private extension NutritionInsightEngineClassifierV1 {

    static func classifyCarbSplitStatus(
        from prepared: NITPreparedCarbSplitMetricV1,
        stage: NITWindowStageV1
    ) -> NITCarbSplitStatusV1 {
        guard prepared.completedWindowsCount > 0 else {
            return .tooEarly
        }

        guard prepared.isAssessable else {
            return .notApplicable
        }

        switch prepared.completedWindowsCount {
        case 1:
            if prepared.morningTargetShare >= 0.50 {
                return .frontLoaded
            }

            if prepared.morningTargetShare <= 0.45 {
                return .balancedSoFar
            }

            return .mixed

        case 2:
            let maxCompletedTargetShare = max(
                prepared.morningTargetShare,
                prepared.afternoonTargetShare
            )

            let completedGap = abs(
                prepared.morningTargetShare - prepared.afternoonTargetShare
            )

            if prepared.morningTargetShare >= 0.55 &&
                prepared.morningTargetShare >= prepared.afternoonTargetShare + 0.15 {
                return .frontLoaded
            }

            if prepared.afternoonTargetShare >= 0.55 &&
                prepared.afternoonTargetShare >= prepared.morningTargetShare + 0.15 {
                return .midDayLoaded
            }

            if maxCompletedTargetShare <= 0.45 && completedGap <= 0.15 {
                return .balancedSoFar
            }

            return .mixed

        default:
            if stage == .dayClosed {
                if prepared.morningTargetShare >= 0.55 &&
                    prepared.morningTargetShare >= prepared.afternoonTargetShare + 0.15 &&
                    prepared.morningTargetShare >= prepared.nightTargetShare + 0.15 {
                    return .frontLoaded
                }

                if prepared.afternoonTargetShare >= 0.55 &&
                    prepared.afternoonTargetShare >= prepared.morningTargetShare + 0.15 &&
                    prepared.afternoonTargetShare >= prepared.nightTargetShare + 0.15 {
                    return .midDayLoaded
                }

                if prepared.nightTargetShare >= 0.55 &&
                    prepared.nightTargetShare >= prepared.morningTargetShare + 0.15 &&
                    prepared.nightTargetShare >= prepared.afternoonTargetShare + 0.15 {
                    return .lateLoaded
                }

                let maxTargetShare = max(
                    prepared.morningTargetShare,
                    prepared.afternoonTargetShare,
                    prepared.nightTargetShare
                )

                if maxTargetShare <= 0.45 {
                    return .balancedSoFar
                }
            }

            return .mixed
        }
    }
}

// ============================================================
// MARK: - Goal / Achievement / Lead
// ============================================================

private extension NutritionInsightEngineClassifierV1 {

    static func classifyAchievementState(
        achievedMainTargetCount: Int,
        strongAchievedMainTargetCount: Int,
        overrunMainTargetCount: Int
    ) -> NITAchievementStateV1 {
        if overrunMainTargetCount > 0 {
            return .none
        }

        if strongAchievedMainTargetCount >= 2 {
            return .strongMultiMainTargetAchievement
        }

        if strongAchievedMainTargetCount == 1 {
            return .strongSingleMainTargetAchievement
        }

        if achievedMainTargetCount >= 2 {
            return .multiMainTargetsAchieved
        }

        if achievedMainTargetCount == 1 {
            return .singleMainTargetAchieved
        }

        return .none
    }

    static func classifyAchievedMainTargetCount(
        carbsProgressState: NITMainTargetProgressStateV1,
        proteinProgressState: NITMainTargetProgressStateV1,
        fatProgressState: NITMainTargetProgressStateV1,
        caloriesProgressState: NITMainTargetProgressStateV1,
        includeCaloriesInEvaluation: Bool
    ) -> Int {
        countMainTargetStates(
            carbsProgressState: carbsProgressState,
            proteinProgressState: proteinProgressState,
            fatProgressState: fatProgressState,
            caloriesProgressState: caloriesProgressState,
            includeCaloriesInEvaluation: includeCaloriesInEvaluation
        ) { $0 == .achieved }
    }

    static func classifyStrongAchievedMainTargetCount(
        carbsPrepared: NITPreparedTargetMetricV1,
        proteinPrepared: NITPreparedTargetMetricV1,
        fatPrepared: NITPreparedTargetMetricV1,
        caloriesPrepared: NITPreparedTargetMetricV1,
        includeCaloriesInEvaluation: Bool
    ) -> Int {
        let carbStrong = carbsPrepared.targetRatio >= 1.05 && carbsPrepared.targetRatio < 1.18
        let proteinStrong = proteinPrepared.targetRatio >= 1.05 && proteinPrepared.targetRatio < 1.18
        let fatStrong = fatPrepared.targetRatio >= 1.05 && fatPrepared.targetRatio < 1.18
        let caloriesStrong = includeCaloriesInEvaluation &&
            caloriesPrepared.targetRatio >= 1.05 &&
            caloriesPrepared.targetRatio < 1.18

        return
            (carbStrong ? 1 : 0) +
            (proteinStrong ? 1 : 0) +
            (fatStrong ? 1 : 0) +
            (caloriesStrong ? 1 : 0)
    }

    static func classifyLaggingMainTargetCount(
        carbsProgressState: NITMainTargetProgressStateV1,
        proteinProgressState: NITMainTargetProgressStateV1,
        fatProgressState: NITMainTargetProgressStateV1,
        caloriesProgressState: NITMainTargetProgressStateV1,
        includeCaloriesInEvaluation: Bool
    ) -> Int {
        countMainTargetStates(
            carbsProgressState: carbsProgressState,
            proteinProgressState: proteinProgressState,
            fatProgressState: fatProgressState,
            caloriesProgressState: caloriesProgressState,
            includeCaloriesInEvaluation: includeCaloriesInEvaluation
        ) { $0 == .lagging }
    }

    static func classifyOnTrackMainTargetCount(
        carbsProgressState: NITMainTargetProgressStateV1,
        proteinProgressState: NITMainTargetProgressStateV1,
        fatProgressState: NITMainTargetProgressStateV1,
        caloriesProgressState: NITMainTargetProgressStateV1,
        includeCaloriesInEvaluation: Bool
    ) -> Int {
        countMainTargetStates(
            carbsProgressState: carbsProgressState,
            proteinProgressState: proteinProgressState,
            fatProgressState: fatProgressState,
            caloriesProgressState: caloriesProgressState,
            includeCaloriesInEvaluation: includeCaloriesInEvaluation
        ) { $0 == .onTrack }
    }

    static func classifyAheadMainTargetCount(
        carbsProgressState: NITMainTargetProgressStateV1,
        proteinProgressState: NITMainTargetProgressStateV1,
        fatProgressState: NITMainTargetProgressStateV1,
        caloriesProgressState: NITMainTargetProgressStateV1,
        includeCaloriesInEvaluation: Bool
    ) -> Int {
        countMainTargetStates(
            carbsProgressState: carbsProgressState,
            proteinProgressState: proteinProgressState,
            fatProgressState: fatProgressState,
            caloriesProgressState: caloriesProgressState,
            includeCaloriesInEvaluation: includeCaloriesInEvaluation
        ) { $0 == .ahead }
    }

    static func classifyOverrunMainTargetCount(
        carbsProgressState: NITMainTargetProgressStateV1,
        proteinProgressState: NITMainTargetProgressStateV1,
        fatProgressState: NITMainTargetProgressStateV1,
        caloriesProgressState: NITMainTargetProgressStateV1,
        includeCaloriesInEvaluation: Bool
    ) -> Int {
        countMainTargetStates(
            carbsProgressState: carbsProgressState,
            proteinProgressState: proteinProgressState,
            fatProgressState: fatProgressState,
            caloriesProgressState: caloriesProgressState,
            includeCaloriesInEvaluation: includeCaloriesInEvaluation
        ) { $0 == .overrun }
    }

    static func classifyMainTargetLeadState(
        carbsPrepared: NITPreparedTargetMetricV1,
        proteinPrepared: NITPreparedTargetMetricV1,
        fatPrepared: NITPreparedTargetMetricV1,
        caloriesPrepared: NITPreparedTargetMetricV1,
        includeCaloriesInEvaluation: Bool,
        stage: NITWindowStageV1
    ) -> NITMainTargetLeadStateV1 {
        var candidates: [(state: NITMainTargetLeadStateV1, value: Double)] = [
            (.carbsLeading, leadMetricValue(from: carbsPrepared, stage: stage)),
            (.proteinLeading, leadMetricValue(from: proteinPrepared, stage: stage)),
            (.fatLeading, leadMetricValue(from: fatPrepared, stage: stage))
        ]

        if includeCaloriesInEvaluation {
            candidates.append((.caloriesLeading, leadMetricValue(from: caloriesPrepared, stage: stage)))
        }

        let sorted = candidates.sorted { $0.value > $1.value }

        guard let first = sorted.first, first.value > 0 else {
            return .none
        }

        guard sorted.count >= 2 else {
            return first.state
        }

        let second = sorted[1]

        if abs(first.value - second.value) < 0.10 {
            return .mixedLead
        }

        return first.state
    }

    static func leadMetricValue(
        from prepared: NITPreparedTargetMetricV1,
        stage: NITWindowStageV1
    ) -> Double {
        switch stage {
        case .morning, .afternoon:
            return prepared.progressRelativeToExpected
        case .evening, .dayClosed:
            return prepared.targetRatio
        }
    }

    static func countMainTargetStates(
        carbsProgressState: NITMainTargetProgressStateV1,
        proteinProgressState: NITMainTargetProgressStateV1,
        fatProgressState: NITMainTargetProgressStateV1,
        caloriesProgressState: NITMainTargetProgressStateV1,
        includeCaloriesInEvaluation: Bool,
        where predicate: (NITMainTargetProgressStateV1) -> Bool
    ) -> Int {
        let states: [NITMainTargetProgressStateV1] = includeCaloriesInEvaluation
            ? [carbsProgressState, proteinProgressState, fatProgressState, caloriesProgressState]
            : [carbsProgressState, proteinProgressState, fatProgressState]

        return states.filter(predicate).count
    }
}

// ============================================================
// MARK: - Combined Bias
// ============================================================

private extension NutritionInsightEngineClassifierV1 {

    static func classifyCombinedBias(
        carbsProgressState: NITMainTargetProgressStateV1,
        proteinProgressState: NITMainTargetProgressStateV1,
        fatProgressState: NITMainTargetProgressStateV1,
        caloriesProgressState: NITMainTargetProgressStateV1,
        includeCaloriesInEvaluation: Bool,
        includeEnergyInInterpretation: Bool,
        energyStatus: NITEnergyBalanceStatusV1
    ) -> NITInterpretationBiasV1 {
        let summary = makeProgressSignalSummary(
            carbsProgressState: carbsProgressState,
            proteinProgressState: proteinProgressState,
            fatProgressState: fatProgressState,
            caloriesProgressState: caloriesProgressState,
            includeCaloriesInEvaluation: includeCaloriesInEvaluation,
            includeEnergyInInterpretation: includeEnergyInInterpretation,
            energyStatus: energyStatus
        )

        if summary.positiveCount > 0 && summary.negativeCount > 0 {
            return .mixed
        }

        if summary.positiveCount > 0 {
            return .positive
        }

        if summary.negativeCount > 0 {
            return .negative
        }

        return .none
    }

    static func classifyMainCriteriaAlignment(
        carbsProgressState: NITMainTargetProgressStateV1,
        proteinProgressState: NITMainTargetProgressStateV1,
        fatProgressState: NITMainTargetProgressStateV1,
        caloriesProgressState: NITMainTargetProgressStateV1,
        includeCaloriesInEvaluation: Bool,
        includeEnergyInInterpretation: Bool,
        energyStatus: NITEnergyBalanceStatusV1
    ) -> NITMainCriteriaAlignmentV1 {
        let summary = makeProgressSignalSummary(
            carbsProgressState: carbsProgressState,
            proteinProgressState: proteinProgressState,
            fatProgressState: fatProgressState,
            caloriesProgressState: caloriesProgressState,
            includeCaloriesInEvaluation: includeCaloriesInEvaluation,
            includeEnergyInInterpretation: includeEnergyInInterpretation,
            energyStatus: energyStatus
        )

        if summary.positiveCount >= max(summary.stateCount - 1, 2) && summary.negativeCount == 0 {
            return .alignedPositive
        }

        if summary.negativeCount >= 2 && summary.positiveCount == 0 {
            return .alignedNegative
        }

        if summary.positiveCount > 0 && summary.negativeCount > 0 {
            return .conflicting
        }

        if summary.positiveCount > 0 || summary.negativeCount > 0 {
            return .mixed
        }

        return .neutral
    }

    static func makeProgressSignalSummary(
        carbsProgressState: NITMainTargetProgressStateV1,
        proteinProgressState: NITMainTargetProgressStateV1,
        fatProgressState: NITMainTargetProgressStateV1,
        caloriesProgressState: NITMainTargetProgressStateV1,
        includeCaloriesInEvaluation: Bool,
        includeEnergyInInterpretation: Bool,
        energyStatus: NITEnergyBalanceStatusV1
    ) -> (stateCount: Int, positiveCount: Int, negativeCount: Int) {
        let states: [NITMainTargetProgressStateV1] = includeCaloriesInEvaluation
            ? [carbsProgressState, proteinProgressState, fatProgressState, caloriesProgressState]
            : [carbsProgressState, proteinProgressState, fatProgressState]

        let positiveCount = states.filter { $0 == .onTrack || $0 == .achieved }.count

        let stateNegativeCount = states.filter { $0 == .lagging || $0 == .overrun }.count
        let energyNegativeCount = (includeEnergyInInterpretation && energyStatus == .over) ? 1 : 0
        let negativeCount = stateNegativeCount + energyNegativeCount

        let totalCount = states.count + (includeEnergyInInterpretation ? 1 : 0)

        return (totalCount, positiveCount, negativeCount)
    }
}
