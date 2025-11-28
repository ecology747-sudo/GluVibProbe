//
//  BodySectionCard.swift
//  GluVibProbe
//

import SwiftUI

struct BodySectionCard: View {

    // MARK: - Eingabewerte

    let title: String                 // Aktiver Metrik-Name (z. B. "Sleep", "Weight")

    // --- GENERISCHE KPI-WERTE ---
    let kpiTitle: String
    let kpiTargetText: String
    let kpiCurrentText: String
    let kpiDeltaText: String

    /// Gibt an, ob es einen Zielwert gibt (z. B. Weight-Target) oder nicht (z. B. Sleep)
    let hasTarget: Bool

    // --- DATEN FÜR DIE CHARTS ---
    let last90DaysData: [DailyStepsEntry]
    let monthlyData: [MonthlyMetricEntry]

    // Monatschart-Label z. B. "Sleep / Month"
    let monthlyMetricLabel: String

    // Header-Titel der Section
    let sectionTitle: String

    // Zielwert für horizontale Chart-Linie (falls vorhanden)
    let dailyGoalForChart: Int?

    // Callback für Chips
    let onMetricSelected: (String) -> Void

    // Chip-Liste (z. B. ["Sleep", "Weight"])
    let metrics: [String]

    // Durchschnittswerte für 7D–365D
    let periodAverages: [PeriodAverageEntry]

    // Skala für die Charts (z. B. .hours bei Sleep)
    let scaleType: MetricScaleType

    // MARK: - Formatter

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    // MARK: - Init

    init(
        sectionTitle: String = "Body",
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
        metrics: [String] = ["Sleep", "Weight"],
        monthlyMetricLabel: String = "Value / Month",
        periodAverages: [PeriodAverageEntry] = [],
        scaleType: MetricScaleType = .smallInteger
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
        self.dailyGoalForChart = dailyGoalForChart
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

            // Chips (z. B. Sleep / Weight)
            metricChips

            // KPI-Bereich
            kpiHeader

            // 90-Tage-Chart in Kachel
            ChartCard(borderColor: Color.Glu.bodyAccent) {
                Last90DaysBarChart(
                    entries: last90DaysData,
                    metricLabel: title,
                    dailyStepsGoal: dailyGoalForChart,
                    barColor: Color.Glu.bodyAccent,
                    scaleType: scaleType
                )
                .frame(height: 260)
            }

            // Durchschnitts-Chart in Kachel
            if !periodAverages.isEmpty {
                ChartCard(borderColor: Color.Glu.bodyAccent) {
                    AveragePeriodsBarChart(
                        data: periodAverages,
                        metricLabel: title,
                        goalValue: dailyGoalForChart,
                        barColor: Color.Glu.bodyAccent,
                        scaleType: scaleType,
                        valueFormatter: { value in
                            BodySectionCard.numberFormatter
                                .string(from: NSNumber(value: value))
                            ?? "\(value)"
                        }
                    )
                    .frame(height: 260)
                }
            }

            // Monats-Chart in Kachel
            ChartCard(borderColor: Color.Glu.bodyAccent) {
                MonthlyBarChart(
                    data: monthlyData,
                    metricLabel: monthlyMetricLabel,
                    barColor: Color.Glu.bodyAccent,
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

private extension BodySectionCard {

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
                                    ? Color.Glu.bodyAccent
                                    : Color.Glu.backgroundSurface
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                active
                                    ? Color.clear
                                    : Color.Glu.bodyAccent.opacity(0.8),
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
        return Color.Glu.primaryBlue.opacity(0.75)
    }
}

// MARK: - Preview

#Preview("BodySectionCard – Sleep Demo") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Demo: 30 Tage Sleep als Minuten (wir packen es in DailyStepsEntry.steps)
    let last30: [DailyStepsEntry] = (0..<30).compactMap { offset in
        guard let d = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
        // 6–9 Stunden Sleep → 360–540 Minuten
        let minutes = Int.random(in: 360...540)
        return DailyStepsEntry(date: d, steps: minutes)
    }
    .sorted { $0.date < $1.date }

    let monthlyDemo: [MonthlyMetricEntry] = [
        .init(monthShort: "Jul", value: 15_000),
        .init(monthShort: "Aug", value: 16_200),
        .init(monthShort: "Sep", value: 15_800),
        .init(monthShort: "Oct", value: 16_000),
        .init(monthShort: "Nov", value: 15_900)
    ]

    let periodDemo: [PeriodAverageEntry] = [
        .init(label: "7T",   days: 7,   value: 430),
        .init(label: "14T",  days: 14,  value: 420),
        .init(label: "30T",  days: 30,  value: 415),
        .init(label: "90T",  days: 90,  value: 410)
    ]

    return BodySectionCard(
        sectionTitle: "Body",
        title: "Sleep",
        kpiTitle: "Sleep Today",
        kpiTargetText: "",
        kpiCurrentText: "7 h 15 min",
        kpiDeltaText: "",
        hasTarget: false,
        last90DaysData: last30,
        monthlyData: monthlyDemo,
        dailyGoalForChart: nil,
        onMetricSelected: { _ in },
        metrics: ["Sleep", "Weight"],
        monthlyMetricLabel: "Sleep / Month",
        periodAverages: periodDemo,
        scaleType: .hours     // 👉 wenn du .hours in MetricScaleType ergänzt
    )
    .padding()
    .background(Color.Glu.backgroundSurface)
}
