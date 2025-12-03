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
    let value: Int           // Aggregierter Monatswert (z. B. Steps, kcal, Minuten Schlaf)
}

// MARK: - View

struct MonthlyBarChart: View {

    // MARK: - Input

    let data: [MonthlyMetricEntry]
    let metricLabel: String
    let barColor: Color
    let scaleType: MetricScaleType

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
            let step: Int
            if maxValue <= 40_000 { step = 10_000 }
            else if maxValue <= 100_000 { step = 20_000 }
            else { step = 40_000 }

            let upper = ((maxValue + step - 1) / step) * step
            return Array(stride(from: 0, through: upper, by: step))

        case .smallInteger:
            let step: Int
            if maxValue <= 200 { step = 20 }
            else if maxValue <= 500 { step = 50 }
            else if maxValue <= 2_000 { step = 100 }
            else if maxValue <= 10_000 { step = 500 }
            else if maxValue <= 20_000 { step = 2_000 }
            else { step = 5_000 }

            let upper = ((maxValue + step - 1) / step) * step
            return Array(stride(from: 0, through: upper, by: step))

        // 🔥 Nutrition Energy — immer 500er-Intervalle
        case .nutritionEnergyDaily,
             .nutritionEnergyMonthly:
            let step = 500
            let upper = ((maxValue + step - 1) / step) * step
            return Array(stride(from: 0, through: upper, by: step))

        case .percent:
            return Array(stride(from: 0, through: 100, by: 20))

        case .hours:
            let maxHours = Double(maxValue) / 60.0

            let stepHours: Double
            if maxHours <= 50 { stepHours = 10 }
            else if maxHours <= 150 { stepHours = 20 }
            else { stepHours = 50 }

            let upperHours = ceil(maxHours / stepHours) * stepHours
            let upperMinutes = Int(upperHours * 60.0)

            return Array(
                stride(
                    from: 0,
                    through: upperMinutes,
                    by: Int(stepHours * 60.0)
                )
            )
        }
    }

    // MARK: - Formatter für Balken-Labels

    private func formattedBarLabel(_ value: Int) -> String {
        switch scaleType {

        case .steps:
            let t = Double(value) / 1000.0
            return "\(Int(t.rounded())) T"

        case .smallInteger,
             .nutritionEnergyDaily,
             .nutritionEnergyMonthly:
            return "\(value)"

        case .percent:
            return "\(value) %"

        case .hours:
            let hours = Int((Double(value) / 60.0).rounded())
            return "\(hours) h"
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

                .annotation(position: .top) {
                    Text(formattedBarLabel(entry.value))
                        .font(.caption2.bold())
                        .foregroundColor(Color.Glu.primaryBlue)
                }
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
                            if v >= 1_000 { Text("\(v / 1_000)T") }
                            else { Text("\(v)") }

                        case .smallInteger,
                             .nutritionEnergyDaily,
                             .nutritionEnergyMonthly:
                            Text("\(v)")

                        case .percent:
                            Text("\(v)%")

                        case .hours:
                            let hours = Int((Double(v) / 60.0).rounded())
                            Text("\(hours) h")
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
                        Text(m)
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
