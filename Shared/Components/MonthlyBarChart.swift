//
//  MonthlyBarChart.swift
//  GluVibProbe
//

import SwiftUI
import Charts

// MARK: - Datenmodell

struct MonthlyMetricEntry: Identifiable {
    let id = UUID()
    let monthShort: String   // "Jan", "Feb", ...
    let value: Int           // Aggregierter Monatswert
}

// MARK: - View

struct MonthlyBarChart: View {

    // MARK: - Input

    let data: [MonthlyMetricEntry]
    let metricLabel: String          // z. B. "Steps / Month", "kcal / Month"
    let barColor: Color              // Domain-Farbe (BodyActivity, Nutrition, Metabolic)
    let scaleType: MetricScaleType   // .steps / .smallInteger / .percent

    // MARK: - Init

    init(
        data: [MonthlyMetricEntry],
        metricLabel: String = "Value / Month",
        barColor: Color = Color.Glu.activityOrange,
        scaleType: MetricScaleType = .steps
    ) {
        self.data = data
        self.metricLabel = metricLabel
        self.barColor = barColor
        self.scaleType = scaleType
    }

    // MARK: - Y-Achsen-Ticks

    private var yAxisTickValues: [Int] {
        guard let maxData = data.map(\.value).max() else { return [0] }

        let maxValue = maxData

        if maxValue <= 0 { return [0] }

        switch scaleType {

        case .steps:
            // Schritte pro Monat → eher große Zahlen
            let step: Int
            if maxValue <= 40_000 {
                step = 10_000
            } else if maxValue <= 100_000 {
                step = 20_000
            } else {
                step = 40_000
            }
            let upper = ((maxValue + step - 1) / step) * step
            return Array(stride(from: 0, through: upper, by: step))

        case .smallInteger:
            // z. B. g, kcal, Minuten – dynamisch
            let step: Int

            if maxValue <= 200 {
                step = 20              // 0, 20, 40, ...
            } else if maxValue <= 500 {
                step = 50              // 0, 50, 100, ...
            } else if maxValue <= 2_000 {
                step = 100             // 0, 100, 200, ...
            } else if maxValue <= 10_000 {
                step = 500             // 0, 500, 1 000, ...
            } else if maxValue <= 20_000 {
                step = 2_000           // 0, 2 000, 4 000, ... 20 000
            } else {
                step = 5_000           // 0, 5 000, 10 000, ... (extrem hohe Werte)
            }

            let upper = ((maxValue + step - 1) / step) * step
            return Array(stride(from: 0, through: upper, by: step))

        case .percent:
            return Array(stride(from: 0, through: 100, by: 20))
        }
    }

    // MARK: - Label-Formatter (für Annotation)

    private func formattedBarLabel(_ value: Int) -> String {
        switch scaleType {
        case .steps:
            // 82 000 → "82 T"
            let t = Double(value) / 1000.0
            let rounded = Int(t.rounded())
            return "\(rounded) T"

        case .smallInteger:
            return "\(value)"

        case .percent:
            return "\(value) %"
        }
    }

    // MARK: - Body

    var body: some View {
        Chart {
            ForEach(data) { entry in
                BarMark(
                    x: .value("Month", entry.monthShort),
                    y: .value(metricLabel, entry.value)
                )
                .foregroundStyle(barColor.gradient)
                .cornerRadius(4)

                // Balken-Label oben drauf
                .annotation(position: .top) {
                    Text(formattedBarLabel(entry.value))
                        .font(.caption2.bold())
                        .foregroundColor(Color.Glu.primaryBlue)
                        .padding(.bottom, 2)
                }
            }
        }
        // Y-Achse rechts, CI-konforme Labels
        .chartYAxis {
            AxisMarks(position: .trailing, values: yAxisTickValues) { value in

                AxisGridLine().foregroundStyle(Color.gray.opacity(0.25))
                AxisTick()

                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        switch scaleType {
                        case .steps:
                            if v >= 1000 {
                                Text("\(v / 1000)T")
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
            AxisMarks(values: data.map { $0.monthShort }) { value in
                AxisValueLabel {
                    if let m = value.as(String.self) {
                        Text("\(m)")
                    }
                }
                .font(.caption.bold())
                .foregroundStyle(Color.Glu.primaryBlue)
            }
        
            
        }
        .frame(height: 260)
    }
}

// MARK: - Preview

#Preview("Monthly Bar Chart – Steps Demo") {
    let sampleDataSteps: [MonthlyMetricEntry] = [
        .init(monthShort: "Jan", value: 82_000),
        .init(monthShort: "Feb", value: 76_500),
        .init(monthShort: "Mar", value: 91_200),
        .init(monthShort: "Apr", value: 88_300),
        .init(monthShort: "May", value: 95_100),
        .init(monthShort: "Jun", value: 87_400)
    ]

    return MonthlyBarChart(
        data: sampleDataSteps,
        metricLabel: "Steps / Month",
        barColor: Color.Glu.activityOrange,
        scaleType: .steps
    )
    .padding()
    .background(Color.Glu.backgroundSurface)
}
