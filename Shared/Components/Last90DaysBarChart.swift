//
//  Last90DaysBarChart.swift
//  GluVibProbe
//

import SwiftUI
import Charts


// MARK: - Datenmodell

struct DailyStepsEntry: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Int      // wird auch für Activity Energy (kcal) wiederverwendet
}

// Zeitraum-Auswahl für den Chart
enum Last90DaysPeriod: String, CaseIterable, Identifiable {
    case days7  = "7"
    case days14 = "14"
    case days30 = "30"
    case days90 = "90"

    var id: Self { self }

    /// Anzahl der Tage, die im Chart sichtbar sein sollen
    var days: Int {
        switch self {
        case .days7:  return 7
        case .days14: return 14
        case .days30: return 30
        case .days90: return 90
        }
    }
}



// MARK: - View

struct Last90DaysBarChart: View {

    // Eingabedaten (generisch, wird für Steps & Energy verwendet)
    let entries: [DailyStepsEntry]
        let metricLabel: String
        let dailyStepsGoal: Int?

        let barColor: Color              // schon vorhanden
        let scaleType: MetricScaleType   // 👈 NEU

        // interner UI-State (aktiver Zeitraum)
        @State private var selectedPeriod: Last90DaysPeriod = .days30

    // MARK: - Init mit Default-Werten

    init(
        entries: [DailyStepsEntry],
        metricLabel: String = "Value",
        dailyStepsGoal: Int? = nil,
        barColor: Color = Color.Glu.activityOrange,   // 🔸 Default = BodyActivity
        scaleType: MetricScaleType = .steps           // 🔸 Default = Steps
    ) {
        self.entries = entries
        self.metricLabel = metricLabel
        self.dailyStepsGoal = dailyStepsGoal
        self.barColor = barColor
        self.scaleType = scaleType                    // 👈 NEU
    }

    // MARK: - Gefilterte Daten

    /// Daten auf den gewählten Zeitraum begrenzen
    private var filteredEntries: [DailyStepsEntry] {
        guard let maxDate = entries.map(\.date).max() else { return [] }

        let calendar = Calendar.current
        let startDate = calendar.date(
            byAdding: .day,
            value: -selectedPeriod.days + 1,
            to: maxDate
        ) ?? maxDate

        return entries
            .filter { $0.date >= startDate && $0.date <= maxDate }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Trendlinie

    /// Lineare Regression über die aktuell sichtbaren Daten
    private var trendPoints: [(date: Date, value: Double)] {
        let data = filteredEntries
        guard data.count > 1 else { return [] }

        let sorted = data.sorted { $0.date < $1.date }

        let xs: [Double] = sorted.indices.map { Double($0) }
        let ys: [Double] = sorted.map { Double($0.steps) }
        let n = Double(sorted.count)

        let sumX  = xs.reduce(0, +)
        let sumY  = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumX2 = xs.reduce(0) { $0 + $1 * $1 }

        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else { return [] }

        let m = (n * sumXY - sumX * sumY) / denom
        let b = (sumY - m * sumX) / n

        return zip(sorted.indices, sorted).map { idx, entry in
            let x = Double(idx)
            let yPred = m * x + b
            return (date: entry.date, value: yPred)
        }
    }

    // MARK: - Y-Achsen-Ticks

    /// Dynamische Y-Achsen-Ticks abhängig vom Scale-Typ (Steps / SmallInt / Percent)
    private var yAxisTickValues: [Int] {
        let dataMax = filteredEntries.map(\.steps).max() ?? 0
        let goalMax = dailyStepsGoal ?? 0
        let maxValue = max(dataMax, goalMax)

        switch scaleType {
        case .percent:
            // 0–100% (oder leicht darüber), Ticks alle 10%
            let upper = max(100, ((maxValue + 9) / 10) * 10)
            return Array(stride(from: 0, through: upper, by: 10))

        case .smallInteger:
            // z.B. Insulin, Minuten, kleine kcal-Bereiche
            guard maxValue > 0 else { return [0] }

            let step: Int
            if maxValue <= 20 {
                step = 5          // 0, 5, 10, 15, 20
            } else if maxValue <= 200 {
                step = 20         // 0, 20, 40, ... 200
            } else if maxValue <= 2_000 {
                step = 200        // 0, 200, 400, ...
            } else {
                step = 500        // Fallback
            }

            let upper = ((maxValue + step - 1) / step) * step
            return Array(stride(from: 0, through: upper, by: step))

        case .steps:
            // große Bereiche in Steps, Darstellung später in T
            guard maxValue > 0 else { return [0] }

            let step: Int
            if maxValue <= 4_000 {
                step = 500        // feiner für kleine Step-Bereiche
            } else if maxValue <= 20_000 {
                step = 2_000
            } else {
                step = 5_000
            }

            let upper = ((maxValue + step - 1) / step) * step
            return Array(stride(from: 0, through: upper, by: step))
        }
    }


    // MARK: - Body

    var body: some View {
        VStack(alignment: .center, spacing: 20) {

            periodPicker

            Chart {

                // 🔸 Balken (für Steps ODER Activity Energy)
                ForEach(filteredEntries) { entry in
                    BarMark(
                        x: .value("Date", entry.date),
                        y: .value(metricLabel, entry.steps),
                        width: .fixed(selectedPeriod == .days90 ? 2 : 8)
                    )
                    .foregroundStyle(barColor.gradient)   // ✅ jetzt generisch
                }

                // 🔹 Optional: horizontale Ziel-Linie (Goal) – nur Linie, kein Label
                if let goal = dailyStepsGoal {
                    RuleMark(
                        y: .value("Goal", goal)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    .foregroundStyle(Color.green)
                }

                // 🔴 Trendlinie über den Balken
                ForEach(trendPoints, id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Trend", point.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
            }
            .chartXScale(range: .plotDimension(padding: 16))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.gray.opacity(0.25))

                    AxisTick()

                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.day())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.8))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(
                    position: .trailing,
                    values: yAxisTickValues
                ) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.gray.opacity(0.25))

