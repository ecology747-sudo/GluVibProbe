//
//  ReportDailyMeanGlucoseLineChartV1.swift
//  GluVibProbe
//
//  GluVib Report (V1) — Daily Mean Glucose (Line Chart)
//  - Report-only view (no HealthKit, no fetching)
//  - Uses existing DailyGlucoseStatsEntry (mean mg/dL) from SSoT
//

import SwiftUI
import Charts

struct ReportDailyMeanGlucoseLineChartV1: View {

    let windowDays: Int
    let glucoseUnit: GlucoseUnit
    let entries: [DailyGlucoseStatsEntry]

    // settings-driven TIR band (mg/dL)
    let targetMinMgdl: Int
    let targetMaxMgdl: Int

    private let blue = Color.Glu.primaryBlue
    private let tirGreen = Color.green
    private let lineColor = Color("acidCGMRed")

    private var unitDigits: Int { (glucoseUnit == .mgdL) ? 0 : 1 }

    // ============================================================
    // MARK: - Axis Baseline (stronger coordinate system)
    // ============================================================

    private var axisBaselineColor: Color { blue.opacity(0.450) }
    private var axisBaselineLineWidth: CGFloat { 1.0 }

    // ============================================================
    // MARK: - Y Floor (start at 35, not 0)
    // ============================================================

    private var yFloorDisplay: Double {
        glucoseUnit.convertedValue(fromMgdl: 35.0)
    }

    // ============================================================
    // MARK: - Title (Report style)
    // ============================================================

    private var chartTitleText: String {
        "Daily Mean Glucose (\(windowDays) Days)"
    }

    // ============================================================
    // MARK: - X Axis density
    // ============================================================

    private var xDesiredCount: Int {
        // UPDATED: More date labels for orientation (avoids "only 2")
        // 7d: 5 labels, 14d: 6 labels, 30d: 7 labels, 90d: 8 labels (bounded)
        if windowDays <= 7 { return 5 }
        if windowDays <= 14 { return 6 }
        if windowDays <= 30 { return 7 }
        return 8
    }

