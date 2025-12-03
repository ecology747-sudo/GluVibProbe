//
//  NutritionSectionCard.swift
//  GluVibProbe
//
//  Domain: NUTRITION – Carbs, Protein, Fat, Nutrition Energy
//

import SwiftUI

struct NutritionSectionCard: View {

    // MARK: - Eingabewerte

    /// Aktiver Metrik-Name (z. B. "Carbs", "Protein")
    let title: String

    // --- GENERISCHE KPI-WERTE ---
    let kpiTitle: String
    let kpiTargetText: String
    let kpiCurrentText: String
    let kpiDeltaText: String

    /// Gibt an, ob es einen Zielwert gibt (z. B. Carbs-Target) oder nicht
    let hasTarget: Bool

    // --- DATEN FÜR DIE CHARTS ---
    let last90DaysData: [DailyStepsEntry]
    let monthlyData: [MonthlyMetricEntry]

    /// Monatschart-Label z. B. "Carbs / Month"
    let monthlyMetricLabel: String

    /// Header-Titel der Section (z. B. "Nutrition")
    let sectionTitle: String

    /// Zielwert für horizontale Chart-Linie (falls vorhanden)
    let dailyGoalForChart: Int?

    /// Callback für Chips
    let onMetricSelected: (String) -> Void

    /// Chip-Liste (z. B. ["Carbs", "Protein", "Fat", "Nutrition Energy"])
    let metrics: [String]

    /// Durchschnittswerte für 7D–365D
    let periodAverages: [PeriodAverageEntry]

    /// Skala für die Charts (altes System)
    let dailyScaleType: MetricScaleType
    let monthlyScaleType: MetricScaleType

    /// Steuert, ob der Monats-Chart angezeigt wird
    let showMonthlyChart: Bool

    // MARK: - NEU: optionale Skalen-Ergebnisse NUR für den 90d-Chart

    /// Wenn gesetzt → der 90d-Chart nutzt Last90DaysScaledBarChart.
    /// Wenn `nil` → der alte Last90DaysBarChart wird verwendet.
    let dailyScaleResult: MetricScaleResult?

    /// Reserviert, falls wir später einmal Monthly skaliert anbinden wollen.
    /// Aktuell NICHT verwendet, damit es einfach bleibt.
    let monthlyScaleResult: MetricScaleResult?

    // MARK: - Formatter

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    // MARK: - Init

