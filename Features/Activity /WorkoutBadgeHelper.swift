//
//  WorkoutBadgeHelper.swift
//  GluVibProbe
//

import Foundation
import HealthKit

struct WorkoutBadgeHelper {

    // MARK: - Public API

    static func symbolName(for activityType: HKWorkoutActivityType) -> String { // 🟨 UPDATED
        switch activityType {
        case .walking:
            return "figure.walk"

        case .running:
            return "figure.run"

        case .cycling:
            return "figure.outdoor.cycle"

        case .traditionalStrengthTraining:
            return "dumbbell"

        case .functionalStrengthTraining:
            return "figure.strengthtraining.traditional"

        case .highIntensityIntervalTraining:
            return "flame.fill"

        case .swimming:
            return "figure.pool.swim"

        case .rowing:
            return "figure.rower"

        case .hiking:
            return "figure.hiking"

        case .yoga:
            return "figure.yoga"

        case .pilates:
            return "figure.pilates"

        case .coreTraining:
            return "figure.core.training"

        case .elliptical:
            return "figure.elliptical"

        case .dance:
            return "figure.dance"

        case .martialArts:
            return "figure.kickboxing"

        default:
            return "figure.walk"
        }
    }

    static func symbolName(for rawName: String) -> String {
        let name = clean(rawName)

        if name.contains("walk")
            || name.contains("walking")
            || name.contains("brisk walk")
            || name.contains("power walk")
            || name.contains("outdoor walk")
            || name.contains("gehen")
            || name.contains("spazieren")
            || name.contains("walking pad") {
            return "figure.walk"
        }

        if name.contains("indoor run")
            || name.contains("treadmill")
            || name.contains("treadmill run")
            || name.contains("indoor jogging")
            || name.contains("laufband") {
            return "figure.run"
        }

        if name.contains("run")
            || name.contains("running")
            || name.contains("jogging")
            || name.contains("jog")
            || name.contains("road run")
            || name.contains("long run")
            || name.contains("outdoor run")
            || name.contains("laufen") {
            return "figure.run"
        }

        if name.contains("indoor cycling")
            || name.contains("indoor cycle")
            || name.contains("indoor bike")
            || name.contains("spin")
            || name.contains("spinning")
            || name.contains("bike trainer")
            || name.contains("indoor ride")
            || name.contains("turbo trainer")
            || name.contains("indoor cycling")
            || name.contains("spinningrad") {
            return "figure.indoor.cycle"
        }

        if name.contains("cycling")
            || name.contains("cycle")
            || name.contains("bike")
            || name.contains("biking")
            || name.contains("bike ride")
            || name.contains("road bike")
            || name.contains("outdoor ride")
            || name.contains("outdoor cycling")
            || name.contains("radfahren")
            || name.contains("fahrrad")
            || name.contains("radtour") {
            return "figure.outdoor.cycle"
        }

        if name.contains("strength")
            || name.contains("strength training")
            || name.contains("weight training")
            || name.contains("weights")
            || name.contains("resistance training")
            || name.contains("resistance")
            || name.contains("lifting")
            || name.contains("weightlifting")
            || name.contains("krafttraining")
            || name.contains("gewichtheben") {
            return "dumbbell"
        }

        if name.contains("functional training")
            || name.contains("functional")
            || name.contains("crossfit")
            || name.contains("bootcamp")
            || name.contains("wod")
            || name.contains("metabolic conditioning")
            || name.contains("bodyweight training")
            || name.contains("funktionelles training") {
            return "figure.strengthtraining.traditional"
        }

        if name.contains("hiit")
            || name.contains("high intensity")
            || name.contains("interval training")
            || name.contains("intervals")
            || name.contains("tabata")
            || name.contains("intervalltraining") {
            return "flame.fill"
        }

        if name.contains("swim")
            || name.contains("swimming")
            || name.contains("pool swim")
            || name.contains("open water")
            || name.contains("open water swim")
            || name.contains("laps")
            || name.contains("schwimmen") {
            return "figure.pool.swim"
        }

        if name.contains("row")
            || name.contains("rowing")
            || name.contains("rowing machine")
            || name.contains("erg")
            || name.contains("indoor row")
            || name.contains("rudern") {
            return "figure.rower"
        }

        if name.contains("hike")
            || name.contains("hiking")
            || name.contains("trail")
            || name.contains("trail hike")
            || name.contains("mountain hike")
            || name.contains("wandern") {
            return "figure.hiking"
        }

        if name.contains("yoga") {
            return "figure.yoga"
        }

        if name.contains("pilates") {
            return "figure.pilates"
        }

        if name.contains("core")
            || name.contains("core workout")
            || name.contains("core training")
            || name.contains("abs")
            || name.contains("rumpftraining")
            || name.contains("bauchtraining") {
            return "figure.core.training"
        }

        if name.contains("elliptical")
            || name.contains("cross trainer")
            || name.contains("elliptical machine")
            || name.contains("crosstrainer") {
            return "figure.elliptical"
        }

        if name.contains("dance")
            || name.contains("dancing")
            || name.contains("zumba")
            || name.contains("ballet")
            || name.contains("dance fitness")
            || name.contains("tanzen") {
            return "figure.dance"
        }

        if name.contains("martial arts")
            || name.contains("martial")
            || name.contains("karate")
            || name.contains("boxing")
            || name.contains("kickboxing")
            || name.contains("judo")
            || name.contains("taekwondo")
            || name.contains("mma")
            || name.contains("fight")
            || name.contains("kampfsport")
            || name.contains("boxen") {
            return "figure.kickboxing"
        }

        return "figure.walk"
    }

    // MARK: - Helper

    private static func clean(_ raw: String) -> String {
        let lowered = raw.lowercased()
        let lettersAndSpaces = lowered.filter { $0.isLetter || $0.isWhitespace }
        let squashed = lettersAndSpaces.replacingOccurrences(
            of: " +",
            with: " ",
            options: .regularExpression
        )
        return squashed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
