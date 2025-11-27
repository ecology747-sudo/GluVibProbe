//
//  MetricScaleType.swift
//  GluVibProbe
//

import Foundation

enum MetricScaleType {
    case steps          // große Werte (Tausender)
    case smallInteger   // Minuten, kcal, Gramm, Insulin
    case percent        // 0–100 %
    case hours          // 🔥 NEU – Minuten → Stunde für Sleep
}
