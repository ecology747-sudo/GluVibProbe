//
//  AveragePeriodsScaledBarChart.swift
//  GluVibProbe
//
//  Pilot-Version mit externer Y-Skalierung für Perioden-Durchschnittswerte.
//  - Verwendet PeriodAverageEntry (z. B. 7T / 14T / 30T / 90T / 180T / 365T).
//  - Skaleninfos (Ticks, yMax, Label-Formatter) kommen von außen (MetricScaleHelper).
//

import SwiftUI
import Charts

struct AveragePeriodsScaledBarChart: View {

    // MARK: - Eingaben

    let data: [PeriodAverageEntry]
    let metricLabel: String
    let barColor: Color
    let goalValue: Double?

    let yAxisTicks: [Double]
    let yMax: Double
    let valueLabel: (Double) -> String

    // MARK: - Abgeleitete Daten – sortiert: 365 → 7 (links nach rechts)

    private var sortedData: [PeriodAverageEntry] {
        data.sorted { $0.days > $1.days }
    }

    // MARK: - Init

    init(
        data: [PeriodAverageEntry],
        metricLabel: String,
        barColor: Color,
        goalValue: Double? = nil,
        yAxisTicks: [Double],
        yMax: Double,
        valueLabel: @escaping (Double) -> String
    ) {
        self.data = data
        self.metricLabel = metricLabel
        self.barColor = barColor
        self.goalValue = goalValue
        self.yAxisTicks = yAxisTicks
        self.yMax = yMax
        self.valueLabel = valueLabel
    }

    // MARK: - Body

    var body: some View {
        Chart {

            // 🔸 Balken – Liquid-Glas Design
            ForEach(sortedData) { entry in
                BarMark(
                    x: .value("Period", entry.label),
                    y: .value(metricLabel, Double(entry.value))
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

            // 🔹 Ziel-Linie
            if let goalValue {
                RuleMark(
                    y: .value("Goal", goalValue)
                )
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(.green)
            }
        }

        // 🔹 Plot-Hintergrund (Glas-Optik)
        .chartPlotStyle { plot in
            plot
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        // 🔹 Y-Achse – extern gesteuert
        .chartYScale(domain: 0...yMax)
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

        // 🔹 X-Achse – jetzt größer + dicker + Ø
        .chartXAxis {
            AxisMarks { value in

                AxisGridLine().foregroundStyle(Color.gray.opacity(0.22))
                AxisTick()

                AxisValueLabel {
                    if let raw = value.as(String.self) {
                        let numberPart = raw.trimmingCharacters(in: .letters)
                        Text("Ø\(numberPart)")
                            .font(.system(size: 13, weight: .bold)) // ⭐ größer + dicker
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                    }
                }
            }
        }
    }
}


// MARK: - Preview

#Preview("AveragePeriodsScaledBarChart – Demo") {
    let demoData: [PeriodAverageEntry] = [
        .init(label: "7T",   days: 7,   value: 2100),
        .init(label: "14T",  days: 14,  value: 2200),
        .init(label: "30T",  days: 30,  value: 2300),
        .init(label: "90T",  days: 90,  value: 2400),
        .init(label: "180T", days: 180, value: 2450),
        .init(label: "365T", days: 365, value: 2500)
    ]

    let values = demoData.map { Double($0.value) }
    let scale = MetricScaleHelper.energyKcalScale(for: values)

    AveragePeriodsScaledBarChart(
        data: demoData,
        metricLabel: "Energy",
        barColor: Color.Glu.nutritionAccent,
        goalValue: 2300,
        yAxisTicks: scale.yAxisTicks,
        yMax: scale.yMax,
        valueLabel: scale.valueLabel
    )
    .frame(height: 260)
    .padding()
    .background(Color.Glu.backgroundSurface)
}
