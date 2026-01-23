//
//  MedianDailyGlucoseProfileChart.swift
//  GluVibProbe
//
//  Median Daily Glucose Profile (Report)
//  - Presentation-only chart for an already computed ReportGlucoseProfileV1
//

import SwiftUI
import Charts

struct MedianDailyGlucoseProfileChart: View {

    let profile: ReportGlucoseProfileV1
    let glucoseUnit: GlucoseUnit

    // ============================================================
    // MARK: - HARD CAP (nothing above 300)
    // ============================================================

    private var yCapDisplay: Double { displayValue(fromMgdl: 300) } // UPDATED

    private func clampToCap(_ v: Double, cap: Double) -> Double {   // UPDATED
        min(max(0, v), cap)
    }

    private func clampToCapOptional(_ v: Double?, cap: Double) -> Double? { // UPDATED
        guard let v, v.isFinite else { return nil }
        return clampToCap(v, cap: cap)
    }

    var body: some View {

        let cap = yCapDisplay // UPDATED

        let bands = buildSmoothedBands5Slots(capDisplay: cap) // UPDATED
        let median = bands.median.sorted { $0.minuteOfDay < $1.minuteOfDay }
        let p25p75 = bands.p25p75.sorted { $0.minuteOfDay < $1.minuteOfDay }
        let p05p95 = bands.p05p95.sorted { $0.minuteOfDay < $1.minuteOfDay }

        let blue = Color.Glu.primaryBlue
        let acidRed = Color("acidCGMRed")

        let targetMin = clampToCap(displayValue(fromMgdl: profile.targetMinMgdl), cap: cap) // UPDATED
        let targetMax = clampToCap(displayValue(fromMgdl: profile.targetMaxMgdl), cap: cap) // UPDATED

        let refLowRaw = displayValue(fromMgdl: profile.veryLowLimitMgdl)   // UPDATED
        let refHighRaw = displayValue(fromMgdl: profile.veryHighLimitMgdl) // UPDATED

        let refLow: Double? = (refLowRaw <= cap) ? refLowRaw : nil    // UPDATED
        let refHigh: Double? = (refHighRaw <= cap) ? refHighRaw : nil // UPDATED

        let yDomainRange: ClosedRange<Double> = 0.0...cap // UPDATED

        let y95 = clampToCapOptional(bands.lastAvailable(.p95), cap: cap) // UPDATED
        let y75 = clampToCapOptional(bands.lastAvailable(.p75), cap: cap) // UPDATED
        let y50 = clampToCapOptional(bands.lastAvailable(.p50), cap: cap) // UPDATED
        let y25 = clampToCapOptional(bands.lastAvailable(.p25), cap: cap) // UPDATED
        let y05 = clampToCapOptional(bands.lastAvailable(.p05), cap: cap) // UPDATED

        let rightAxisValues: [Double] = [y95, y75, y50, y25, y05].compactMap { $0 } // UPDATED

        Chart {

            // ============================================================
            // MARK: - Vertical Gridlines (BEHIND percentiles)
            // ============================================================

            drawVerticalGridlinesBehind() // UPDATED

            // ============================================================
            // MARK: - Percentile Bands
            // ============================================================

            drawZonedBand(points: p05p95, bandKeyBase: "p05p95", targetMin: targetMin, targetMax: targetMax, zone: .below, capDisplay: cap) // UPDATED
            drawZonedBand(points: p05p95, bandKeyBase: "p05p95", targetMin: targetMin, targetMax: targetMax, zone: .inTarget, capDisplay: cap) // UPDATED
            drawZonedBand(points: p05p95, bandKeyBase: "p05p95", targetMin: targetMin, targetMax: targetMax, zone: .above, capDisplay: cap) // UPDATED

            drawZonedBand(points: p25p75, bandKeyBase: "p25p75", targetMin: targetMin, targetMax: targetMax, zone: .below, capDisplay: cap) // UPDATED
            drawZonedBand(points: p25p75, bandKeyBase: "p25p75", targetMin: targetMin, targetMax: targetMax, zone: .inTarget, capDisplay: cap) // UPDATED
            drawZonedBand(points: p25p75, bandKeyBase: "p25p75", targetMin: targetMin, targetMax: targetMax, zone: .above, capDisplay: cap) // UPDATED

            // Keep “major” dividers (6/12/18) as before (they now sit above the bands)
            RuleMark(x: .value("6h", 360))
                .lineStyle(StrokeStyle(lineWidth: 1.0, lineCap: .butt))
                .foregroundStyle(blue.opacity(0.55))

            RuleMark(x: .value("12h", 720))
                .lineStyle(StrokeStyle(lineWidth: 1.0, lineCap: .butt))
                .foregroundStyle(blue.opacity(0.55))

            RuleMark(x: .value("18h", 1080))
                .lineStyle(StrokeStyle(lineWidth: 1.0, lineCap: .butt))
                .foregroundStyle(blue.opacity(0.55))

            if let refLow { // UPDATED: RuleMarks above cap are not drawn
                RuleMark(y: .value("Ref Low", refLow))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .butt))
                    .foregroundStyle(acidRed.opacity(0.55))
            }

