//
//  ReportInsulinTherapyOverviewSectionV1.swift
//  GluVibProbe
//

import SwiftUI
import Charts

struct ReportInsulinTherapyOverviewSectionV1: View {

    let windowDays: Int

    let dailyBolus90: [DailyBolusEntry]
    let dailyBasal90: [DailyBasalEntry]
    let dailyCarbBolusRatio90: [DailyCarbBolusRatioEntry]
    let dailyBolusBasalRatio90: [DailyBolusBasalRatioEntry]

    // MARK: - Style
    private let blue = Color.Glu.primaryBlue
    private let textColor = ReportStyle.textColor
    private let dividerColor = ReportStyle.dividerColor

    // Global color logic (per request)
    private var bolusColor: Color { Color.Glu.primaryBlue }
    private var basalColor: Color { Color.Glu.metabolicDomain }
    private let trendColor = Color("acidCGMRed")

    // Trendline style (dashed, red)
    private let trendStroke = StrokeStyle(
        lineWidth: 1.8,
        lineCap: .round,
        lineJoin: .round,
        miterLimit: 1,
        dash: [5, 4],
        dashPhase: 0
    )

    // KPI tiles
    private let kpiGridSpacing: CGFloat = 10
    private let kpiTileCornerRadius: CGFloat = 10

    // Axis baseline (thin coordinate system)
    private var axisBaselineColor: Color { blue.opacity(0.35) }
    private var axisBaselineLineWidth: CGFloat { 0.9 }

