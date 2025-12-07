//
//  Last90DaysScaledLineChart.swift
//  GluVibProbe
//
//  Vereinfachtes 90-Tage-Liniendiagramm:
//  - eine Datenlinie
//  - Punkte auf der Linie
//  - optional: grüne Goal-Linie
//

import SwiftUI
import Charts

struct Last90DaysScaledLineChart<DataPoint: Identifiable>: View {

    // MARK: - Eingaben

    let data: [DataPoint]

    let yAxisTicks: [Double]
    let yMax: Double
    let valueLabel: (Double) -> String

    let lineColor: Color
    let goalValue: Double?
    let lineWidth: CGFloat

    let xValue: (DataPoint) -> Date
    let yValue: (DataPoint) -> Double

    // MARK: - Abgeleitete Daten

    private var sortedData: [DataPoint] {
        data.sorted { xValue($0) < xValue($1) }
    }

    private var yMaxWithHeadroom: Double {
        yMax * 1.06
    }

    // MARK: - Body

    var body: some View {
        Chart {

            // 🔹 EINZIGE Datenlinie + Punkte
            ForEach(sortedData) { point in
                let x = xValue(point)
                let y = yValue(point)

                LineMark(
                    x: .value("Date", x),
                    y: .value("Value", y)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(.init(lineWidth: 1.5))
                .foregroundStyle(lineColor)

                PointMark(
                    x: .value("Date", x),
                    y: .value("Value", y)
                )
                .symbolSize(18)
                .foregroundStyle(lineColor.opacity(0.95))
            }

            // 🔹 optionale Ziel-Linie (für Weight etc.; bei Resting HR ist goalValue = nil)
            if let goalValue {
                RuleMark(
                    y: .value("Goal", goalValue)
                )
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(Color.green)
            }
        }
        // Plot-Hintergrund
        .chartPlotStyle { plot in
            plot
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        // Y-Achse
        .chartYScale(domain: 0...yMaxWithHeadroom)
        .chartYAxis {
            AxisMarks(position: .trailing, values: yAxisTicks) { val in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.22))
                AxisTick()

                if let doubleVal = val.as(Double.self) {
                    AxisValueLabel {
                        Text(valueLabel(doubleVal))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.9))
                    }
                }
            }
        }

        // X-Achse – Datum minimal
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { val in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.18))
                AxisTick()

                if let date = val.as(Date.self) {
                    AxisValueLabel {
                        Text(date.formatted(.dateTime.day()))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                    }
                }
            }
        }
    }
}