            if let refHigh { // UPDATED: RuleMarks above cap are not drawn
                RuleMark(y: .value("Ref High", refHigh))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .butt))
                    .foregroundStyle(acidRed.opacity(0.55))
            }

            RuleMark(y: .value("Target Min", targetMin))
                .lineStyle(StrokeStyle(lineWidth: 3.0, lineCap: .round))
                .foregroundStyle(Color.green.opacity(0.90))

            RuleMark(y: .value("Target Max", targetMax))
                .lineStyle(StrokeStyle(lineWidth: 3.0, lineCap: .round))
                .foregroundStyle(Color.green.opacity(0.90))

            ForEach(median) { p in
                LineMark(
                    x: .value("Minute", p.minuteOfDay),
                    y: .value("Median", clampToCap(p.valueDisplay, cap: cap))
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Color.green.opacity(0.95))
            }
        }
        .chartForegroundStyleScale(profileStyleScale())
        .chartLegend(.hidden)
        .chartXScale(domain: 0...1440)
        .chartYScale(domain: yDomainRange)

        .chartXAxis {
            AxisMarks(
                position: .bottom,
                values: xAxisLabelMinutes()
            ) { value in

                // UPDATED: keep axis gridlines OFF (we draw our own behind-bands gridlines)
                AxisGridLine().foregroundStyle(Color.clear)
                AxisTick(length: 0)

                AxisValueLabel(anchor: .top) {
                    if let m = value.as(Int.self) {
                        Text(formatHourLabel(m))
                            .font(.system(size: 10, weight: .regular, design: .default)) // UPDATED
                            .foregroundStyle(Color.Glu.primaryBlue)
                            .monospacedDigit()
                            .frame(width: 34, alignment: .center) // UPDATED (more space for "06:00")
                    }
                }
            }
        }

        .chartYAxis {
            AxisMarks(
                position: .leading,
                values: leftAxisValues(
                    refLow: refLow,
                    refHigh: refHigh,
                    targetMin: targetMin,
                    targetMax: targetMax,
                    capDisplay: cap
                )
            ) { value in
                if let dv = value.as(Double.self) {

                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1.0, lineCap: .butt))
                        .foregroundStyle(blue.opacity(0.18))

                    AxisTick().foregroundStyle(Color.clear)

                    AxisValueLabel {
                        if let refLow, isNear(dv, refLow) {
                            Text(formatYAxisValue(dv))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(acidRed)
                        } else if let refHigh, isNear(dv, refHigh) {
                            Text(formatYAxisValue(dv))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(acidRed)
                        } else if isNear(dv, targetMin) {
                            Text(formatYAxisValue(dv))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                                .background(Capsule().fill(Color.green.opacity(0.95)))
                                .offset(y: -8)
                        } else if isNear(dv, targetMax) {
                            Text(formatYAxisValue(dv))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                                .background(Capsule().fill(Color.green.opacity(0.95)))
                        } else {
                            EmptyView()
                        }
                    }
                }
            }

            AxisMarks(position: .trailing, values: rightAxisValues) { value in
                if let dv = value.as(Double.self) {

                    AxisGridLine().foregroundStyle(Color.clear)
                    AxisTick().foregroundStyle(Color.clear)

                    AxisValueLabel {
                        let label =
                        isNearOptional(dv, y95) ? "95%" :
                        isNearOptional(dv, y75) ? "75%" :
                        isNearOptional(dv, y50) ? "50%" :
                        isNearOptional(dv, y25) ? "25%" :
                        isNearOptional(dv, y05) ? "5%"  : ""

                        if !label.isEmpty {
                            Text(label)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(blue)
                        }
                    }
                }
            }
        }

        .chartBackground { _ in
            Color.clear
        }

        .chartPlotStyle { plotArea in
            plotArea
                .padding(.bottom, 28)
        }
        .accessibilityLabel(Text("Median daily glucose profile"))
    }

    // ============================================================
    // MARK: - Vertical Gridlines (custom, behind)
    // ============================================================

    @ChartContentBuilder
    private func drawVerticalGridlinesBehind() -> some ChartContent { // UPDATED

        let minor = Color.Glu.primaryBlue.opacity(0.22)
        let minorDash = StrokeStyle(lineWidth: 1.0, lineCap: .butt, dash: [3, 4])

        // Minor gridlines every 3 hours (0..24), EXCLUDING the majors (6/12/18) to avoid double-lines.
        let minutes: [Int] = [0, 180, 540, 900, 1260, 1440]

        ForEach(minutes, id: \.self) { m in
            RuleMark(x: .value("grid", m))
                .lineStyle(minorDash)
                .foregroundStyle(minor)
        }
    }

    // ============================================================
    // MARK: - Zoned Band Drawing
    // ============================================================

    private enum Zone { case below, inTarget, above }

    @ChartContentBuilder
    private func drawZonedBand(
        points: [SmoothedBandPoint],
        bandKeyBase: String,
        targetMin: Double,
        targetMax: Double,
        zone: Zone,
        capDisplay: Double
    ) -> some ChartContent {

        ForEach(points) { p in
            let (lo, hi) = clampBandZone(
                low: p.low,
                high: p.high,
                targetMin: targetMin,
                targetMax: targetMax,
                zone: zone,
                capDisplay: capDisplay
            )
            if let lo, let hi, hi > lo {
                AreaMark(
                    x: .value("Minute", p.minuteOfDay),
                    yStart: .value("Low", lo),
                    yEnd: .value("High", hi)
                )
                .foregroundStyle(by: .value("Band", "\(bandKeyBase)_\(zoneKey(zone))"))
                .interpolationMethod(.catmullRom)
            }
        }
    }

    private func clampBandZone(
        low: Double,
        high: Double,
        targetMin: Double,
        targetMax: Double,
        zone: Zone,
        capDisplay: Double
    ) -> (Double?, Double?) {

        let lo0 = clampToCap(low, cap: capDisplay)
        let hi0 = clampToCap(high, cap: capDisplay)
        guard hi0 > lo0 else { return (nil, nil) }

        switch zone {
        case .below:
            let lo = lo0
            let hi = min(hi0, targetMin)
            return (hi > lo) ? (lo, hi) : (nil, nil)
        case .inTarget:
            let lo = max(lo0, targetMin)
            let hi = min(hi0, targetMax)
            return (hi > lo) ? (lo, hi) : (nil, nil)
        case .above:
            let lo = max(lo0, targetMax)
            let hi = hi0
            return (hi > lo) ? (lo, hi) : (nil, nil)
        }
    }

    private func zoneKey(_ zone: Zone) -> String {
        switch zone {
        case .below: return "below"
        case .inTarget: return "in"
        case .above: return "above"
        }
    }

    private func profileStyleScale() -> KeyValuePairs<String, Color> {
        [
            "p05p95_below": Color.gray.opacity(0.14),
            "p05p95_in": Color.green.opacity(0.18),
            "p05p95_above": Color.orange.opacity(0.16),

            "p25p75_below": Color.gray.opacity(0.24),
            "p25p75_in": Color.green.opacity(0.30),
            "p25p75_above": Color.orange.opacity(0.26)
        ]
    }

    // ============================================================
    // MARK: - Smoothed series (5-slot)
    // ============================================================

    private struct SmoothedLinePoint: Identifiable {
        let id = UUID()
        let slot: Int
        let minuteOfDay: Int
        let valueDisplay: Double
    }

    private struct SmoothedBandPoint: Identifiable {
        let id = UUID()
        let slot: Int
        let minuteOfDay: Int
        let low: Double
        let high: Double
    }

    private enum PercentileKey { case p05, p25, p50, p75, p95 }

    private struct SmoothedBandsResult {
        let median: [SmoothedLinePoint]
        let p25p75: [SmoothedBandPoint]
        let p05p95: [SmoothedBandPoint]
        let allValuesForDomain: [Double]

        let sm05: [Double?]
        let sm25: [Double?]
        let sm50: [Double?]
        let sm75: [Double?]
        let sm95: [Double?]

        func lastAvailable(_ key: PercentileKey) -> Double? {
            let arr: [Double?] = {
                switch key {
                case .p05: return sm05
                case .p25: return sm25
                case .p50: return sm50
                case .p75: return sm75
                case .p95: return sm95
                }
            }()
            for i in stride(from: min(95, arr.count - 1), through: 0, by: -1) {
                if let v = arr[i], v.isFinite { return v }
            }
            return nil
        }
    }

    private func buildSmoothedBands5Slots(capDisplay: Double) -> SmoothedBandsResult {

        var raw05: [Double?] = Array(repeating: nil, count: 96)
        var raw25: [Double?] = Array(repeating: nil, count: 96)
        var raw50: [Double?] = Array(repeating: nil, count: 96)
        var raw75: [Double?] = Array(repeating: nil, count: 96)
        var raw95: [Double?] = Array(repeating: nil, count: 96)

        for p in profile.points {
            let s = max(0, min(95, p.slot))
            if let v = p.p05 { raw05[s] = clampToCap(displayValue(fromMgdl: v), cap: capDisplay) }
            if let v = p.p25 { raw25[s] = clampToCap(displayValue(fromMgdl: v), cap: capDisplay) }
            if let v = p.p50 { raw50[s] = clampToCap(displayValue(fromMgdl: v), cap: capDisplay) }
            if let v = p.p75 { raw75[s] = clampToCap(displayValue(fromMgdl: v), cap: capDisplay) }
            if let v = p.p95 { raw95[s] = clampToCap(displayValue(fromMgdl: v), cap: capDisplay) }
        }

        let sm05 = smooth5Slots(values: raw05, minCount: 3)
        let sm25 = smooth5Slots(values: raw25, minCount: 3)
        let sm50 = smooth5Slots(values: raw50, minCount: 3)
        let sm75 = smooth5Slots(values: raw75, minCount: 3)
        let sm95 = smooth5Slots(values: raw95, minCount: 3)

        var medianOut: [SmoothedLinePoint] = []
        medianOut.reserveCapacity(96)
        for i in 0..<96 {
            guard let v = sm50[i] else { continue }
            medianOut.append(.init(slot: i, minuteOfDay: minuteOfDay(forSlot: i), valueDisplay: clampToCap(v, cap: capDisplay)))
        }

        var p25p75Out: [SmoothedBandPoint] = []
        p25p75Out.reserveCapacity(96)
        for i in 0..<96 {
            guard let lo = sm25[i], let hi = sm75[i] else { continue }
            let loC = clampToCap(lo, cap: capDisplay)
            let hiC = clampToCap(hi, cap: capDisplay)
            guard hiC > loC else { continue }
            p25p75Out.append(.init(slot: i, minuteOfDay: minuteOfDay(forSlot: i), low: loC, high: hiC))
        }

        var p05p95Out: [SmoothedBandPoint] = []
        p05p95Out.reserveCapacity(96)
        for i in 0..<96 {
            guard let lo = sm05[i], let hi = sm95[i] else { continue }
            let loC = clampToCap(lo, cap: capDisplay)
            let hiC = clampToCap(hi, cap: capDisplay)
            guard hiC > loC else { continue }
            p05p95Out.append(.init(slot: i, minuteOfDay: minuteOfDay(forSlot: i), low: loC, high: hiC))
        }

        var domainValues: [Double] = []
        domainValues.reserveCapacity(96 * 6)
        domainValues.append(contentsOf: medianOut.map(\.valueDisplay))
        domainValues.append(contentsOf: p25p75Out.flatMap { [$0.low, $0.high] })
        domainValues.append(contentsOf: p05p95Out.flatMap { [$0.low, $0.high] })
        domainValues.append(clampToCap(displayValue(fromMgdl: profile.targetMinMgdl), cap: capDisplay))
        domainValues.append(clampToCap(displayValue(fromMgdl: profile.targetMaxMgdl), cap: capDisplay))
        domainValues.append(clampToCap(displayValue(fromMgdl: profile.veryLowLimitMgdl), cap: capDisplay))
        domainValues.append(clampToCap(displayValue(fromMgdl: profile.veryHighLimitMgdl), cap: capDisplay))
        domainValues.append(capDisplay)

        return .init(
            median: medianOut,
            p25p75: p25p75Out,
            p05p95: p05p95Out,
            allValuesForDomain: domainValues,
            sm05: sm05, sm25: sm25, sm50: sm50, sm75: sm75, sm95: sm95
        )
    }

    private func smooth5Slots(values: [Double?], minCount: Int) -> [Double?] {
        let n = values.count
        guard n > 0 else { return [] }

        let radius = 2
        var out: [Double?] = Array(repeating: nil, count: n)

        for i in 0..<n {
            var sum: Double = 0
            var count: Int = 0

            for j in (i - radius)...(i + radius) {
                guard j >= 0, j < n else { continue }
                if let v = values[j] {
                    sum += v
                    count += 1
                }
            }

            out[i] = (count >= minCount) ? (sum / Double(count)) : nil
        }

        return out
    }

    // ============================================================
    // MARK: - Axes + Formatting
    // ============================================================

    private func minuteOfDay(forSlot slot: Int) -> Int {
        let s = max(0, min(95, slot))
        return s * 15
    }

    private func displayValue(fromMgdl mgdl: Double) -> Double {
        glucoseUnit.convertedValue(fromMgdl: mgdl)
    }

    private func xAxisLabelMinutes() -> [Int] { // UPDATED: show 0 on both sides (0 and 1440)
        [0, 180, 360, 540, 720, 900, 1080, 1260, 1440]
    }

    private func formatHourLabel(_ minute: Int) -> String { // UPDATED: "06:00" + both ends "00:00"
        let m = ((minute % 1440) + 1440) % 1440
        let hh = m / 60
        return String(format: "%02d:00", hh)
    }

    private func formatYAxisValue(_ valueDisplayUnit: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        if glucoseUnit == .mgdL {
            f.minimumFractionDigits = 0
            f.maximumFractionDigits = 0
        } else {
            f.minimumFractionDigits = 0
            f.maximumFractionDigits = 1
        }
        return f.string(from: NSNumber(value: valueDisplayUnit))
        ?? (glucoseUnit == .mmolL ? String(format: "%.1f", valueDisplayUnit) : String(format: "%.0f", valueDisplayUnit))
    }

    private func leftAxisValues(
        refLow: Double?,
        refHigh: Double?,
        targetMin: Double,
        targetMax: Double,
        capDisplay: Double
    ) -> [Double] {
        let top = capDisplay
        var base: [Double] = [0, top, targetMin, targetMax]
        if let refLow { base.append(refLow) }
        if let refHigh { base.append(refHigh) }
        return base
            .filter { $0 >= 0 && $0 <= capDisplay }
            .sorted()
    }

    private func isNear(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) < 0.0001
    }

    private func isNearOptional(_ a: Double, _ b: Double?) -> Bool {
        guard let b else { return false }
        return abs(a - b) < 0.0001
    }
}

// MARK: - Preview
#Preview {
    Text("MedianDailyGlucoseProfileChart Preview requires a ReportGlucoseProfileV1 fixture.")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(16)
}
