//
//  MetricScaleHelper.swift
//  GluVibProbe
//

import Foundation

struct MetricScaleHelper {

    struct MetricScaleResult {
        let yAxisTicks: [Double]
        let yMax: Double
        let valueLabel: (Double) -> String
    }

    // ============================================================
    // MARK: - MetricScaleType
    // ============================================================

    enum MetricScaleType {
        case energyDaily
        case energyMonthly

        case gramsDaily
        case gramsMonthly
        case grams

        case steps
        case weightKg
        case sleepMinutes
        case heartRateBpm
        case exerciseMinutes
        case moveMinutes

        case percentInt10

        case insulinUnitsDaily
        case ratioInt10

        case percent0to100

        case gmiPercent

        case minutes0to1440

        // Metabolic — base-unit only
        case glucoseMeanMgdl              // !!! NEW (IG / Mean Glucose in mg/dL)
        case glucoseSdMgdl                // SD in mg/dL (Base)
        case glucoseCvPercent             // CV in %
    }

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

        case .gramsDaily:
            return gramsDailyScale(values: cleaned)

        case .gramsMonthly:
            return gramsMonthlyScale(values: cleaned)

        case .grams:
            return gramsDailyScale(values: cleaned)

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

        case .moveMinutes:
            return moveMinutesScale(values: cleaned)

        case .percentInt10:
            return percentInt10Scale(values: cleaned)

        case .insulinUnitsDaily:
            return insulinUnitsDailyScale(values: cleaned)

        case .ratioInt10:
            return ratioInt10Scale(values: cleaned)

        case .percent0to100:
            return percent0to100Scale()

        case .gmiPercent:
            return gmiPercentScale(values: cleaned)

        case .minutes0to1440:
            return minutes0to1440Scale(values: cleaned)

        case .glucoseMeanMgdl:                                        // !!! NEW
            return glucoseMeanMgdlScale(values: cleaned)               // !!! NEW

        case .glucoseSdMgdl:
            return glucoseSdMgdlScale(values: cleaned)

