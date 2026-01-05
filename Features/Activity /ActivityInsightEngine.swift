//
//  ActivityInsightEngine.swift
//  GluVibProbe
//
//  Pure logic for the Activity Insight card on the Activity Overview.
//  TODAY ONLY.
//  Uses only already aggregated metrics from the ActivityOverviewViewModel.
//

import Foundation

// MARK: - Insight categories

enum ActivityInsightCategory: String {
    case neutral
    case steps
    case exercise
    case energy
    case sedentary
    case recovery
}

// MARK: - Last workout model

struct ActivityLastWorkoutInfo {
    let name: String
    let minutes: Int
    let distanceKm: Double?
    let energyKcal: Int?
    let startDate: Date
}

// MARK: - Input model for the engine (TODAY ONLY)

struct ActivityInsightInput {

    // Time context
    let now: Date
    let calendar: Calendar

    // Steps
    let stepsToday: Int
    let stepsGoal: Int?
    let steps7DayAverage: Int?

    // Distance (km)
    let distanceTodayKm: Double?
    let distance7DayAverageKm: Double?

    // Exercise / Active Minutes
    let exerciseMinutesToday: Int
    let exerciseMinutes7DayAverage: Int?

    // Active Energy
    let activeEnergyTodayKcal: Int
    let activeEnergy7DayAverageKcal: Int?

    // Movement Split
    let sleepMinutesToday: Int
    let activeMinutesTodayFromSplit: Int
    let sedentaryMinutesToday: Int

    // Last workout (optional)
    let lastWorkout: ActivityLastWorkoutInfo?

    init(
        now: Date = Date(),
        calendar: Calendar = .current,
        stepsToday: Int,
        stepsGoal: Int?,
        steps7DayAverage: Int?,
        distanceTodayKm: Double?,
        distance7DayAverageKm: Double?,
        exerciseMinutesToday: Int,
        exerciseMinutes7DayAverage: Int?,
        activeEnergyTodayKcal: Int,
        activeEnergy7DayAverageKcal: Int?,
        sleepMinutesToday: Int,
        activeMinutesTodayFromSplit: Int,
        sedentaryMinutesToday: Int,
        lastWorkout: ActivityLastWorkoutInfo?
    ) {
        self.now = now
        self.calendar = calendar
        self.stepsToday = stepsToday
        self.stepsGoal = stepsGoal
        self.steps7DayAverage = steps7DayAverage
        self.distanceTodayKm = distanceTodayKm
        self.distance7DayAverageKm = distance7DayAverageKm
        self.exerciseMinutesToday = exerciseMinutesToday
        self.exerciseMinutes7DayAverage = exerciseMinutes7DayAverage
        self.activeEnergyTodayKcal = activeEnergyTodayKcal
        self.activeEnergy7DayAverageKcal = activeEnergy7DayAverageKcal
        self.sleepMinutesToday = sleepMinutesToday
        self.activeMinutesTodayFromSplit = activeMinutesTodayFromSplit
        self.sedentaryMinutesToday = sedentaryMinutesToday
        self.lastWorkout = lastWorkout
    }
}

// MARK: - Output model

struct ActivityInsightOutput {
    let primaryText: String
    let category: ActivityInsightCategory
}

// MARK: - Internal day-time context (TODAY only)

private enum ActivityDayPart {
    case morning
    case afternoon
    case evening
}

private struct ActivityDayContext {
    let dayPart: ActivityDayPart
    let dayProgressFraction: Double   // 0.0 ... 1.0
    let minutesElapsed: Int           // 0 ... 1440
}

// MARK: - Engine (TODAY ONLY)

struct ActivityInsightEngine {

    static func generateInsight(from input: ActivityInsightInput) -> ActivityInsightOutput {

        let context = makeDayContext(now: input.now, calendar: input.calendar)

        // 1) Strong sedentary patterns (critical, but friendly tone)
        if let sedentary = sedentaryInsightIfNeeded(input: input, context: context) {
            return sedentary
        }

        // 2) Strong workout / high activity day
        if let strongWorkout = strongWorkoutInsightIfNeeded(input: input, context: context) {
            return strongWorkout
        }

        // 3) Solid everyday movement, low focused training
        if let everyday = everydayMovementInsightIfNeeded(input: input, context: context) {
            return everyday
        }

        // 4) Last workout was several days ago
        if let reminder = lastWorkoutReminderInsightIfNeeded(input: input, context: context) {
            return reminder
        }

        // 5) Early in the day, low activity so far (no judgment)
        if let early = earlyDayLowActivityInsightIfNeeded(input: input, context: context) {
            return early
        }

        // 6) Neutral fallback (TODAY wording, unchanged)
        return neutralInsightTodayOnly(input: input, context: context)
    }
}

