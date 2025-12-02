//
//  MetricScaleType.swift
//  GluVibProbe
//

import Foundation

/// Skalentyp für Achsen & Formatierung in den Charts.
enum MetricScaleType {
    case steps          // große Werte (Tausender, Steps)
    case smallInteger   // Minuten, kcal, Gramm, Insulin etc.
    case percent        // 0–100 %
    case hours          // Sleep: Rohdaten in Minuten, Anzeige in Stunden
}
