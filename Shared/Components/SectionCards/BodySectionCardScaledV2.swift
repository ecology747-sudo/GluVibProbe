//
//  BodySectionCardScaledV2.swift
//  GluVibProbe
//
//  V2: Body Section Card (vereinheitlicht)
//  - ersetzt langfristig BodySectionCardScaled + BodySectionCardScaledLine
//  - basiert 1:1 auf ActivitySectionCardScaledV2 (Slots + adaptive Daily-Scale)
//  - keine Layout-/Font-Änderungen innerhalb der Card, nur zentrale Card-Styles via ChartCard/KPICard
//

import SwiftUI

struct BodySectionCardScaledV2: View {

    // ============================================================
    // MARK: - Internal Chart Point (supports Double)               // !!! NEW
    // ============================================================

    private struct ChartPoint: Identifiable, Equatable {            // !!! NEW
        var id: Date { date }                                       // !!! NEW (stable)
        let date: Date                                              // !!! NEW
        let value: Double                                           // !!! NEW (true Double, no Int scaling)
    }

    // MARK: - Inputs

    let sectionTitle: String
    let title: String

    // KPI-Werte
    let kpiTitle: String
    let kpiTargetText: String
    let kpiCurrentText: String
    let kpiDeltaText: String
    let kpiDeltaColor: Color?
    let hasTarget: Bool

    // Daten (Display-Einheit)
    private let last90DaysPoints: [ChartPoint]                      // !!! UPDATED (was [DailyStepsEntry])
    let periodAverages: [PeriodAverageEntry]
    let monthlyData: [MonthlyMetricEntry]

    // Skalen (Default / Fallback)
    let dailyScale: MetricScaleResult
    let periodScale: MetricScaleResult
    let monthlyScale: MetricScaleResult

    // Zielwert (optional)
    let goalValue: Int?

    // Navigation + Chips
    let onMetricSelected: (String) -> Void
    let metrics: [String]

    // Slots (V2)
    let showsDailyChart: Bool
    let showsPeriodChart: Bool
    let showsMonthlyChart: Bool

    // Optional: KPI / Chart Slots
    let customKpiContent: AnyView?
    let customChartContent: AnyView?

    // Adaptive Y-Scale pro Periodenwahl (Daily Chart)
    let dailyScaleType: MetricScaleHelper.MetricScaleType?

    // Chart Style (Bar vs Line) – ersetzt das zweite Card-File
    let chartStyle: Last90DaysChartStyle

    // Domain-Farbe
    private let color = Color.Glu.bodyAccent

    @State private var selectedPeriod: Last90DaysPeriod = .days30

    // ============================================================
    // MARK: - Init (INT-series, legacy-compatible)                 // !!! UPDATED
    // ============================================================

    init(
        sectionTitle: String,
        title: String,
        kpiTitle: String,
        kpiTargetText: String,
        kpiCurrentText: String,
        kpiDeltaText: String,
        kpiDeltaColor: Color?,
        hasTarget: Bool,
        last90DaysData: [DailyStepsEntry],                           // stays for existing call-sites
        periodAverages: [PeriodAverageEntry],
        monthlyData: [MonthlyMetricEntry],
        dailyScale: MetricScaleResult,
        periodScale: MetricScaleResult,
        monthlyScale: MetricScaleResult,
        goalValue: Int?,
        onMetricSelected: @escaping (String) -> Void,
        metrics: [String],
        showsDailyChart: Bool,
        showsPeriodChart: Bool,
        showsMonthlyChart: Bool,
        customKpiContent: AnyView? = nil,
        customChartContent: AnyView? = nil,
        dailyScaleType: MetricScaleHelper.MetricScaleType? = nil,
        chartStyle: Last90DaysChartStyle = .bar
    ) {
        self.sectionTitle = sectionTitle
        self.title = title

        self.kpiTitle = kpiTitle
        self.kpiTargetText = kpiTargetText
        self.kpiCurrentText = kpiCurrentText
        self.kpiDeltaText = kpiDeltaText
        self.kpiDeltaColor = kpiDeltaColor
        self.hasTarget = hasTarget

        self.last90DaysPoints = last90DaysData.map {                 // !!! UPDATED
            ChartPoint(date: $0.date, value: Double($0.steps))
        }
        self.periodAverages = periodAverages
        self.monthlyData = monthlyData

        self.dailyScale = dailyScale
        self.periodScale = periodScale
        self.monthlyScale = monthlyScale

        self.goalValue = goalValue
        self.onMetricSelected = onMetricSelected
        self.metrics = metrics

        self.showsDailyChart = showsDailyChart
        self.showsPeriodChart = showsPeriodChart
        self.showsMonthlyChart = showsMonthlyChart

        self.customKpiContent = customKpiContent
        self.customChartContent = customChartContent

        self.dailyScaleType = dailyScaleType
        self.chartStyle = chartStyle
    }

    // ============================================================
    // MARK: - Init (DOUBLE-series, true kg/BMI/BodyFat charts)      // !!! NEW
    // ============================================================

