//
//  L10n+History.swift
//  GluVibProbe
//

import Foundation

extension L10n {

    enum History {

        enum Glucose {

            static func rowTitle(unit: String) -> String {
                String(
                    localized: "history.glucose.row_title",
                    defaultValue: "Glucose (%@)",
                    comment: "Glucose row title in history cards including the selected glucose unit"
                )
                .replacingOccurrences(of: "%@", with: unit)
            }
        }

        enum Format {

            static func insulinValue(_ value: Double) -> String {
                String(
                    format: String(
                        localized: "format.insulin_value",
                        defaultValue: "%.1f U",
                        comment: "Formatted insulin value with localized unit abbreviation"
                    ),
                    value
                )
            }
        }

        enum Section {

            static var title: String {
                String(
                    localized: "history.section.title",
                    defaultValue: "History",
                    comment: "Header title for the history overview screen"
                )
            }

            static var today: String {
                String(
                    localized: "history.section.today",
                    defaultValue: "Today",
                    comment: "Section title for today's history events"
                )
            }

            static var yesterday: String {
                String(
                    localized: "history.section.yesterday",
                    defaultValue: "Yesterday",
                    comment: "Section title for yesterday's history events"
                )
            }
        }

        enum Picker {

            static var activity: String {
                String(
                    localized: "history.picker.activity",
                    defaultValue: "Activity",
                    comment: "History metric picker chip title for activity events"
                )
            }

            static var carbs: String {
                String(
                    localized: "history.picker.carbs",
                    defaultValue: "Carbs",
                    comment: "History metric picker chip title for carbohydrate events"
                )
            }

            static var weight: String {
                String(
                    localized: "history.picker.weight",
                    defaultValue: "Weight",
                    comment: "History metric picker chip title for weight events"
                )
            }

            static var bolus: String {
                String(
                    localized: "history.picker.bolus",
                    defaultValue: "Bolus",
                    comment: "History metric picker chip title for bolus events"
                )
            }

            static var basal: String {
                String(
                    localized: "history.picker.basal",
                    defaultValue: "Basal",
                    comment: "History metric picker chip title for basal events"
                )
            }

            static var cgm: String {
                String(
                    localized: "history.picker.cgm",
                    defaultValue: "CGM",
                    comment: "History metric picker chip title for CGM markers"
                )
            }
        }

        enum Event {

            static var weight: String {
                String(
                    localized: "history.event.weight",
                    defaultValue: "Weight",
                    comment: "History event title for body weight entries"
                )
            }

            static var carbs: String {
                String(
                    localized: "history.event.carbs",
                    defaultValue: "Carbs",
                    comment: "History event title for carbohydrate entries"
                )
            }

            static var bolus: String {
                String(
                    localized: "history.event.bolus",
                    defaultValue: "Bolus",
                    comment: "History event title for bolus insulin entries"
                )
            }

            static var basal: String {
                String(
                    localized: "history.event.basal",
                    defaultValue: "Basal",
                    comment: "History event title for basal insulin entries"
                )
            }

            static var cgmPending: String {
                String(
                    localized: "history.event.cgm_pending",
                    defaultValue: "CGM Data Pending",
                    comment: "Placeholder text shown when CGM data for a history event is expected but not yet available"
                )
            }

            static var noCGMData: String {
                String(
                    localized: "history.event.no_cgm_data",
                    defaultValue: "No CGM Data",
                    comment: "Placeholder text shown when no CGM data is available for a history event"
                )
            }
        }

        enum Workout {

            static var walking: String {
                String(
                    localized: "history.workout.walking",
                    defaultValue: "Walking",
                    comment: "Workout type label for walking workouts in history"
                )
            }

            static var running: String {
                String(
                    localized: "history.workout.running",
                    defaultValue: "Running",
                    comment: "Workout type label for running workouts in history"
                )
            }

            static var cycling: String {
                String(
                    localized: "history.workout.cycling",
                    defaultValue: "Cycling",
                    comment: "Workout type label for cycling workouts in history"
                )
            }

            static var hiit: String {
                String(
                    localized: "history.workout.hiit",
                    defaultValue: "HIIT",
                    comment: "Workout type label for high intensity interval training workouts in history"
                )
            }

            static var functionalTraining: String {
                String(
                    localized: "history.workout.functional_training",
                    defaultValue: "Functional Training",
                    comment: "Workout type label for functional strength training workouts in history"
                )
            }

            static var strengthTraining: String {
                String(
                    localized: "history.workout.strength_training",
                    defaultValue: "Strength Training",
                    comment: "Workout type label for traditional strength training workouts in history"
                )
            }

            static var yoga: String {
                String(
                    localized: "history.workout.yoga",
                    defaultValue: "Yoga",
                    comment: "Workout type label for yoga workouts in history"
                )
            }

            static var pilates: String {
                String(
                    localized: "history.workout.pilates",
                    defaultValue: "Pilates",
                    comment: "Workout type label for pilates workouts in history"
                )
            }

            static var coreTraining: String {
                String(
                    localized: "history.workout.core_training",
                    defaultValue: "Core Training",
                    comment: "Workout type label for core training workouts in history"
                )
            }

            static var elliptical: String {
                String(
                    localized: "history.workout.elliptical",
                    defaultValue: "Elliptical",
                    comment: "Workout type label for elliptical workouts in history"
                )
            }

            static var swimming: String {
                String(
                    localized: "history.workout.swimming",
                    defaultValue: "Swimming",
                    comment: "Workout type label for swimming workouts in history"
                )
            }

            static var rowing: String {
                String(
                    localized: "history.workout.rowing",
                    defaultValue: "Rowing",
                    comment: "Workout type label for rowing workouts in history"
                )
            }

            static var hiking: String {
                String(
                    localized: "history.workout.hiking",
                    defaultValue: "Hiking",
                    comment: "Workout type label for hiking workouts in history"
                )
            }

            static var dance: String {
                String(
                    localized: "history.workout.dance",
                    defaultValue: "Dance",
                    comment: "Workout type label for dance workouts in history"
                )
            }

            static var martialArts: String {
                String(
                    localized: "history.workout.martial_arts",
                    defaultValue: "Martial Arts",
                    comment: "Workout type label for martial arts workouts in history"
                )
            }

            static var `default`: String {
                String(
                    localized: "history.workout.default",
                    defaultValue: "Workout",
                    comment: "Default workout type label in history"
                )
            }
        }
    }
}
