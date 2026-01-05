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

    /// Kleine Luft nach oben, damit Labels über hohen Balken nicht abgeschnitten werden
    private var yMaxWithHeadroom: Double {
        yMax * 1.06      // 8 % Headroom
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

            // 🔸 Balken – Liquid-Glas Design + Wert oben drüber
            ForEach(sortedData) { entry in
                let doubleValue = Double(entry.value)

                BarMark(
                    x: .value("Period", entry.label),
                    y: .value(metricLabel, doubleValue)
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
                // 🔹 Wert direkt über dem Balken – formatiert über valueLabel (BMI: 261 -> 26,1)
                .annotation(position: .top, alignment: .center) {
                    Text(valueLabel(doubleValue))                           // !!! FIX
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                        .padding(.bottom, 2)
                }
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

        // 🔹 Y-Achse – extern gesteuert + Headroom
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

        // 🔹 X-Achse – Ø dünn, Zahl fett
        .chartXAxis {
            AxisMarks { value in

                AxisGridLine().foregroundStyle(Color.gray.opacity(0.22))
                AxisTick()

                AxisValueLabel {
                    if let raw = value.as(String.self) {
                        let numberPart = raw.trimmingCharacters(in: .letters)

                        HStack(spacing: 0) {
                            Text("Ø")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))

                            Text(numberPart)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                        }
                    }
                }
            }
        }
    }
}


// MARK: - Preview

#Preview("AveragePeriodsScaledBarChart – Demo") {
    let demoData: [PeriodAverageEntry] = [
        .init(label: "7T",   days: 7,   value: 216),
        .init(label: "14T",  days: 14,  value: 199),
        .init(label: "30T",  days: 30,  value: 188),
        .init(label: "90T",  days: 90,  value: 171),
        .init(label: "180T", days: 180, value: 180),
        .init(label: "365T", days: 365, value: 190)
    ]

    let values = demoData.map { Double($0.value) }
    let scale = MetricScaleHelper.scale(values, for: .grams)

    AveragePeriodsScaledBarChart(
        data: demoData,
        metricLabel: "Carbs",
        barColor: Color.Glu.nutritionAccent,
        goalValue: 250,
        yAxisTicks: scale.yAxisTicks,
        yMax: scale.yMax,
        valueLabel: scale.valueLabel
    )
    .frame(height: 260)
    .padding()
    .background(Color.Glu.backgroundSurface)
}
