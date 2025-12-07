//  HbA1cEntry.swift
//  GluVibProbe

import Foundation

struct HbA1cEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date
    var valuePercent: Double   // z.B. 6.5 (%)

    init(id: UUID = UUID(), date: Date, valuePercent: Double) {
        self.id = id
        self.date = date
        self.valuePercent = valuePercent
    }
}
