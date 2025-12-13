//
//  DailyExerciseMinutesEntry.swift
//  GluVibProbe
//
//  Model für tägliche Exercise Minutes (Trainingsminuten)
//

import Foundation

struct DailyExerciseMinutesEntry: Identifiable {        // !!! NEW
    let id = UUID()                                     // !!! NEW
    let date: Date                                     // !!! NEW
    let minutes: Int                                   // !!! NEW
}

// Optionale Mock-Daten für Previews / Tests             // !!! NEW
extension DailyExerciseMinutesEntry {                    // !!! NEW
    static func mock(date: Date, minutes: Int) -> Self { // !!! NEW
        DailyExerciseMinutesEntry(date: date, minutes: minutes)
    }                                                   // !!! NEW
}
