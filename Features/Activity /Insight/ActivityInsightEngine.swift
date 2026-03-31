//
//  ActivityInsightEngine.swift
//  GluVibProbe
//
//  Domain: Activity / Overview Insight
//
//  Purpose
//  - Public output engine for the Activity insight card.
//  - TODAY ONLY.
//  - Uses only:
//    - Steps
//    - Active Energy
//    - Time of day
//    - Goal as secondary signal
//
//  Important
//  - No HealthKit access
//  - No UI logic
//  - Localization is now routed through L10n.ActivityOverview
//  - Public API remains compatibility-safe for existing project call sites
//

import Foundation

// ============================================================
// MARK: - Public Models
// ============================================================

enum ActivityInsightCategory: String {
    case neutral
    case steps
    case energy
}

// ============================================================
// MARK: - Compatibility
// ============================================================

struct ActivityLastWorkoutInfo {
    let name: String
    let minutes: Int
    let distanceKm: Double?
    let energyKcal: Int?
    let startDate: Date
}

struct ActivityInsightInput {

    // Time context
    let now: Date
    let calendar: Calendar

    // Primary evaluation metrics
    let stepsToday: Int
    let stepsGoal: Int?
    let steps7DayAverage: Int?

    let activeEnergyTodayKcal: Int

    // ============================================================
    // MARK: - Active Energy Baselines
    // ============================================================
    // 30d is the intended primary baseline.
    // 7d remains as compatibility fallback so older classifier / call sites keep compiling.
    let activeEnergy30DayAverageKcal: Int?
    let activeEnergy7DayAverageKcal: Int?

    // ============================================================
    // MARK: - Compatibility Fields
    // ============================================================
    // These fields remain in the public input so existing Overview /
    // Score / Preview call sites keep compiling.
    // The current V1 ActivityInsightEngine does NOT evaluate them.
    // Real decision logic uses only Steps + Active Energy + Time + Goal.

    let distanceTodayKm: Double?
    let distance7DayAverageKm: Double?

    let exerciseMinutesToday: Int
    let exerciseMinutes7DayAverage: Int?

    let sleepMinutesToday: Int
    let activeMinutesTodayFromSplit: Int
    let sedentaryMinutesToday: Int

    let lastWorkout: ActivityLastWorkoutInfo?

    let hasEarlyActivityBlockHint: Bool?
    let hasLateActivityBlockHint: Bool?
    let hasWorkoutContextHint: Bool?

    init(
        now: Date = Date(),
        calendar: Calendar = .current,
        stepsToday: Int,
        stepsGoal: Int?,
        steps7DayAverage: Int?,
        distanceTodayKm: Double? = nil,
        distance7DayAverageKm: Double? = nil,
        exerciseMinutesToday: Int = 0,
        exerciseMinutes7DayAverage: Int? = nil,
        activeEnergyTodayKcal: Int,
        activeEnergy30DayAverageKcal: Int? = nil,
        activeEnergy7DayAverageKcal: Int? = nil,
        sleepMinutesToday: Int = 0,
        activeMinutesTodayFromSplit: Int = 0,
        sedentaryMinutesToday: Int = 0,
        lastWorkout: ActivityLastWorkoutInfo? = nil,
        hasEarlyActivityBlockHint: Bool? = nil,
        hasLateActivityBlockHint: Bool? = nil,
        hasWorkoutContextHint: Bool? = nil
    ) {
        self.now = now
        self.calendar = calendar
        self.stepsToday = stepsToday
        self.stepsGoal = stepsGoal
        self.steps7DayAverage = steps7DayAverage

        self.activeEnergyTodayKcal = activeEnergyTodayKcal
        self.activeEnergy30DayAverageKcal = activeEnergy30DayAverageKcal
        self.activeEnergy7DayAverageKcal = activeEnergy7DayAverageKcal

        self.distanceTodayKm = distanceTodayKm
        self.distance7DayAverageKm = distance7DayAverageKm
        self.exerciseMinutesToday = exerciseMinutesToday
        self.exerciseMinutes7DayAverage = exerciseMinutes7DayAverage
        self.sleepMinutesToday = sleepMinutesToday
        self.activeMinutesTodayFromSplit = activeMinutesTodayFromSplit
        self.sedentaryMinutesToday = sedentaryMinutesToday
        self.lastWorkout = lastWorkout
        self.hasEarlyActivityBlockHint = hasEarlyActivityBlockHint
        self.hasLateActivityBlockHint = hasLateActivityBlockHint
        self.hasWorkoutContextHint = hasWorkoutContextHint
    }
}

struct ActivityInsightDebugInfo {
    let windowStage: String
    let isPracticalDayClose: Bool
    let availability: String
    let stepsStatus: String?
    let energyStatus: String?
    let combinedPrimary: String
    let combinedBias: String
    let goalStatus: String?
    let achievementState: String
    let outputClass: String
    let confidence: String
    let suppressionReason: String?
    let appliedRules: [String]
}

struct ActivityInsightOutput {
    let primaryText: String
    let category: ActivityInsightCategory
    let debug: ActivityInsightDebugInfo?
}

// ============================================================
// MARK: - Public Engine
// ============================================================

struct ActivityInsightEngine {

