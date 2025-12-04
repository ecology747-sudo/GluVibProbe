//
//  BodySectionCardScaled.swift
//  GluVibProbe
//
//  Helper-basierte SectionCard für Body-Metriken
//  (Weight, Sleep).
//

import SwiftUI

struct BodySectionCardScaled: View {

    // MARK: - Eingabewerte

    let sectionTitle: String
    let title: String

    // KPI-Werte
    let kpiTitle: String
    let kpiTargetText: String
    let kpiCurrentText: String
    let kpiDeltaText: String
    let hasTarget: Bool

    // Originaldaten (90 Tage, Perioden, Monat) – bereits in Display-Einheit
    let last90DaysData: [DailyStepsEntry]
    let periodAverages: [PeriodAverageEntry]
    let monthlyData: [MonthlyMetricEntry]

    // Skalen aus dem ViewModel
    let dailyScale: MetricScaleResult
    let periodScale: MetricScaleResult
    let monthlyScale: MetricScaleResult

    /// Zielwert (z. B. Target Weight oder Target Sleep, in Display-Einheit)
    let goalValue: Int?

    /// Chip-Callback (z. B. Sleep / Weight)
    let onMetricSelected: (String) -> Void
    let metrics: [String]

    /// Steuert, ob der Monats-Chart angezeigt wird
    let showMonthlyChart: Bool

    /// Skala-Typ für die dynamische Periode (z. B. .weightKg, .sleepHours)
    let scaleType: MetricScaleHelper.MetricScaleType

    // Domain-Farbe
    private let color = Color.Glu.bodyAccent

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

    // MARK: - Adaptive Skala für die aktuell gewählte Periode

    private var dailyScaleForSelectedPeriod: MetricScaleResult {
        let values = filteredLast90DaysData.map { Double($0.steps) }

        // Wenn keine Daten → auf ursprüngliche 90-Tage-Skala zurückfallen
        guard !values.isEmpty else {
            return dailyScale
        }

        return MetricScaleHelper.scale(values, for: scaleType)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // SECTION HEADER
            SectionHeader(title: sectionTitle, subtitle: nil)

            // METRIC CHIPS
            metricChips

            // KPI-ZEILE
            kpiHeader

            // TOP: 90-Day Scaled Chart + PeriodPicker
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

            // BOTTOM: Monthly Scaled Chart (optional)
            if showMonthlyChart {
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

// MARK: - Metric Chips

private extension BodySectionCardScaled {

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

private extension BodySectionCardScaled {

    var kpiHeader: some View {
        HStack(alignment: .top, spacing: 10) {

            if hasTarget {
                KPICard(
                    title: "Target",
                    valueText: kpiTargetText,
                    unit: nil,
                    domain: .body
                )

                KPICard(
                    title: "Current",
                    valueText: kpiCurrentText,
                    unit: nil,
                    domain: .body
                )

                KPICard(
                    title: "Delta",
                    valueText: kpiDeltaText,
                    unit: nil,
                    valueColor: deltaColor,
                    domain: .body
                )
            } else {
                Spacer()
                KPICard(
                    title: "Current",
                    valueText: kpiCurrentText,
                    unit: nil,
                    domain: .body
                )
                Spacer()
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

// MARK: - Period Picker

private extension BodySectionCardScaled {

    var periodPicker: some View {
        HStack(spacing: 12) {
            Spacer()

            ForEach(Last90DaysPeriod.allCases) { period in
                let active = (period == selectedPeriod)

                Button {
                    selectedPeriod = period
                } label: {
                    Text(period.rawValue)   // "7", "14", "30", "90"
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

// MARK: - Preview

#Preview("BodySectionCardScaled – Weight Demo") {
    BodySectionCardScaled(
        sectionTitle: "Body",
        title: "Weight",
        kpiTitle: "Weight Today",
        kpiTargetText: "80 kg",
        kpiCurrentText: "82 kg",
        kpiDeltaText: "+2 kg",
        hasTarget: true,
        last90DaysData: [],
        periodAverages: [],
        monthlyData: [],
        dailyScale: MetricScaleResult(
            yAxisTicks: [60, 70, 80, 90, 100],
            yMax: 100,
            valueLabel: { "\($0)" }
        ),
        periodScale: MetricScaleResult(
            yAxisTicks: [60, 70, 80, 90, 100],
            yMax: 100,
            valueLabel: { "\($0)" }
        ),
        monthlyScale: MetricScaleResult(
            yAxisTicks: [60, 70, 80, 90, 100],
            yMax: 100,
            valueLabel: { "\($0)" }
        ),
        goalValue: 80,
        onMetricSelected: { _ in },
        metrics: ["Sleep", "Weight"],
        showMonthlyChart: false,
        scaleType: .weightKg
    )
    .padding()
    .background(Color.Glu.backgroundSurface)
}
