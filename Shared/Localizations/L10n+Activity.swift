//
//  L10n+Activity.swift
//  GluVib
//

import Foundation

extension L10n {

    enum ActivityOverview {

        // MARK: - Header

        static var title: String {
            String(
                localized: "overview.activity.title",
                defaultValue: "Activity Overview",
                comment: "Title of the activity overview screen"
            )
        }

        static var today: String {
            String(
                localized: "overview.activity.today",
                defaultValue: "TODAY",
                comment: "Header subtitle for today in activity overview"
            )
        }

        static var yesterday: String {
            String(
                localized: "overview.activity.yesterday",
                defaultValue: "YESTERDAY",
                comment: "Header subtitle for yesterday in activity overview"
            )
        }

        // MARK: - Score

        static var scoreLabel: String {
            String(
                localized: "overview.activity.score_label",
                defaultValue: "Activity score",
                comment: "Label above the activity score badge"
            )
        }

        // MARK: - Steps Card

        static var stepsTitle: String {
            String(
                localized: "overview.activity.steps.title",
                defaultValue: "Steps",
                comment: "Title of the steps card in activity overview"
            )
        }

        static var stepsRemaining: String {
            String(
                localized: "overview.activity.steps.remaining",
                defaultValue: "Remaining",
                comment: "Remaining steps label in activity overview steps card"
            )
        }

        static var stepsTarget: String {
            String(
                localized: "overview.activity.steps.target",
                defaultValue: "Target",
                comment: "Target label in activity overview steps card"
            )
        }

        static var distanceTitle: String {
            String(
                localized: "overview.activity.distance.title",
                defaultValue: "Distance",
                comment: "Title of the distance card in activity overview"
            )
        }

        static var average7d: String {
            String(
                localized: "overview.activity.distance.average_7d",
                defaultValue: "7-day avg",
                comment: "7-day average label in activity overview distance card"
            )
        }

        // MARK: - Movement Split Card

        static var movementSplitTitle: String {
            String(
                localized: "overview.activity.movement_split.title",
                defaultValue: "Movement split",
                comment: "Title of the movement split card in activity overview"
            )
        }

        static var movementLegendSleep: String {
            String(
                localized: "overview.activity.movement_split.legend.sleep",
                defaultValue: "Sleep",
                comment: "Sleep legend label in activity overview movement split card"
            )
        }

        static var movementLegendActive: String {
            String(
                localized: "overview.activity.movement_split.legend.active",
                defaultValue: "Active",
                comment: "Active legend label in activity overview movement split card"
            )
        }

        static var movementLegendNotActive: String {
            String(
                localized: "overview.activity.movement_split.legend.not_active",
                defaultValue: "Not Active",
                comment: "Not active legend label in activity overview movement split card"
            )
        }

        static var movementHintExerciseMinutes: String {
            String(
                localized: "overview.activity.movement_split.hint.exercise_minutes",
                defaultValue: "Active time based on Exercise Minutes",
                comment: "Hint in activity overview movement split card when active time is based on exercise minutes"
            )
        }

        static var movementHintWorkoutMinutes: String {
            String(
                localized: "overview.activity.movement_split.hint.workout_minutes",
                defaultValue: "Active time estimated from Workout Minutes",
                comment: "Hint in activity overview movement split card when active time is estimated from workout minutes"
            )
        }

        // MARK: - Workout + Active Energy Tiles

        static var workoutMinTitle: String {
            String(
                localized: "overview.activity.workout_tile.title",
                defaultValue: "Workout min",
                comment: "Title of the workout minutes tile in activity overview"
            )
        }

        static var activeEnergyTitle: String {
            String(
                localized: "overview.activity.active_energy_tile.title",
                defaultValue: "Active energy",
                comment: "Title of the active energy tile in activity overview"
            )
        }

        static var average7dShort: String {
            String(
                localized: "overview.activity.average_7d_short",
                defaultValue: "7d",
                comment: "Short 7-day average label in activity overview tiles"
            )
        }

        // MARK: - Last Exercise Card

        static var lastExerciseTitle: String {
            String(
                localized: "overview.activity.last_exercise.title",
                defaultValue: "Last exercise",
                comment: "Title of the last exercise card in activity overview"
            )
        }