// MARK: - Shared helpers

private extension ActivityInsightEngine {

    static func makeDayContext(now: Date, calendar: Calendar) -> ActivityDayContext {
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        let minutesSinceMidnight = max(0, min(hour * 60 + minute, 24 * 60))
        let fraction = Double(minutesSinceMidnight) / Double(24 * 60)

        let dayPart: ActivityDayPart
        switch fraction {
        case 0.0..<0.33:
            dayPart = .morning
        case 0.33..<0.66:
            dayPart = .afternoon
        default:
            dayPart = .evening
        }

        return ActivityDayContext(
            dayPart: dayPart,
            dayProgressFraction: fraction,
            minutesElapsed: minutesSinceMidnight
        )
    }

    static func safeRatio(_ value: Int, average: Int?) -> Double? {
        guard let avg = average, avg > 0 else { return nil }
        return Double(value) / Double(avg)
    }
}

// MARK: - Rule 1: Sedentary pattern (a lot of sitting)

private extension ActivityInsightEngine {

    static func sedentaryInsightIfNeeded(
        input: ActivityInsightInput,
        context: ActivityDayContext
    ) -> ActivityInsightOutput? {

        // No sedentary judgment early in the day
        guard context.dayPart != .morning else { return nil }
        guard context.minutesElapsed >= 6 * 60 else { return nil } // only after 6 hours of the day

        let minutesElapsed = max(context.minutesElapsed, 1)
        let sedentaryShare = Double(input.sedentaryMinutesToday) / Double(minutesElapsed)

        // High sedentary share if ≥ 70 % of elapsed time
        guard sedentaryShare >= 0.7 else { return nil }

        // Additional checks: few steps & little exercise
        let stepsRatio = safeRatio(input.stepsToday, average: input.steps7DayAverage) ?? 0.0
        let exerciseRatio = safeRatio(input.exerciseMinutesToday, average: input.exerciseMinutes7DayAverage) ?? 0.0

        let fewSteps = input.stepsToday < 5000 && stepsRatio < 0.7
        let littleExercise = input.exerciseMinutesToday < 20 && exerciseRatio < 0.7

        guard fewSteps && littleExercise else { return nil }

        switch context.dayPart {
        case .afternoon:
            return ActivityInsightOutput(
                primaryText: "So far your day has been quite sedentary: many inactive minutes and not much movement yet. Short standing or walking breaks this afternoon can help you align your activity level with your recent days.",
                category: .sedentary
            )
        case .evening:
            return ActivityInsightOutput(
                primaryText: "Today has been mostly sedentary and you are below your usual range for steps and exercise minutes. If it fits your schedule, a short walk or light workout can nicely round off the day.",
                category: .sedentary
            )
        case .morning:
            return nil
        }
    }
}

// MARK: - Rule 2: Strong workout / high activity day

private extension ActivityInsightEngine {

    static func strongWorkoutInsightIfNeeded(
        input: ActivityInsightInput,
        context: ActivityDayContext
    ) -> ActivityInsightOutput? {

        let stepsRatio = safeRatio(input.stepsToday, average: input.steps7DayAverage) ?? 0.0
        let exerciseRatio = safeRatio(input.exerciseMinutesToday, average: input.exerciseMinutes7DayAverage) ?? 0.0
        let energyRatio = safeRatio(input.activeEnergyTodayKcal, average: input.activeEnergy7DayAverageKcal) ?? 0.0

        let highSteps = stepsRatio >= 1.3 && input.stepsToday >= 8000
        let highExercise = exerciseRatio >= 1.3 && input.exerciseMinutesToday >= 30
        let highEnergy = energyRatio >= 1.3 && input.activeEnergyTodayKcal >= 300

        guard highSteps || highExercise || highEnergy else { return nil }

        return ActivityInsightOutput(
            primaryText: "You are clearly above your 7-day average in activity and energy expenditure today. Strong movement day – make sure to plan enough rest and recovery later on.",
            category: .exercise
        )
    }
}

// MARK: - Rule 3: Solid everyday movement, little focused training

private extension ActivityInsightEngine {

