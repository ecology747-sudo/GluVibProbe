//
//  BodySectionCardScaledV2.swift
//  GluVibProbe
//
//  Body V2 — Helper-based SectionCard for all Body metrics
//
//  Purpose
//  - Shared card shell for Body detail metrics (Weight, Sleep, BMI, Body Fat, Resting Heart Rate).
//  - Renders metric chips, KPI row, daily / period / monthly charts.
//  - Supports both Int-based and Double-based daily series.
//  - Keeps chart scaling, chip routing and badge rendering centralized at the UI shell layer.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → ViewModel → BodySectionCardScaledV2
//
//  Notes
//  - This view is render-only.
//  - No HealthKit access, no fetch logic, no metric-specific business logic here.
//  - Metric warning badges are injected from the parent via closure.
//  - Localization follows the same pattern as NutritionSectionCardScaledV2.
//

import SwiftUI

struct BodySectionCardScaledV2: View {

    // ============================================================
    // MARK: - Internal Chart Point
    // ============================================================

    private struct ChartPoint: Identifiable, Equatable {
        var id: Date { date }
        let date: Date
        let value: Double
    }

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let sectionTitle: String
    let title: String

    let kpiTitle: String
    let kpiTargetText: String
    let kpiCurrentText: String
    let kpiDeltaText: String
    let kpiDeltaColor: Color?
    let hasTarget: Bool

    private let last90DaysPoints: [ChartPoint]
    let periodAverages: [PeriodAverageEntry]
    let monthlyData: [MonthlyMetricEntry]

    let dailyScale: MetricScaleResult
    let periodScale: MetricScaleResult
    let monthlyScale: MetricScaleResult

    let goalValue: Int?

    let onMetricSelected: (String) -> Void
    let metrics: [String]

    let isMetricLocked: ((String) -> Bool)?
    let onLockedMetricSelected: ((String) -> Void)?
    let showsWarningBadgeForMetric: (String) -> Bool

    let showsDailyChart: Bool
    let showsPeriodChart: Bool
    let showsMonthlyChart: Bool

    let customKpiContent: AnyView?
    let customChartContent: AnyView?

    let dailyScaleType: MetricScaleHelper.MetricScaleType?
    let chartStyle: Last90DaysChartStyle

    private let color = Color.Glu.bodyAccent

    @State private var selectedPeriod: Last90DaysPeriod = .days30

