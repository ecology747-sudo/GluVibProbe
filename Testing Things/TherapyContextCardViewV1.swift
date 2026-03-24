//
//  TherapyContextTimeSeriesCardViewV1.swift
//  GluVib
//
//  Metabolic — Therapy Context (Time Series) Card (V1)
//  - Display-only (no HealthKit fetch here)
//  - X: Time (days)
//  - Y (left): Mean Glucose (line) with target band 70–180
//  - Y (right): Carbs/Bolus ratio (points)
//  - Ratio point turns RED if the day's mean is outside target band
//

import SwiftUI
import Charts

// MARK: - Model

struct TherapyContextDayPointV1: Identifiable, Hashable {
    let id = UUID()
    let date: Date

    // Mean glucose for that day (already converted to display unit: mg/dL OR mmol/L)
    let meanGlucose: Double?

    // Carbs/Bolus ratio (g/U) for that day
    let carbsBolusRatio: Double?
}

// MARK: - View

struct TherapyContextTimeSeriesCardViewV1: View {

    // Input (SSoT arrays mapped elsewhere)
    let points90: [TherapyContextDayPointV1]

    // Target band (in same unit as meanGlucose)
    let targetMin: Double
    let targetMax: Double

    // Unit labels (display only)
    let glucoseUnitLabel: String   // "mg/dL" or "mmol/L"
    let ratioUnitLabel: String     // "g/U"

    // Style
    private let titleColor = Color.Glu.primaryBlue
    private let cardFill = Color.white
    private let cardStroke = Color.Glu.primaryBlue.opacity(0.22)

    private var sortedPoints: [TherapyContextDayPointV1] {
        points90.sorted { $0.date < $1.date }
    }

    private var latestPoint: TherapyContextDayPointV1? {
        sortedPoints.last
    }

    private var xDomain: ClosedRange<Date> {
        let dates = sortedPoints.map(\.date)
        guard let minD = dates.first, let maxD = dates.last else {
            let now = Date()
            return now...now
        }
        return minD...maxD
    }

    private var glucoseDomain: ClosedRange<Double> {
        let values = sortedPoints.compactMap(\.meanGlucose)
        guard let minV = values.min(), let maxV = values.max() else {
            return (targetMin - 10)...(targetMax + 10)
        }

        // include target band bounds so the band always fits
        let lo = min(minV, targetMin)
        let hi = max(maxV, targetMax)

        let pad = (hi - lo) * 0.10
        return (lo - pad)...(hi + pad)
    }

    private var ratioDomain: ClosedRange<Double> {
        let values = sortedPoints.compactMap(\.carbsBolusRatio)
        guard let minV = values.min(), let maxV = values.max() else {
            return 0...1
        }
        let pad = (maxV - minV) * 0.12
        return (minV - pad)...(maxV + pad)
    }

    private func isMeanInRange(_ mean: Double) -> Bool {
        mean >= targetMin && mean <= targetMax
    }

