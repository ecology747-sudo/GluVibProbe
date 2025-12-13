//
//  WorkoutBadgeHelper.swift
//  GluVibProbe
//
//  !!! NEW / UPDATED – Hilfsdatei für robuste Erkennung von Workout-Typen
//  – Lowercasing
//  – Entfernen von Sonderzeichen
//  – Keyword-Matching (Outdoor/Indoor, Synonyme, typische App-Namen)
//  – Fallback „drop.fill“
//

import Foundation

struct WorkoutBadgeHelper {

    // MARK: - Public API
    // ----------------------------------------------------

    static func symbolName(for rawName: String) -> String {
        let name = clean(rawName)

        // MARK: Walking
        if name.contains("walk")
            || name.contains("walking")
            || name.contains("brisk walk")
            || name.contains("power walk")
            || name.contains("outdoor walk") {
            return "figure.walk"
        }

        // MARK: Indoor Run / Treadmill
        if name.contains("indoor run")
            || name.contains("treadmill")
            || name.contains("treadmill run")
            || name.contains("indoor jogging") {
            return "figure.run"
        }

        // MARK: Running (general)
        if name.contains("run")
            || name.contains("running")
            || name.contains("jogging")
            || name.contains("jog")
            || name.contains("road run")
            || name.contains("long run")
            || name.contains("outdoor run") {
            return "figure.run"
        }

        // MARK: Indoor Cycling / Spinning / Trainer                 // !!! UPDATED
        if name.contains("indoor cycling")
            || name.contains("indoor cycle")
            || name.contains("indoor bike")
            || name.contains("spin")
            || name.contains("spinning")
            || name.contains("bike trainer")
            || name.contains("indoor ride")
            || name.contains("turbo trainer") {

            return "figure.indoor.cycle"                            // !!! UPDATED: Indoor-Bike
        }

        // MARK: Cycling (general)                                   // !!! UPDATED
        if name.contains("cycling")
            || name.contains("cycle")
            || name.contains("bike")
            || name.contains("biking")
            || name.contains("bike ride")
            || name.contains("road bike")
            || name.contains("outdoor ride")
            || name.contains("outdoor cycling") {

            return "figure.outdoor.cycle"                           // !!! UPDATED: Rennrad/Fahrer
        }

        // MARK: Strength Training
        if name.contains("strength")
            || name.contains("strength training")
            || name.contains("weight training")
            || name.contains("weights")
            || name.contains("resistance training")
            || name.contains("resistance")
            || name.contains("lifting")
            || name.contains("weightlifting") {
            return "dumbbell"
        }

        // MARK: Functional Training / CrossFit
        if name.contains("functional training")
            || name.contains("functional")
            || name.contains("crossfit")
            || name.contains("bootcamp")
            || name.contains("wod")
            || name.contains("metabolic conditioning")
            || name.contains("bodyweight training") {
            return "figure.strengthtraining.traditional"
        }

        // MARK: HIIT
        if name.contains("hiit")
            || name.contains("high intensity")
            || name.contains("interval training")
            || name.contains("intervals")
            || name.contains("tabata") {
            return "flame.fill"
        }

        // MARK: Swimming
        if name.contains("swim")
            || name.contains("swimming")
            || name.contains("pool swim")
            || name.contains("open water")
            || name.contains("open water swim")
            || name.contains("laps") {
            return "figure.pool.swim"
        }

        // MARK: Rowing
        if name.contains("row")
            || name.contains("rowing")
            || name.contains("rowing machine")
            || name.contains("erg")
            || name.contains("indoor row") {
            return "figure.rower"
        }

        // MARK: Hiking
        if name.contains("hike")
            || name.contains("hiking")
            || name.contains("trail")
            || name.contains("trail hike")
            || name.contains("mountain hike") {
            return "figure.hiking"
        }

        // MARK: Yoga
        if name.contains("yoga")
            || name.contains("hatha yoga")
            || name.contains("vinyasa")
            || name.contains("power yoga") {
            return "figure.yoga"
        }

        // MARK: Pilates
        if name.contains("pilates")
            || name.contains("mat pilates")
            || name.contains("reformer pilates") {
            return "figure.pilates"
        }

        // MARK: Core Training
        if name.contains("core")
            || name.contains("core workout")
            || name.contains("core training")
            || name.contains("abs") {
            return "figure.core.training"
        }

        // MARK: Elliptical
        if name.contains("elliptical")
            || name.contains("cross trainer")
            || name.contains("elliptical machine") {
            return "figure.elliptical"
        }

        // MARK: Dance
        if name.contains("dance")
            || name.contains("dancing")
            || name.contains("zumba")
            || name.contains("ballet")
            || name.contains("dance fitness") {
            return "figure.dance"
        }

        // MARK: Martial Arts
        if name.contains("martial arts")
            || name.contains("martial")
            || name.contains("karate")
            || name.contains("boxing")
            || name.contains("kickboxing")
            || name.contains("judo")
            || name.contains("taekwondo")
            || name.contains("mma")
            || name.contains("fight") {
            return "figure.kickboxing"
        }

        // MARK: Fallback – Schweißtropfen
        return "drop.fill"
    }

    // MARK: - Helper: String Cleaning
    // ----------------------------------------------------

    /// Entfernt Sonderzeichen, macht lowercased, ersetzt doppelte Leerzeichen.
    private static func clean(_ raw: String) -> String {
        let lowered = raw.lowercased()
        let lettersAndSpaces = lowered.filter { $0.isLetter || $0.isWhitespace }
        let squashed = lettersAndSpaces.replacingOccurrences(of: " +",
                                                              with: " ",
                                                              options: .regularExpression)
        return squashed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
