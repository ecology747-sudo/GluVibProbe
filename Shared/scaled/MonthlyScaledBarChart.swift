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

    /// Monatsdaten, z. B. "Jan", "Feb", ... mit einem Wert (z. B. kcal pro Monat)
    let data: [MonthlyMetricEntry]

    /// Name der Metrik (z. B. "Energy / Month")
    let metricLabel: String

    /// Domain-Farbe
    let barColor: Color

    /// Vollständige Y-Ticks vom Helper (können sehr fein sein)
    let yAxisTicks: [Double]

    /// Oberer Y-Wert für die Chart-Skala
    let yMax: Double

    /// Formatter-Funktion für Y-Achsenlabels
    let valueLabel: (Double) -> String

    /// Optional: Monats-Ziellinie (aktuell nicht genutzt, aber vorbereitet)
    let goalValue: Double?

    // MARK: - Abgeleitete Werte

    /// Reduzierte Tick-Liste für die Anzeige:
    /// Wir nehmen nur jede n-te Marke, damit die Labels nicht mehr übereinander kleben.
    private var displayedTicks: [Double] {
        guard yAxisTicks.count > 7 else { return yAxisTicks }

        // maximal ca. 6–7 Labels
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

            // 🔸 Monats-Balken (Liquid-Glas-Optik)
            ForEach(data) { entry in
                BarMark(
                    x: .value("Month", entry.monthShort),
                    y: .value(metricLabel, Double(entry.value))
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

        // Y-Achse – Skala vollständig von außen geliefert
        .chartYScale(domain: 0...yMax)
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

        // X-Achse – Monatskürzel (Aug, Sep, Oct, …)
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
        .init(monthShort: "Aug", value: 62_000),
        .init(monthShort: "Sep", value: 58_500),
        .init(monthShort: "Oct", value: 64_200),
        .init(monthShort: "Nov", value: 61_300),
        .init(monthShort: "Dec", value: 63_900)
    ]

    let values = demoData.map { Double($0.value) }
    let scale = MetricScaleHelper.energyKcalScale(for: values)

    MonthlyScaledBarChart(
        data: demoData,
        metricLabel: "Energy / Month",
        barColor: Color.Glu.nutritionAccent,
        yAxisTicks: scale.yAxisTicks,
        yMax: scale.yMax,
        valueLabel: scale.valueLabel
    )
    .frame(height: 260)
    .padding()
    .background(Color.Glu.backgroundSurface)
}
