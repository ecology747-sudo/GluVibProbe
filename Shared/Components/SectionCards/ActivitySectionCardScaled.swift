//
//  ActivitySectionCardScaled.swift
//  GluVibProbe
//
//  Helper-basierte SectionCard für alle Activity-Metriken
//  (Steps, Active Time, Activity Energy).
//

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
            metricChips

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

// MARK: - Metric Chips (zweireihig)

private extension ActivitySectionCardScaled {

    var metricChips: some View {
        VStack(alignment: .leading, spacing: 12) {          // !!! UPDATED: weniger Abstand zwischen den Reihen

            HStack(spacing: 6) {                           // !!! UPDATED: etwas enger zusammen
                ForEach(metrics.prefix(3), id: \.self) { metric in
                    metricChip(metric)
                }
            }

            HStack(spacing: 6) {                           // !!! UPDATED: identischer Abstand in Reihe 2
                ForEach(metrics.suffix(from: 3), id: \.self) { metric in
                    metricChip(metric)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)   // !!! bleibt: beide Reihen linksbündig
        .padding(.vertical, 4)
    }
}

private extension ActivitySectionCardScaled {

    // MARK: - Metric Chip mit Outline im Inaktiv-Zustand

    private func metricChip(_ metric: String) -> some View {
        let isActive = (metric == title)

        // !!! NEU: Farben & Linienstärken für beide Zustände
        let strokeColor: Color = isActive
            ? Color.white.opacity(0.90)        // aktiver Chip → weißer Rand
            : color.opacity(0.90)              // inaktiv → rote/Activity-Farbe als Linie

        let lineWidth: CGFloat = isActive ? 1.6 : 1.2

        let backgroundFill: some ShapeStyle = isActive
            ? LinearGradient(                   // aktiver Chip → kräftig gefüllt
                colors: [
                    color.opacity(0.95),
                    color.opacity(0.75)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            : LinearGradient(                   // inaktiv → transparenter Look, Form bleibt durch Outline sichtbar
                colors: [
                    Color.clear,
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )

        let shadowOpacity: Double = isActive ? 0.25 : 0.15
        let shadowRadius: CGFloat = isActive ? 4 : 2.5
        let shadowYOffset: CGFloat = isActive ? 2 : 1.5

        return Button {
            onMetricSelected(metric)            // Auswahl-Callback bleibt unverändert
        } label: {
            Text(metric)
                .font(.caption.weight(.semibold))      // etwas größer, gut lesbar
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
                .padding(.vertical, 5)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(backgroundFill)          // !!! hier wird aktiv/inaktiv unterschieden
                )
                .overlay(
                    Capsule()
                        .stroke(
                            strokeColor,               // !!! inaktiv: rote/Activity-Linie
                            lineWidth: lineWidth
                        )
                )
                .shadow(
                    color: Color.black.opacity(shadowOpacity),
                    radius: shadowRadius,
                    x: 0,
                    y: shadowYOffset
                )
                .foregroundStyle(
                    isActive
                    ? Color.white                       // aktiver Chip → weiße Schrift
                    : Color.Glu.primaryBlue.opacity(0.95)
                )
                .scaleEffect(isActive ? 1.05 : 1.0)     // „Hover“-Effekt beim aktiven Chip
                .animation(.easeOut(duration: 0.15), value: isActive)
        }
        .buttonStyle(.plain)
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
