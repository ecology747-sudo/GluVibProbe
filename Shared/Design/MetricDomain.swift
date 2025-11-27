//
//  MetricDomain.swift
//  GluVibProbe
//

import SwiftUI

/// Fach-Domain für Metriken – steuert u.a. Farben.
/// Wird von SectionCards verwendet, um Charts & Chips
/// CI-konform zu färben.
enum MetricDomain {
    case bodyActivity    // Steps, Activity Energy, Weight, Sleep
    case nutrition       // Carbs, Protein, Fat, Calories
    case metabolic       // Glucose, Insulin, Time in Range
}

extension MetricDomain {

    /// Primäre Akzentfarbe für Charts (Balken etc.)
    var accentColor: Color {
        switch self {
        case .bodyActivity:
            // Steps / Activity → Orange
            return Color.Glu.activityOrange

        case .nutrition:
            // Nutrition → Primär-Blau
            return Color.Glu.primaryBlue

        case .metabolic:
            // Metabolik → Lime
            return Color.Glu.accentLime
        }
    }

    /// (Optional für später)
    /// Farbe für Chips, Badges, kleine Highlights
    var chipColor: Color {
        switch self {
        case .bodyActivity:
            return Color.Glu.activityOrange
        case .nutrition:
            return Color.Glu.primaryBlue
        case .metabolic:
            return Color.Glu.accentLime
        }
    }
}
