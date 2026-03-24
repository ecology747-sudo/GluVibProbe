//
//  GluLog.swift
//  GluVibProbe
//
//  Central Unified Logging entry point
//

import Foundation
import OSLog

enum GluLog {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "GluVibProbe"

    static let app = Logger(subsystem: subsystem, category: "app.lifecycle")
    static let ui = Logger(subsystem: subsystem, category: "ui.lifecycle")
    static let routing = Logger(subsystem: subsystem, category: "routing")
    static let healthStore = Logger(subsystem: subsystem, category: "healthstore")
    static let bootstrap = Logger(subsystem: subsystem, category: "bootstrap")
    static let permissions = Logger(subsystem: subsystem, category: "permissions")

    static let steps = Logger(subsystem: subsystem, category: "metric.steps")
    static let carbs = Logger(subsystem: subsystem, category: "metric.carbs")
    static let sugar = Logger(subsystem: subsystem, category: "metric.sugar")
    static let weight = Logger(subsystem: subsystem, category: "metric.weight")
    static let cgm = Logger(subsystem: subsystem, category: "metric.cgm")
    static let insulin = Logger(subsystem: subsystem, category: "metric.insulin")
    static let range = Logger(subsystem: subsystem, category: "metric.range")
    static let activeEnergy = Logger(subsystem: subsystem, category: "metric.activeEnergy")
    static let workoutMinutes = Logger(subsystem: subsystem, category: "metric.workoutMinutes")
    static let movementSplit = Logger(subsystem: subsystem, category: "metric.movementSplit")
    static let bmi = Logger(subsystem: subsystem, category: "metric.bmi")
    static let bodyFat = Logger(subsystem: subsystem, category: "metric.bodyFat")
    static let sleep = Logger(subsystem: subsystem, category: "metric.sleep")
    static let restingHeartRate = Logger(subsystem: subsystem, category: "metric.restingHeartRate")
    static let nutritionEnergy = Logger(subsystem: subsystem, category: "metric.nutritionEnergy")
    static let protein = Logger(subsystem: subsystem, category: "metric.protein")
    static let fat = Logger(subsystem: subsystem, category: "metric.fat")
    static let restingEnergy = Logger(subsystem: subsystem, category: "metric.restingEnergy") // 🟨 UPDATED

    static let performance = Logger(subsystem: subsystem, category: "performance")
}