    // ============================================================
    // MARK: - Init (INT series)
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
        last90DaysData: [DailyStepsEntry],
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
        chartStyle: Last90DaysChartStyle = .bar,
        isMetricLocked: ((String) -> Bool)? = nil,
        onLockedMetricSelected: ((String) -> Void)? = nil,
        showsWarningBadgeForMetric: @escaping (String) -> Bool = { _ in false }
    ) {
        self.sectionTitle = sectionTitle
        self.title = title

        self.kpiTitle = kpiTitle
        self.kpiTargetText = kpiTargetText
        self.kpiCurrentText = kpiCurrentText
        self.kpiDeltaText = kpiDeltaText
        self.kpiDeltaColor = kpiDeltaColor
        self.hasTarget = hasTarget

        self.last90DaysPoints = last90DaysData.map {
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

        self.isMetricLocked = isMetricLocked
        self.onLockedMetricSelected = onLockedMetricSelected
        self.showsWarningBadgeForMetric = showsWarningBadgeForMetric
    }

    // ============================================================
    // MARK: - Init (DOUBLE series)
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
        last90DaysDoubleData: [DailyDoubleEntry],
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
        chartStyle: Last90DaysChartStyle = .bar,
        isMetricLocked: ((String) -> Bool)? = nil,
        onLockedMetricSelected: ((String) -> Void)? = nil,
        showsWarningBadgeForMetric: @escaping (String) -> Bool = { _ in false }
    ) {
        self.sectionTitle = sectionTitle
        self.title = title

        self.kpiTitle = kpiTitle
        self.kpiTargetText = kpiTargetText
        self.kpiCurrentText = kpiCurrentText
        self.kpiDeltaText = kpiDeltaText
        self.kpiDeltaColor = kpiDeltaColor
        self.hasTarget = hasTarget

        self.last90DaysPoints = last90DaysDoubleData.map {
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

        self.isMetricLocked = isMetricLocked
        self.onLockedMetricSelected = onLockedMetricSelected
        self.showsWarningBadgeForMetric = showsWarningBadgeForMetric
    }

    // ============================================================
    // MARK: - Derived
    // ============================================================

    private var filteredLast90DaysPoints: [ChartPoint] {
        guard !last90DaysPoints.isEmpty else { return [] }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let maxDataDate = last90DaysPoints.map(\.date).max() ?? todayStart
        let endDay = min(calendar.startOfDay(for: maxDataDate), todayStart)

        let startDay = calendar.date(
            byAdding: .day,
            value: -(selectedPeriod.days - 1),
            to: endDay
        ) ?? endDay

        return last90DaysPoints
            .filter { entry in
                let day = calendar.startOfDay(for: entry.date)
                return day >= startDay && day <= endDay
            }
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

    private var dailyScaleForSelectedPeriod: MetricScaleResult {
        let values = filteredLast90DaysPoints.map(\.value)

        guard !values.isEmpty else { return dailyScale }
        guard let dailyScaleType else { return dailyScale }

        return MetricScaleHelper.scale(values, for: dailyScaleType)
    }

    private var resolvedMonthlyChartTitle: String { // 🟨 UPDATED
        "\(title) / \(L10n.Common.month)"
    }

    private var selectedMetricForChips: String { // 🟨 UPDATED
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if let idx = trimmed.firstIndex(of: "(") {
            return trimmed[..<idx].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmed
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

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
                                data: filteredLast90DaysPoints,
                                yAxisTicks: dailyScaleForSelectedPeriod.yAxisTicks,
                                yMax: dailyScaleForSelectedPeriod.yMax,
                                valueLabel: dailyScaleForSelectedPeriod.valueLabel,
                                barColor: color,
                                goalValue: goalValue.map(Double.init),
                                barWidth: barWidthForSelectedPeriod,
                                xValue: { $0.date },
                                yValue: { $0.value }
                            )

                        case .line:
                            Last90DaysScaledLineChart(
                                data: filteredLast90DaysPoints,
                                yAxisTicks: dailyScaleForSelectedPeriod.yAxisTicks,
                                yMax: dailyScaleForSelectedPeriod.yMax,
                                valueLabel: dailyScaleForSelectedPeriod.valueLabel,
                                lineColor: color,
                                goalValue: goalValue.map(Double.init),
                                lineWidth: barWidthForSelectedPeriod,
                                xValue: { $0.date },
                                yValue: { $0.value }
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
                        metricLabel: resolvedMonthlyChartTitle,
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
        .padding(.horizontal, 8) // 🟨 UPDATED
    }
}

// ============================================================
// MARK: - Chips / KPI / Period Picker
// ============================================================

private extension BodySectionCardScaledV2 {

    var metricChips: some View {
        MetricChipGroup(
            metrics: metrics,
            layoutStyle: .bodyDomain,
            selected: selectedMetricForChips, // 🟨 UPDATED
            accent: color,
            onSelect: { metric in
                onMetricSelected(metric)
            },
            isLocked: { metric in
                isMetricLocked?(metric) ?? false
            },
            onSelectLocked: { metric in
                (onLockedMetricSelected ?? onMetricSelected)(metric)
            },
            showsWarningBadge: showsWarningBadgeForMetric
        )
    }

    var kpiHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            if hasTarget {
                KPICard(
                    title: L10n.Common.target, // 🟨 UPDATED
                    valueText: kpiTargetText,
                    unit: nil,
                    domain: .body
                )
                KPICard(
                    title: L10n.Common.current, // 🟨 UPDATED
                    valueText: kpiCurrentText,
                    unit: nil,
                    domain: .body
                )
                KPICard(
                    title: L10n.Common.delta, // 🟨 UPDATED
                    valueText: kpiDeltaText,
                    unit: nil,
                    valueColor: kpiDeltaColor,
                    domain: .body
                )
            } else {
                KPICard(
                    title: L10n.Common.current, // 🟨 UPDATED
                    valueText: kpiCurrentText,
                    unit: nil,
                    domain: .body
                )
            }
        }
        .padding(.bottom, 10)
    }

    var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(Last90DaysPeriod.allCases) { period in
                let active = (period == selectedPeriod)

                Button { selectedPeriod = period } label: {
                    Text(
                        period.days == 7 ? L10n.Common.period7d : // 🟨 UPDATED
                        period.days == 14 ? L10n.Common.period14d :
                        period.days == 30 ? L10n.Common.period30d :
                        period.days == 90 ? L10n.Common.period90d :
                        period.rawValue
                    )
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
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
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("BodySectionCardScaledV2 – Demo") {
    BodySectionCardScaledV2(
        sectionTitle: "Body",
        title: "Weight",
        kpiTitle: "Weight Today",
        kpiTargetText: "80.0 kg",
        kpiCurrentText: "82.4 kg",
        kpiDeltaText: "+2.4 kg",
        kpiDeltaColor: Color.Glu.successGreen,
        hasTarget: true,
        last90DaysDoubleData: [],
        periodAverages: [],
        monthlyData: [],
        dailyScale: MetricScaleResult(
            yAxisTicks: [70, 75, 80, 85, 90],
            yMax: 90,
            valueLabel: { "\($0)" }
        ),
        periodScale: MetricScaleResult(
            yAxisTicks: [70, 75, 80, 85, 90],
            yMax: 90,
            valueLabel: { "\($0)" }
        ),
        monthlyScale: MetricScaleResult(
            yAxisTicks: [70, 75, 80, 85, 90],
            yMax: 90,
            valueLabel: { "\($0)" }
        ),
        goalValue: 80,
        onMetricSelected: { _ in },
        metrics: ["Weight", "Sleep", "BMI", "Body Fat", "Resting Heart Rate"],
        showsDailyChart: true,
        showsPeriodChart: false,
        showsMonthlyChart: false,
        customKpiContent: nil,
        customChartContent: nil,
        dailyScaleType: .weightKg,
        chartStyle: .bar,
        isMetricLocked: { $0 != "Weight" },
        onLockedMetricSelected: { _ in },
        showsWarningBadgeForMetric: { _ in false }
    )
    .padding()
}
