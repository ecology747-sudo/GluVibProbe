//
//  BodyActivitySectionCard.swift
//  GluVibProbe
//

import SwiftUI

struct BodyActivitySectionCard_Archive: View {

    // MARK: - Eingabewerte

    let title: String
    let kpiTitle: String
    let kpiValue: String

    /// Formatierter Zielwert für die KPI-Karte ("10 000")
    let dailyStepsGoalLabel: String

    /// Formatierter „to go“-Wert
    let stepsToGoValue: String

    let last90DaysData: [DailyStepsEntry]
    let monthlyData: [MonthlyMetricEntry]

    /// Label für den Monats-Chart (z. B. "Steps / Month", "kcal / Month")
    let monthlyMetricLabel: String

    let sectionTitle: String

    /// Zielwert als Int – für die horizontale Goal-Linie im Chart
    let dailyStepsGoalForChart: Int?

    let onMetricSelected: (String) -> Void

    /// Liste der Metrik-Namen für die Chips (z. B. ["Weight", "Steps", ...])
    let metrics: [String]

    /// Durchschnittswerte für 7D / 14D / 30D / 90D / 180D / 365D
    let periodAverages: [PeriodAverageEntry]

    // MARK: - Formatter

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    // MARK: - Initializer

    init(
        sectionTitle: String = "Körper & Aktivität",
        title: String,
        kpiTitle: String,
        kpiValue: String,
        dailyStepsGoalLabel: String,
        stepsToGoValue: String,
        last90DaysData: [DailyStepsEntry],
        monthlyData: [MonthlyMetricEntry],
        dailyStepsGoalForChart: Int? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in },
        metrics: [String] = ["Weight", "Steps", "Sleep", "Activity Energy"],
        monthlyMetricLabel: String = "Steps / Month",
        periodAverages: [PeriodAverageEntry] = []
    ) {
        self.sectionTitle = sectionTitle
        self.title = title
        self.kpiTitle = kpiTitle
        self.kpiValue = kpiValue
        self.dailyStepsGoalLabel = dailyStepsGoalLabel
        self.stepsToGoValue = stepsToGoValue
        self.last90DaysData = last90DaysData
        self.monthlyData = monthlyData
        self.dailyStepsGoalForChart = dailyStepsGoalForChart
        self.onMetricSelected = onMetricSelected
        self.metrics = metrics
        self.monthlyMetricLabel = monthlyMetricLabel
        self.periodAverages = periodAverages
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Haupt-Header
            SectionHeader(
                title: sectionTitle,
                subtitle: nil
            )

            // Chips (Weight / Steps / Sleep / Activity Energy)
            metricChips

            // KPI-Bereich
            kpiHeader

            // 90-Tage-Chart in Kachel
            ChartCard(borderColor: Color.Glu.activityOrange) {
                Last90DaysBarChart(
                    entries: last90DaysData,
                    metricLabel: title,
                    dailyStepsGoal: dailyStepsGoalForChart,
                    barColor: Color.Glu.activityOrange,
                    scaleType: .steps
                )
                .frame(height: 260)
            }

            // Monats-Chart in Kachel
            ChartCard(borderColor: Color.Glu.activityOrange) {
                MonthlyBarChart(
                    data: monthlyData,
                    metricLabel: monthlyMetricLabel,
                    barColor: Color.Glu.activityOrange,
                    scaleType: .steps
                )
                .frame(height: 260)
            }

            // Durchschnitts-Chart in Kachel
            if !periodAverages.isEmpty {
                ChartCard(borderColor: Color.Glu.activityOrange) {
                    AveragePeriodsBarChart(
                        data: periodAverages,
                        metricLabel: title,
                        goalValue: dailyStepsGoalForChart,
                        barColor: Color.Glu.activityOrange,
                        scaleType: .steps,
                        valueFormatter: { value in
                            BodyActivitySectionCard.numberFormatter
                                .string(from: NSNumber(value: value))
                            ?? "\(value)"
                        }
                    )
                    .frame(height: 260)
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.Glu.backgroundSurface)
                .shadow(
                    color: .black.opacity(0.10),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        )
    }
}

// MARK: - Subviews

private extension BodyActivitySectionCard {

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
                                    ? Color.Glu.activityOrange
                                    : Color.Glu.backgroundSurface
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                active
                                    ? Color.clear
                                    : Color.Glu.activityOrange.opacity(0.8),
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
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    // MARK: KPI-Header
    var kpiHeader: some View {
        HStack(alignment: .top, spacing: 10) {

            KPICard(
                title: "Target",              // neuer Name, wie besprochen
                valueText: dailyStepsGoalLabel,
                unit: nil
            )

            KPICard(
                title: "Current",
                valueText: kpiValue,
                unit: nil
            )

            KPICard(
                title: "Delta",
                valueText: stepsToGoValue,
                unit: nil
            )
        }
        .padding(.bottom, 10)
    }
}

// MARK: - Preview

#Preview("BodyActivitySectionCard – Steps Demo") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    let demoLast90: [DailyStepsEntry] = (0..<90).compactMap { offset in
        guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
        return DailyStepsEntry(date: date, steps: Int.random(in: 2_000...12_000))
    }
    .sorted { $0.date < $1.date }

    let demoMonthly: [MonthlyMetricEntry] = [
        MonthlyMetricEntry(monthShort: "Feb", value: 140_000),
        MonthlyMetricEntry(monthShort: "Mar", value: 155_000),
        MonthlyMetricEntry(monthShort: "Apr", value: 168_000),
        MonthlyMetricEntry(monthShort: "May", value: 160_000),
        MonthlyMetricEntry(monthShort: "Jun", value: 172_000)
    ]

    let demoAverages: [PeriodAverageEntry] = [
        .init(label: "7D",   days: 7,   value: 8_417),
        .init(label: "14D",  days: 14,  value: 8_010),
        .init(label: "30D",  days: 30,  value: 7_560),
        .init(label: "90D",  days: 90,  value: 7_100),
        .init(label: "180D", days: 180, value: 6_900),
        .init(label: "365D", days: 365, value: 6_800)
    ]

    BodyActivitySectionCard(
        sectionTitle: "Körper & Aktivität",
        title: "Steps",
        kpiTitle: "Steps Today",
        kpiValue: "8 532",
        dailyStepsGoalLabel: "10 000",
        stepsToGoValue: "1 468",
        last90DaysData: demoLast90,
        monthlyData: demoMonthly,
        dailyStepsGoalForChart: 10_000,
        onMetricSelected: { _ in },
        metrics: ["Weight", "Steps", "Sleep", "Activity Energy"],
        monthlyMetricLabel: "Steps / Month",
        periodAverages: demoAverages
    )
    .padding()
    .background(Color.Glu.backgroundNavy)
}
