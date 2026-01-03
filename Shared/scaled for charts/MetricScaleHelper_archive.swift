//
//  MetricScaleHelper.swift
//  GluVibProbe
//
//  Zentrale, generische Skalierungslogik für die neuen *scaled* Charts.
//
//  Verwendet von:
//  - Nutrition (Carbs, Protein, Fat, Nutrition Energy)
//  - Activity (Steps, Activity Energy, Exercise Minutes)
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
        case energyDaily
        case energyMonthly
        case grams
        case steps
        case weightKg
        case sleepMinutes
        case heartRateBpm
        case exerciseMinutes

        case bmiTenths            // !!! NEW: BMI als "tenths" (×10) im Chart (26,4 -> 264), Labels rechnen zurück
    }

    // MARK: - Zentrale Factory

    static func scale(
        _ values: [Double],
        for type: MetricScaleType
    ) -> MetricScaleResult {

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

        case .heartRateBpm:
            return heartRateScale(values: cleaned)

        case .exerciseMinutes:
            return exerciseMinutesScale(values: cleaned)

        case .bmiTenths:                                             // !!! NEW
            return bmiTenthsScale(values: cleaned)                    // !!! NEW
        }
    }

    // MARK: - Profile

    private static func energyDailyScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [0, 500, 1000, 1500, 2000]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 2000,
                valueLabel: { v in "\(Int(v.rounded()))" }
            )
        }

        let step: Double
        switch maxValue {
        case 0...4000: step = 250
        case 4001...8000: step = 500
        case 8001...20000: step = 1000
        default: step = 2000
        }

        let upper = ceil(maxValue / step) * step
        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded()))" }
        )
    }

    private static func energyMonthlyScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [0, 5000, 10000, 15000]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 15000,
                valueLabel: { v in "\(Int(v.rounded()))" }
            )
        }

        let step: Double
        switch maxValue {
        case 0...5000: step = 500
        case 5001...20000: step = 1000
        default: step = 2500
        }

        let upper = ceil(maxValue / step) * step
        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded()))" }
        )
    }

    private static func gramsScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
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
            step  = 25
        case 100..<200:
            upper = 200
            step  = 50
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

    private static func stepsScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [0, 2000, 4000, 6000, 8000, 10000]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 10000,
                valueLabel: { v in
                    if v >= 1000 { return "\(Int(v / 1000))T" }
                    return "\(Int(v.rounded()))"
                }
            )
        }

        let step: Double
        switch maxValue {
        case 0..<4000: step = 500
        case 4000..<10000: step = 1000
        case 10000..<20000: step = 2000
        default: step = 5000
        }

        let upper = ceil(maxValue / step) * step
        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in
                if v >= 1000 { return "\(Int(v / 1000))T" }
                return "\(Int(v.rounded()))"
            }
        )
    }

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
        case 0..<80: step = 10
        case 80..<160: step = 20
        case 160..<240: step = 20
        default: step = 50
        }

        let upper = ceil(maxValue / step) * step
        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded()))" }
        )
    }

    // !!! NEW: BMI – Werte sind "tenths" (×10), Labels zeigen 1 Dezimalstelle (÷10)
    private static func bmiTenthsScale(values: [Double]) -> MetricScaleResult {       // !!! NEW
        let formatter: (Double) -> String = { raw in                                  // !!! NEW
            let bmi = raw / 10.0                                                      // !!! NEW
            let f = NumberFormatter()                                                 // !!! NEW
            f.numberStyle = .decimal                                                  // !!! NEW
            f.minimumFractionDigits = 1                                               // !!! NEW
            f.maximumFractionDigits = 1                                               // !!! NEW
            return f.string(from: NSNumber(value: bmi)) ?? String(format: "%.1f", bmi)// !!! NEW
        }

        guard let maxValue = values.max(), maxValue > 0 else {                        // !!! NEW
            let ticks: [Double] = [180, 220, 260, 300, 340]                           // !!! NEW (18,0 .. 34,0)
            return MetricScaleResult(                                                 // !!! NEW
                yAxisTicks: ticks,                                                    // !!! NEW
                yMax: 350,                                                            // !!! NEW
                valueLabel: formatter                                                 // !!! NEW
            )
        }

        let step: Double                                                             // !!! NEW
        switch maxValue {
        case 0..<250: step = 5        // 0,5 BMI
        case 250..<400: step = 10     // 1,0 BMI
        default: step = 20            // 2,0 BMI
        }

        let upper = ceil(maxValue / step) * step                                     // !!! NEW
        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }           // !!! NEW

        return MetricScaleResult(                                                     // !!! NEW
            yAxisTicks: ticks,                                                        // !!! NEW
            yMax: upper,                                                              // !!! NEW
            valueLabel: formatter                                                     // !!! NEW
        )
    }

    private static func sleepScale(values: [Double]) -> MetricScaleResult {
        guard let maxMinutes = values.max(), maxMinutes > 0 else {
            let ticks: [Double] = [0, 240, 360, 480]
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
        case 0..<5: stepHours = 1
        case 5..<10: stepHours = 2
        default: stepHours = 3
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

    private static func heartRateScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [40, 60, 80, 100, 120]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 120,
                valueLabel: { v in "\(Int(v.rounded())) bpm" }
            )
        }

        let upper: Double
        let step: Double

        switch maxValue {
        case 0..<60:
            upper = 80
            step  = 10
        case 60..<100:
            upper = 100
            step  = 10
        case 100..<140:
            upper = 140
            step  = 10
        case 140..<200:
            upper = 200
            step  = 20
        default:
            step  = 20
            upper = ceil(maxValue / step) * step
        }

        let start = max(0, upper - 160)
        let ticks = stride(from: start, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded())) bpm" }
        )
    }

    private static func exerciseMinutesScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [0, 15, 30, 45, 60]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 60,
                valueLabel: { v in "\(Int(v.rounded()))" }
            )
        }

        let maxAbs = maxValue
        let upper: Double
        let step: Double

        switch maxAbs {
        case 0..<30:
            upper = 30
            step  = 5
        case 30..<60:
            upper = 60
            step  = 10
        case 60..<90:
            upper = 90
            step  = 15
        case 90..<150:
            upper = 150
            step  = 15
        default:
            step  = 30
            upper = ceil(maxAbs / step) * step
        }

        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded()))" }
        )
    }
}

// MARK: - Globaler Alias (für ältere Stellen)

typealias MetricScaleResult = MetricScaleHelper.MetricScaleResult
