//
//  ActivityInsightEngineClassifierV1.swift
//  GluVibProbe
//
//  Domain: Activity Insight Engine
//  Layer: Internal Classification V1
//
//  Purpose
//  - Builds simplified day context
//  - Prepares baseline-aware metrics
//  - Classifies relative Steps / Active Energy status
//  - Classifies goal status
//  - Produces stable input for the simplified resolver
//

import Foundation

enum ActivityInsightEngineClassifierV1 {

    static func classify(from input: ActivityInsightInput) -> AIClassifiedSignalsV1 {
        let dayContext = makeDayContext(now: input.now, calendar: input.calendar)

        let stepsPrepared = makeRelativePreparedMetric(
            todayValue: Double(input.stepsToday),
            baselineDayAverage: input.steps7DayAverage.map(Double.init),
            dayProgressFraction: dayContext.dayProgressFraction
        )

        let activeEnergyBaseline = input.activeEnergy30DayAverageKcal ?? input.activeEnergy7DayAverageKcal

        let activeEnergyPrepared = makeRelativePreparedMetric(
            todayValue: Double(input.activeEnergyTodayKcal),
            baselineDayAverage: activeEnergyBaseline.map(Double.init),
            dayProgressFraction: dayContext.dayProgressFraction
        )

        let goalPrepared = AIPreparedGoalMetricV1(
            todayValue: Double(input.stepsToday),
            goalValue: input.stepsGoal.map(Double.init),
            goalRatio: makeGoalRatio(todayValue: input.stepsToday, goalValue: input.stepsGoal)
        )

        let stepsStatus = classifyRelativeStatus(
            deviationPercent: stepsPrepared.deviationPercent,
            expectedBaselineAtProgress: stepsPrepared.expectedBaselineAtProgress,
            minimumExpectedBaseline: 400
        )

        let energyStatus = classifyRelativeStatus(
            deviationPercent: activeEnergyPrepared.deviationPercent,
            expectedBaselineAtProgress: activeEnergyPrepared.expectedBaselineAtProgress,
            minimumExpectedBaseline: 40
        )

        let stepsStrength = stepsPrepared.deviationPercent.map(classifyStrength)
        let energyStrength = activeEnergyPrepared.deviationPercent.map(classifyStrength)

        let goalStatus = goalPrepared.goalRatio.map(classifyGoalStatus)

        let availabilityState = classifyAvailabilityState(
            stepsPrepared: stepsPrepared,
            activeEnergyPrepared: activeEnergyPrepared,
            stepsToday: input.stepsToday,
            activeEnergyTodayKcal: input.activeEnergyTodayKcal
        )

        let isStepGoalReached = {
            guard let goalStatus else { return false }
            return goalStatus == .goalMet || goalStatus == .goalExceeded
        }()

        let isEnergyAchievementReached = classifyEnergyAchievement(
            todayEnergy: activeEnergyPrepared.todayValue,
            energyBaselineDayAverage: activeEnergyPrepared.baselineDayAverage
        )

        // 🟨 UPDATED: dual achievement is now upgraded to strongDualAchievement
        // as soon as both goals are reached and at least one side is clearly standout.
        let achievementState = classifyAchievementState(
            goalRatio: goalPrepared.goalRatio,
            isStepGoalReached: isStepGoalReached,
            isEnergyAchievementReached: isEnergyAchievementReached,
            todayEnergy: activeEnergyPrepared.todayValue,
            energyBaselineDayAverage: activeEnergyPrepared.baselineDayAverage
        )

        let combinedBias = classifyCombinedBias(
            stepsStatus: stepsStatus,
            energyStatus: energyStatus
        )

        return AIClassifiedSignalsV1(
            dayContext: dayContext,
            availabilityState: availabilityState,
            stepsPrepared: stepsPrepared,
            activeEnergyPrepared: activeEnergyPrepared,
            goalPrepared: goalPrepared,
            stepsStatus: stepsStatus,
            energyStatus: energyStatus,
            stepsStrength: stepsStrength,
            energyStrength: energyStrength,
            combinedBias: combinedBias,
            goalStatus: goalStatus,
            isStepGoalReached: isStepGoalReached,
            isEnergyAchievementReached: isEnergyAchievementReached,
            achievementState: achievementState
        )
    }
}