    var body: some View {

        let data = filteredWindow(entries: entries, windowDays: windowDays)

        let yMax = computeYMaxDisplay(
            data: data,
            targetMinMgdl: targetMinMgdl,
            targetMaxMgdl: targetMaxMgdl
        )

        let yMin = min(yFloorDisplay, yMax)

        let tirLow = glucoseUnit.convertedValue(fromMgdl: Double(max(0, targetMinMgdl)))
        let tirHigh = glucoseUnit.convertedValue(fromMgdl: Double(max(0, targetMaxMgdl)))

        VStack(alignment: .leading, spacing: 8) {

            // UPDATED: Title styled like other report chart headings
            Text(chartTitleText)
                .font(ReportStyle.FontToken.value)
                .foregroundStyle(ReportStyle.textColor)

            Chart {

                // ========================================================
                // TIR band (behind the line)
                // ========================================================
                RectangleMark(
                    yStart: .value("TIR Low", min(tirLow, tirHigh)),
                    yEnd: .value("TIR High", max(tirLow, tirHigh))
                )
                .foregroundStyle(tirGreen.opacity(0.14))

                // ========================================================
                // Line + points
                // ========================================================
                ForEach(data, id: \.date) { e in
                    let mgdl = max(0.0, e.meanMgdl)
                    let y = glucoseUnit.convertedValue(fromMgdl: mgdl)

                    LineMark(
                        x: .value("Date", e.date),
                        y: .value("Glucose", y)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(lineColor)

                    PointMark(
                        x: .value("Date", e.date),
                        y: .value("Glucose", y)
                    )
                    .symbolSize(14)
                    .foregroundStyle(lineColor.opacity(0.70))
                }
            }
            .chartLegend(.hidden)

            // Start Y at 35 (display-unit), not 0
            .chartYScale(domain: yMin...yMax)

            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: xDesiredCount)) { value in
                    AxisGridLine()
                        .foregroundStyle(blue.opacity(0.12))
                    AxisTick()
                        .foregroundStyle(blue.opacity(0.25))
                    AxisValueLabel {
                        if let d = value.as(Date.self) {
                            Text(axisDateLabel(d))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(blue.opacity(0.85))
                                .monospacedDigit()
                        }
                    }
                }
            }

            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(blue.opacity(0.10))
                    AxisTick()
                        .foregroundStyle(blue.opacity(0.22))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatDisplay(v))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(blue.opacity(0.85))
                                .monospacedDigit()
                        }
                    }
                }
            }

            // ============================================================
            // Draw stronger X/Y axis baselines in plot-area overlay
            // ============================================================

            .chartOverlay { proxy in
                GeometryReader { geo in
                    let frame = geo[proxy.plotAreaFrame]

                    Path { p in
                        // Y axis (left)
                        p.move(to: CGPoint(x: frame.minX, y: frame.minY))
                        p.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))

                        // X axis (bottom)
                        p.move(to: CGPoint(x: frame.minX, y: frame.maxY))
                        p.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
                    }
                    .stroke(axisBaselineColor, style: StrokeStyle(lineWidth: axisBaselineLineWidth, lineCap: .butt))
                }
            }

            .accessibilityLabel(Text("Daily mean glucose over \(windowDays) days"))
        }
    }

    // ============================================================
    // MARK: - Window + Formatting (no new models)
    // ============================================================

    private func filteredWindow(entries: [DailyGlucoseStatsEntry], windowDays: Int) -> [DailyGlucoseStatsEntry] {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())

        let fullDays = entries
            .filter { $0.coverageMinutes > 0 }
            .filter { cal.startOfDay(for: $0.date) < todayStart } // exclude today partial
            .sorted { $0.date < $1.date }

        let n = max(1, windowDays)
        return Array(fullDays.suffix(n))
    }

    private func computeYMaxDisplay(
        data: [DailyGlucoseStatsEntry],
        targetMinMgdl: Int,
        targetMaxMgdl: Int
    ) -> Double {
        let dataVals = data.map { e in
            glucoseUnit.convertedValue(fromMgdl: max(0.0, e.meanMgdl))
        }
        let dataMax = dataVals.max() ?? glucoseUnit.convertedValue(fromMgdl: 200)

        let tLow = glucoseUnit.convertedValue(fromMgdl: Double(max(0, targetMinMgdl)))
        let tHigh = glucoseUnit.convertedValue(fromMgdl: Double(max(0, targetMaxMgdl)))
        let targetsMax = max(tLow, tHigh)

        let maxVal = max(dataMax, targetsMax)

        let baseline = glucoseUnit.convertedValue(fromMgdl: 220)
        return max(maxVal * 1.12, baseline)
    }

    private func formatDisplay(_ valueDisplay: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = unitDigits
        return f.string(from: NSNumber(value: valueDisplay)) ?? "–"
    }

    private func axisDateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("dd.MM")
        return f.string(from: date)
    }
}

// MARK: - Preview

private struct ReportDailyMeanGlucoseLineChartV1_PreviewWrapper: View {

    @State private var unit: GlucoseUnit = .mgdL

    private var fixture: [DailyGlucoseStatsEntry] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        var out: [DailyGlucoseStatsEntry] = []
        out.reserveCapacity(30)

        for offset in stride(from: 30, through: 1, by: -1) {
            let d = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let mean: Double = 110.0 + Double((30 - offset)) * 1.2

            out.append(
                DailyGlucoseStatsEntry(
                    id: UUID(),
                    date: d,
                    meanMgdl: mean,
                    standardDeviationMgdl: 18.0,
                    coefficientOfVariationPercent: 22.0,
                    coverageMinutes: 1100,
                    expectedMinutes: 1440,
                    isPartial: false
                )
            )
        }

        return out
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Unit", selection: $unit) {
                Text("mg/dL").tag(GlucoseUnit.mgdL)
                Text("mmol/L").tag(GlucoseUnit.mmolL)
            }
            .pickerStyle(.segmented)

            ReportDailyMeanGlucoseLineChartV1(
                windowDays: 30,
                glucoseUnit: unit,
                entries: fixture,
                targetMinMgdl: 70,
                targetMaxMgdl: 180
            )
            .frame(height: 140)
            .padding(16)
        }
        .background(Color.white)
    }
}

#Preview("Report Daily Mean Glucose Line Chart") {
    ReportDailyMeanGlucoseLineChartV1_PreviewWrapper()
}
