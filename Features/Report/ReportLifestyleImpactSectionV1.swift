//
//  ReportLifestyleImpactSectionV1.swift
//  GluVibProbe
//
//  GluVib Report (V1) — Lifestyle Impact (Carbs + Active Energy)
//  - Report-only view (no HealthKit, no fetching)
//  - Uses existing SSoT arrays (last90DaysCarbs / last90DaysActiveEnergy)
//  - Period = windowDays (7/14/30/90), full days only (ends yesterday)
//  - NO tile / NO background cards
//  - Trendlines: Asset Red, dashed
//

import SwiftUI
import Charts

struct ReportLifestyleImpactSectionV1: View {

    let windowDays: Int

    let dailyCarbs90: [DailyCarbsEntry]
    let dailyActiveEnergy90: [ActivityEnergyEntry]

    // MARK: - Style (fixed)
    private let blue = Color.Glu.primaryBlue
    private let textColor = ReportStyle.textColor
    private let trendRed = Color("acidCGMRed")

    private let carbsBarColor = Color.Glu.nutritionDomain.opacity(0.78)
    private let energyBarColor = Color.Glu.activityDomain.opacity(0.70)

    private let gridSpacing: CGFloat = 10

    // Axis baseline (thin coordinate system) — matches Insulin micro-charts
    private var axisBaselineColor: Color { blue.opacity(0.35) }
    private var axisBaselineLineWidth: CGFloat { 0.9 }

    var body: some View {

        let carbs = windowedCarbs()
        let energy = windowedActiveEnergy()

        VStack(alignment: .leading, spacing: 10) {

            Text("Lifestyle Impact (\(windowDays) Days)")
                .font(ReportStyle.FontToken.value)
                .foregroundStyle(textColor)

            HStack(alignment: .top, spacing: gridSpacing) {

                lifestyleChart(
                    title: "Daily Carbs (g)",
                    series: carbs.map { .init(date: $0.date, value: Double(max(0, $0.grams))) },
                    barColor: carbsBarColor
                )

                lifestyleChart(
                    title: "Daily Active Energy (kcal)",
                    series: energy.map { .init(date: $0.date, value: Double(max(0, $0.activeEnergy))) },
                    barColor: energyBarColor
                )
            }
        }
    }

    // ============================================================
    // MARK: - Chart
    // ============================================================

    private struct MicroPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private func lifestyleChart(
        title: String,
        series: [MicroPoint],
        barColor: Color
    ) -> some View {

        let yMin: Double = 0
        let yMax: Double = max(1, (series.map(\.value).max() ?? 1) * 1.20)

        let trend = linearTrend(series)

        return VStack(alignment: .leading, spacing: 6) {

            // UPDATED: stronger chart title (match Insulin micro-charts)
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
                    .foregroundStyle(trendRed)
                    .lineStyle(dashedTrendStyle)

                    LineMark(
                        x: .value("End", trend.x1),
                        y: .value("y1", trend.y1)
                    )
                    .foregroundStyle(trendRed)
                    .lineStyle(dashedTrendStyle)
                }
            }
            .chartLegend(.hidden)
            .chartYScale(domain: yMin...yMax)

            // UPDATED: keep bars fully inside plot (match Insulin micro-charts fix)
            .chartXScale(range: .plotDimension(padding: 12))

            // UPDATED: remove X axis labels entirely (no ticks/labels/grid)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine().foregroundStyle(Color.clear)
                    AxisTick().foregroundStyle(Color.clear)
                    AxisValueLabel { EmptyView() }
                }
            }

            // Y axis stays (labels + subtle grid) — matches Insulin micro-charts
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8))
                        .foregroundStyle(blue.opacity(0.12))
                    AxisTick(stroke: StrokeStyle(lineWidth: 1.0))
                        .foregroundStyle(blue.opacity(0.45))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(format0(v))
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
        // IMPORTANT: no tile / no background / no overlay
    }

    private var dashedTrendStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: 1.8,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 1,
            dash: [4, 3],
            dashPhase: 0
        )
    }

    // ============================================================
    // MARK: - Windowing (full days only, ends yesterday)
    // ============================================================

    private func windowedCarbs() -> [DailyCarbsEntry] {
        windowFullDays(dailyCarbs90, windowDays: windowDays) { $0.date }
    }

    private func windowedActiveEnergy() -> [ActivityEnergyEntry] {
        windowFullDays(dailyActiveEnergy90, windowDays: windowDays) { $0.date }
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

private struct ReportLifestyleImpactSectionV1_PreviewWrapper: View {

    private var carbs: [DailyCarbsEntry] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (1...30).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyCarbsEntry(date: d, grams: 120 + (offset % 7) * 12)
        }
    }

    private var energy: [ActivityEnergyEntry] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (1...30).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return ActivityEnergyEntry(date: d, activeEnergy: 420 + (offset % 6) * 55)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReportLifestyleImpactSectionV1(
                windowDays: 30,
                dailyCarbs90: carbs,
                dailyActiveEnergy90: energy
            )
        }
        .padding(16)
        .background(Color.white)
    }
}

#Preview("Report — Lifestyle Impact") {
    ReportLifestyleImpactSectionV1_PreviewWrapper()
}