// ============================================================
// MARK: - Day Context
// ============================================================

private extension ActivityInsightEngineClassifierV1 {

    static func makeDayContext(now: Date, calendar: Calendar) -> AIDayContextV1 {
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        let minutesElapsed = max(0, min(hour * 60 + minute, 1440))
        let progress = Double(minutesElapsed) / 1440.0

        let isPracticalDayClose = minutesElapsed >= (22 * 60 + 30)

        let stage: AIWindowStageV1
        if isPracticalDayClose {
            stage = .dayClosed
        } else if minutesElapsed < 12 * 60 {
            stage = .morning
        } else if minutesElapsed < 18 * 60 {
            stage = .afternoon
        } else {
            stage = .evening
        }

        return AIDayContextV1(
            minutesElapsed: minutesElapsed,
            dayProgressFraction: progress,
            windowStage: stage,
            isPracticalDayClose: isPracticalDayClose
        )
    }
}

// ============================================================
// MARK: - Prepared Metrics
// ============================================================

private extension ActivityInsightEngineClassifierV1 {

    static func makeRelativePreparedMetric(
        todayValue: Double,
        baselineDayAverage: Double?,
        dayProgressFraction: Double
    ) -> AIPreparedRelativeMetricV1 {
        guard let baselineDayAverage, baselineDayAverage > 0 else {
            return AIPreparedRelativeMetricV1(
                todayValue: todayValue,
                baselineDayAverage: nil,
                expectedBaselineAtProgress: nil,
                deviationPercent: nil
            )
        }

        let effectiveProgress = max(dayProgressFraction, 0.05)
        let expectedAtProgress = baselineDayAverage * effectiveProgress

        let deviationPercent: Double? = {
            guard expectedAtProgress > 0 else { return nil }
            return (todayValue - expectedAtProgress) / expectedAtProgress
        }()

        return AIPreparedRelativeMetricV1(
            todayValue: todayValue,
            baselineDayAverage: baselineDayAverage,
            expectedBaselineAtProgress: expectedAtProgress,
            deviationPercent: deviationPercent
        )
    }

    static func makeGoalRatio(todayValue: Int, goalValue: Int?) -> Double? {
        guard let goalValue, goalValue > 0 else { return nil }
        return Double(todayValue) / Double(goalValue)
    }
}

// ============================================================
// MARK: - Availability
// ============================================================

private extension ActivityInsightEngineClassifierV1 {

    static func classifyAvailabilityState(
        stepsPrepared: AIPreparedRelativeMetricV1,
        activeEnergyPrepared: AIPreparedRelativeMetricV1,
        stepsToday: Int,
        activeEnergyTodayKcal: Int
    ) -> AIAvailabilityStateV1 {
        let hasAnyRawActivity = stepsToday > 0 || activeEnergyTodayKcal > 0

        let hasAnyBaseline =
            (stepsPrepared.baselineDayAverage ?? 0) > 0 ||
            (activeEnergyPrepared.baselineDayAverage ?? 0) > 0

        let hasAnyPreparedSignal =
            stepsPrepared.deviationPercent != nil ||
            activeEnergyPrepared.deviationPercent != nil

        if !hasAnyRawActivity && !hasAnyBaseline {
            return .noData
        }

        if !hasAnyPreparedSignal {
            return .insufficientData
        }

        if hasAnyBaseline {
            return .ready
        }

        return .insufficientData
    }
}

// ============================================================
// MARK: - Relative Status
// ============================================================

private extension ActivityInsightEngineClassifierV1 {