    init(
        sectionTitle: String,
        title: String,
        kpiTitle: String,
        kpiTargetText: String,
        kpiCurrentText: String,
        kpiDeltaText: String,
        kpiDeltaColor: Color?,
        hasTarget: Bool,
        last90DaysDoubleData: [DailyDoubleEntry],                    // !!! NEW
        periodAverages: [PeriodAverageEntry],
        monthlyData: [MonthlyMetricEntry],
        dailyScale: MetricScaleResult,
        periodScale: MetricScaleResult,
        monthlyScale: MetricScaleResult,
        goalValue: Int?,
        onMetricSelected: @escaping (String) -> Void,
        metrics: [String],
        showsDailyChart: Bool,
        showsPeriodChart: Bool,
        showsMonthlyChart: Bool,
        customKpiContent: AnyView? = nil,
        customChartContent: AnyView? = nil,
        dailyScaleType: MetricScaleHelper.MetricScaleType? = nil,
        chartStyle: Last90DaysChartStyle = .bar
    ) {
        self.sectionTitle = sectionTitle
        self.title = title

        self.kpiTitle = kpiTitle
        self.kpiTargetText = kpiTargetText
        self.kpiCurrentText = kpiCurrentText
        self.kpiDeltaText = kpiDeltaText
        self.kpiDeltaColor = kpiDeltaColor
        self.hasTarget = hasTarget

        self.last90DaysPoints = last90DaysDoubleData.map {           // !!! NEW
            ChartPoint(date: $0.date, value: max(0, $0.value))
        }
        self.periodAverages = periodAverages
        self.monthlyData = monthlyData

        self.dailyScale = dailyScale
        self.periodScale = periodScale
        self.monthlyScale = monthlyScale

        self.goalValue = goalValue
        self.onMetricSelected = onMetricSelected
        self.metrics = metrics

        self.showsDailyChart = showsDailyChart
        self.showsPeriodChart = showsPeriodChart
        self.showsMonthlyChart = showsMonthlyChart

        self.customKpiContent = customKpiContent
        self.customChartContent = customChartContent

        self.dailyScaleType = dailyScaleType
        self.chartStyle = chartStyle
    }

    // MARK: - Derived

    private var filteredLast90DaysPoints: [ChartPoint] {             // !!! UPDATED
        guard let maxDate = last90DaysPoints.map(\.date).max() else { return [] }
        let calendar = Calendar.current

        let startDate = calendar.date(
            byAdding: .day,
            value: -selectedPeriod.days + 1,
            to: maxDate
        ) ?? maxDate

        return last90DaysPoints
            .filter { $0.date >= startDate && $0.date <= maxDate }
            .sorted { $0.date < $1.date }
    }

    private var barWidthForSelectedPeriod: CGFloat {
        switch selectedPeriod {
        case .days7:  return 16
        case .days14: return 12
        case .days30: return 8
        case .days90: return 4
        }
    }

    // Adaptive Skala für die aktuell gewählte Periode (Daily Chart)
    private var dailyScaleForSelectedPeriod: MetricScaleResult {
        let values = filteredLast90DaysPoints.map(\.value)           // !!! UPDATED (true Double)

        guard !values.isEmpty else { return dailyScale }
        guard let dailyScaleType else { return dailyScale }

        return MetricScaleHelper.scale(values, for: dailyScaleType)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            metricChips

            if let customKpiContent {
                customKpiContent
            } else {
                kpiHeader
            }

            if let customChartContent {
                ChartCard(borderColor: color) {
                    customChartContent
                }
            }

            if showsDailyChart {
                ChartCard(borderColor: color) {
                    VStack(spacing: 8) {
                        periodPicker

                        switch chartStyle {
                        case .bar:
                            Last90DaysScaledBarChart(
                                data: filteredLast90DaysPoints,                         // !!! UPDATED
                                yAxisTicks: dailyScaleForSelectedPeriod.yAxisTicks,
                                yMax: dailyScaleForSelectedPeriod.yMax,
                                valueLabel: dailyScaleForSelectedPeriod.valueLabel,
                                barColor: color,
                                goalValue: goalValue.map(Double.init),
                                barWidth: barWidthForSelectedPeriod,
                                xValue: { $0.date },                                    // !!! UPDATED
                                yValue: { $0.value }                                    // !!! UPDATED (Double)
                            )

                        case .line:
                            Last90DaysScaledLineChart(
                                data: filteredLast90DaysPoints,                         // !!! UPDATED
                                yAxisTicks: dailyScaleForSelectedPeriod.yAxisTicks,
                                yMax: dailyScaleForSelectedPeriod.yMax,
                                valueLabel: dailyScaleForSelectedPeriod.valueLabel,
                                lineColor: color,
                                goalValue: goalValue.map(Double.init),
                                lineWidth: barWidthForSelectedPeriod,
                                xValue: { $0.date },                                    // !!! UPDATED
                                yValue: { $0.value }                                    // !!! UPDATED (Double)
                            )
                        }
                    }
                    .frame(height: 260)
                }
            }

            if showsPeriodChart {
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
            }

            if showsMonthlyChart {
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
        .padding(.vertical, 4)
    }
}

// MARK: - Chips / KPI / PeriodPicker (Pattern wie Activity V2)

private extension BodySectionCardScaledV2 {

