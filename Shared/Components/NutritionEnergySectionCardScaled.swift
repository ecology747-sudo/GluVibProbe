//
//  NutritionEnergySectionCardScaled.swift
//  GluVibProbe
//
//  Neue, Helper-basierte SectionCard NUR für Nutrition Energy.
//

import SwiftUI

struct NutritionEnergySectionCardScaled: View {

    // MARK: - Eingabewerte

    let sectionTitle: String
    let title: String

    // KPI-Werte
    let kpiTitle: String
    let kpiTargetText: String
    let kpiCurrentText: String
    let kpiDeltaText: String
    let hasTarget: Bool

    // Originaldaten
    let last90DaysData: [DailyStepsEntry]
    let periodAverages: [PeriodAverageEntry]
    let monthlyData: [MonthlyMetricEntry]

    // Skalierungen aus MetricScaleHelper
    let dailyScale: MetricScaleResult
    let periodScale: MetricScaleResult
    let monthlyScale: MetricScaleResult

    let goalValue: Int?
    let onMetricSelected: (String) -> Void
    let metrics: [String]

    // Domain-Farbe
    private let color = Color.Glu.nutritionAccent

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // SECTION HEADER
            SectionHeader(title: sectionTitle, subtitle: nil)

            // METRIC CHIPS
            metricChips

            // KPI-ZEILE
            kpiHeader

            // TOP: 90-Day Scaled Chart
            ChartCard(borderColor: color) {
                Last90DaysScaledBarChart(
                    data: last90DaysData,
                    yAxisTicks: dailyScale.yAxisTicks,
                    yMax: dailyScale.yMax,
                    valueLabel: dailyScale.valueLabel,
                    barColor: color,
                    goalValue: goalValue.map(Double.init),
                    barWidth: 6,
                    xValue: { $0.date },
                    yValue: { Double($0.steps) }
                )
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
}

// MARK: - Metric Chips

private extension NutritionEnergySectionCardScaled {

    var metricChips: some View {

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(metrics, id: \.self) { metric in
                    let active = (metric == title)

                    Text(metric)
                        .font(.caption2.weight(.medium))
                        .padding(.vertical, 5)
                        .padding(.horizontal, 9)
                        .background(
                            Capsule().fill(
                                active ? color : Color.Glu.backgroundSurface
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                active ? Color.clear : color.opacity(0.8),
                                lineWidth: active ? 0 : 1
                            )
                        )
                        .foregroundStyle(
                            active
                                ? Color.Glu.primaryBlue
                                : Color.Glu.primaryBlue.opacity(0.85)
                        )
                        .onTapGesture {
                            onMetricSelected(metric)
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - KPI Header

private extension NutritionEnergySectionCardScaled {

    var kpiHeader: some View {
        HStack(alignment: .top, spacing: 10) {

            if hasTarget {
                KPICard(
                    title: "Target",
                    valueText: kpiTargetText,
                    unit: nil,
                    domain: .nutrition
                )

                KPICard(
                    title: "Current",
                    valueText: kpiCurrentText,
                    unit: nil,
                    domain: .nutrition
                )

                KPICard(
                    title: "Delta",
                    valueText: kpiDeltaText,
                    unit: nil,
                    valueColor: deltaColor,
                    domain: .nutrition
                )
            } else {
                Spacer()
                KPICard(title: "Current", valueText: kpiCurrentText, unit: nil)
                Spacer()
            }
        }
        .padding(.bottom, 10)
    }

    var deltaColor: Color {
        let trimmed = kpiDeltaText.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("+") { return .green }
        if trimmed.hasPrefix("-") { return .red }

        return Color.Glu.primaryBlue.opacity(0.75)
    }
}

// MARK: - Preview

#Preview("NutritionEnergySectionCardScaled – Demo") {
    NutritionEnergySectionCardScaled(
        sectionTitle: "Nutrition",
        title: "Nutrition Energy",
        kpiTitle: "Energy Today",
        kpiTargetText: "2 500 kcal",
        kpiCurrentText: "1 800 kcal",
        kpiDeltaText: "-700 kcal",
        hasTarget: true,
        last90DaysData: [],
        periodAverages: [],
        monthlyData: [],
        dailyScale: .empty,
        periodScale: .empty,
        monthlyScale: .empty,
        goalValue: 2500,
        onMetricSelected: { _ in },
        metrics: ["Carbs", "Protein", "Fat", "Nutrition Energy"]
    )
    .padding()
    .background(Color.Glu.backgroundSurface)
}
