//  ActivitySectionCardScaled.swift
//  LEGACY: wird schrittweise durch ActivitySectionCardScaledV2 ersetzt.
//  Bitte keine neuen Features mehr hier hinzufügen.

import SwiftUI

struct ActivitySectionCardScaled: View {

    // MARK: - Eingabewerte (müssen zur Aufruf-Signatur passen!)

    let sectionTitle: String          // aktuell leer in den Activity-Views
    let title: String                 // "Steps", "Active Time", "Activity Energy"

    // KPI-Werte
    let kpiTitle: String
    let kpiTargetText: String
    let kpiCurrentText: String
    let kpiDeltaText: String
    let hasTarget: Bool

    // Originaldaten (90 Tage, Perioden, Monat)
    let last90DaysData: [DailyStepsEntry]
    let periodAverages: [PeriodAverageEntry]
    let monthlyData: [MonthlyMetricEntry]

    // Skalen aus dem ViewModel
    let dailyScale: MetricScaleResult
    let periodScale: MetricScaleResult
    let monthlyScale: MetricScaleResult

    // Zielwert (optional)
    let goalValue: Int?

    // Navigation + Chips
    let onMetricSelected: (String) -> Void
    let metrics: [String]

    // Domain-Farbe
    private let color = Color.Glu.activityAccent

    // MARK: - Interner UI-State (Periodenwahl)

    @State private var selectedPeriod: Last90DaysPeriod = .days30

    // Gefilterte 90-Tage-Daten basierend auf der aktuellen Periodenwahl
    private var filteredLast90DaysData: [DailyStepsEntry] {
        guard let maxDate = last90DaysData.map(\.date).max() else { return [] }
        let calendar = Calendar.current

        let startDate = calendar.date(
            byAdding: .day,
            value: -selectedPeriod.days + 1,
            to: maxDate
        ) ?? maxDate

        return last90DaysData
            .filter { $0.date >= startDate && $0.date <= maxDate }
            .sorted { $0.date < $1.date }
    }

    // 👉 Kein MetricScaleHelper-Typ hier – wir verwenden einfach die Skala aus dem ViewModel
    private var dailyScaleForSelectedPeriod: MetricScaleResult {
        dailyScale
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ⛔ Kein SectionHeader hier – der liegt in StepsView / ActivityEnergyView / ExerciseMinutesView

            // METRIC CHIPS (zweireihig, linksbündig)
            // CHANGED: Metric Chips jetzt zentral
            MetricChipGroup(
                metrics: metrics,
                selected: title,
                accent: color,
                onSelect: onMetricSelected
            )

            // KPI-ZEILE
            kpiHeader

            // TOP: 90-Day Scaled Chart + PeriodPicker in einer Karte
            ChartCard(borderColor: color) {
                VStack(spacing: 8) {

                    periodPicker

                    Last90DaysScaledBarChart(
                        data: filteredLast90DaysData,
                        yAxisTicks: dailyScaleForSelectedPeriod.yAxisTicks,
                        yMax: dailyScaleForSelectedPeriod.yMax,
                        valueLabel: dailyScaleForSelectedPeriod.valueLabel,
                        barColor: color,
                        goalValue: goalValue.map(Double.init),
                        barWidth: barWidthForSelectedPeriod,
                        xValue: { $0.date },
                        yValue: { Double($0.steps) }
                    )
                }
                .frame(height: 260)
            }

            // MIDDLE: Period Averages Scaled Chart
            ChartCard(borderColor: color) {
                AveragePeriodsScaledBarChart(
                    data: periodAverages,
                    metricLabel: title,
                    barColor: color,
                    goalValue: goalValue.map(Double.init),
                    yAxisTicks: periodScale.yAxisTicks,
                    yMax: periodScale.yMax,
                    valueLabel: periodScale.valueLabel
                )
                .frame(height: 260)
            }

            // BOTTOM: Monthly Scaled Chart
            ChartCard(borderColor: color) {
                MonthlyScaledBarChart(
                    data: monthlyData,
                    metricLabel: "\(title) / Month",
                    barColor: color,
                    yAxisTicks: monthlyScale.yAxisTicks,
                    yMax: monthlyScale.yMax,
                    valueLabel: monthlyScale.valueLabel
                )
                .frame(height: 260)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Balkenbreite je nach Periodenwahl

    private var barWidthForSelectedPeriod: CGFloat {
        switch selectedPeriod {
        case .days7:
            return 16
        case .days14:
            return 12
        case .days30:
            return 8
        case .days90:
            return 4
        }
    }
}




// MARK: - KPI Header

private extension ActivitySectionCardScaled {

    var kpiHeader: some View {
        HStack(alignment: .top, spacing: 10) {

            if hasTarget {
                KPICard(
                    title: "Target",
                    valueText: kpiTargetText,
                    unit: nil,
                    domain: .activity
                )

                KPICard(
                    title: "Current",
                    valueText: kpiCurrentText,
                    unit: nil,
                    domain: .activity
                )

                KPICard(
                    title: "Delta",
                    valueText: kpiDeltaText,
                    unit: nil,
                    domain: .activity
                )
            } else {
                
                KPICard(
                    title: "Current",
                    valueText: kpiCurrentText,
                    unit: nil,
                    domain: .activity
                )
        
            }
        }
        .padding(.bottom, 10)
    }
}

// MARK: - Period Picker (wie bei Nutrition, nur Activity-Farbe)

private extension ActivitySectionCardScaled {

    var periodPicker: some View {
        HStack(spacing: 12) {
            Spacer()

            ForEach(Last90DaysPeriod.allCases) { period in
                let active = (period == selectedPeriod)

                Button {
                    selectedPeriod = period
                } label: {
                    Text(period.rawValue)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 22)
                        .background(
                            Capsule()
                                .fill(
                                    active
                                    ? LinearGradient(
                                        colors: [
                                            color.opacity(0.95),
                                            color.opacity(0.75)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                      )
                                    : LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.10),
                                            color.opacity(0.22)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                      )
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    active
                                    ? Color.white.opacity(0.90)
                                    : Color.white.opacity(0.35),
                                    lineWidth: active ? 1.6 : 0.8
                                )
                        )
                        .shadow(
                            color: Color.black.opacity(active ? 0.25 : 0.08),
                            radius: active ? 4 : 2,
                            x: 0,
                            y: active ? 2 : 1
                        )
                        .foregroundStyle(
                            active
                            ? Color.white
                            : Color.Glu.primaryBlue.opacity(0.95)
                        )
                        .scaleEffect(active ? 1.05 : 1.0)
                        .animation(.easeOut(duration: 0.15), value: active)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }
}
