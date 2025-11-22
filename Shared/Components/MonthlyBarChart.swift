//
//  MonthlyBarChart.swift
//  GluVibProbe
//

import SwiftUI
import Charts

struct MonthlyMetricEntry: Identifiable {
    let id = UUID()
    let monthShort: String
    let value: Int
}

struct MonthlyBarChart: View {
    let data: [MonthlyMetricEntry]

    /// Hilfsfunktion: 82000 → "82 T"
    private func formatToT(_ number: Int) -> String {
        let t = Double(number) / 1000.0
        let rounded = Int(t.rounded())   // auf ganze T runden
        return "\(rounded) T"
    }

    var body: some View {
        Chart {
            ForEach(data) { entry in
                BarMark(
                    x: .value("Month", entry.monthShort),
                    y: .value("Value", entry.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.Glu.activityOrange.opacity(0.95),
                            Color.Glu.activityOrange.opacity(0.45)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)

                // 🔸 Abgekürzte Monatswerte (z. B. "82 T")
                .annotation(position: .top) {
                    Text(formatToT(entry.value))
                        .font(.caption.bold())
                        .foregroundColor(Color.Glu.primaryBlue)
                        .padding(.bottom, 2)
                }
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: data.map { $0.monthShort }) { value in
                AxisValueLabel {
                    if let m = value.as(String.self) {
                        Text(m)
                            .font(.caption.bold())
                            .foregroundColor(Color.Glu.primaryBlue)
                    }
                }
            }
        }
    }
}

#Preview("Monthly Bar Chart – Demo") {
    let sampleData: [MonthlyMetricEntry] = [
        .init(monthShort: "Jan", value: 82000),
        .init(monthShort: "Feb", value: 76500),
        .init(monthShort: "Mar", value: 91200),
        .init(monthShort: "Apr", value: 88300),
        .init(monthShort: "May", value: 95100),
        .init(monthShort: "Jun", value: 87400)
    ]

    MonthlyBarChart(data: sampleData)
        .padding()
        .frame(height: 260)
}
