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
                defaultValue: "No stable activity insight is available yet.",
                comment: "Fallback insight text when no activity insight is available"
            )
        }

        // MARK: - Insight Engine Texts (NEW ENGINE)

        static var insightBlocked: String {
            String(
                localized: "overview.activity.insight.blocked",
                defaultValue: "No activity insight is available because activity data access is currently blocked.",
                comment: "Insight text when activity insight cannot be generated because access is blocked"
            )
        }

        static var insightNoData: String {
            String(
                localized: "overview.activity.insight.no_data",
                defaultValue: "No activity data is available for a stable activity insight.",
                comment: "Insight text when no activity data is available"
            )
        }

        static var insightInsufficientData: String {
            String(
                localized: "overview.activity.insight.insufficient_data",
                defaultValue: "There is not enough activity data yet for a stable activity insight.",
                comment: "Insight text when activity data is insufficient"
            )
        }

        static var insightStrongDualAchievementMorning: String {
            String(
                localized: "overview.activity.insight.strong_dual_achievement.morning",
                defaultValue: "You have already reached your activity goals for today and are clearly exceeding them.",
                comment: "Insight text for strong dual achievement in the morning"
            )
        }

        static var insightStrongDualAchievementLater: String {
            String(
                localized: "overview.activity.insight.strong_dual_achievement.later",
                defaultValue: "You have reached your activity goals for today and are clearly exceeding them.",
                comment: "Insight text for strong dual achievement later in the day"
            )
        }

        static var insightStrongStepAchievementMorning: String {
            String(
                localized: "overview.activity.insight.strong_step_achievement.morning",
                defaultValue: "You have already reached your step goal today and are clearly exceeding it.",
                comment: "Insight text for strong step achievement in the morning"
            )
        }

        static var insightStrongStepAchievementLater: String {
            String(
                localized: "overview.activity.insight.strong_step_achievement.later",
                defaultValue: "You have reached your step goal today and are clearly exceeding it.",
                comment: "Insight text for strong step achievement later in the day"
            )
        }

        static var insightStrongEnergyAchievementMorning: String {
            String(
                localized: "overview.activity.insight.strong_energy_achievement.morning",
                defaultValue: "You have already reached your active energy goal today and are clearly exceeding it.",
                comment: "Insight text for strong active energy achievement in the morning"
            )
        }

        static var insightStrongEnergyAchievementLater: String {
            String(
                localized: "overview.activity.insight.strong_energy_achievement.later",
                defaultValue: "You have reached your active energy goal today and are clearly exceeding it.",
                comment: "Insight text for strong active energy achievement later in the day"
            )
        }

        static var insightDualAchievementMorning: String {
            String(
                localized: "overview.activity.insight.dual_achievement.morning",
                defaultValue: "You have already reached your activity goals for today.",
                comment: "Insight text for dual achievement in the morning"
            )
        }

        static var insightDualAchievementLater: String {
            String(
                localized: "overview.activity.insight.dual_achievement.later",
                defaultValue: "You have reached your activity goals for today.",
                comment: "Insight text for dual achievement later in the day"
            )
        }

        static var insightStepAchievementMorning: String {
            String(
                localized: "overview.activity.insight.step_achievement.morning",
                defaultValue: "You have already reached your step goal today.",
                comment: "Insight text for step achievement in the morning"
            )
        }

        static var insightStepAchievementLater: String {
            String(
                localized: "overview.activity.insight.step_achievement.later",
                defaultValue: "You have reached your step goal today.",
                comment: "Insight text for step achievement later in the day"
            )
        }

        static var insightEnergyAchievementMorning: String {
            String(
                localized: "overview.activity.insight.energy_achievement.morning",
                defaultValue: "You have already reached your active energy goal for today.",
                comment: "Insight text for active energy achievement in the morning"
            )
        }

        static var insightEnergyAchievementLater: String {
            String(
                localized: "overview.activity.insight.energy_achievement.later",
                defaultValue: "You have reached your active energy goal for today.",
                comment: "Insight text for active energy achievement later in the day"
            )
        }

        static var insightPositiveProgressMorning: String {
            String(
                localized: "overview.activity.insight.positive_progress.morning",
                defaultValue: "Today already shows a positive activity progression.",
                comment: "Insight text for positive activity progress in the morning"
            )
        }

        static var insightPositiveProgressAfternoon: String {
            String(
                localized: "overview.activity.insight.positive_progress.afternoon",
                defaultValue: "Today is developing as a positively active day.",
                comment: "Insight text for positive activity progress in the afternoon"
            )
        }

        static var insightPositiveProgressEvening: String {
            String(
                localized: "overview.activity.insight.positive_progress.evening",
                defaultValue: "Today shows a clearly positive activity progression.",
                comment: "Insight text for positive activity progress in the evening or day close"
            )
        }

        static var insightMidZoneMorning: String {
            String(
                localized: "overview.activity.insight.mid_zone.morning",
                defaultValue: "Today is still developing, with no clearly positive or low activity signal yet.",
                comment: "Insight text for mid-zone activity in the morning"
            )
        }

        static var insightMidZoneAfternoon: String {
            String(
                localized: "overview.activity.insight.mid_zone.afternoon",
                defaultValue: "Today currently shows a moderate activity pattern without a clear overall direction.",
                comment: "Insight text for mid-zone activity in the afternoon"
            )
        }

        static var insightMidZoneEvening: String {
            String(
                localized: "overview.activity.insight.mid_zone.evening",
                defaultValue: "Today shows a moderate overall activity pattern.",
                comment: "Insight text for mid-zone activity in the evening or day close"
            )
        }

        static var insightLowActivityMorning: String {
            String(
                localized: "overview.activity.insight.low_activity.morning",
                defaultValue: "So far, activity remains limited, but the day is still open.",
                comment: "Insight text for low activity in the morning"
            )
        }

        static var insightLowActivityAfternoon: String {
            String(
                localized: "overview.activity.insight.low_activity.afternoon",
                defaultValue: "Today currently shows a rather low activity level.",
                comment: "Insight text for low activity in the afternoon"
            )
        }

        static var insightLowActivityEvening: String {
            String(
                localized: "overview.activity.insight.low_activity.evening",
                defaultValue: "Today shows a low overall activity level.",
                comment: "Insight text for low activity in the evening or day close"
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

        static var hintNoDataOrPermission: String {
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

        static var hintNoDataOrPermission: String {
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

        static var hintNoDataOrPermission: String {
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

        static var hintNoDataOrPermission: String {
            String(
                localized: "metric.movement_split.hint.no_data_or_permission",
                defaultValue: "No movement split data available. Please check Apple Health permissions and whether sleep or activity data have already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible movement split data is available because required permissions are missing and/or no readable sleep/activity history exists"
            )
        }

        static var hintNoToday: String {
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
