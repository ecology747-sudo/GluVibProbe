//
//  AveragePeriodsBarChart.swift
//  GluVibProbe
//

import SwiftUI
import Charts

// MARK: - Datenmodell für Durchschnitts-Chart

struct PeriodAverageEntry: Identifiable {
    let id = UUID()
    let label: String      // "7T", "14T", "30T", etc.
    let days: Int          // 7, 14, 30, 90, 180, 365
    let value: Int         // Durchschnittswert
}

// MARK: - CHART VIEW

struct AveragePeriodsBarChart: View {

    // MARK: - Input

    let data: [PeriodAverageEntry]
    let metricLabel: String              // z. B. "Steps", "kcal", "g"
    let goalValue: Int?                  // optionale Zielwert-Linie
    let barColor: Color                  // Domain-Farbe
    let scaleType: MetricScaleType       // Steps / smallInteger / percent
    let valueFormatter: (Int) -> String  // Formatierung des Balkenlabels

    // MARK: - Sortierte Daten (365T → 7T)

    /// Sortiert die Perioden von groß nach klein (z. B. 365T, 180T, ..., 7T)
    private var sortedData: [PeriodAverageEntry] {
        data.sorted { $0.days > $1.days }
    }

    // MARK: - Y-Achsen-Ticks

    private var yAxisTickValues: [Int] {
        guard let maxData = sortedData.map(\.value).max() else { return [0] }

        // Zielwert einbeziehen
        let maxGoal = goalValue ?? 0
        let maxValue = max(maxData, maxGoal)

        if maxValue <= 0 { return [0] }

        switch scaleType {

        case .steps:
            // Schrittweite 2000 ähnlich wie in Last90DaysBarChart
            let step = 2_000
            let upper = ((maxValue + step - 1) / step) * step
            return Array(stride(from: 0, through: upper, by: step))

        case .smallInteger:
            // z. B. Minuten, kcal, g – dynamisch
            let step: Int
            if maxValue <= 200 { step = 20 }
            else if maxValue <= 500 { step = 50 }
            else { step = 100 }
            let upper = ((maxValue + step - 1) / step) * step
            return Array(stride(from: 0, through: upper, by: step))

        case .percent:
            return Array(stride(from: 0, through: 100, by: 20))
        }
    }

    // MARK: - Body

    var body: some View {
        Chart {

            // ---------- BALKEN ----------
            ForEach(sortedData) { entry in
                BarMark(
                    x: .value("Period", entry.label),
                    y: .value(metricLabel, entry.value)
                )
                .foregroundStyle(barColor.gradient)
                .cornerRadius(4)
                .annotation(position: .top) {
                    Text(valueFormatter(entry.value))
                        .font(.caption2.bold())
                        .foregroundColor(Color.Glu.primaryBlue)
                        .padding(.bottom, 2)
                }
            }

            // ---------- ZIELWERT-LINIE ----------
            if let goal = goalValue {
                RuleMark(
                    y: .value("Goal", goal)
                )
                .lineStyle(.init(lineWidth: 1.4, dash: [6, 6]))
                .foregroundStyle(Color.green)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: yAxisTickValues) { value in

                AxisGridLine().foregroundStyle(Color.gray.opacity(0.25))
                AxisTick()

                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        switch scaleType {
                        case .steps:
                            if v >= 1_000 {
                                Text("\(v / 1_000)T")
                            } else {
                                Text("\(v)")
                            }

                        case .smallInteger:
                            Text("\(v)")

                        case .percent:
                            Text("\(v)%")
                        }
                    }
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.85))
            }
        }
        .chartXAxis {
            AxisMarks(values: sortedData.map { $0.label }) { value in
                AxisValueLabel {
                    if let text = value.as(String.self) {
                        Text("Ø \(text.filter { $0.isNumber })")
                    }
                }
                .font(.caption2.bold())
                .foregroundStyle(Color.Glu.primaryBlue)
            }
        }
        .frame(height: 240)  // Basishöhe analog zu deinen anderen Charts
    }
}

// MARK: - Preview

#Preview("Average Periods Chart Demo") {

    let demo = [
        PeriodAverageEntry(label: "7T",   days: 7,   value: 8_417),
        PeriodAverageEntry(label: "14T",  days: 14,  value: 8_010),
        PeriodAverageEntry(label: "30T",  days: 30,  value: 7_560),
        PeriodAverageEntry(label: "90T",  days: 90,  value: 7_100),
        PeriodAverageEntry(label: "180T", days: 180, value: 6_900),
        PeriodAverageEntry(label: "365T", days: 365, value: 6_800)
    ]

    return AveragePeriodsBarChart(
        data: demo,
        metricLabel: "Steps",
        goalValue: 10_000,
        barColor: Color.Glu.activityOrange,
        scaleType: .steps,
        valueFormatter: { value in
            // einfache Demo-Formatierung
            let f = NumberFormatter()
            f.numberStyle = .decimal
            return f.string(from: NSNumber(value: value)) ?? "\(value)"
        }
    )
    .padding()
    .background(Color.Glu.backgroundSurface)
}
