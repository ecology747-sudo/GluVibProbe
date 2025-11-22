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

    /// Label der Metrik, z. B. "Steps" oder "kcal"
    let metricLabel: String

    /// Optionaler Zielwert für eine horizontale Linie (z. B. 10 000 Steps)
    let dailyGoal: Int?

    // interner UI-State (aktiver Zeitraum)
    @State private var selectedPeriod: Last90DaysPeriod = .days30

    // MARK: - Init mit Default-Werten

    init(
        entries: [DailyStepsEntry],
        metricLabel: String = "Value",
        dailyGoal: Int? = nil
    ) {
        self.entries = entries
        self.metricLabel = metricLabel
        self.dailyGoal = dailyGoal
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

    /// Dynamische Y-Achsen-Ticks (Steps & Activity Energy)
    private var yAxisTickValues: [Int] {
        // Maximaler Datenwert
        let dataMax = filteredEntries.map(\.steps).max() ?? 0
        // Zielwert einbeziehen, falls vorhanden
        let goalMax = dailyGoal ?? 0
        let maxValue = max(dataMax, goalMax)

        if maxValue <= 0 {
            return [0]
        }

        // Schrittweite abhängig vom Maximalwert
        let step: Int
        if maxValue <= 2_000 {
            step = 200          // z.B. kcal Bereich
        } else {
            step = 2_000        // Steps-Bereich
        }

        // nach oben auf das nächste Vielfache von "step" runden
        let upper = ((maxValue + step - 1) / step) * step

        return Array(stride(from: 0, through: upper, by: step))
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            periodPicker

            Chart {

                // 🔸 Balken (für Steps ODER Activity Energy)
                ForEach(filteredEntries) { entry in
                    BarMark(
                        x: .value("Date", entry.date),
                        y: .value(metricLabel, entry.steps),
                        width: .fixed(selectedPeriod == .days90 ? 2 : 8)
                    )
                    .foregroundStyle(Color.Glu.activityOrange.gradient)
                }

                // 🔹 Optional: horizontale Ziel-Linie (Goal) – nur Linie, kein Label
                if let goal = dailyGoal {
                    RuleMark(
                        y: .value("Goal", goal)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 3]))   // etwas dicker + gestrichelt
                    .foregroundStyle(Color.Glu.accentLime)                // grün aus deinem CI
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
            // Plot-Area leicht einrücken:
            //  - rechts mehr Luft → Y-Labels wirken nicht angeklebt
            //  - links minimal Puffer
            .chartPlotStyle { plotArea in
                plotArea
                    .padding(.trailing, 20)
                    .padding(.leading, 6)
            }
            // X-Skala mit Innenpadding, damit der letzte Tag (z.B. 20) nicht am Rand klebt
            .chartXScale(range: .plotDimension(padding: 16))
            // X-Achse: Datum, Beschriftung in GluPrimaryBlue
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
            // Y-Achse: rechts, Beschriftung in GluPrimaryBlue
            .chartYAxis {
                let maxValue = filteredEntries.map(\.steps).max() ?? 0

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
                                // 0 ausblenden → kein Label
                                EmptyView()
                            }
                            else if maxValue <= 2_000 {
                                // z.B. kcal: exakte Werte
                                Text("\(intValue)")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.8))
                            }
                            else {
                                // Steps: ab 1000 in T darstellen
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
            .frame(height: 220)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Zeitraum-Picker (7 / 14 / 30 / 90)

    private var periodPicker: some View {
        HStack(spacing: 14) {     // 🔹 etwas mehr Abstand zwischen den Chips

            Spacer()  // Zentrierung in der Card

            ForEach(Last90DaysPeriod.allCases) { period in
                let active = (period == selectedPeriod)

                Button {
                    selectedPeriod = period
                } label: {
                    Text(period.rawValue)                      // 7 / 14 / 30 / 90
                        .font(.caption2.weight(.medium))       // wie Metric-Chips
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.vertical, 6)                 // ca. 32–36 pt Tap-Höhe
                        .padding(.horizontal, 12)
                        .frame(minWidth: 40)
                        .background(
                            Capsule()
                                .fill(
                                    active
                                    ? Color.Glu.activityOrange
                                    : Color.Glu.backgroundSurface   // 🔹 CI statt weiß
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
                        .shadow(color: .black.opacity(0.06),    // dezenter Shadow → Apple Style
                                radius: 2,
                                x: 0,
                                y: 1)
                        .foregroundStyle(
                            Color.Glu.primaryBlue                // Textfarbe CI-konform
                        )
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
        dailyGoal: 10_000
    )
    .padding()
    .background(Color.Glu.backgroundSurface)
}
