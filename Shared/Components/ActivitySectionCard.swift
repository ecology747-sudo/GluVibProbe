//
//  ActivitySectionCard.swift
//  GluVibProbe
//

import SwiftUI

struct ActivitySectionCard: View {

    // MARK: - Eingabewerte

    let title: String                 // Aktiver Metrik-Name (z. B. "Steps")

    // --- GENERISCHE KPI-WERTE ---
    let kpiTitle: String              // z. B. "Steps Today"
    let kpiTargetText: String         // z. B. "10 000"
    let kpiCurrentText: String        // z. B. "8 532"
    let kpiDeltaText: String          // z. B. "+1 468" oder "−500"

    /// Gibt an, ob es einen Zielwert gibt (z. B. Steps) oder nicht (z. B. Activity Energy)
    let hasTarget: Bool               // true = Target/Current/Delta, false = nur Current

    // --- DATEN FÜR DIE CHARTS ---
    let last90DaysData: [DailyStepsEntry]
    let monthlyData: [MonthlyMetricEntry]

    // Monatschart-Label z. B. "Steps / Month"
    let monthlyMetricLabel: String

    // Header-Titel der Section
    let sectionTitle: String

    // Zielwert für horizontale Chart-Linie
    let dailyStepsGoalForChart: Int?

    // Callback für Chips
    let onMetricSelected: (String) -> Void

    // Chip-Liste (Steps / Activity Energy)
    let metrics: [String]

    // Durchschnittswerte für 7D–365D
    let periodAverages: [PeriodAverageEntry]

    // Skala für die Charts (Steps / smallInt / Prozent / Stunden)
    let scaleType: MetricScaleType

    // MARK: - Formatter

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    // MARK: - Initializer

    init(
        sectionTitle: String = "Activity",
        title: String,
        kpiTitle: String,
        kpiTargetText: String,
        kpiCurrentText: String,
        kpiDeltaText: String,
        hasTarget: Bool = true,
        last90DaysData: [DailyStepsEntry],
        monthlyData: [MonthlyMetricEntry],
        dailyGoalForChart: Int? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in },
        metrics: [String] = ["Steps", "Activity Energy"],   // 👈 nur Activity-Metriken
        monthlyMetricLabel: String = "Steps / Month",
        periodAverages: [PeriodAverageEntry] = [],
        scaleType: MetricScaleType = .steps
    ) {
        self.sectionTitle = sectionTitle
        self.title = title
        self.kpiTitle = kpiTitle
        self.kpiTargetText = kpiTargetText
        self.kpiCurrentText = kpiCurrentText
        self.kpiDeltaText = kpiDeltaText
        self.hasTarget = hasTarget
        self.last90DaysData = last90DaysData
        self.monthlyData = monthlyData
        self.dailyStepsGoalForChart = dailyGoalForChart
        self.onMetricSelected = onMetricSelected
        self.metrics = metrics
        self.monthlyMetricLabel = monthlyMetricLabel
        self.periodAverages = periodAverages
        self.scaleType = scaleType
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Haupt-Header
            SectionHeader(
                title: sectionTitle,
                subtitle: nil
            )

            // Chips (Steps / Activity Energy)
            metricChips

            // KPI-Bereich
            kpiHeader

            // 90-Tage-Chart in Kachel
            ChartCard(borderColor: Color.Glu.activityAccent) {
                Last90DaysBarChart(
                    entries: last90DaysData,
                    metricLabel: title,
                    dailyStepsGoal: dailyStepsGoalForChart,
                    barColor: Color.Glu.activityAccent,
                    scaleType: scaleType
                )
                .frame(height: 260)
            }

            // Durchschnitts-Chart in Kachel
            if !periodAverages.isEmpty {
                ChartCard(borderColor: Color.Glu.activityAccent) {
                    AveragePeriodsBarChart(
                        data: periodAverages,
                        metricLabel: title,
                        goalValue: dailyStepsGoalForChart,
                        barColor: Color.Glu.activityAccent,
                        scaleType: scaleType,
                        valueFormatter: { value in
                            ActivitySectionCard.numberFormatter
                                .string(from: NSNumber(value: value))
                            ?? "\(value)"
                        }
                    )
                    .frame(height: 260)
                }
            }

            // Monats-Chart in Kachel
            ChartCard(borderColor: Color.Glu.activityAccent) {
                MonthlyBarChart(
                    data: monthlyData,
                    metricLabel: monthlyMetricLabel,
                    barColor: Color.Glu.activityAccent,
                    scaleType: scaleType
                )
                .frame(height: 260)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Subviews

private extension ActivitySectionCard {

    // MARK: Metric Chips
    var metricChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                    let active = (metric == title)

                    Text(metric)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 9)
                        .background(
                            Capsule().fill(
                                active
                                    ? Color.Glu.activityAccent
                                    : Color.Glu.backgroundSurface
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                active
                                    ? Color.clear
                                    : Color.Glu.activityAccent.opacity(0.8),
                                lineWidth: active ? 0 : 1
                            )
                        )
                        .foregroundStyle(
                            active
                                ? Color.Glu.primaryBlue
                                : Color.Glu.primaryBlue.opacity(0.85)
                        )
                        .shadow(color: .black.opacity(0.04),
                                radius: 1,
                                x: 0,
                                y: 1)
                        .onTapGesture {
                            onMetricSelected(metric)
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(minWidth: 0,
                   maxWidth: .infinity,
                   alignment: .center)
        }
    }

    // MARK: KPI-Header
    var kpiHeader: some View {
        HStack(alignment: .top, spacing: 10) {

            if hasTarget {
                // 🔹 Standard-Fall: 3 KPIs (Target / Current / Delta)
                KPICard(
                    title: "Target",
                    valueText: kpiTargetText,
                    unit: nil
                )

                KPICard(
                    title: "Current",
                    valueText: kpiCurrentText,
                    unit: nil
                )

                KPICard(
                    title: "Delta",
                    valueText: kpiDeltaText,
                    unit: nil,
                    valueColor: deltaColor
                )
            } else {
                // 🔹 Kein Ziel: nur Current, zentriert
                Spacer(minLength: 0)

                KPICard(
                    title: "Current",
                    valueText: kpiCurrentText,
                    unit: nil
                )

                Spacer(minLength: 0)
            }
        }
        .padding(.bottom, 10)
    }

    /// Farbe für Delta basierend auf Vorzeichen des Textes
    var deltaColor: Color {
        let trimmed = kpiDeltaText.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("+") {
            return .green
        }
        if trimmed.hasPrefix("-") || trimmed.hasPrefix("−") {
            return .red
        }
        return Color.Glu.primaryBlue.opacity(0.75) // neutral
    }
}
