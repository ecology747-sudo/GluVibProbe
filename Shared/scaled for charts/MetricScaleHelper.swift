//
//  MetricScaleHelper.swift
//  GluVibProbe
//
//  Zentrale, generische Skalierungslogik für die neuen *scaled* Charts.
//
//  Verwendet von:
//  - Nutrition (Carbs, Protein, Fat, Nutrition Energy)
//  - Activity (Steps, Activity Energy)
//  - Body (Weight, Sleep, Resting HR, BMI/Body Fat via generische Skalen)
//

import Foundation

struct MetricScaleHelper {

    // MARK: - Öffentlicher Ergebnistyp

    struct MetricScaleResult {
        let yAxisTicks: [Double]              // Werte für die Y-Achsen-Beschriftung
        let yMax: Double                      // Oberkante des Diagramms
        let valueLabel: (Double) -> String    // Formatter für Labels
    }

    // MARK: - Skalen-Typen für alle Domains

    enum MetricScaleType {
        case energyDaily        // Nutrition / Activity Energy – Tageswerte (kcal / kJ)
        case energyMonthly      // Nutrition / Activity Energy – Monatswerte
        case grams              // Carbs / Protein / Fat – Gramm
        case steps              // Steps
        case weightKg           // Weight (kg oder lbs, aber gleiche Skala)
        case sleepMinutes       // Sleep in Minuten (Achse zeigt Stunden)
        case heartRateBpm       // !!! NEW – Resting Heart Rate (bpm)
    }

    // MARK: - Zentrale Factory

    static func scale(
        _ values: [Double],
        for type: MetricScaleType
    ) -> MetricScaleResult {

        // Null / leere Daten abfangen → generische Defaults pro Typ
        let cleaned = values.filter { $0 > 0 }

        switch type {
        case .energyDaily:
            return energyDailyScale(values: cleaned)

        case .energyMonthly:
            return energyMonthlyScale(values: cleaned)

        case .grams:
            return gramsScale(values: cleaned)

        case .steps:
            return stepsScale(values: cleaned)

        case .weightKg:
            return weightScale(values: cleaned)

        case .sleepMinutes:
            return sleepScale(values: cleaned)

        case .heartRateBpm:                               // !!! NEW
            return heartRateScale(values: cleaned)        // !!! NEW
        }
    }

    // MARK: - Profile