    static func classifyRelativeStatus(
        deviationPercent: Double?,
        expectedBaselineAtProgress: Double?,
        minimumExpectedBaseline: Double
    ) -> AIRelativeStatusV1? {
        guard let deviationPercent else { return nil }

        let rawStatus: AIRelativeStatusV1
        switch deviationPercent {
        case ...(-0.35):
            rawStatus = .clearlyBelow
        case ...(-0.18):
            rawStatus = .below
        case ..<0.18:
            rawStatus = .nearBaseline
        case ..<0.35:
            rawStatus = .above
        default:
            rawStatus = .clearlyAbove
        }

        guard let expectedBaselineAtProgress else { return rawStatus }
        guard expectedBaselineAtProgress < minimumExpectedBaseline else { return rawStatus }

        switch rawStatus {
        case .clearlyAbove:
            return .above
        case .clearlyBelow:
            return .below
        default:
            return rawStatus
        }
    }

    static func classifyStrength(_ deviationPercent: Double) -> AISignalStrengthV1 {
        let value = abs(deviationPercent)

        switch value {
        case ..<0.18:
            return .weak
        case ..<0.35:
            return .moderate
        default:
            return .strong
        }
    }
}

// ============================================================
// MARK: - Goal / Achievement
// ============================================================

private extension ActivityInsightEngineClassifierV1 {

    static func classifyGoalStatus(_ ratio: Double) -> AIGoalStatusV1 {
        switch ratio {
        case ..<0.50:
            return .farBelowGoal
        case ..<0.85:
            return .belowGoal
        case ..<1.00:
            return .nearGoal
        case ..<1.20:
            return .goalMet
        default:
            return .goalExceeded
        }
    }

    static func classifyEnergyAchievement(
        todayEnergy: Double,
        energyBaselineDayAverage: Double?
    ) -> Bool {
        guard let energyBaselineDayAverage, energyBaselineDayAverage > 0 else {
            return false
        }

        return todayEnergy >= energyBaselineDayAverage
    }

    static func classifyAchievementState(
        goalRatio: Double?,
        isStepGoalReached: Bool,
        isEnergyAchievementReached: Bool,
        todayEnergy: Double,
        energyBaselineDayAverage: Double?
    ) -> AIAchievementStateV1 {
        let isStrongStepAchievement: Bool = {
            guard isStepGoalReached, let goalRatio else { return false }
            return goalRatio >= 1.45
        }()

        let isStrongEnergyAchievement: Bool = {
            guard isEnergyAchievementReached,
                  let energyBaselineDayAverage,
                  energyBaselineDayAverage > 0 else { return false }

            let energyRatio = todayEnergy / energyBaselineDayAverage
            return energyRatio >= 1.75
        }()

        if isStepGoalReached && isEnergyAchievementReached && (isStrongStepAchievement || isStrongEnergyAchievement) {
            return .strongDualAchievement
        }

        if isStepGoalReached && isEnergyAchievementReached {
            return .dualGoalReached
        }

        if isStrongStepAchievement {
            return .strongStepAchievement
        }

        if isStrongEnergyAchievement {
            return .strongEnergyAchievement
        }

        if isStepGoalReached {
            return .stepGoalReached
        }

        if isEnergyAchievementReached {
            return .energyGoalReached
        }

        return .none
    }
}

// ============================================================
// MARK: - Combined Bias
// ============================================================

private extension ActivityInsightEngineClassifierV1 {

    static func classifyCombinedBias(
        stepsStatus: AIRelativeStatusV1?,
        energyStatus: AIRelativeStatusV1?
    ) -> AIInterpretationBiasV1 {
        let stepsPositive = isPositive(stepsStatus)
        let energyPositive = isPositive(energyStatus)

        let stepsNegative = isNegative(stepsStatus)
        let energyNegative = isNegative(energyStatus)

        if (stepsPositive && energyNegative) || (stepsNegative && energyPositive) {
            return .mixed
        }

        if stepsPositive || energyPositive {
            return .positive
        }

        if stepsNegative || energyNegative {
            return .negative
        }

        return .none
    }

    static func isPositive(_ status: AIRelativeStatusV1?) -> Bool {
        status == .above || status == .clearlyAbove
    }

    static func isNegative(_ status: AIRelativeStatusV1?) -> Bool {
        status == .below || status == .clearlyBelow
    }
}
