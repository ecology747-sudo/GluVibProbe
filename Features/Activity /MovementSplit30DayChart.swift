//
//  MovementSplitDailyChart.swift
//  GluVibProbe
//
//  ✅ UPDATED → generisch für 7/14/30/90
//  - Sleep Morning + Sleep Evening = gleiche Farbe (wie Morning)
//  - Legende zeigt nur: Sleep / Active / Rest
//  - Bars sind eckig (keine cornerRadius mehr)
//  - Legendengröße = X-Achsen-Beschriftung
//

import SwiftUI
import Charts

struct MovementSplitDailyChart: View {

    let data: [DailyMovementSplitEntry]
    let barWidth: CGFloat

    private let sleepColor     = Color.Glu.bodyAccent
    private let sedentaryColor = Color.gray.opacity(0.35)
    private let activeColor    = Color.Glu.activityAccent

    var body: some View {
        VStack(spacing: 8) {

            Chart {
                ForEach(data) { entry in

                    let morningEnd   = Double(entry.sleepMorningMinutes)
                    let activeEnd    = morningEnd + Double(entry.activeMinutes)
                    let sedentaryEnd = activeEnd + Double(entry.sedentaryMinutes)
                    let totalEnd     = sedentaryEnd + Double(entry.sleepEveningMinutes)

                    // SLEEP (unten)
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        yStart: .value("Minutes", 0),
                        yEnd: .value("Minutes", morningEnd),
                        width: .fixed(barWidth)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            Gradient(colors: [
                                sleepColor.opacity(0.45),
                                sleepColor.opacity(0.95)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: sleepColor.opacity(0.16), radius: 2.5, x: 0, y: 1.5)

                    // ACTIVE
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        yStart: .value("Minutes", morningEnd),
                        yEnd: .value("Minutes", activeEnd),
                        width: .fixed(barWidth)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            Gradient(colors: [
                                activeColor.opacity(0.65),
                                activeColor.opacity(0.95)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: activeColor.opacity(0.16), radius: 2.5, x: 0, y: 1.5)

                    // REST
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        yStart: .value("Minutes", activeEnd),
                        yEnd: .value("Minutes", sedentaryEnd),
                        width: .fixed(barWidth)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            Gradient(colors: [
                                sedentaryColor.opacity(0.65),
                                sedentaryColor.opacity(0.95)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: sedentaryColor.opacity(0.16), radius: 2.5, x: 0, y: 1.5)

                    // SLEEP (oben, gleiche Farbe)
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        yStart: .value("Minutes", sedentaryEnd),
                        yEnd: .value("Minutes", totalEnd),
                        width: .fixed(barWidth)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            Gradient(colors: [
                                sleepColor.opacity(0.7),
                                sleepColor.opacity(0.95)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .shadow(color: sleepColor.opacity(0.16), radius: 2.5, x: 0, y: 1.5)
                }
            }

            // Plot-Hintergrund
            .chartPlotStyle { plot in
                plot
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .chartXScale(range: .plotDimension(padding: 16))

            // Y-Achse (0–24 h)
            .chartYScale(domain: 0...1440)
            .chartYAxis {
                AxisMarks(values: .stride(by: 240)) { value in
                    AxisGridLine().foregroundStyle(Color.gray.opacity(0.22))
                    AxisTick()
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) {
                            Text("\(minutes / 60) h")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                        }
                    }
                }
            }

            // X-Achse (Tage)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine().foregroundStyle(Color.gray.opacity(0.22))
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.day())
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                        }
                    }
                }
            }

            // ✅ Legend – jetzt gleiche Größe wie X-Achse
            HStack(spacing: 18) {
                legendDot(color: sleepColor,     label: "Sleep")
                legendDot(color: activeColor,    label: "Active")
                legendDot(color: sedentaryColor, label: "Not Active")
            }
            .font(.system(size: 14, weight: .bold))          // ⭐ MATCH X-AXIS
            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
            .padding(.top, 6)
        }
    }

    // MARK: - Legend Helper

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)                // ⭐ leicht größer
            Text(label)
        }
    }
}

#Preview("Movement Split – Daily Chart") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    let demo: [DailyMovementSplitEntry] = (0..<30).compactMap { offset in
        guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }

        let morningSleep = Int.random(in: 240...420)
        let eveningSleep = Int.random(in: 0...120)
        let active       = Int.random(in: 30...150)
        let sedentary    = max(0, 1440 - (morningSleep + eveningSleep) - active)

        return DailyMovementSplitEntry(
            date: date,
            sleepMorningMinutes: morningSleep,
            sleepEveningMinutes: eveningSleep,
            sedentaryMinutes: sedentary,
            activeMinutes: active
        )
    }
    .sorted { $0.date < $1.date }

    return MovementSplitDailyChart(data: demo, barWidth: 10)
        .frame(height: 260)
        .padding()
        .background(Color.Glu.backgroundSurface)
}