    var body: some View {

        let bolus = windowedBolus()
        let basal = windowedBasal()
        let carbBolus = windowedCarbBolusRatio()
        let bolusBasal = windowedBolusBasalRatio()

        let avgBolus = averageBolusPerDay(bolus)
        let avgBasal = averageBasalPerDay(basal)
        let avgCarbBolus = averageCarbBolusRatio(carbBolus)

        VStack(alignment: .leading, spacing: 10) {

            Text("Insulin Therapy Overview (\(windowDays) Days)")
                .font(ReportStyle.FontToken.value)
                .foregroundStyle(textColor)

            // ====================================================
            // Block A — 3 KPIs
            // ====================================================
            kpiRow(
                avgBolus: avgBolus,
                avgBasal: avgBasal,
                avgCarbBolus: avgCarbBolus
            )
            .padding(.bottom, 4)

            // ====================================================
            // Block B — horizontal split (FULL WIDTH, like before)
            // ====================================================
            stackedSplitBar(avgBolus: avgBolus, avgBasal: avgBasal)
                .padding(.bottom, 6)

            // ====================================================
            // Block C — Row 1: Daily Bolus | Daily Basal
            // ====================================================
            HStack(alignment: .top, spacing: 12) {
                microTrendChartBolus(bolus)
                    .frame(maxWidth: .infinity, alignment: .leading)

                microTrendChartBasal(basal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // ====================================================
            // Block D — Row 2: Bolus/Basal | Carbs/Bolus
            // ====================================================
            HStack(alignment: .top, spacing: 12) {
                microTrendChartBolusBasalRatio(bolusBasal)
                    .frame(maxWidth: .infinity, alignment: .leading)

                microTrendChartCarbBolusRatio(carbBolus)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // ============================================================
    // MARK: - Block A (KPIs)
    // ============================================================

    private func kpiRow(
        avgBolus: Double,
        avgBasal: Double,
        avgCarbBolus: Double
    ) -> some View {

        HStack(spacing: kpiGridSpacing) {
            kpiTile(title: "Ø Bolus", value: format1(avgBolus), unit: "U/day")
            kpiTile(title: "Ø Basal", value: format1(avgBasal), unit: "U/day")
            kpiTile(title: "Ø Carbs/Bolus", value: format1(avgCarbBolus), unit: "g/U")
        }
    }

    private func kpiTile(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ReportStyle.textColor.opacity(0.70))
                .lineLimit(1)
                .minimumScaleFactor(0.90)

            HStack(alignment: .firstTextBaseline, spacing: 4) {

                Text(value == "–" ? "–" : value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ReportStyle.textColor.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .monospacedDigit()

                if !unit.isEmpty, value != "–" {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(ReportStyle.textColor.opacity(0.60))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
        .background(Color.white.opacity(0.30))
        .overlay(
            RoundedRectangle(cornerRadius: kpiTileCornerRadius)
                .stroke(ReportStyle.dividerColor.opacity(0.9), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: kpiTileCornerRadius))
    }

    // ============================================================
    // MARK: - Block B (Avg Split — full width, no card)
    // ============================================================

    private func stackedSplitBar(avgBolus: Double, avgBasal: Double) -> some View {

        let total = max(0.0001, avgBolus + avgBasal)
        let bolusFrac = CGFloat(max(0, avgBolus) / total)
        let basalFrac = CGFloat(max(0, avgBasal) / total)

        let bolusSplitColor = bolusColor.opacity(0.85)
        let basalSplitColor = basalColor.opacity(0.70)

        return VStack(alignment: .leading, spacing: 8) {

            HStack {
                Text("Avg Daily Split (Bolus vs Basal)")
                    .font(ReportStyle.FontToken.caption)
                    .foregroundStyle(textColor.opacity(0.72))
                Spacer()
                Text("\(Int((bolusFrac * 100).rounded()))% / \(Int((basalFrac * 100).rounded()))%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(textColor.opacity(0.75))
                    .monospacedDigit()
            }

            GeometryReader { geo in
                let w = geo.size.width
                HStack(spacing: 0) {

                    Rectangle()
                        .fill(bolusSplitColor)
                        .frame(width: w * bolusFrac)

                    Rectangle()
                        .fill(basalSplitColor)
                        .frame(width: w * basalFrac)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(blue.opacity(0.35), lineWidth: 1.2)
                )
            }
            .frame(height: 16)

            HStack(spacing: 12) {
                legendDot(color: bolusSplitColor, text: "Bolus")
                legendDot(color: basalSplitColor, text: "Basal")
            }
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color.opacity(0.85)).frame(width: 8, height: 8)
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(textColor.opacity(0.75))
        }
    }

    // ============================================================
    // MARK: - Micro Charts (no card)
    // ============================================================

    private func microTrendChartBolus(_ data: [DailyBolusEntry]) -> some View {
        microTrendChart(
            title: "Daily Bolus (U)",
            series: data.map { (.init(date: $0.date, value: max(0, $0.bolusUnits))) },
            barColor: bolusColor.opacity(0.75),
            valueFormat: .int0
        )
    }

    private func microTrendChartBasal(_ data: [DailyBasalEntry]) -> some View {
        microTrendChart(
            title: "Daily Basal (U)",
            series: data.map { (.init(date: $0.date, value: max(0, $0.basalUnits))) },
            barColor: basalColor.opacity(0.70),
            valueFormat: .int0
        )
    }

    private func microTrendChartBolusBasalRatio(_ data: [DailyBolusBasalRatioEntry]) -> some View {
        microTrendChart(
            title: "Bolus/Basal Ratio",
            series: data.map { (.init(date: $0.date, value: max(0, $0.ratio))) },
            barColor: bolusColor.opacity(0.40),
            valueFormat: .oneDecimal
        )
    }

    private func microTrendChartCarbBolusRatio(_ data: [DailyCarbBolusRatioEntry]) -> some View {
        microTrendChart(
            title: "Carbs/Bolus (g/U)",
            series: data.map { (.init(date: $0.date, value: max(0, $0.gramsPerUnit))) },
            barColor: basalColor.opacity(0.40),
            valueFormat: .oneDecimal
        )
    }

    private enum ValueFormat {
        case int0
        case oneDecimal
    }

    private struct MicroPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private func microTrendChart(
        title: String,
        series: [MicroPoint],
        barColor: Color,
        valueFormat: ValueFormat
    ) -> some View {

        let yMin: Double = 0
        let yMax: Double = max(1, (series.map(\.value).max() ?? 1) * 1.20)

        let trend = linearTrend(series)

        return VStack(alignment: .leading, spacing: 6) {

            // UPDATED: stronger chart title
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(textColor.opacity(0.88))

            Chart {

                ForEach(series) { p in
                    BarMark(
                        x: .value("Date", p.date),
                        y: .value("Value", p.value)
                    )
                    .foregroundStyle(barColor)
                    .cornerRadius(2)
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
            .chartYScale(domain: yMin...yMax)
            .chartXScale(range: .plotDimension(padding: 12))
            // UPDATED: remove X axis labels entirely (no ticks/labels/grid)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine().foregroundStyle(Color.clear)
                    AxisTick().foregroundStyle(Color.clear)
                    AxisValueLabel { EmptyView() } // no X-axis labels
                }
            }
            // Y axis stays (labels + subtle grid)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8))
                        .foregroundStyle(blue.opacity(0.12))
                    AxisTick(stroke: StrokeStyle(lineWidth: 1.0))
                        .foregroundStyle(blue.opacity(0.45))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatYAxis(v, format: valueFormat))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(blue.opacity(0.85))
                                .monospacedDigit()
                        }
                    }
                }
            }

            // UPDATED: thin coordinate baselines (X + Y) to keep "coordinate system" feeling
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

            .frame(height: 120)
        }
    }

    private func formatYAxis(_ v: Double, format: ValueFormat) -> String {
        switch format {
        case .int0:
            return format0(v)
        case .oneDecimal:
            return format1(v)
        }
    }

    // ============================================================
    // MARK: - Windowing (full days only, ends yesterday)
    // ============================================================

    private func windowedBolus() -> [DailyBolusEntry] {
        windowFullDays(dailyBolus90, windowDays: windowDays) { $0.date }
    }

    private func windowedBasal() -> [DailyBasalEntry] {
        windowFullDays(dailyBasal90, windowDays: windowDays) { $0.date }
    }

    private func windowedCarbBolusRatio() -> [DailyCarbBolusRatioEntry] {
        windowFullDays(dailyCarbBolusRatio90, windowDays: windowDays) { $0.date }
    }

    private func windowedBolusBasalRatio() -> [DailyBolusBasalRatioEntry] {
        windowFullDays(dailyBolusBasalRatio90, windowDays: windowDays) { $0.date }
    }

    private func windowFullDays<T>(
        _ entries: [T],
        windowDays: Int,
        date: (T) -> Date
    ) -> [T] {

        guard !entries.isEmpty else { return [] }

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: -1, to: todayStart) else { return [] }

        let n = max(1, windowDays)
        guard let start = cal.date(byAdding: .day, value: -(n - 1), to: end) else { return [] }

        return entries
            .filter {
                let d = cal.startOfDay(for: date($0))
                return d >= start && d <= end
            }
            .sorted { date($0) < date($1) }
    }

    // ============================================================
    // MARK: - Averages (period)
    // ============================================================

    private func averageBolusPerDay(_ entries: [DailyBolusEntry]) -> Double {
        guard !entries.isEmpty else { return 0 }
        let values = entries.map { max(0, $0.bolusUnits) }
        return values.reduce(0, +) / Double(values.count)
    }

    private func averageBasalPerDay(_ entries: [DailyBasalEntry]) -> Double {
        guard !entries.isEmpty else { return 0 }
        let values = entries.map { max(0, $0.basalUnits) }
        return values.reduce(0, +) / Double(values.count)
    }

    private func averageCarbBolusRatio(_ entries: [DailyCarbBolusRatioEntry]) -> Double {
        let values = entries.map { max(0, $0.gramsPerUnit) }.filter { $0 > 0 }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    // ============================================================
    // MARK: - Trend (simple linear regression)
    // ============================================================

    private func linearTrend(_ series: [MicroPoint]) -> (x0: Date, y0: Double, x1: Date, y1: Double)? {
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

        let y0 = max(0, slope * x0i + intercept)
        let y1 = max(0, slope * x1i + intercept)

        return (series.first!.date, y0, series.last!.date, y1)
    }

    // ============================================================
    // MARK: - Formatting
    // ============================================================

    private func format1(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: v)) ?? "–"
    }

