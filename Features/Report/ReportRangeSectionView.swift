//
//  ReportRangeSectionView.swift
//  GluVibProbe
//

import SwiftUI
import Charts

struct ReportRangeSectionView: View {

    // ============================================================
    // MARK: - Inputs (presentation only)
    // ============================================================

    let windowDays: Int
    let summaryWindow: RangePeriodSummaryEntry?

    let meanText: String
    let gmiText: String
    let cvText: String
    let sdText: String

    let tirDailySeries: [DailyTIREntry]
    let tirTargetPercent: Int

    let onTap: (() -> Void)?

    // ============================================================
    // MARK: - Layout constants
    // ============================================================

    private let barWidth: CGFloat = 28
    private let barHeight: CGFloat = 150

    private let dotSize: CGFloat = 6
    private let valueFont: Font = .caption.weight(.semibold)

    private let rowsTopBottomPadding: CGFloat = 14
    private let rowsOuterSpacing: CGFloat = 10
    private let rowsInnerSpacing: CGFloat = 6

    private let percentColumnWidth: CGFloat = 92
    private let reportMaxContentWidth: CGFloat = 520

    // pull charts apart more (no vertical divider)
    private let colGap: CGFloat = 26
    private let colInnerGap: CGFloat = 12

    // UPDATED: range block further right
    private let rangeBlockLeadingInset: CGFloat = 22 // UPDATED

    // TIR chart sizing
    private let tirChartWidth: CGFloat = 260
    private var tirChartHeight: CGFloat { barHeight } // UPDATED: match range height exactly

    // UPDATED: push TIR chart further right
    private let tirBlockLeadingInset: CGFloat = 16 // UPDATED

    // Layout spacing
    private let sectionVStackSpacing: CGFloat = 10

    // KPI boxes
    private let kpiRowSpacing: CGFloat = 10
    private let kpiTileCornerRadius: CGFloat = 10

