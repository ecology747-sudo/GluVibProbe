//
//  MonthlyScaledBarChart.swift
//  GluVibProbe
//
//  Pilot-Version mit externer Y-Skalierung für Monatsdaten.
//  - verwendet MonthlyMetricEntry (z. B. "Jan", "Feb", "Mär", ...)
//  - Skaleninfos (Ticks, yMax, Label-Formatter) kommen von außen (MetricScaleHelper)
//  - Optik: Liquid-Glas-Balken, einheitliche Grid-Linien wie die anderen Scaled-Charts
//

import SwiftUI
import Charts

struct MonthlyScaledBarChart: View {

    // MARK: - Eingaben

    /// Monatsdaten, z. B. "Jan", "Feb", ... mit einem Wert (z. B. g / Monat)
    let data: [MonthlyMetricEntry]

    /// Name der Metrik (z. B. "Carbs / Month")
    let metricLabel: String

    /// Domain-Farbe
    let barColor: Color

    /// Vollständige Y-Ticks vom Helper (können sehr fein sein)
    let yAxisTicks: [Double]

    /// Oberer Y-Wert für die Chart-Skala
    let yMax: Double

    /// Formatter-Funktion für Y-Achsenlabels
    let valueLabel: (Double) -> String

    /// Optional: Monats-Ziellinie
    let goalValue: Double?

    /// Kleine Luft nach oben, damit Labels nicht abgeschnitten werden
    private var yMaxWithHeadroom: Double {
        yMax * 1.08
    }

    /// Reduzierte Tick-Liste für die Anzeige
    private var displayedTicks: [Double] {
        guard yAxisTicks.count > 7 else { return yAxisTicks }

        let maxLabels = 6
        let step = max(1, yAxisTicks.count / maxLabels)

        return yAxisTicks.enumerated().compactMap { index, value in
            index % step == 0 ? value : nil
        }
    }

    // MARK: - Init

    init(
        data: [MonthlyMetricEntry],
        metricLabel: String,
        barColor: Color,
        yAxisTicks: [Double],
        yMax: Double,
        valueLabel: @escaping (Double) -> String,
        goalValue: Double? = nil
    ) {
        self.data = data
        self.metricLabel = metricLabel
        self.barColor = barColor
        self.yAxisTicks = yAxisTicks
        self.yMax = yMax
        self.valueLabel = valueLabel
        self.goalValue = goalValue
    }

    // MARK: - Body

    var body: some View {
        Chart {

            // 🔸 Monats-Balken (Liquid-Glas-Optik) + Wert oben drüber
            ForEach(data) { entry in
                let value = Double(entry.value)

                BarMark(
                    x: .value("Month", entry.monthShort),
                    y: .value(metricLabel, value)
                )
                .foregroundStyle(
                    .linearGradient(
                        Gradient(colors: [
                            barColor.opacity(0.45),   // oben etwas transparenter
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
                // 🔹 Wert direkt über dem Balken – nur Zahl, keine Einheit
                .annotation(position: .top, alignment: .center) {
                    Text("\(Int(value.rounded()))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                        .padding(.bottom, 2)
                }
            }

            // 🔹 Optional: Monats-Ziellinie
            if let goalValue {
                RuleMark(
                    y: .value("MonthlyGoal", goalValue)
                )
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(.green)
            }
        }

        // Plot-Area im Glas-Stil (wie die anderen Scaled-Charts)
        .chartPlotStyle { plot in
            plot
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        // Y-Achse – Skala mit Headroom
        .chartYScale(domain: 0...yMaxWithHeadroom)
        .chartYAxis {
            AxisMarks(position: .trailing, values: displayedTicks) { value in

                AxisGridLine().foregroundStyle(Color.gray.opacity(0.22))
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

        // X-Achse – Monatskürzel (Aug, Sep, …)
        .chartXAxis {
            AxisMarks { value in

                AxisGridLine().foregroundStyle(Color.gray.opacity(0.22))
                AxisTick()

                AxisValueLabel {
                    if let month = value.as(String.self) {
                        Text(month)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                    }
                }
            }
        }
    }
}


// MARK: - Preview

#Preview("MonthlyScaledBarChart – Demo") {
    let demoData: [MonthlyMetricEntry] = [
        .init(monthShort: "Aug", value: 6000),
        .init(monthShort: "Sep", value: 6100),
        .init(monthShort: "Oct", value: 3035),
        .init(monthShort: "Nov", value: 4944),
        .init(monthShort: "Dec", value: 458)
    ]

    let values = demoData.map { Double($0.value) }
    let scale = MetricScaleHelper.scale(values, for: .grams)

    MonthlyScaledBarChart(
        data: demoData,
        metricLabel: "Carbs / Month",
        barColor: Color.Glu.nutritionAccent,
        yAxisTicks: scale.yAxisTicks,
        yMax: scale.yMax,
        valueLabel: scale.valueLabel
    )
    .frame(height: 260)
    .padding()
    .background(Color.Glu.backgroundSurface)
}