    // Nutrition / Activity Energy – Tageswerte (kcal / kJ)
    private static func energyDailyScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            // Fallback – typischer Tagesbereich in kcal
            let ticks: [Double] = [0, 500, 1000, 1500, 2000]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 2000,
                valueLabel: { v in "\(Int(v.rounded()))" }
            )
        }

        let step: Double
        switch maxValue {
        case 0...4000:
            // normale kcal-Bereiche → feinere Skala
            step = 250
        case 4001...8000:
            // Übergangsbereich
            step = 500
        case 8001...20000:
            // typische kJ-Bereiche
            step = 1000
        default:
            step = 2000
        }

        let upper = ceil(maxValue / step) * step
        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded()))" }
        )
    }

    // Nutrition / Activity Energy – Monatswerte (Summen)
    private static func energyMonthlyScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            // Fallback – eher große Monatswerte
            let ticks: [Double] = [0, 5000, 10000, 15000]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 15000,
                valueLabel: { v in "\(Int(v.rounded()))" }
            )
        }

        let step: Double
        switch maxValue {
        case 0...5000:
            step = 500
        case 5001...20000:
            step = 1000
        default:
            step = 2500
        }

        let upper = ceil(maxValue / step) * step
        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded()))" }
        )
    }

    // Gramm-Profil – für Carbs / Protein / Fat
    private static func gramsScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            // Fallback – kleiner Bereich
            let ticks: [Double] = [0, 50, 100]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 100,
                valueLabel: { v in "\(Int(v.rounded())) g" }
            )
        }

        let maxAbs = maxValue
        let upper: Double
        let step: Double

        switch maxAbs {
        case 0..<100:
            upper = 100
            step  = 25      // 0, 25, 50, 75, 100
        case 100..<200:
            upper = 200
            step  = 50      // 0, 50, 100, 150, 200
        case 200..<300:
            upper = 300
            step  = 50
        case 300..<500:
            upper = 500
            step  = 100
        case 500..<800:
            upper = 800
            step  = 100
        case 800..<1200:
            upper = 1200
            step  = 200
        default:
            step  = 250
            upper = ceil(maxAbs / step) * step
        }

        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded())) g" }
        )
    }

    // Steps – für Activity Steps
    private static func stepsScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [0, 2000, 4000, 6000, 8000, 10000]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 10000,
                valueLabel: { v in
                    if v >= 1000 {
                        return "\(Int(v / 1000))T"
                    } else {
                        return "\(Int(v.rounded()))"
                    }
                }
            )
        }

        let step: Double
        switch maxValue {
        case 0..<4000:
            step = 500
        case 4000..<10000:
            step = 1000
        case 10000..<20000:
            step = 2000
        default:
            step = 5000
        }

        let upper = ceil(maxValue / step) * step
        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in
                if v >= 1000 {
                    return "\(Int(v / 1000))T"
                } else {
                    return "\(Int(v.rounded()))"
                }
            }
        )
    }

    // Weight – für Body Weight (kg / lbs)
    private static func weightScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [40, 60, 80, 100]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 100,
                valueLabel: { v in "\(Int(v.rounded()))" }
            )
        }

        let step: Double
        switch maxValue {
        case 0..<80:
            step = 10
        case 80..<160:
            step = 20
        case 160..<240:
            step = 20
        default:
            step = 50
        }

        let upper = ceil(maxValue / step) * step
        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded()))" }
        )
    }

    // Sleep – Werte in Minuten, Achse + Labels in Stunden
    private static func sleepScale(values: [Double]) -> MetricScaleResult {
        guard let maxMinutes = values.max(), maxMinutes > 0 else {
            let ticks: [Double] = [0, 240, 360, 480]   // 0, 4, 6, 8 h
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 480,
                valueLabel: { v in
                    let hours = v / 60.0
                    return String(format: "%.1f h", hours)
                }
            )
        }

        let maxHours = maxMinutes / 60.0

        let stepHours: Double
        switch maxHours {
        case 0..<5:
            stepHours = 1
        case 5..<10:
            stepHours = 2
        default:
            stepHours = 3
        }

        let upperHours = ceil(maxHours / stepHours) * stepHours
        let upperMinutes = upperHours * 60.0
        let stepMinutes = stepHours * 60.0

        let ticks = stride(from: 0.0, through: upperMinutes, by: stepMinutes).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upperMinutes,
            valueLabel: { v in
                let hours = v / 60.0
                return String(format: "%.1f h", hours)
            }
        )
    }

    // MARK: - NEW: Heart Rate – Resting HR (bpm)                    // !!! NEW

    /// Skala für Herzfrequenz in bpm.
    /// Typische Resting HR: ~40–100 bpm, aber robust auch für höhere Werte. // !!! NEW
    private static func heartRateScale(values: [Double]) -> MetricScaleResult { // !!! NEW
        guard let maxValue = values.max(), maxValue > 0 else {        // !!! NEW
            // Fallback – sinnvoller Bereich für Ruhepuls              // !!! NEW
            let ticks: [Double] = [40, 60, 80, 100, 120]              // !!! NEW
            return MetricScaleResult(                                 // !!! NEW
                yAxisTicks: ticks,                                    // !!! NEW
                yMax: 120,                                            // !!! NEW
                valueLabel: { v in "\(Int(v.rounded())) bpm" }        // !!! NEW
            )                                                         // !!! NEW
        }                                                             // !!! NEW

        let upper: Double                                             // !!! NEW
        let step: Double                                              // !!! NEW

        switch maxValue {                                             // !!! NEW
        case 0..<60:                                                  // sehr niedriger Bereich
            upper = 80                                                // !!! NEW
            step  = 10                                                // 40,50,60,70,80 // !!! NEW
        case 60..<100:                                                // typischer Ruhebereich
            upper = 100                                               // !!! NEW
            step  = 10                                                // 40,50,60,70,80,90,100 // !!! NEW
        case 100..<140:                                               // leicht erhöht
            upper = 140                                               // !!! NEW
            step  = 10                                                // !!! NEW
        case 140..<200:                                               // deutlich erhöht / Training
            upper = 200                                               // !!! NEW
            step  = 20                                                // 0,20,...,200 // !!! NEW
        default:                                                      // extreme Outlier
            step  = 20                                                // !!! NEW
            upper = ceil(maxValue / step) * step                      // !!! NEW
        }                                                             // !!! NEW

        let start = max(0, upper - 160)                               // Chart beginnt nicht zu tief // !!! NEW
        let ticks = stride(from: start, through: upper, by: step)     // !!! NEW
            .map { $0 }                                               // !!! NEW

        return MetricScaleResult(                                     // !!! NEW
            yAxisTicks: ticks,                                        // !!! NEW
            yMax: upper,                                              // !!! NEW
            valueLabel: { v in "\(Int(v.rounded())) bpm" }            // !!! NEW
        )                                                             // !!! NEW
    }                                                                 // !!! NEW
}

// MARK: - Globaler Alias (für ältere Stellen)

typealias MetricScaleResult = MetricScaleHelper.MetricScaleResult