    // Trendline style (dashed, red)
    private let trendStroke = StrokeStyle(
        lineWidth: 1.8,
        lineCap: .round,
        lineJoin: .round,
        miterLimit: 1,
        dash: [5, 4],
        dashPhase: 0
    )
    private let trendColor = Color("acidCGMRed")

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        VStack(alignment: .leading, spacing: sectionVStackSpacing) {

            // Charts row (NO individual headings, NO vertical divider)
            HStack(alignment: .top, spacing: colGap) {

                leftRangeBlock

                tirBlock
                    .frame(width: tirChartWidth, height: tirChartHeight, alignment: .topLeading) // UPDATED
                    .padding(.leading, tirBlockLeadingInset) // UPDATED
            }

            // KPI boxes (centered, no dividers, no separator above)
            HStack(spacing: kpiRowSpacing) {
                kpiBox(title: "Ø Glucose", value: meanText)
                kpiBox(title: "GMI", value: gmiText == "–" ? "–" : "\(gmiText)%")
                kpiBox(title: "CV", value: cvTextPercentNormalized) // UPDATED
                kpiBox(title: "SD", value: sdText)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: reportMaxContentWidth)
        .frame(maxWidth: .infinity, alignment: .center)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    // ============================================================
    // MARK: - LEFT: Range Block
    // ============================================================

    private var leftRangeBlock: some View {
        HStack(alignment: .top, spacing: colInnerGap) {

            rangeStackBar
                .frame(width: barWidth, height: barHeight)

            percentDotsColumn
                .frame(width: percentColumnWidth, alignment: .leading)
                .frame(height: barHeight)
        }
        .padding(.leading, rangeBlockLeadingInset) // UPDATED
    }

    private var rangeStackBar: some View {
        GeometryReader { geo in
            let h = geo.size.height

            let cov = max(0, summaryWindow?.coverageMinutes ?? 0)
            let total = max(1, cov)

            let vl = max(0, summaryWindow?.veryLowMinutes ?? 0)
            let lo = max(0, summaryWindow?.lowMinutes ?? 0)
            let ir = max(0, summaryWindow?.inRangeMinutes ?? 0)
            let hi = max(0, summaryWindow?.highMinutes ?? 0)
            let vh = max(0, summaryWindow?.veryHighMinutes ?? 0)

            let vlH = h * CGFloat(Double(vl) / Double(total))
            let loH = h * CGFloat(Double(lo) / Double(total))
            let irH = h * CGFloat(Double(ir) / Double(total))
            let hiH = h * CGFloat(Double(hi) / Double(total))
            let vhH = h * CGFloat(Double(vh) / Double(total))

            ZStack(alignment: .bottom) {

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.25))

                VStack(spacing: 0) {
                    Rectangle().fill(colorVeryHigh).frame(height: vhH)
                    Rectangle().fill(colorHigh).frame(height: hiH)
                    Rectangle().fill(colorInRange).frame(height: irH)
                    Rectangle().fill(colorLow).frame(height: loH)
                    Rectangle().fill(colorVeryLow).frame(height: vlH)
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))

                RoundedRectangle(cornerRadius: 2)
                    .stroke(ReportStyle.dividerColor.opacity(0.9), lineWidth: 1)
            }
        }
        .accessibilityLabel(Text("Time in Range distribution"))
    }

    private var colorVeryLow: Color { Color.Glu.acidCGMRed }
    private var colorLow: Color { Color.yellow.opacity(0.80) }
    private var colorInRange: Color { Color.Glu.metabolicDomain }
    private var colorHigh: Color { Color.yellow.opacity(0.80) }
    private var colorVeryHigh: Color { Color.Glu.acidCGMRed }

    private var percentDotsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {

            Spacer(minLength: rowsTopBottomPadding)

            percentDotRow(color: colorVeryHigh, text: veryHighPctText, valueColor: ReportStyle.textColor.opacity(0.92))
            Spacer(minLength: rowsOuterSpacing)

            percentDotRow(color: colorHigh, text: highPctText, valueColor: ReportStyle.textColor.opacity(0.92))
            Spacer(minLength: rowsInnerSpacing)

            percentDotRow(color: colorInRange, text: inRangePctText, valueColor: Color.Glu.successGreen)
            Spacer(minLength: rowsInnerSpacing)

            percentDotRow(color: colorLow, text: lowPctText, valueColor: ReportStyle.textColor.opacity(0.92))
            Spacer(minLength: rowsOuterSpacing)

            percentDotRow(color: colorVeryLow, text: veryLowPctText, valueColor: ReportStyle.textColor.opacity(0.92))

            Spacer(minLength: rowsTopBottomPadding)
        }
        .font(valueFont)
        .frame(maxHeight: .infinity)
    }

    private func percentDotRow(color: Color, text: String, valueColor: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: dotSize, height: dotSize)

            Text(text)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private var coverageMinutesSafe: Int { max(0, summaryWindow?.coverageMinutes ?? 0) }

    private func pctText(minutes: Int) -> String {
        let m = max(0, minutes)
        let cov = max(0, coverageMinutesSafe)
        guard cov > 0 else { return "–" }
        guard m > 0 else { return "0%" }

        let pct = (Double(m) / Double(cov)) * 100.0
        if pct > 0 && pct < 1.0 { return "< 1%" }

        let rounded = Int(pct.rounded())
        return "\(max(0, min(100, rounded)))%"
    }

    private var veryHighPctText: String { pctText(minutes: summaryWindow?.veryHighMinutes ?? 0) }
    private var highPctText: String { pctText(minutes: summaryWindow?.highMinutes ?? 0) }
    private var inRangePctText: String { pctText(minutes: summaryWindow?.inRangeMinutes ?? 0) }
    private var lowPctText: String { pctText(minutes: summaryWindow?.lowMinutes ?? 0) }
    private var veryLowPctText: String { pctText(minutes: summaryWindow?.veryLowMinutes ?? 0) }

    // ============================================================
    // MARK: - RIGHT: TIR Block
    // ============================================================

    private var tirBlock: some View {
        tirMicroChart
            .frame(height: tirChartHeight, alignment: .topLeading) // UPDATED
    }

    private struct TIRPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private var tirPoints: [TIRPoint] {
        tirDailySeries.map { .init(date: $0.date, value: Double(tirPercentValue(from: $0))) }
    }

    private var tirMicroChart: some View {
        let series = tirPoints
        let fixedBarW = reportBarWidth(for: windowDays)
        let trend = linearTrend(series)

        return Chart {

            ForEach(series) { p in
                BarMark(
                    x: .value("Date", p.date),
                    y: .value("TIR", p.value),
                    width: .fixed(fixedBarW)
                )
                .foregroundStyle(Color.Glu.metabolicDomain.opacity(0.70))
                .cornerRadius(2)
            }

            if tirTargetPercent > 0 {
                RuleMark(y: .value("Target", Double(tirTargetPercent)))
                    .foregroundStyle(Color.Glu.successGreen)
                    .lineStyle(StrokeStyle(lineWidth: 1.4))
            }

            if let trend {
                LineMark(
                    x: .value("Start", trend.x0),
                    y: .value("y0", trend.y0)
                )
                .foregroundStyle(trendColor)
                .lineStyle(trendStroke)

                LineMark(
                    x: .value("End", trend.x1),
                    y: .value("y1", trend.y1)
                )
                .foregroundStyle(trendColor)
                .lineStyle(trendStroke)
            }
        }
        .chartLegend(.hidden)
        .chartYScale(domain: 0...100)
        .chartXScale(range: .plotDimension(padding: 12))
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine().foregroundStyle(Color.clear)
                AxisTick().foregroundStyle(Color.clear)
                AxisValueLabel { EmptyView() }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8))
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.12))
                AxisTick(stroke: StrokeStyle(lineWidth: 1.0))
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.45))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v.rounded()))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.85))
                            .monospacedDigit()
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                let frame = geo[proxy.plotAreaFrame]
                Path { p in
                    p.move(to: CGPoint(x: frame.minX, y: frame.minY))
                    p.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
                    p.move(to: CGPoint(x: frame.minX, y: frame.maxY))
                    p.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
                }
                .stroke(
                    Color.Glu.primaryBlue.opacity(0.35),
                    style: StrokeStyle(lineWidth: 0.9, lineCap: .butt)
                )
            }
        }
        .frame(height: tirChartHeight) // UPDATED: force chart height == range height
    }

    private func reportBarWidth(for days: Int) -> CGFloat {
        if days <= 30 { return 6 }
        if days <= 60 { return 4 }
        return 3
    }

    private func tirPercentValue(from entry: DailyTIREntry) -> Int {
        let cov = max(0, entry.coverageMinutes)
        guard cov > 0 else { return 0 }
        let inRange = max(0, entry.inRangeMinutes)
        let pct = Int((Double(inRange) / Double(cov) * 100.0).rounded())
        return max(0, min(100, pct))
    }

    private func linearTrend(_ series: [TIRPoint]) -> (x0: Date, y0: Double, x1: Date, y1: Double)? {
        guard series.count >= 2 else { return nil }

        let n = Double(series.count)
        let xs = series.indices.map { Double($0) }
        let ys = series.map(\.value)

        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXX = xs.reduce(0) { $0 + $1 * $1 }
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }

        let denom = (n * sumXX - sumX * sumX)
        guard abs(denom) > 0.000001 else { return nil }

        let slope = (n * sumXY - sumX * sumY) / denom
        let intercept = (sumY - slope * sumX) / n

        let x0i = 0.0
        let x1i = Double(series.count - 1)

        let y0 = max(0, min(100, slope * x0i + intercept))
        let y1 = max(0, min(100, slope * x1i + intercept))

        return (series.first!.date, y0, series.last!.date, y1)
    }

    // ============================================================
    // MARK: - KPI Boxes
    // ============================================================

    private var cvTextPercentNormalized: String {
        let t = cvText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t == "–" { return "–" }
        if t.contains("%") { return t }
        return "\(t)%"
    }

    private func kpiBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ReportStyle.textColor.opacity(0.70))
                .lineLimit(1)
                .minimumScaleFactor(0.90)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ReportStyle.textColor.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.80)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(width: 118, alignment: .topLeading)
        .frame(minHeight: 52)
        .background(Color.white.opacity(0.30))
        .overlay(
            RoundedRectangle(cornerRadius: kpiTileCornerRadius)
                .stroke(ReportStyle.dividerColor.opacity(0.9), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: kpiTileCornerRadius))
    }
}
