//
//  Last90DaysScaledBarChart.swift
//  GluVibProbe
//
//  Skaliertes 90-Tage-Diagramm.
//  - Liquid-Glas-Balken
//  - Ziellinie
//  - Trendlinie
//  - externe Y-Skala (MetricScaleHelper)
//

import SwiftUI
import Charts

struct Last90DaysScaledBarChart<DataPoint>: View {

    // MARK: - Eingaben

    let data: [DataPoint]
    let yAxisTicks: [Double]
    let yMax: Double
    let valueLabel: (Double) -> String
    let barColor: Color
    let goalValue: Double?
    let barWidth: CGFloat

    let xValue: (DataPoint) -> Date
    let yValue: (DataPoint) -> Double

    // MARK: - Daten sortiert für Trendlinie

    private var sortedData: [DataPoint] {
        data.sorted { xValue($0) < xValue($1) }
    }

    // MARK: - Trendlinie (lineare Regression)

    private var trendPoints: [(date: Date, value: Double)] {
        let pts = sortedData
        guard pts.count > 1 else { return [] }

        let ys = pts.map { yValue($0) }
        let xs = pts.indices.map { Double($0) }
        let n = Double(pts.count)

        let sumX  = xs.reduce(0, +)
        let sumY  = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumX2 = xs.reduce(0) { $0 + $1 * $1 }

        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else { return [] }

        let m = (n * sumXY - sumX * sumY) / denom
        let b = (sumY - m * sumX) / n

        return zip(pts.indices, pts).map { idx, point in
            let x = Double(idx)
            let yPred = m * x + b
            return (xValue(point), yPred)
        }
    }

    // MARK: - Body

    var body: some View {
        Chart {

            // 🔸 Liquid-Glas-Balken
            ForEach(Array(sortedData.enumerated()), id: \.offset) { _, entry in
                let date = xValue(entry)
                let yVal = yValue(entry)

                BarMark(
                    x: .value("Date", date),
                    y: .value("Value", yVal),
                    width: .fixed(barWidth)
                )
                .foregroundStyle(
                    .linearGradient(
                        Gradient(colors: [
                            barColor.opacity(0.45),   // oben transparenter
                            barColor.opacity(0.95)    // unten kräftig
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(5)
                .shadow(
                    color: barColor.opacity(0.16),
                    radius: 2.5,
                    x: 0,
                    y: 1.5
                )
            }

            // 🔹 Ziellinie
            if let goalValue {
                RuleMark(
                    y: .value("Goal", goalValue)
                )
                .lineStyle(StrokeStyle(lineWidth: 1.8, dash: [6, 6]))
                .foregroundStyle(.green)
            }

            // 🔴 Trendlinie
            ForEach(trendPoints, id: \.date) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Trend", p.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 1.8, dash: [4, 3]))
            }
        }

        // 🔹 Gläserischer Plot-Hintergrund
        .chartPlotStyle { plot in
            plot
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        // 🔹 X-Achse – größere Schrift
        .chartXScale(range: .plotDimension(padding: 16))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in

                AxisGridLine().foregroundStyle(Color.gray.opacity(0.22))
                AxisTick()

                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.day())
                            .font(.system(size: 13, weight: .bold))   // ⭐ größer + dicker
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                    }
                }
            }
        }

        // 🔹 Y-Achse – gleiche Grid-Optik wie AveragePeriods
        .chartYScale(domain: 0...yMax)
        .chartYAxis {
            AxisMarks(position: .trailing, values: yAxisTicks) { value in

                AxisGridLine().foregroundStyle(Color.gray.opacity(0.22))  // einheitlich
                AxisTick()

                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(valueLabel(v))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.9))
                    }
                }
            }
        }
    }
}


// MARK: - Preview

#Preview("Last90DaysScaledBarChart – Demo") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    let entries: [DailyStepsEntry] = (0..<90).compactMap { offset in
        guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
        return DailyStepsEntry(date: date, steps: Int.random(in: 2000...6000))
    }
    .sorted { $0.date < $1.date }

    let values = entries.map { Double($0.steps) }
    let scale = MetricScaleHelper.scale(values, for: .energyDaily)

    Last90DaysScaledBarChart(
        data: entries,
        yAxisTicks: scale.yAxisTicks,
        yMax: scale.yMax,
        valueLabel: scale.valueLabel,
        barColor: Color.Glu.nutritionAccent,
        goalValue: 2500,
        barWidth: 6,
        xValue: { $0.date },
        yValue: { Double($0.steps) }
    )
    .frame(height: 260)
    .padding()
    .background(Color.Glu.backgroundSurface)
}