        static var noWorkoutYet: String {
            String(
                localized: "overview.activity.last_exercise.empty",
                defaultValue: "No workout tracked yet",
                comment: "Empty state text when no workout has been tracked yet"
            )
        }

        // MARK: - Workout Types

        static var workoutTypeWalking: String {
            String(
                localized: "overview.activity.workout_type.walking",
                defaultValue: "Walking",
                comment: "Workout type label for walking"
            )
        }

        static var workoutTypeRunning: String {
            String(
                localized: "overview.activity.workout_type.running",
                defaultValue: "Running",
                comment: "Workout type label for running"
            )
        }

        static var workoutTypeCycling: String {
            String(
                localized: "overview.activity.workout_type.cycling",
                defaultValue: "Cycling",
                comment: "Workout type label for cycling"
            )
        }

        static var workoutTypeHIIT: String {
            String(
                localized: "overview.activity.workout_type.hiit",
                defaultValue: "HIIT",
                comment: "Workout type label for HIIT"
            )
        }

        static var workoutTypeFunctionalTraining: String {
            String(
                localized: "overview.activity.workout_type.functional_training",
                defaultValue: "Functional Training",
                comment: "Workout type label for functional training"
            )
        }

        static var workoutTypeStrengthTraining: String {
            String(
                localized: "overview.activity.workout_type.strength_training",
                defaultValue: "Strength Training",
                comment: "Workout type label for strength training"
            )
        }

        static var workoutTypeYoga: String {
            String(
                localized: "overview.activity.workout_type.yoga",
                defaultValue: "Yoga",
                comment: "Workout type label for yoga"
            )
        }

        static var workoutTypePilates: String {
            String(
                localized: "overview.activity.workout_type.pilates",
                defaultValue: "Pilates",
                comment: "Workout type label for pilates"
            )
        }

        static var workoutTypeCoreTraining: String {
            String(
                localized: "overview.activity.workout_type.core_training",
                defaultValue: "Core Training",
                comment: "Workout type label for core training"
            )
        }

        static var workoutTypeElliptical: String {
            String(
                localized: "overview.activity.workout_type.elliptical",
                defaultValue: "Elliptical",
                comment: "Workout type label for elliptical"
            )
        }

        static var workoutTypeSwimming: String {
            String(
                localized: "overview.activity.workout_type.swimming",
                defaultValue: "Swimming",
                comment: "Workout type label for swimming"
            )
        }

        static var workoutTypeRowing: String {
            String(
                localized: "overview.activity.workout_type.rowing",
                defaultValue: "Rowing",
                comment: "Workout type label for rowing"
            )
        }

        static var workoutTypeHiking: String {
            String(
                localized: "overview.activity.workout_type.hiking",
                defaultValue: "Hiking",
                comment: "Workout type label for hiking"
            )
        }

        static var workoutTypeDance: String {
            String(
                localized: "overview.activity.workout_type.dance",
                defaultValue: "Dance",
                comment: "Workout type label for dance"
            )
        }

        static var workoutTypeMartialArts: String {
            String(
                localized: "overview.activity.workout_type.martial_arts",
                defaultValue: "Martial Arts",
                comment: "Workout type label for martial arts"
            )
        }

        static var workoutTypeGeneric: String {
            String(
                localized: "overview.activity.workout_type.generic",
                defaultValue: "Workout",
                comment: "Generic fallback workout type label"
            )
        }

        // MARK: - Insight Card

        static var insightTitle: String {
            String(
                localized: "overview.activity.insight.title",
                defaultValue: "Activity insight",
                comment: "Title of the activity insight card"
            )
        }

        static var insightFallback: String {
            String(
                localized: "overview.activity.insight.fallback",
                defaultValue: "Not enough activity data is available yet. This insight will automatically adapt to your movement pattern as the day progresses.",
                comment: "Fallback insight text when not enough activity data is available"
            )
        }

        // MARK: - Insight Texts

        static var insightSedentaryAfternoon: String {
            String(
                localized: "overview.activity.insight.sedentary_afternoon",
                defaultValue: "So far your day has been quite sedentary: many inactive minutes and not much movement yet. Short standing or walking breaks this afternoon can help you align your activity level with your recent days.",
                comment: "Activity insight text for sedentary afternoon pattern"
            )
        }