    init(
        sectionTitle: String = "Nutrition",
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
        metrics: [String] = ["Carbs"],
        monthlyMetricLabel: String = "Value / Month",
        periodAverages: [PeriodAverageEntry] = [],
        showMonthlyChart: Bool = true,
        dailyScaleType: MetricScaleType = .smallInteger,
        monthlyScaleType: MetricScaleType = .smallInteger,
        dailyScaleResult: MetricScaleResult? = nil,
        monthlyScaleResult: MetricScaleResult? = nil
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
        self.showMonthlyChart = showMonthlyChart
        self.dailyScaleType = dailyScaleType
        self.monthlyScaleType = monthlyScaleType
        self.dailyScaleResult = dailyScaleResult
        self.monthlyScaleResult = monthlyScaleResult
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Haupt-Header
            SectionHeader(
                title: sectionTitle,
                subtitle: nil
            )

            // Chips (z. B. Carbs / Protein / Fat / Nutrition Energy)
            metricChips

            // KPI-Bereich
            kpiHeader

            // 90-Tage-Chart in Kachel
            ChartCard(borderColor: Color.Glu.nutritionAccent) {
                if let scale = dailyScaleResult {
                    // 🔹 NEUES SYSTEM: skaliert über MetricScaleHelper (NUR 90d-Chart)
                    Last90DaysScaledBarChart(
                        data: last90DaysData,
                        yAxisTicks: scale.yAxisTicks,
                        yMax: scale.yMax,
                        valueLabel: scale.valueLabel,
                        barColor: Color.Glu.nutritionAccent,
                        goalValue: dailyGoalForChart.map { Double($0) },
                        barWidth: 8,
                        xValue: { $0.date },
                        yValue: { Double($0.steps) }
                    )
                    .frame(height: 260)
                } else {
                    // 🔹 ALTES SYSTEM: klassischer Chart mit MetricScaleType
                    Last90DaysBarChart(
                        entries: last90DaysData,
                        metricLabel: title,
                        dailyStepsGoal: dailyGoalForChart,
                        barColor: Color.Glu.nutritionAccent,
                        scaleType: dailyScaleType
                    )
                    .frame(height: 260)
                }
            }

            // Durchschnitts-Chart in Kachel
            if !periodAverages.isEmpty {
                ChartCard(borderColor: Color.Glu.nutritionAccent) {
                    // 👉 Vorerst: IMMER alter AveragePeriodsBarChart
                    AveragePeriodsBarChart(
                        data: periodAverages,
                        metricLabel: title,
                        goalValue: dailyGoalForChart,
                        barColor: Color.Glu.nutritionAccent,
                        scaleType: dailyScaleType,
                        valueFormatter: { value in
                            NutritionSectionCard.numberFormatter
                                .string(from: NSNumber(value: value))
                            ?? "\(value)"
                        }
                    )
                    .frame(height: 260)
                }
            }

            // Monats-Chart in Kachel (optional)
            if showMonthlyChart {
                ChartCard(borderColor: Color.Glu.nutritionAccent) {
                    // 👉 Vorerst: IMMER alter MonthlyBarChart
                    MonthlyBarChart(
                        data: monthlyData,
                        metricLabel: monthlyMetricLabel,
                        barColor: Color.Glu.nutritionAccent,
                        scaleType: monthlyScaleType
                    )
                    .frame(height: 260)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Subviews

private extension NutritionSectionCard {

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
                                    ? Color.Glu.nutritionAccent
                                    : Color.Glu.backgroundSurface
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                active
                                    ? Color.clear
                                    : Color.Glu.nutritionAccent.opacity(0.8),
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

#Preview("NutritionSectionCard – Carbs Demo") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Demo: 30 Tage Carbs in Gramm
    let last30: [DailyStepsEntry] = (0..<30).compactMap { offset in
        guard let d = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
        let grams = Int.random(in: 80...260)
        return DailyStepsEntry(date: d, steps: grams)
    }
    .sorted { $0.date < $1.date }

    let monthlyDemo: [MonthlyMetricEntry] = [
        .init(monthShort: "Jul", value: 12_000),
        .init(monthShort: "Aug", value: 13_500),
        .init(monthShort: "Sep", value: 11_800),
        .init(monthShort: "Oct", value: 12_400),
        .init(monthShort: "Nov", value: 12_900)
    ]

    let periodDemo: [PeriodAverageEntry] = [
        .init(label: "7",   days: 7,   value: 180),
        .init(label: "14",  days: 14,  value: 190),
        .init(label: "30",  days: 30,  value: 200),
        .init(label: "90",  days: 90,  value: 210)
    ]

    // Dummy-Skala für Preview (nur für den 90d-Chart)
    let dummyScale = MetricScaleHelper.scale(for: [80, 260, 200], type: .smallInteger)

    NutritionSectionCard(
        sectionTitle: "Nutrition",
        title: "Carbs",
        kpiTitle: "Carbs Today",
        kpiTargetText: "200 g",
        kpiCurrentText: "180 g",
        kpiDeltaText: "-20 g",
        hasTarget: true,
        last90DaysData: last30,
        monthlyData: monthlyDemo,
        dailyGoalForChart: 200,
        onMetricSelected: { _ in },
        metrics: ["Carbs", "Protein", "Fat", "Nutrition Energy"],
        monthlyMetricLabel: "Carbs / Month",
        periodAverages: periodDemo,
        showMonthlyChart: true,
        dailyScaleType: .smallInteger,
        monthlyScaleType: .smallInteger,
        dailyScaleResult: dummyScale,
        monthlyScaleResult: nil
    )
    .padding()
    .background(Color.Glu.backgroundSurface)
}
