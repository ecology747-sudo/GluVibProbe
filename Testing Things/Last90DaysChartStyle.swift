//
//  Last90DaysChartStyle.swift
//  GluVibProbe
//
//  Shared V2: Chart style + metric kind used by SectionCards.
//  - Only defines types (no logic)
//

import Foundation
import SwiftUI

enum Last90DaysChartStyle: Equatable {
    case bar
    case line
}

enum Last90DaysMetricKind: Equatable {
    case steps
    case exerciseMinutes
    case activeEnergyKcal
    case moveTimeMinutes
    case workoutMinutes

    // Body
    case weightKg
    case sleepMinutes
    case restingHeartRateBpm
    case bodyFatPercent
    case bmi
}

enum Last90DaysDeltaColor: Equatable {
    case green
    case red
    case neutral
}

extension Last90DaysDeltaColor {
    var color: Color {
        switch self {
        case .green: return .green
        case .red: return .red
        case .neutral: return Color.Glu.primaryBlue
        }
    }
}
