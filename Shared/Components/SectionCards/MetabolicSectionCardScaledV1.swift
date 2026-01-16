//
//  MetabolicSectionCardScaledV1.swift
//  GluVibProbe
//

import SwiftUI

struct MetabolicSectionCardScaledV1: View {

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let title: String

    // KPI (Default)
    let kpiTitle: String
    let kpiCurrentText: String
    let kpiSecondaryText: String?

    // Charts (Default Data)
    let last90DaysData: [DailyStepsEntry]
    let periodAverages: [PeriodAverageEntry]

    // Scales (Default)
    let dailyScale: MetricScaleResult
    let periodScale: MetricScaleResult

    // Target (optional)
    let goalValue: Double?

    // Navigation + Chips
    let onMetricSelected: (String) -> Void
    let metrics: [String]

    // Scale Type (adaptive)
    let dailyScaleType: MetricScaleHelper.MetricScaleType?

    // Slots (V2 Pattern)
    let showsDailyChart: Bool
    let showsPeriodChart: Bool
    let showsMonthlyChart: Bool

    // Optional Custom Content (V2 Pattern)
    let customKpiContent: AnyView?
    let customChartContent: AnyView?
    let customDailyChartBuilder: ((Last90DaysPeriod, [DailyStepsEntry]) -> AnyView)?
    let customPeriodChartContent: AnyView?

    // ============================================================
    // MARK: - State
    // ============================================================

    @State private var selectedPeriod: Last90DaysPeriod = .days30

    private let color = Color.Glu.metabolicDomain

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        title: String,

        kpiTitle: String,
        kpiCurrentText: String,
        kpiSecondaryText: String?,

        last90DaysData: [DailyStepsEntry],
        periodAverages: [PeriodAverageEntry],

        dailyScale: MetricScaleResult,
        periodScale: MetricScaleResult,

        goalValue: Double?,

        onMetricSelected: @escaping (String) -> Void,
        metrics: [String],

        dailyScaleType: MetricScaleHelper.MetricScaleType?,

        showsDailyChart: Bool = true,
        showsPeriodChart: Bool = true,
        showsMonthlyChart: Bool = false,

        customKpiContent: AnyView? = nil,
        customChartContent: AnyView? = nil,
        customDailyChartBuilder: ((Last90DaysPeriod, [DailyStepsEntry]) -> AnyView)? = nil,
        customPeriodChartContent: AnyView? = nil
    ) {
        self.title = title

        self.kpiTitle = kpiTitle
        self.kpiCurrentText = kpiCurrentText
        self.kpiSecondaryText = kpiSecondaryText

        self.last90DaysData = last90DaysData
        self.periodAverages = periodAverages

        self.dailyScale = dailyScale
        self.periodScale = periodScale

        self.goalValue = goalValue

        self.onMetricSelected = onMetricSelected
        self.metrics = metrics

        self.dailyScaleType = dailyScaleType

        self.showsDailyChart = showsDailyChart
        self.showsPeriodChart = showsPeriodChart
        self.showsMonthlyChart = showsMonthlyChart

        self.customKpiContent = customKpiContent
        self.customChartContent = customChartContent
        self.customDailyChartBuilder = customDailyChartBuilder
        self.customPeriodChartContent = customPeriodChartContent
    }

    // ============================================================
    // MARK: - Derived (90-Day Clamp + Period Filter)
    // ============================================================

    private var filteredLast90DaysData: [DailyStepsEntry] {

        guard !last90DaysData.isEmpty else { return [] }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        let maxDataDate = last90DaysData.map(\.date).max() ?? todayStart
        let endDay = min(calendar.startOfDay(for: maxDataDate), todayStart)

        let startDay = calendar.date(
            byAdding: .day,
            value: -(selectedPeriod.days - 1),
            to: endDay
        ) ?? endDay

        return last90DaysData
            .filter {
                let d = calendar.startOfDay(for: $0.date)
                return d >= startDay && d <= endDay
            }
            .sorted { $0.date < $1.date }
    }

    // ✅ FIX: Keep the VM’s valueLabel (unit-aware), only recompute ticks+yMax adaptively.
    private var dailyScaleForSelectedPeriod: MetricScaleResult {
        let values = filteredLast90DaysData.map { Double($0.steps) }
        guard !values.isEmpty else { return dailyScale }
        guard let dailyScaleType else { return dailyScale }

        let adaptive = MetricScaleHelper.scale(values, for: dailyScaleType)

        return MetricScaleResult(
            yAxisTicks: adaptive.yAxisTicks,
            yMax: adaptive.yMax,
            valueLabel: dailyScale.valueLabel   // ✅ IMPORTANT: keep unit-aware label (mmol/L)
        )
    }

    private var barWidthForSelectedPeriod: CGFloat {
        switch selectedPeriod {
        case .days7:  return 16
        case .days14: return 12
        case .days30: return 8
        case .days90: return 4
        }
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
                customChartContent
            }

            if showsDailyChart {
                ChartCard(borderColor: color) {
                    VStack(spacing: 8) {

                        periodPicker

                        if let customDailyChartBuilder {
                            customDailyChartBuilder(selectedPeriod, filteredLast90DaysData)
                        } else {
                            Last90DaysScaledBarChart(
                                data: filteredLast90DaysData,
                                yAxisTicks: dailyScaleForSelectedPeriod.yAxisTicks,
                                yMax: dailyScaleForSelectedPeriod.yMax,
                                valueLabel: dailyScaleForSelectedPeriod.valueLabel,
                                barColor: color,
                                goalValue: goalValue,
                                barWidth: barWidthForSelectedPeriod,
                                xValue: { $0.date },
                                yValue: { Double($0.steps) }
                            )
                        }
                    }
                    .frame(height: 260)
                }
            }

            if showsPeriodChart {
                ChartCard(borderColor: color) {
                    if let customPeriodChartContent {
                        customPeriodChartContent
                    } else {
                        AveragePeriodsScaledBarChart(
                            data: periodAverages,
                            metricLabel: title,
                            barColor: color,
                            goalValue: goalValue,
                            yAxisTicks: periodScale.yAxisTicks,
                            yMax: periodScale.yMax,
                            valueLabel: periodScale.valueLabel
                        )
                        .frame(height: 260)
                    }
                }
            }

            if showsMonthlyChart {
                EmptyView()
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}

// ============================================================
// MARK: - Subviews
// ============================================================

private extension MetabolicSectionCardScaledV1 {

    var metricChips: some View {
        MetricChipGroup(
            row1: Array(metrics.prefix(4)),
            row2: Array(metrics.dropFirst(4)),
            selected: title,
            accent: color,
            onSelect: onMetricSelected
        )
    }

    var kpiHeader: some View {
        HStack(spacing: 12) {

            KPICard(
                title: kpiTitle,
                valueText: kpiCurrentText,
                unit: nil,
                domain: .metabolic
            )

            if let secondary = kpiSecondaryText {
                KPICard(
                    title: "Ø",
                    valueText: secondary,
                    unit: nil,
                    domain: .metabolic
                )
            }
        }
        .padding(.bottom, 8)
    }

    var periodPicker: some View {
        HStack(spacing: 12) {
            Spacer()

            ForEach(Last90DaysPeriod.allCases, id: \.self) { period in
                let active = (period == selectedPeriod)

                let bg: some ShapeStyle = active
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

                Button {
                    selectedPeriod = period
                } label: {
                    Text(period.rawValue)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 22)
                        .background(Capsule().fill(bg))
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

            Spacer()
        }
        .padding(.horizontal, 4)
    }
}
