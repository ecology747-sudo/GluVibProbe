//
//  MovementSplit30DayChart.swift
//  GluVibProbe
//
//  30-Tage-Stacked-Bar-Chart für Movement Split:
//  - Sleep Morning (unten)
//  - Active (direkt darüber)
//  - Sedentary
//  - Sleep Evening (oben)
//  - Y-Achse 0–24 h
//

import SwiftUI
import Charts

struct MovementSplit30DayChart: View {

    let data: [DailyMovementSplitEntry]

    // Farben
    private let sleepMorningColor = Color.Glu.bodyAccent
    private let sleepEveningColor = Color.Glu.bodyAccent.opacity(0.30)
    private let sedentaryColor    = Color.gray.opacity(0.35)
    private let activeColor       = Color.Glu.activityAccent

    var body: some View {
        VStack(spacing: 8) {
            Chart {
                ForEach(data) { entry in

                    // Reihenfolge (von unten nach oben):
                    // 1) Sleep Morning
                    // 2) Active
                    // 3) Sedentary
                    // 4) Sleep Evening

                    let morningEnd    = Double(entry.sleepMorningMinutes)
                    let activeEnd     = morningEnd + Double(entry.activeMinutes)
                    let sedentaryEnd  = activeEnd + Double(entry.sedentaryMinutes)
                    let totalEnd      = sedentaryEnd + Double(entry.sleepEveningMinutes)

                    // SLEEP MORNING (unten)
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        yStart: .value("Minutes", 0),
                        yEnd: .value("Minutes", morningEnd),
                        width: .fixed(10)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            Gradient(colors: [
                                sleepMorningColor.opacity(0.45),
                                sleepMorningColor.opacity(0.95)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(5)
                    .shadow(
                        color: sleepMorningColor.opacity(0.16),
                        radius: 2.5,
                        x: 0,
                        y: 1.5
                    )

                    // ACTIVE (direkt über Morning-Sleep)
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        yStart: .value("Minutes", morningEnd),
                        yEnd: .value("Minutes", activeEnd),
                        width: .fixed(10)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            Gradient(colors: [
                                activeColor.opacity(0.45),
                                activeColor.opacity(0.95)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(5)
                    .shadow(
                        color: activeColor.opacity(0.16),
                        radius: 2.5,
                        x: 0,
                        y: 1.5
                    )

                    // SEDENTARY
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        yStart: .value("Minutes", activeEnd),
                        yEnd: .value("Minutes", sedentaryEnd),
                        width: .fixed(10)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            Gradient(colors: [
                                sedentaryColor.opacity(0.45),
                                sedentaryColor.opacity(0.95)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(5)
                    .shadow(
                        color: sedentaryColor.opacity(0.16),
                        radius: 2.5,
                        x: 0,
                        y: 1.5
                    )

                    // SLEEP EVENING (oben)
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        yStart: .value("Minutes", sedentaryEnd),
                        yEnd: .value("Minutes", totalEnd),
                        width: .fixed(10)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            Gradient(colors: [
                                sleepEveningColor.opacity(0.45),
                                sleepEveningColor.opacity(0.95)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(5)
                    .shadow(
                        color: sleepEveningColor.opacity(0.16),
                        radius: 2.5,
                        x: 0,
                        y: 1.5
                    )
                }
            }
            // 🔹 Plot-Hintergrund im „Liquid-Glas“-Stil
            .chartPlotStyle { plot in
                plot
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .chartXScale(range: .plotDimension(padding: 16))

            // 🔹 Y-Achse (0–24 h) – etwas größer + fett + Primary Blue
            .chartYAxis {
                AxisMarks(values: .stride(by: 240)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.gray.opacity(0.22))
                    AxisTick()
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) {
                            let hours = minutes / 60
                            Text("\(hours) h")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(
                                    Color.Glu.primaryBlue.opacity(0.95)
                                )
                        }
                    }
                }
            }
            .chartYScale(domain: 0...1440)

            // 🔹 X-Achse – nur Tage, etwas größer + fett + Primary Blue
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.gray.opacity(0.22))
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.day())           // !!! UPDATED – nur Tag
                                .font(.system(size: 14, weight: .bold))  // wie gewünscht
                                .foregroundStyle(
                                    Color.Glu.primaryBlue.opacity(0.95)
                                )
                        }
                    }
                }
            }

            // Legende
            HStack(spacing: 16) {
                legendDot(color: sleepMorningColor, label: "Sleep (Morning)")
                legendDot(color: sleepEveningColor, label: "Sleep (Evening)")
                legendDot(color: activeColor,       label: "Active")
                legendDot(color: sedentaryColor,    label: "Rest")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
            .padding(.top, 4)
        }
    }

    // MARK: - Legend Helper

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

// MARK: - Preview

#Preview("Movement Split – 30 Days") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    var demo: [DailyMovementSplitEntry] = []
    for offset in 0..<30 {
        let date = calendar.date(byAdding: .day, value: -offset, to: today)!

        let morningSleep = Int.random(in: 240...420)             // 4–7 h
        let eveningSleep = Int.random(in: 0...120)               // 0–2 h
        let active       = Int.random(in: 30...150)
        let totalSleep   = morningSleep + eveningSleep
        let sedentary    = max(0, 1440 - totalSleep - active)

        demo.append(
            DailyMovementSplitEntry(
                date: date,
                sleepMorningMinutes: morningSleep,
                sleepEveningMinutes: eveningSleep,
                sedentaryMinutes: sedentary,
                activeMinutes: active
            )
        )
    }

    let sortedDemo = demo.sorted { $0.date < $1.date }

    return MovementSplit30DayChart(data: sortedDemo)
        .frame(height: 325)                              // !!! UPDATED – 260 → 325
        .padding()
        .previewDisplayName("Movement Split 30 Day Chart")
}