                    AxisTick()

                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {

                            if intValue == 0 {
                                // 0 kannst du bei Bedarf auch anzeigen – aktuell ausgeblendet
                                EmptyView()
                            } else {
                                switch scaleType {
                                case .percent:
                                    Text("\(intValue)%")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.8))

                                case .smallInteger:
                                    // z.B. Insulin-Einheiten, Minuten, kleine kcal-Bereiche
                                    Text("\(intValue)")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.8))

                                case .steps:
                                    // Steps: ab 1 000 → „T“ (Tausend)
                                    if intValue >= 1_000 {
                                        Text("\(intValue / 1_000)T")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.8))
                                    } else {
                                        Text("\(intValue)")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.8))
                                    }
                                }
                            }
                        }
                    }
                }
            }

                          
            .frame(height: 220)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Zeitraum-Picker (7 / 14 / 30 / 90)

    private var periodPicker: some View {
        HStack(spacing: 14) {

            Spacer()

            ForEach(Last90DaysPeriod.allCases) { period in
                let active = (period == selectedPeriod)

                Button {
                    selectedPeriod = period
                } label: {
                    Text(period.rawValue)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 20)
                        .frame(minWidth: 40)
                        .background(
                            Capsule()
                                .fill(
                                    active
                                    ? Color.Glu.activityOrange
                                    : Color.Glu.backgroundSurface
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    active
                                    ? Color.clear
                                    : Color.Glu.activityOrange.opacity(0.8),
                                    lineWidth: active ? 0 : 1
                                )
                        )
                        .shadow(color: .black.opacity(0.06),
                                radius: 2,
                                x: 0,
                                y: 1)
                        .foregroundStyle(Color.Glu.primaryBlue)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = Date()

    let entries = (0..<90).map { offset -> DailyStepsEntry in
        let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        let steps = Int.random(in: 2_000...12_000)
        return DailyStepsEntry(date: date, steps: steps)
    }
    .sorted { $0.date < $1.date }

    return Last90DaysBarChart(
        entries: entries,
        metricLabel: "Steps",
        dailyStepsGoal: 10_000,
        barColor: Color.Glu.activityOrange   // 🔸 BodyActivity
    )
    .padding()
    .background(Color.Glu.backgroundSurface)
}