    private func formatNumber(_ v: Double, decimals: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = decimals
        f.minimumFractionDigits = decimals
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            headerRow

            kpiRow

            chart
                .frame(height: 210)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cardStroke, lineWidth: 1.6)
        )
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Therapy Context (90d)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(titleColor)

            Spacer()

            // Mean badge (Today)
            if let m = latestPoint?.meanGlucose {
                MeanBadgeV1(isInRange: isMeanInRange(m))
            }
        }
    }

    // MARK: - KPIs

    private var kpiRow: some View {
        HStack(spacing: 10) {

            kpiTile(
                title: "Mean (Today)",
                value: latestPoint?.meanGlucose.map {
                    formatNumber($0, decimals: glucoseUnitLabel == "mmol/L" ? 1 : 0)
                } ?? "–",
                unit: glucoseUnitLabel
            )

            kpiTile(
                title: "Carbs/Bolus (Today)",
                value: latestPoint?.carbsBolusRatio.map { formatNumber($0, decimals: 1) } ?? "–",
                unit: ratioUnitLabel
            )

            kpiTile(
                title: "Mean target",
                value: "\(formatNumber(targetMin, decimals: glucoseUnitLabel == "mmol/L" ? 1 : 0))–\(formatNumber(targetMax, decimals: glucoseUnitLabel == "mmol/L" ? 1 : 0))",
                unit: glucoseUnitLabel
            )
        }
    }

    private func kpiTile(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(titleColor.opacity(0.70))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(titleColor)

                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(titleColor.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.Glu.primaryBlue.opacity(0.12), lineWidth: 1.2)
        )
    }

    // MARK: - Chart (Dual axis via overlay)

    private var chart: some View {
        ZStack {

            // =========================================================
            // 🟨 UPDATED: Base chart = Glucose (left axis) + target band
            // =========================================================

            Chart {
                // Target band (horizontal band across full time window)
                RectangleMark(
                    xStart: .value("Start", xDomain.lowerBound),
                    xEnd: .value("End", xDomain.upperBound),
                    yStart: .value("Target Min", targetMin),
                    yEnd: .value("Target Max", targetMax)
                )
                .foregroundStyle(Color.green.opacity(0.10))

                // Mean glucose line
                ForEach(sortedPoints) { p in
                    if let mg = p.meanGlucose {
                        LineMark(
                            x: .value("Day", p.date),
                            y: .value("Mean", mg)
                        )
                        .interpolationMethod(.linear)
                        .foregroundStyle(Color.Glu.primaryBlue)

                        // Optional: dot on the line (small)
                        PointMark(
                            x: .value("Day", p.date),
                            y: .value("Mean", mg)
                        )
                        .symbolSize(18)
                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))
                    }
                }

                // Target bounds as rules
                RuleMark(y: .value("Target Min", targetMin))
                    .foregroundStyle(Color.green.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                RuleMark(y: .value("Target Max", targetMax))
                    .foregroundStyle(Color.green.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: glucoseDomain)
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .chartLegend(.hidden)

            // =========================================================
            // 🟨 UPDATED: Overlay chart = Ratio points (right axis)
            // - Shares same X domain
            // - Own Y domain (ratio)
            // - X axis hidden to avoid duplicates
            // =========================================================

            Chart {
                ForEach(sortedPoints) { p in
                    if let ratio = p.carbsBolusRatio, let mg = p.meanGlucose {
                        PointMark(
                            x: .value("Day", p.date),
                            y: .value("Carbs/Bolus", ratio)
                        )
                        .symbolSize(46)
                        .foregroundStyle(isMeanInRange(mg) ? Color.Glu.primaryBlue : Color.red) // red if mean out of range
                    }
                }
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: ratioDomain)
            .chartYAxis {
                AxisMarks(position: .trailing) {
                    AxisGridLine().foregroundStyle(Color.clear) // no extra grid from overlay
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartXAxis(.hidden)
            .chartLegend(.hidden)
            .allowsHitTesting(false) // keeps gestures clean
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mean glucose and carbs bolus ratio over time")
    }
}

// MARK: - Badge

private struct MeanBadgeV1: View {
    let isInRange: Bool

    var body: some View {
        Text(isInRange ? "Mean In Range" : "Mean Out of Range")
            .font(.caption.weight(.semibold))
            .foregroundStyle(isInRange ? Color.green : Color.red)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill((isInRange ? Color.green : Color.red).opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke((isInRange ? Color.green : Color.red).opacity(0.35), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    let cal = Calendar.current
    let base = cal.startOfDay(for: .now)

    let demo: [TherapyContextDayPointV1] = (0..<28).map { i in
        let d = cal.date(byAdding: .day, value: -i, to: base)!
        // mean swings around target band
        let mean = Double(85 + (i % 11) * 12) // 85..217
        // ratio swings independently
        let ratio = Double(8 + (i % 9)) + Double(i % 3) * 0.3
        return TherapyContextDayPointV1(
            date: d,
            meanGlucose: mean,
            carbsBolusRatio: ratio
        )
    }.sorted { $0.date < $1.date }

    return VStack(alignment: .leading, spacing: 16) {
        TherapyContextTimeSeriesCardViewV1(
            points90: demo,
            targetMin: 70,
            targetMax: 180,
            glucoseUnitLabel: "mg/dL",
            ratioUnitLabel: "g/U"
        )
        .padding()
    }
    .background(Color.white)
}