    private func format0(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "–"
    }

    private func axisDateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("dd.MM")
        return f.string(from: date)
    }
}

// MARK: - Preview

private struct ReportInsulinTherapyOverviewSectionV1_PreviewWrapper: View {

    private var fixtureBolus: [DailyBolusEntry] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (1...30).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyBolusEntry(id: UUID(), date: d, bolusUnits: 18.0 + Double(offset % 7) * 0.8)
        }
    }

    private var fixtureBasal: [DailyBasalEntry] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (1...30).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyBasalEntry(id: UUID(), date: d, basalUnits: 22.0 + Double(offset % 5) * 0.6)
        }
    }

    private var fixtureCarbBolus: [DailyCarbBolusRatioEntry] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (1...30).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyCarbBolusRatioEntry(id: UUID(), date: d, gramsPerUnit: 9.5 + Double(offset % 6) * 0.4)
        }
    }

    private var fixtureBolusBasal: [DailyBolusBasalRatioEntry] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (1...30).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyBolusBasalRatioEntry(id: UUID(), date: d, ratio: 0.75 + Double(offset % 6) * 0.03)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReportInsulinTherapyOverviewSectionV1(
                windowDays: 30,
                dailyBolus90: fixtureBolus,
                dailyBasal90: fixtureBasal,
                dailyCarbBolusRatio90: fixtureCarbBolus,
                dailyBolusBasalRatio90: fixtureBolusBasal
            )
        }
        .padding(16)
        .background(Color.white)
    }
}

#Preview("Report — Insulin Therapy Overview") {
    ReportInsulinTherapyOverviewSectionV1_PreviewWrapper()
}