    var metricChips: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(metrics.prefix(3), id: \.self) { metric in
                    metricChip(metric)
                }
            }
            HStack(spacing: 6) {
                ForEach(metrics.suffix(from: 3), id: \.self) { metric in
                    metricChip(metric)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    func metricChip(_ metric: String) -> some View {
        let isActive = (metric == title)

        let strokeColor: Color = isActive
            ? Color.white.opacity(0.90)
            : color.opacity(0.90)

        let lineWidth: CGFloat = isActive ? 1.6 : 1.2

        let backgroundFill: some ShapeStyle = isActive
            ? LinearGradient(
                colors: [color.opacity(0.95), color.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            : LinearGradient(
                colors: [Color.clear, Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )

        let shadowOpacity: Double = isActive ? 0.25 : 0.15
        let shadowRadius: CGFloat = isActive ? 4 : 2.5
        let shadowYOffset: CGFloat = isActive ? 2 : 1.5

        return Button {
            onMetricSelected(metric)
        } label: {
            Text(metric)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
                .padding(.vertical, 5)
                .padding(.horizontal, 14)
                .background(Capsule().fill(backgroundFill))
                .overlay(Capsule().stroke(strokeColor, lineWidth: lineWidth))
                .shadow(
                    color: Color.black.opacity(shadowOpacity),
                    radius: shadowRadius,
                    x: 0,
                    y: shadowYOffset
                )
                .foregroundStyle(isActive ? Color.white : Color.Glu.primaryBlue.opacity(0.95))
                .scaleEffect(isActive ? 1.05 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isActive)
        }
        .buttonStyle(.plain)
    }

    var kpiHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            if hasTarget {
                KPICard(title: "Target", valueText: kpiTargetText, unit: nil, domain: .body)
                KPICard(title: "Current", valueText: kpiCurrentText, unit: nil, domain: .body)
                KPICard(
                    title: "Delta",
                    valueText: kpiDeltaText,
                    unit: nil,
                    valueColor: kpiDeltaColor,
                    domain: .body
                )
            } else {
                KPICard(title: "Current", valueText: kpiCurrentText, unit: nil, domain: .body)
            }
        }
        .padding(.bottom, 10)
    }

    var periodPicker: some View {
        HStack(spacing: 12) {
            Spacer()
            ForEach(Last90DaysPeriod.allCases) { period in
                let active = (period == selectedPeriod)

                Button { selectedPeriod = period } label: {
                    Text(period.rawValue)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 22)
                        .background(
                            Capsule().fill(
                                active
                                ? LinearGradient(
                                    colors: [color.opacity(0.95), color.opacity(0.75)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  )
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.10), color.opacity(0.22)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  )
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                active ? Color.white.opacity(0.90) : Color.white.opacity(0.35),
                                lineWidth: active ? 1.6 : 0.8
                            )
                        )
                        .shadow(
                            color: Color.black.opacity(active ? 0.25 : 0.08),
                            radius: active ? 4 : 2,
                            x: 0,
                            y: active ? 2 : 1
                        )
                        .foregroundStyle(active ? Color.white : Color.Glu.primaryBlue.opacity(0.95))
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

#Preview("BodySectionCardScaledV2 – Demo") {
    BodySectionCardScaledV2(
        sectionTitle: "Body",
        title: "Weight",
        kpiTitle: "Weight Today",
        kpiTargetText: "80.0 kg",
        kpiCurrentText: "82.4 kg",
        kpiDeltaText: "+2.4 kg",
        kpiDeltaColor: .green,
        hasTarget: true,
        last90DaysDoubleData: [],                                       // !!! UPDATED (Double init)
        periodAverages: [],
        monthlyData: [],
        dailyScale: MetricScaleResult(yAxisTicks: [70, 75, 80, 85, 90], yMax: 90, valueLabel: { "\($0)" }),
        periodScale: MetricScaleResult(yAxisTicks: [70, 75, 80, 85, 90], yMax: 90, valueLabel: { "\($0)" }),
        monthlyScale: MetricScaleResult(yAxisTicks: [70, 75, 80, 85, 90], yMax: 90, valueLabel: { "\($0)" }),
        goalValue: 80,
        onMetricSelected: { _ in },
        metrics: ["Weight", "Sleep", "BMI", "Body Fat", "Resting Heart Rate"],
        showsDailyChart: true,
        showsPeriodChart: false,
        showsMonthlyChart: false,
        customKpiContent: (nil as AnyView?),
        customChartContent: (nil as AnyView?),
        dailyScaleType: .weightKg,
        chartStyle: .bar
    )
    .padding()
}
