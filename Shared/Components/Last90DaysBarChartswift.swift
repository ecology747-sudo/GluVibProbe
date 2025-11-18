//
//  Last90DaysBarChart.swift
//  GluVibProbe
//

import SwiftUI
import Charts

struct DailyStepsEntry: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Int
}

// 🔴 Trend-Punkt für die Trendlinie (linear)
struct DailyStepsTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Double
}

struct Last90DaysBarChart: View {
    let data: [DailyStepsEntry]
    
    // 🔴 LINEARE TRENDLINIE wie in Excel
    private var trendData: [DailyStepsTrendPoint] {
        // Mindestens 2 Punkte für Regression nötig
        guard data.count > 1 else { return [] }
        
        // x = 0,1,2,... (Index), y = Steps
        let xs: [Double] = data.indices.map { Double($0) }
        let ys: [Double] = data.map { Double($0.steps) }
        let n = Double(data.count)
        
        let sumX  = xs.reduce(0, +)
        let sumY  = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumX2 = xs.reduce(0) { $0 + $1 * $1 }
        
        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else { return [] }
        
        let m = (n * sumXY - sumX * sumY) / denom     // Steigung
        let b = (sumY - m * sumX) / n                 // Achsenabschnitt
        
        // Für jeden Tag den "Trend-Steps"-Wert berechnen
        return data.indices.map { i in
            let x = Double(i)
            let yTrend = m * x + b
            return DailyStepsTrendPoint(
                date: data[i].date,
                steps: yTrend
            )
        }
    }
    
    var body: some View {
        Chart {
            // 🟦 Balken wie bisher
            ForEach(data) { entry in
                BarMark(
                    x: .value("Date", entry.date),
                    y: .value("Steps", entry.steps),
                    width: .fixed(2)         // schmalere Balken
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.95),
                            Color.accentColor.opacity(0.45)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
            }
            
            // 🔴 GESTRICHENE TRENDLINIE (linear)
            ForEach(trendData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Trend", point.steps)
                )
                .foregroundStyle(Color.red)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
        }
        // ⬇️ Platz unter dem Plot (für Labels)
        .chartPlotStyle { plot in
            plot
                .padding(.bottom, 4)
        }
        
        // ⬇️ X-Achse: alle 10 Tage, nur Tag anzeigen
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 10)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.day())
                            .font(.caption2)
                    }
                }
            }
        }
        
        // ⬇️ Y-Achse: alle 2.000 Schritte beschriften — LINKS
        .chartYAxis {
            AxisMarks(
                position: .leading,
                values: Array(stride(from: 0, through: 18000, by: 2000))
            ) { value in
                AxisGridLine()
                    .foregroundStyle(.gray.opacity(0.2))
                
                AxisValueLabel()
                    .font(.caption2)
            }
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    let demoData: [DailyStepsEntry] = (0..<90).compactMap { offset in
        guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
            return nil
        }
        return DailyStepsEntry(
            date: date,
            steps: Int.random(in: 2_000...12_000)
        )
    }
    .sorted { $0.date < $1.date }

    return Last90DaysBarChart(data: demoData)
        .frame(height: 240)
        .padding()
}