    static func generateInsight(from input: ActivityInsightInput) -> ActivityInsightOutput {
        let signals = ActivityInsightEngineClassifierV1.classify(from: input)
        let decision = ActivityInsightEngineResolverV1.resolve(from: signals)

        return ActivityInsightOutput(
            primaryText: resolvePrimaryText(from: decision, input: input), // 🟨 UPDATED
            category: mapCategory(from: decision.outputClass),
            debug: ActivityInsightDebugInfo(
                windowStage: decision.windowStage.rawValue,
                isPracticalDayClose: decision.isPracticalDayClose,
                availability: decision.availabilityState.rawValue,
                stepsStatus: decision.stepsStatus?.rawValue,
                energyStatus: decision.energyStatus?.rawValue,
                combinedPrimary: decision.combinedPrimary.rawValue,
                combinedBias: decision.combinedBias.rawValue,
                goalStatus: decision.goalStatus?.rawValue,
                achievementState: decision.achievementState.rawValue,
                outputClass: decision.outputClass.rawValue,
                confidence: decision.confidence.rawValue,
                suppressionReason: decision.suppressionReason?.rawValue,
                appliedRules: decision.appliedRules.map(\.rawValue)
            )
        )
    }
}

// ============================================================
// MARK: - Output Mapping
// ============================================================

private extension ActivityInsightEngine {

    static func mapCategory(from outputClass: AIOutputClassV1) -> ActivityInsightCategory {
        switch outputClass {
        case .dualAchievement,
             .energyAchievement,
             .strongDualAchievement,
             .strongEnergyAchievement:
            return .energy

        case .stepAchievement,
             .strongStepAchievement,
             .positiveProgress:
            return .steps

        case .blocked, .noData, .insufficientData, .midZone, .lowActivity:
            return .neutral
        }
    }

    static func resolvePrimaryText(
        from decision: AIResolvedDecisionV1,
        input: ActivityInsightInput
    ) -> String {
        switch decision.outputClass {

        case .blocked:
            return L10n.ActivityOverview.insightBlocked

        case .noData:
            return L10n.ActivityOverview.insightNoData

        case .insufficientData:
            return L10n.ActivityOverview.insightInsufficientData

        case .strongDualAchievement:
            switch decision.windowStage {
            case .morning:
                return L10n.ActivityOverview.insightStrongDualAchievementMorning
            case .afternoon, .evening, .dayClosed:
                return L10n.ActivityOverview.insightStrongDualAchievementLater
            }

        case .strongStepAchievement:
            switch decision.windowStage {
            case .morning:
                return L10n.ActivityOverview.insightStrongStepAchievementMorning
            case .afternoon, .evening, .dayClosed:
                return L10n.ActivityOverview.insightStrongStepAchievementLater
            }

        case .strongEnergyAchievement:
            switch decision.windowStage {
            case .morning:
                return L10n.ActivityOverview.insightStrongEnergyAchievementMorning
            case .afternoon, .evening, .dayClosed:
                return L10n.ActivityOverview.insightStrongEnergyAchievementLater
            }

        case .dualAchievement:
            switch decision.windowStage {
            case .morning:
                return L10n.ActivityOverview.insightDualAchievementMorning
            case .afternoon, .evening, .dayClosed:
                return L10n.ActivityOverview.insightDualAchievementLater
            }

        case .stepAchievement:
            switch decision.windowStage {
            case .morning:
                return L10n.ActivityOverview.insightStepAchievementMorning
            case .afternoon, .evening, .dayClosed:
                return L10n.ActivityOverview.insightStepAchievementLater
            }

        case .energyAchievement:
            switch decision.windowStage {
            case .morning:
                return L10n.ActivityOverview.insightEnergyAchievementMorning
            case .afternoon, .evening, .dayClosed:
                return L10n.ActivityOverview.insightEnergyAchievementLater
            }

        case .positiveProgress:
            switch decision.windowStage {
            case .morning:
                return L10n.ActivityOverview.insightPositiveProgressMorning
            case .afternoon:
                return L10n.ActivityOverview.insightPositiveProgressAfternoon
            case .evening, .dayClosed:
                return L10n.ActivityOverview.insightPositiveProgressEvening
            }

        case .midZone:
            if let workoutContextText = workoutContextOverrideText(for: decision, input: input) { // 🟨 UPDATED
                return workoutContextText
            }

            switch decision.windowStage {
            case .morning:
                return L10n.ActivityOverview.insightMidZoneMorning
            case .afternoon:
                return L10n.ActivityOverview.insightMidZoneAfternoon
            case .evening, .dayClosed:
                return L10n.ActivityOverview.insightMidZoneEvening
            }

        case .lowActivity:
            if let workoutContextText = workoutContextOverrideText(for: decision, input: input) { // 🟨 UPDATED
                return workoutContextText
            }

            switch decision.windowStage {
            case .morning:
                return L10n.ActivityOverview.insightLowActivityMorning
            case .afternoon:
                return L10n.ActivityOverview.insightLowActivityAfternoon
            case .evening, .dayClosed:
                return L10n.ActivityOverview.insightLowActivityEvening
            }
        }
    }
}

// ============================================================
// MARK: - Workout Context Modulation
// ============================================================

private extension ActivityInsightEngine {

    static func workoutContextOverrideText(
        for decision: AIResolvedDecisionV1,
        input: ActivityInsightInput
    ) -> String? {
        guard hasWorkoutContext(input) else { return nil }
        guard decision.outputClass == .midZone || decision.outputClass == .lowActivity else { return nil }

        switch decision.windowStage {
        case .morning:
            return "Today already includes a recorded workout and shows early structured activity."

        case .afternoon:
            return "Today already includes a recorded workout and shows structured activity so far."

        case .evening, .dayClosed:
            return nil
        }
    }

    static func hasWorkoutContext(_ input: ActivityInsightInput) -> Bool {
        if input.hasWorkoutContextHint == true {
            return true
        }

        guard let lastWorkout = input.lastWorkout else { return false }
        guard lastWorkout.minutes > 0 else { return false }
        guard lastWorkout.startDate <= input.now else { return false }

        let calendar = input.calendar
        return calendar.isDate(lastWorkout.startDate, inSameDayAs: input.now)
    }
}
