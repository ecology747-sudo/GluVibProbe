//
//  MetricScaleType.swift
//  GluVibProbe
//

import Foundation

/// Skalentyp für Achsen & Formatierung in den Charts.
///
/// Wird aktuell von den "alten" Charts (Last90DaysBarChart, AveragePeriodsBarChart,
/// MonthlyBarChart) und vom neuen MetricScaleHelper (Energy-Pilot) verwendet.
enum MetricScaleType {
    case steps              // große Werte (Tausender, Steps)
    case smallInteger       // Minuten, g, kleinere kcal-Bereiche
    case percent            // 0–100 %
    case hours              // Sleep: Minuten → Anzeige in Stunden
    case nutritionEnergyMonthly   // Monthly Nutrition Energy (kcal/kJ)
    case nutritionEnergyDaily     // Daily Nutrition Energy (kcal/kJ)
}