        static var insightSedentaryEvening: String {
            String(
                localized: "overview.activity.insight.sedentary_evening",
                defaultValue: "Today has been mostly sedentary and you are below your usual range for steps and exercise minutes. If it fits your schedule, a short walk or light workout can nicely round off the day.",
                comment: "Activity insight text for sedentary evening pattern"
            )
        }

        static var insightStrongWorkout: String {
            String(
                localized: "overview.activity.insight.strong_workout",
                defaultValue: "You are clearly above your 7-day average in activity and energy expenditure today. Strong movement day – make sure to plan enough rest and recovery later on.",
                comment: "Activity insight text for a strong workout or high activity day"
            )
        }

        static var insightEverydayMovement: String {
            String(
                localized: "overview.activity.insight.everyday_movement",
                defaultValue: "Your everyday movement is solid today and roughly in line with your usual level. There is still room for focused training – even a short workout would nicely complement this positive trend.",
                comment: "Activity insight text for solid everyday movement with little focused training"
            )
        }

        static var insightLastWorkout3Days: String {
            String(
                localized: "overview.activity.insight.last_workout_3_days",
                defaultValue: "Your last workout was about three days ago. If it fits your schedule, today or tomorrow would be a good moment to plan a new session.",
                comment: "Activity insight text when last workout was about three days ago"
            )
        }

        static var insightLastWorkoutFewDays: String {
            String(
                localized: "overview.activity.insight.last_workout_few_days",
                defaultValue: "Your last workout was a few days ago. A moderate training session can help you get back into your usual rhythm.",
                comment: "Activity insight text when last workout was a few days ago"
            )
        }

        static var insightLastWorkoutLongAgo: String {
            String(
                localized: "overview.activity.insight.last_workout_long_ago",
                defaultValue: "Your last workout was quite some time ago. Maybe you can plan a small restart in the next few days – even a short session sends a strong signal to your body.",
                comment: "Activity insight text when last workout was quite some time ago"
            )
        }

        static var insightEarlyDayLowActivity: String {
            String(
                localized: "overview.activity.insight.early_day_low_activity",
                defaultValue: "The day has just started – there has not been much need for movement yet. Short activity bursts distributed over the day help you reach your usual level of steps and exercise minutes in a relaxed way.",
                comment: "Activity insight text for early day with low activity"
            )
        }

        static var insightNeutralTypical: String {
            String(
                localized: "overview.activity.insight.neutral_typical",
                defaultValue: "Your activity today is currently close to your usual range over the last week. Keep your current pace or plan an extra session if it feels right.",
                comment: "Neutral activity insight when today's activity is close to the recent average"
            )
        }

        static var insightNeutralBelowTypical: String {
            String(
                localized: "overview.activity.insight.neutral_below_typical",
                defaultValue: "You are currently a bit below your typical activity level. A little extra activity later today can help you move closer to your 7-day average.",
                comment: "Neutral activity insight when today's activity is below the recent average"
            )
        }

        static var insightNeutralAboveTypical: String {
            String(
                localized: "overview.activity.insight.neutral_above_typical",
                defaultValue: "You are slightly more active today than on most recent days. Keep this good feeling and at the same time pay attention to sufficient recovery.",
                comment: "Neutral activity insight when today's activity is above the recent average"
            )
        }
    }