        case .glucoseCvPercent:
            return glucoseCvPercentScale(values: cleaned)
        }
    }

    // ============================================================
    // MARK: - FIXED PERCENT 0...100 (TIR)
    // ============================================================

    private static func percent0to100Scale() -> MetricScaleResult {
        let ticks: [Double] = [0, 25, 50, 75, 100]
        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: 100,
            valueLabel: { v in "\(Int(v.rounded()))" }
        )
    }

    // ============================================================
    // MARK: - FIXED MINUTES 0...1440 (Range)
    // ============================================================

    private static func minutes0to1440Scale(values: [Double]) -> MetricScaleResult {
        let ticks: [Double] = [0, 360, 720, 1080, 1440]
        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: 1440,
            valueLabel: { v in "\(Int(v.rounded()))" }
        )
    }

    // ============================================================
    // MARK: - IG / Mean Glucose (mg/dL) — dynamic scale (Base Unit)
    // ============================================================

    private static func glucoseMeanMgdlScale(values: [Double]) -> MetricScaleResult {  // !!! NEW
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [0, 50, 100, 150, 200, 250, 300]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 300,
                valueLabel: { v in "\(Int(v.rounded()))" }
            )
        }

        let step: Double
        switch maxValue {
        case ..<120: step = 20
        case ..<200: step = 25
        case ..<300: step = 50
        default:     step = 75
        }

        let upper = max(ceil(maxValue / step) * step, 200)
        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded()))" }
        )
    }

    // ============================================================
    // MARK: - SD (mg/dL) — dynamic scale (Base Unit)
    // ============================================================

    private static func glucoseSdMgdlScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [0, 20, 40, 60, 80, 100, 120]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 120,
                valueLabel: { v in "\(Int(v.rounded()))" }
            )
        }

        let step: Double
        switch maxValue {
        case ..<30:  step = 5
        case ..<60:  step = 10
        case ..<100: step = 20
        default:     step = 30
        }

        let upper = ceil(maxValue / step) * step
        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded()))" }
        )
    }

    // ============================================================
    // MARK: - CV (%) — dynamic scale
    // ============================================================

    private static func glucoseCvPercentScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [0, 15, 30, 45, 60]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 60,
                valueLabel: { v in "\(Int(v.rounded()))" }
            )
        }

        let step: Double
        switch maxValue {
        case ..<20:   step = 5
        case ..<40:   step = 10
        case ..<60:   step = 15
        case ..<80:   step = 20
        default:      step = 25
        }

        let upper = max(ceil(maxValue / step) * step, 40)
        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded()))" }
        )
    }

    // ============================================================
    // MARK: - GMI (%) — dynamic 3...20-ish scale
    // ============================================================

    private static func gmiPercentScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [3, 6, 9, 12, 15, 18, 20]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 20,
                valueLabel: { v in String(format: "%.1f", v) }
            )
        }

        let minY: Double = 3

        let step: Double
        switch maxValue {
        case ..<8:   step = 1
        case ..<12:  step = 2
        case ..<16:  step = 2
        case ..<20:  step = 2.5
        default:     step = 5
        }

        let upperRaw = max(maxValue, minY + step * 2)
        let upper = max(ceil(upperRaw / step) * step, 20)

        let ticks = stride(from: minY, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in String(format: "%.1f", v) }
        )
    }

    // MARK: - Profile (unchanged)

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

    private static func gramsDailyScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [0, 50, 100]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 100,
                valueLabel: { v in "\(Int(v.rounded()))" }
            )
        }

        let upper: Double
        let step: Double

        switch maxValue {
        case 0..<100:  upper = 100; step = 25
        case 100..<200: upper = 200; step = 50
        case 200..<300: upper = 300; step = 50
        case 300..<400: upper = 400; step = 100
        case 400..<500: upper = 500; step = 100
        case 500..<700: upper = 700; step = 100
        case 700..<900: upper = 900; step = 150
        case 900..<1200: upper = 1200; step = 200
        default:
            step = 250
            upper = ceil(maxValue / step) * step
        }

        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded()))" }
        )
    }

    private static func gramsMonthlyScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [0, 250, 500, 750, 1000]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 1000,
                valueLabel: { v in "\(Int(v.rounded()))" }
            )
        }

        let step: Double
        switch maxValue {
        case 0..<500:   step = 50
        case 500..<1000: step = 100
        case 1000..<2000: step = 200
        default:        step = 500
        }

        let upper = ceil(maxValue / step) * step
        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded()))" }
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

    private static func sleepScale(values: [Double]) -> MetricScaleResult {
        guard let maxMinutes = values.max(), maxMinutes > 0 else {
            let ticks: [Double] = [0, 240, 360, 480]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 480,
                valueLabel: { v in
                    let hours = v / 60.0
                    return "\(Int(hours.rounded()))"
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
                return "\(Int(hours.rounded()))"
            }
        )
    }

    private static func heartRateScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [40, 60, 80, 100, 120]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 120,
                valueLabel: { v in "\(Int(v.rounded()))" }
            )
        }

        let upper: Double
        let step: Double

        switch maxValue {
        case 0..<60: upper = 80; step = 10
        case 60..<100: upper = 100; step = 10
        case 100..<140: upper = 140; step = 10
        case 140..<200: upper = 200; step = 20
        default:
            step = 20
            upper = ceil(maxValue / step) * step
        }

        let start = max(0, upper - 160)
        let ticks = stride(from: start, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded()))" }
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
        case 0..<30: upper = 30; step = 5
        case 30..<60: upper = 60; step = 10
        case 60..<90: upper = 90; step = 15
        case 90..<150: upper = 150; step = 15
        default:
            step = 30
            upper = ceil(maxAbs / step) * step
        }

        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded()))" }
        )
    }

    private static func moveMinutesScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [0, 60, 120, 180, 240]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 240,
                valueLabel: { v in "\(Int(v.rounded()))" }
            )
        }

        let maxAbs = maxValue
        let upper: Double
        let step: Double

        switch maxAbs {
        case 0..<120: upper = 120; step = 30
        case 120..<240: upper = 240; step = 60
        case 240..<360: upper = 360; step = 90
        default:
            step = 120
            upper = ceil(maxAbs / step) * step
        }

        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded()))" }
        )
    }

    private static func insulinUnitsDailyScale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [0, 5, 10, 15, 20]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 20,
                valueLabel: { v in "\(Int(v.rounded()))" }
            )
        }

        let step: Double
        switch maxValue {
        case 0..<10:   step = 1
        case 10..<20:  step = 2
        case 20..<40:  step = 5
        case 40..<80:  step = 10
        default:       step = 20
        }

        let upper = ceil(maxValue / step) * step
        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in "\(Int(v.rounded()))" }
        )
    }

    private static func ratioInt10Scale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [0, 5, 10, 15, 20]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 20,
                valueLabel: { v in String(format: "%.1f", v / 10.0) }
            )
        }

        let step: Double
        switch maxValue {
        case 0..<20:     step = 2
        case 20..<50:    step = 5
        case 50..<100:   step = 10
        case 100..<150:  step = 15
        case 150..<200:  step = 20
        default:         step = 25
        }

        let upper = ceil(maxValue / step) * step
        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in String(format: "%.1f", v / 10.0) }
        )
    }

    private static func percentInt10Scale(values: [Double]) -> MetricScaleResult {
        guard let maxValue = values.max(), maxValue > 0 else {
            let ticks: [Double] = [0, 50, 100, 150, 200, 250, 300]
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 300,
                valueLabel: { v in
                    let pct = v / 10.0
                    return String(format: "%.1f", pct)
                }
            )
        }

        let upper: Double
        let step: Double

        switch maxValue {
        case 0..<100:   upper = 100;  step = 10
        case 100..<200: upper = 200;  step = 20
        case 200..<300: upper = 300;  step = 25
        case 300..<400: upper = 400;  step = 50
        case 400..<500: upper = 500;  step = 50
        default:
            step = 50
            upper = ceil(maxValue / step) * step
        }

        let ticks = stride(from: 0.0, through: upper, by: step).map { $0 }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: { v in
                let pct = v / 10.0
                return String(format: "%.1f", pct)
            }
        )
    }
}

typealias MetricScaleResult = MetricScaleHelper.MetricScaleResult
