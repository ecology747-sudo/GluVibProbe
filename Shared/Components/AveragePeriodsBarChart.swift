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
    let value: Int         // Durchschnittswert (z. B. Steps, Minuten Schlaf, kcal)
}

// MARK: - CHART VIEW

struct AveragePeriodsBarChart: View {

    // MARK: - Input

    let data: [PeriodAverageEntry]
    let metricLabel: String              // z. B. "Steps", "kcal", "g", "Sleep"
    let goalValue: Int?                  // optionale Zielwert-Linie
    let barColor: Color                  // Domain-Farbe
    let scaleType: MetricScaleType       // .steps / .smallInteger / .percent / .hours
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
            
            // 🔥 Neu: Nutrition Energy Daily → fixe 250er-Intervalle
            case .nutritionEnergyDaily:
                let step = 250
                let upper = ((maxValue + step - 1) / step) * step
                return Array(stride(from: 0, through: upper, by: step))

            // Für Monthly nur „fallback“ wie eine kleine Zahlenskala
            case .nutritionEnergyMonthly:
                let step: Int
                if maxValue <= 2_000 {
                    step = 250
                } else if maxValue <= 10_000 {
                    step = 500
                } else {
                    step = 1_000
                }
                let upper = ((maxValue + step - 1) / step) * step
                return Array(stride(from: 0, through: upper, by: step))

        case .percent:
            return Array(stride(from: 0, through: 100, by: 20))

        case .hours:
            // 🔥 Sleep: Werte in Minuten → Achse in Stunden
            // maxValue ist in Minuten
            let maxHours = Double(maxValue) / 60.0

            let stepHours: Double
            if maxHours <= 5 {
                stepHours = 1        // 0, 1, 2, 3, 4, 5 h
            } else if maxHours <= 10 {
                stepHours = 2        // 0, 2, 4, 6, 8, 10 h
            } else {
                stepHours = 5        // 0, 5, 10, 15, ... h
            }

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
                    let labelText: String = {
                        switch scaleType {
                        case .hours:
                            // 🔥 Sleep: Minuten → Stunden
                            let hours = Double(entry.value) / 60.0
                            return String(format: "%.1f h", hours)

                        default:
                            return valueFormatter(entry.value)
                        }
                    }()

                    Text(labelText)
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

                            // 👉 neue Fälle einfach zusammen mit smallInteger behandeln
                            case .smallInteger,
                                 .nutritionEnergyDaily,
                                 .nutritionEnergyMonthly:
                                Text("\(v)")
                       

                        case .percent:
                            Text("\(v)%")

                        case .hours:
                            // 🔥 Sleep-Achse in Stunden (eine Nachkommastelle)
                            let hours = Double(v) / 60.0
                            Text(String(format: "%.1f h", hours))
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
