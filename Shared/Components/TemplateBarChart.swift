//
//  TemplateBarChart.swift
//  GluVibProbe
//

import SwiftUI
import Charts

private struct DayBar: Identifiable {
    let id = UUID()
    let index: Int      // 0 = ältester Tag
    let value: Int
}

struct TemplateBarChart: View {
    let data: [Int]     // z.B. last30Days

    private var bars: [DayBar] {
        data.enumerated().map { DayBar(index: $0.offset, value: $0.element) }
    }

    var body: some View {
        if bars.isEmpty {
            Text("No step data for this period")
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(bars) { bar in
                BarMark(
                    x: .value("Day", bar.index),
                    y: .value("Steps", bar.value)
                )
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: [0, bars.count - 1]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intVal = value.as(Int.self) {
                            Text(intVal == bars.count - 1 ? "Today" : "Start")
                                .font(.caption2)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    TemplateBarChart(data: [3000, 4500, 6000, 8000, 7500, 9000, 5000])
}