    static func everydayMovementInsightIfNeeded(
        input: ActivityInsightInput,
        context: ActivityDayContext
    ) -> ActivityInsightOutput? {

        // Only meaningful once the day has progressed a bit
        guard context.dayPart != .morning else { return nil }
        guard context.minutesElapsed >= 6 * 60 else { return nil }

        let stepsRatio = safeRatio(input.stepsToday, average: input.steps7DayAverage) ?? 0.0
        let nearOrAboveStepsAvg = stepsRatio >= 0.9

        // Low exercise compared to recent average
        let exerciseRatio = safeRatio(input.exerciseMinutesToday, average: input.exerciseMinutes7DayAverage) ?? 0.0
        let lowExerciseCompared = exerciseRatio < 0.7 || input.exerciseMinutesToday < 20

        guard nearOrAboveStepsAvg && lowExerciseCompared else { return nil }

        return ActivityInsightOutput(
            primaryText: "Your everyday movement is solid today and roughly in line with your usual level. There is still room for focused training – even a short workout would nicely complement this positive trend.",
            category: .steps
        )
    }
}

// MARK: - Rule 4: Last workout was several days ago

private extension ActivityInsightEngine {

    static func lastWorkoutReminderInsightIfNeeded(
        input: ActivityInsightInput,
        context: ActivityDayContext
    ) -> ActivityInsightOutput? {

        guard let lastWorkout = input.lastWorkout else { return nil }

        let daysSinceWorkout = daysBetween(
            calendar: input.calendar,
            from: lastWorkout.startDate,
            to: input.now
        )

        // Gentle reminder after 3+ days without a workout
        guard daysSinceWorkout >= 3 else { return nil }

        let text: String
        switch daysSinceWorkout {
        case 3:
            text = "Your last workout was about three days ago. If it fits your schedule, today or tomorrow would be a good moment to plan a new session."
        case 4...6:
            text = "Your last workout was a few days ago. A moderate training session can help you get back into your usual rhythm."
        default:
            text = "Your last workout was quite some time ago. Maybe you can plan a small restart in the next few days – even a short session sends a strong signal to your body."
        }

        return ActivityInsightOutput(
            primaryText: text,
            category: .recovery
        )
    }

    static func daysBetween(calendar: Calendar, from: Date, to: Date) -> Int {
        let startOfFrom = calendar.startOfDay(for: from)
        let startOfTo = calendar.startOfDay(for: to)
        let components = calendar.dateComponents([.day], from: startOfFrom, to: startOfTo)
        return components.day ?? 0
    }
}

// MARK: - Rule 5: Early in the day, low activity (no judgment)

private extension ActivityInsightEngine {

    static func earlyDayLowActivityInsightIfNeeded(
        input: ActivityInsightInput,
        context: ActivityDayContext
    ) -> ActivityInsightOutput? {

        guard context.dayPart == .morning else { return nil }

        // Only in the first ~25 % of the day
        guard context.dayProgressFraction <= 0.25 else { return nil }

        // Very little activity so far
        let veryLowSteps = input.stepsToday < 1000
        let veryLowExercise = input.exerciseMinutesToday == 0

        guard veryLowSteps && veryLowExercise else { return nil }

        return ActivityInsightOutput(
            primaryText: "The day has just started – there has not been much need for movement yet. Short activity bursts distributed over the day help you reach your usual level of steps and exercise minutes in a relaxed way.",
            category: .neutral
        )
    }
}

// MARK: - Rule 6: Neutral fallback (TODAY wording, unchanged)

private extension ActivityInsightEngine {

    static func neutralInsightTodayOnly(
        input: ActivityInsightInput,
        context: ActivityDayContext
    ) -> ActivityInsightOutput {

        let stepsRatio = safeRatio(input.stepsToday, average: input.steps7DayAverage) ?? 1.0
        let exerciseRatio = safeRatio(input.exerciseMinutesToday, average: input.exerciseMinutes7DayAverage) ?? 1.0
        let energyRatio = safeRatio(input.activeEnergyTodayKcal, average: input.activeEnergy7DayAverageKcal) ?? 1.0

        let closeToTypical =
            (0.8...1.2).contains(stepsRatio) &&
            (0.7...1.3).contains(exerciseRatio) &&
            (0.7...1.3).contains(energyRatio)

        if closeToTypical {
            return ActivityInsightOutput(
                primaryText: "Your activity today is currently close to your usual range over the last week. Keep your current pace or plan an extra session if it feels right.",
                category: .neutral
            )
        } else if stepsRatio < 0.8 || exerciseRatio < 0.7 {
            return ActivityInsightOutput(
                primaryText: "You are currently a bit below your typical activity level. A little extra activity later today can help you move closer to your 7-day average.",
                category: .neutral
            )
        } else {
            return ActivityInsightOutput(
                primaryText: "You are slightly more active today than on most recent days. Keep this good feeling and at the same time pay attention to sufficient recovery.",
                category: .neutral
            )
        }
    }
}
