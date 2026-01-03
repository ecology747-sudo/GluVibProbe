//
//  MetricDomain.swift
//  GluVibProbe
//

import SwiftUI

/// Fach-Domain für Metriken.
/// Steuert CI-Farben für:
/// - SectionCards
/// - Charts
/// - Chips
/// - KPI-Highlights
///
/// Die Domain entspricht dem fachlichen Bereich
/// der jeweiligen Metrik (z. B. Steps → Activity).
enum MetricDomain {

    /// 🔥 **ACTIVITY**
    /// Schritte, Aktivitätsenergie, Workouts, Training
    /// → Farbe: **Rot (GluBodyRed)**
    case activity

    /// 🟠 **BODY**
    /// Schlaf, Gewicht, Herzfrequenz, Körperdaten
    /// → Farbe: **Orange (GluActivityOrange)**
    case body

    /// 🟦 **NUTRITION**
    /// Carbs, Protein, Fat, Calories
    /// → Farbe: **Aqua/Blau**
    case nutrition

    /// 🟢 **METABOLIC**
    /// Glucose, Insulin, Time-in-Range
    /// → Farbe: **Lime**
    case metabolic
}

extension MetricDomain {

    /// Primäre CI-Farbe für Charts, Linien, Bars,
    /// KPI-Highlights, SectionFrames.
    var accentColor: Color {
        switch self {

        case .activity:
            // 🔥 Rot – symbolisiert Bewegung & Aktivität
            return Color.Glu.activityAccent

        case .body:
            // 🟠 Orange – warme Farbe für Körperdaten
            return Color.Glu.bodyAccent

        case .nutrition:
            // 🟦 Aqua – klar & frisch für Ernährung
            return Color.Glu.nutritionAccent

        case .metabolic:
            // 🟢 Lime – Glukose / Medizinische Werte
            return Color.Glu.metabolicAccent
        }
    }

    /// Farbe für Chips (Filter), Badges, kleine UI-Highlights.
    var chipColor: Color {
        switch self {

        case .activity:
            return Color.Glu.activityAccent

        case .body:
            return Color.Glu.bodyAccent

        case .nutrition:
            return Color.Glu.nutritionAccent

        case .metabolic:
            return Color.Glu.metabolicAccent
        }
    }
}
