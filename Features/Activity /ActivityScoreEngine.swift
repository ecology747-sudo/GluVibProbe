//
//  ActivityScoreEngine.swift
//  GluVibProbe
//
//  Pure logic for the Activity score on the Activity Overview.
//  Uses only aggregated metrics from ActivityOverviewViewModel (no HealthKit).
//

import Foundation

// MARK: - Input model

/// Input for Activity score calculation
struct ActivityScoreInput {
    // Time context
    let now: Date
    let calendar: Calendar

    // Steps
    let stepsToday: Int
    let stepsGoal: Int
    let steps7DayAverage: Int

    // Exercise minutes
    let exerciseMinutesToday: Int
    let exerciseMinutes7DayAverage: Int

    // Active energy (kcal)
    let activeEnergyTodayKcal: Int
    let activeEnergy7DayAverageKcal: Int

    // Movement split (minutes since midnight)
    let sleepMinutesToday: Int
    let activeMinutesTodayFromSplit: Int
    let sedentaryMinutesToday: Int

    // Last workout (optional – for consistency / recency)
    let lastWorkout: ActivityLastWorkoutInfo?

    init(
        now: Date = Date(),
        calendar: Calendar = .current,
        stepsToday: Int,
        stepsGoal: Int,
        steps7DayAverage: Int,
        exerciseMinutesToday: Int,
        exerciseMinutes7DayAverage: Int,
        activeEnergyTodayKcal: Int,
        activeEnergy7DayAverageKcal: Int,
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

// MARK: - Engine

/// Activity score engine (0–100, higher = better activity pattern)
final class ActivityScoreEngine {

    // MARK: - Public API

    func makeScore(from input: ActivityScoreInput) -> Int {
        let stepsScore      = stepsScore(from: input)
        let exerciseScore   = exerciseScore(from: input)
        let energyScore     = energyScore(from: input)
        let sedentaryScore  = sedentaryScore(from: input)
        let recencyScore    = workoutRecencyScore(from: input)

        // Weighting: steps & exercise most important, then energy,
        // sedentary share and workout recency as stabilizers.
        let combined =
            stepsScore     * 0.30 +
            exerciseScore  * 0.25 +
            energyScore    * 0.20 +
            sedentaryScore * 0.15 +
            recencyScore   * 0.10

        return Int(combined.rounded())
    }

    // MARK: - Steps score (with time-of-day factor)

    /// Steps vs. goal, scaled by time-of-day.
    /// Being ABOVE the expected level is always treated as 100.
    private func stepsScore(from input: ActivityScoreInput) -> Double {
        guard input.stepsGoal > 0 else {
            // No goal defined → neutral
            return 60.0                                           // !!! UPDATED (leicht positiv)
        }

        let expected = expectedForTimeOfDay(
            goal: Double(input.stepsGoal),
            now: input.now,
            calendar: input.calendar
        )

        guard expected > 0 else {
            return 60.0                                           // !!! UPDATED
        }

        let ratio = Double(input.stepsToday) / expected

        // Being ahead of schedule should never be punished.
        if ratio >= 1.0 {                                         // !!! UPDATED
            return 100.0
        }

        // Only penalise if you are below the expected level.
        let diff = 1.0 - ratio                                    // !!! UPDATED (kein abs)
        let toleratedDiff: Double = 0.25
        let maxDiff: Double       = 0.80

        if diff <= toleratedDiff {
            return 100.0
        }

        let over = min(diff, maxDiff) - toleratedDiff
        let range = maxDiff - toleratedDiff
        let penaltyFraction = over / range
        let score = 100.0 * (1.0 - penaltyFraction)

        return max(0.0, min(100.0, score))
    }

    // MARK: - Exercise score (minutes vs. 7-day average + time-of-day)

    /// Exercise / active minutes compared to 7-day average and time-of-day.
    /// Being ABOVE the expected level is always treated as 100.
    private func exerciseScore(from input: ActivityScoreInput) -> Double {
        guard input.exerciseMinutes7DayAverage > 0 else {
            // No history yet → slightly positive neutral
            return 60.0                                           // !!! UPDATED
        }

        let expected = expectedForTimeOfDay(
            goal: Double(input.exerciseMinutes7DayAverage),
            now: input.now,
            calendar: input.calendar
        )

        guard expected > 0 else { return 60.0 }                   // !!! UPDATED

        let ratio = Double(input.exerciseMinutesToday) / expected

        // Stronger training than usual is good, never punished.
        if ratio >= 1.0 {                                         // !!! UPDATED
            return 100.0
        }

        // Only penalise if exercise is clearly below expectation.
        let diff = 1.0 - ratio                                    // !!! UPDATED
        // Exercise can be more "spiky" → slightly wider tolerance.
        let toleratedDiff: Double = 0.35
        let maxDiff: Double       = 1.0

        if diff <= toleratedDiff {
            return 100.0
        }

        let over = min(diff, maxDiff) - toleratedDiff
        let range = maxDiff - toleratedDiff
        let penaltyFraction = over / range
        let score = 100.0 * (1.0 - penaltyFraction)

        return max(0.0, min(100.0, score))
    }

    // MARK: - Energy score (kcal vs. 7-day average + time-of-day)

    /// Active energy vs. 7-day average, scaled by time-of-day.
    /// Being ABOVE the expected level is always treated as 100.
    private func energyScore(from input: ActivityScoreInput) -> Double {
        guard input.activeEnergy7DayAverageKcal > 0 else {
            return 60.0                                           // !!! UPDATED
        }

        let expected = expectedForTimeOfDay(
            goal: Double(input.activeEnergy7DayAverageKcal),
            now: input.now,
            calendar: input.calendar
        )

        guard expected > 0 else { return 60.0 }                   // !!! UPDATED

        let ratio = Double(input.activeEnergyTodayKcal) / expected

        // Higher energy expenditure than expected is good.
        if ratio >= 1.0 {                                         // !!! UPDATED
            return 100.0
        }

        // Only penalise if clearly below expected energy.
        let diff = 1.0 - ratio                                    // !!! UPDATED
        // ±30% below expected is okay, ≥ ~90% missing falls to 0.
        let toleratedDiff: Double = 0.30
        let maxDiff: Double       = 0.90

        if diff <= toleratedDiff {
            return 100.0
        }

        let over = min(diff, maxDiff) - toleratedDiff
        let range = maxDiff - toleratedDiff
        let penaltyFraction = over / range
        let score = 100.0 * (1.0 - penaltyFraction)

        return max(0.0, min(100.0, score))
    }

    // MARK: - Sedentary score (movement split)

    /// Penalizes very high sedentary share of elapsed time.
    private func sedentaryScore(from input: ActivityScoreInput) -> Double {
        let elapsed = max(
            input.sleepMinutesToday
            + input.activeMinutesTodayFromSplit
            + input.sedentaryMinutesToday,
            1
        )

        let sedentaryShare = Double(input.sedentaryMinutesToday) / Double(elapsed)

        // If we do not have much of the day yet, stay mild.
        // We approximate "elapsed fraction" as elapsed / 1440.
        let dayFraction = Double(elapsed) / 1440.0

        // Very early in the day → near neutral.
        if dayFraction < 0.25 {
            return 60.0
        }

        // Good: ≤ 50 % sedentary of elapsed time.
        if sedentaryShare <= 0.50 {
            return 100.0
        }

        // Moderate: 50–80 % sedentary → 100 → 50
        if sedentaryShare <= 0.80 {
            let over = sedentaryShare - 0.50
            let range = 0.30
            let penaltyFraction = over / range
            let score = 100.0 - 50.0 * penaltyFraction
            return max(50.0, min(100.0, score))
        }

        // Very high sedentary share → strong penalty but not zero
        return 40.0
    }

    // MARK: - Workout recency score

    /// Scores how recent the last workout was (more recent = higher score).
    private func workoutRecencyScore(from input: ActivityScoreInput) -> Double {
        guard let last = input.lastWorkout else {
            // No workout yet or unknown → slightly below neutral
            return 55.0
        }

        let days = daysBetween(
            calendar: input.calendar,
            from: last.startDate,
            to: input.now
        )

        switch days {
        case ..<0:
            // Future / invalid → neutral
            return 60.0
        case 0:
            return 100.0
        case 1:
            return 95.0
        case 2:
            return 90.0
        case 3:
            return 80.0
        case 4...6:
            return 65.0
        case 7...9:
            return 50.0
        case 10...14:
            return 45.0
        default:
            return 40.0
        }
    }

    // MARK: - Helpers (time-of-day & date diff)

    /// Time-of-day factor (similar to NutritionScoreEngine),
    /// applied to steps / exercise / energy "goals" for the day.
    private func expectedForTimeOfDay(
        goal: Double,
        now: Date,
        calendar: Calendar
    ) -> Double {
        let hour = calendar.component(.hour, from: now)

        let factor: Double

        switch hour {
        case ..<8:
            factor = 0.25   // early morning: very mild expectation
        case 8..<12:
            factor = 0.45   // late morning
        case 12..<16:
            factor = 0.60   // midday / early afternoon
        case 16..<20:
            factor = 0.75   // late afternoon / early evening
        case 20..<21:
            factor = 0.90   // transition to end-of-day
        default:
            factor = 1.0    // 21–23: full-day comparison
        }

        return goal * factor
    }

    private func daysBetween(
        calendar: Calendar,
        from: Date,
        to: Date
    ) -> Int {
        let startOfFrom = calendar.startOfDay(for: from)
        let startOfTo = calendar.startOfDay(for: to)
        let components = calendar.dateComponents([.day], from: startOfFrom, to: startOfTo)
        return components.day ?? 0
    }
}
