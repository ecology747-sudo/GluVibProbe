//
//  ActivitySectionCardScaledV2.swift
//  GluVibProbe
//

import SwiftUI

struct ActivitySectionCardScaledV2: View {

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

    // Daten
    let last90DaysData: [DailyStepsEntry]
    let periodAverages: [PeriodAverageEntry]
    let monthlyData: [MonthlyMetricEntry]

    // Skalen
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

    // ✅ Optionaler KPI-Block (z.B. Movement Split: 3 KPIs in "Current")
    let customKpiContent: AnyView?

    // ✅ Optionaler Custom-Chart-Block (Legacy: ohne Period Picker)
    let customChartContent: AnyView?

    // ✅ NEW: Optionaler Custom Daily Chart Builder (MIT Period Picker wie Steps)     // !!! NEW
    let customDailyChartBuilder: ((Last90DaysPeriod, [DailyStepsEntry]) -> AnyView)? // !!! NEW

    // ✅ Skala-Typ für adaptive Y-Achse je nach Periodenwahl
    let dailyScaleType: MetricScaleHelper.MetricScaleType?

    private let color = Color.Glu.activityAccent

    @State private var selectedPeriod: Last90DaysPeriod = .days30

    // MARK: - Init
    init(
        sectionTitle: String,
        title: String,
        kpiTitle: String,
        kpiTargetText: String,
        kpiCurrentText: String,
        kpiDeltaText: String,
        kpiDeltaColor: SwiftUI.Color?,
        hasTarget: Swift.Bool,
        last90DaysData: [GluVibProbe.DailyStepsEntry],
        periodAverages: [GluVibProbe.PeriodAverageEntry],
        monthlyData: [GluVibProbe.MonthlyMetricEntry],
        dailyScale: GluVibProbe.MetricScaleHelper.MetricScaleResult,
        periodScale: GluVibProbe.MetricScaleHelper.MetricScaleResult,
        monthlyScale: GluVibProbe.MetricScaleHelper.MetricScaleResult,
        goalValue: Swift.Int?,
        onMetricSelected: @escaping (Swift.String) -> (),
        metrics: [Swift.String],
        showsDailyChart: Swift.Bool,
        showsPeriodChart: Swift.Bool,
        showsMonthlyChart: Swift.Bool,
        customKpiContent: SwiftUI.AnyView?,
        customChartContent: SwiftUI.AnyView?,
        customDailyChartBuilder: ((Last90DaysPeriod, [DailyStepsEntry]) -> AnyView)? = nil, // !!! NEW
        dailyScaleType: GluVibProbe.MetricScaleHelper.MetricScaleType? = nil
    ) {
        self.sectionTitle = sectionTitle
        self.title = title

        self.kpiTitle = kpiTitle
        self.kpiTargetText = kpiTargetText
        self.kpiCurrentText = kpiCurrentText
        self.kpiDeltaText = kpiDeltaText
        self.kpiDeltaColor = kpiDeltaColor
        self.hasTarget = hasTarget

        self.last90DaysData = last90DaysData
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

        self.customDailyChartBuilder = customDailyChartBuilder            // !!! NEW
        self.dailyScaleType = dailyScaleType
    }

    // MARK: - Derived

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

    private var barWidthForSelectedPeriod: CGFloat {
        switch selectedPeriod {
        case .days7:  return 16
        case .days14: return 12
        case .days30: return 8
        case .days90: return 4
        }
    }

    // MARK: - Adaptive Skala für die aktuell gewählte Periode (Daily Chart)

    private var dailyScaleForSelectedPeriod: MetricScaleResult {
        let values = filteredLast90DaysData.map { Double($0.steps) }

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

            // ✅ Legacy Custom Chart Slot (ohne Period Picker)
            if let customChartContent {
                ChartCard(borderColor: color) {
                    customChartContent
                }
            }

            if showsDailyChart {
                ChartCard(borderColor: color) {
                    VStack(spacing: 8) {

                        periodPicker

                        // ✅ NEW: Wenn Daily-Builder gesetzt ist → nutze ihn (Movement Split)   // !!! NEW
                        if let customDailyChartBuilder {                                       // !!! NEW
                            customDailyChartBuilder(selectedPeriod, filteredLast90DaysData)    // !!! NEW
                        } else {
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
                    }
                    .frame(height: 260) // ✅ bleibt einheitlich wie Steps
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

// MARK: - Chips / KPI / PeriodPicker

private extension ActivitySectionCardScaledV2 {

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
                KPICard(title: "Target", valueText: kpiTargetText, unit: nil, domain: .activity)
                KPICard(title: "Current", valueText: kpiCurrentText, unit: nil, domain: .activity)
                KPICard(
                    title: "Delta",
                    valueText: kpiDeltaText,
                    unit: nil,
                    valueColor: kpiDeltaColor,
                    domain: .activity
                )
            } else {
                KPICard(title: "Current", valueText: kpiCurrentText, unit: nil, domain: .activity)
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