    enum Steps {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.steps.title",
                defaultValue: "Steps",
                comment: "Metric title for steps"
            )
        }

        static var todayKPI: String {
            String(
                localized: "metric.steps.kpi.today",
                defaultValue: "Steps Today",
                comment: "KPI title for today's step count"
            )
        }

        static var monthlyTitle: String {
            String(
                localized: "metric.steps.monthly_title",
                defaultValue: "Steps / Month",
                comment: "Monthly chart title for steps"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String { // 🟨 UPDATED
            String(
                localized: "metric.steps.hint.no_data_or_permission",
                defaultValue: "No step data available. Please check Apple Health permissions and whether steps have already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible step data is available because permission is missing and/or no readable step history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.steps.hint.no_today",
                defaultValue: "No steps recorded today yet.",
                comment: "Hint shown when no steps are recorded today yet"
            )
        }
    }

    enum WorkoutMinutes {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.workout_minutes.title",
                defaultValue: "Workout Minutes",
                comment: "Metric title for workout minutes"
            )
        }

        static var todayKPI: String {
            String(
                localized: "metric.workout_minutes.kpi.today",
                defaultValue: "Workout Minutes Today",
                comment: "KPI title for today's workout minutes"
            )
        }

        static var monthlyTitle: String {
            String(
                localized: "metric.workout_minutes.monthly_title",
                defaultValue: "Workout Minutes / Month",
                comment: "Monthly chart title for workout minutes"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String { // 🟨 UPDATED
            String(
                localized: "metric.workout_minutes.hint.no_data_or_permission",
                defaultValue: "No workout minute data available. Please check Apple Health permissions and whether workout minutes have already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible workout minute data is available because permission is missing and/or no readable workout minute history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.workout_minutes.hint.no_today",
                defaultValue: "No workout minutes recorded today yet.",
                comment: "Hint shown when no workout minutes are recorded today yet"
            )
        }
    }

    enum ActivityEnergy {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.activity_energy.title",
                defaultValue: "Activity Energy",
                comment: "Metric title for activity energy"
            )
        }

        static var todayKPI: String {
            String(
                localized: "metric.activity_energy.kpi.today",
                defaultValue: "Active Energy Today",
                comment: "KPI title for today's active energy"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String { // 🟨 UPDATED
            String(
                localized: "metric.activity_energy.hint.no_data_or_permission",
                defaultValue: "No active energy data available. Please check Apple Health permissions and whether active energy has already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible active energy data is available because permission is missing and/or no readable active energy history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.activity_energy.hint.no_today",
                defaultValue: "No active energy recorded today yet.",
                comment: "Hint shown when no active energy is recorded today yet"
            )
        }
    }

    enum MovementSplit {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.movement_split.title",
                defaultValue: "Movement Split",
                comment: "Metric title for movement split"
            )
        }

        static var kpiToday: String {
            String(
                localized: "metric.movement_split.kpi.today",
                defaultValue: "Today",
                comment: "KPI title for movement split today section"
            )
        }

        static var sleepToday: String {
            String(
                localized: "metric.movement_split.kpi.sleep_today",
                defaultValue: "Sleep Today",
                comment: "KPI title for today's sleep minutes"
            )
        }

        static var activeToday: String {
            String(
                localized: "metric.movement_split.kpi.active_today",
                defaultValue: "Active Today",
                comment: "KPI title for today's active minutes"
            )
        }

        static var notActive: String {
            String(
                localized: "metric.movement_split.kpi.not_active",
                defaultValue: "Not Active",
                comment: "KPI title for today's inactive minutes"
            )
        }

        static var legendSleep: String {
            String(
                localized: "metric.movement_split.legend.sleep",
                defaultValue: "Sleep",
                comment: "Legend label for sleep in movement split chart"
            )
        }

        static var legendActive: String {
            String(
                localized: "metric.movement_split.legend.active",
                defaultValue: "Active",
                comment: "Legend label for active time in movement split chart"
            )
        }

        static var legendNotActive: String {
            String(
                localized: "metric.movement_split.legend.not_active",
                defaultValue: "Not Active",
                comment: "Legend label for inactive time in movement split chart"
            )
        }
        
        static var hintNoDataOrPermission: String { // 🟨 NEW
            String(
                localized: "metric.movement_split.hint.no_data_or_permission",
                defaultValue: "No movement split data available. Please check Apple Health permissions and whether sleep or activity data have already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible movement split data is available because required permissions are missing and/or no readable sleep/activity history exists"
            )
        }

        static var hintNoToday: String { // 🟨 NEW
            String(
                localized: "metric.movement_split.hint.no_today",
                defaultValue: "No movement split data recorded today yet.",
                comment: "Hint shown when no movement split data is available for today yet, but historical data exists"
            )
        }

        // MARK: - Hints

        static var hintExerciseMinutes: String {
            String(
                localized: "metric.movement_split.hint.exercise_minutes",
                defaultValue: "Active time based on Exercise Minutes",
                comment: "Hint shown when active time is based on exercise minutes"
            )
        }

        static var hintWorkoutMinutes: String {
            String(
                localized: "metric.movement_split.hint.workout_minutes",
                defaultValue: "Active time estimated from Workout Minutes",
                comment: "Hint shown when active time is estimated from workout minutes"
            )
        }
    }
}
