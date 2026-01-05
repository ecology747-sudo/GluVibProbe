//
//  NutritionSectionCardScaledV2.swift
//  GluVibProbe
//
//  V2: Helper-basierte SectionCard für alle Nutrition-Metriken
//  (Carbs, Protein, Fat, Nutrition Energy).
//
//  - PeriodPicker + adaptive Daily-Scale wie ActivitySectionCardScaledV2
//  - Chips Layout wie Activity (2 Reihen, linksbündig)
//  - Slots (Daily/Period/Monthly) wie Activity V2
//  - Optional custom KPI / custom Chart / custom Daily Builder
//

import SwiftUI

struct NutritionSectionCardScaledV2: View {

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let sectionTitle: String
    let title: String

    // KPI-Werte
    let kpiTitle: String
    let kpiTargetText: String
    let kpiCurrentText: String
    let kpiDeltaText: String
    let kpiDeltaColor: Color?
    let hasTarget: Bool

    // Daten (typed: DailyStepsEntry wie Chart-Komponenten)
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

    // Optionaler KPI-Block (z.B. 3 KPIs statt Target/Current/Delta)
    let customKpiContent: AnyView?

    // Optionaler Custom-Chart-Block (Legacy: ohne Period Picker)
    let customChartContent: AnyView?

    // Optionaler Custom Daily Chart Builder (MIT Period Picker)
    let customDailyChartBuilder: ((Last90DaysPeriod, [DailyStepsEntry]) -> AnyView)?

    // Skala-Typ für adaptive Y-Achse je nach Periodenwahl
    let dailyScaleType: MetricScaleHelper.MetricScaleType?

    // Header optional (wie alt)
    let showHeader: Bool
    let onBack: (() -> Void)?

    // Domain-Farbe
    private let color = Color.Glu.nutritionAccent

    @State private var selectedPeriod: Last90DaysPeriod = .days30

    // ============================================================
    // MARK: - Init (explizit, damit nils typisiert sind)
    // ============================================================

    init(
        sectionTitle: String,
        title: String,
        kpiTitle: String,
        kpiTargetText: String,
        kpiCurrentText: String,
        kpiDeltaText: String,
        kpiDeltaColor: SwiftUI.Color? = nil,
        hasTarget: Swift.Bool,
        last90DaysData: [GluVibProbe.DailyStepsEntry],
        periodAverages: [GluVibProbe.PeriodAverageEntry],
        monthlyData: [GluVibProbe.MonthlyMetricEntry],
        dailyScale: GluVibProbe.MetricScaleHelper.MetricScaleResult,
        periodScale: GluVibProbe.MetricScaleHelper.MetricScaleResult,
        monthlyScale: GluVibProbe.MetricScaleHelper.MetricScaleResult,
        goalValue: Swift.Int?,
        onMetricSelected: @escaping (Swift.String) -> Void,
        metrics: [Swift.String],
        showsDailyChart: Swift.Bool = true,
        showsPeriodChart: Swift.Bool = true,
        showsMonthlyChart: Swift.Bool = true,
        customKpiContent: SwiftUI.AnyView? = nil,
        customChartContent: SwiftUI.AnyView? = nil,
        customDailyChartBuilder: ((Last90DaysPeriod, [DailyStepsEntry]) -> AnyView)? = nil,
        dailyScaleType: GluVibProbe.MetricScaleHelper.MetricScaleType? = nil,
        showHeader: Swift.Bool = false,
        onBack: (() -> Void)? = nil
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
        self.customDailyChartBuilder = customDailyChartBuilder
        self.dailyScaleType = dailyScaleType

        self.showHeader = showHeader
        self.onBack = onBack
    }

    // ============================================================
    // MARK: - Derived
    // ============================================================

    private var filteredLast90DaysData: [DailyStepsEntry] {

        guard !last90DaysData.isEmpty else { return [] }

        let calendar = Calendar.current

        // !!! UPDATED: robustes Period-Fenster (startOfDay), damit 7T wirklich 7 Tage ist
        let todayStart = calendar.startOfDay(for: Date())                                  // !!! UPDATED
        let maxDataDate = last90DaysData.map(\.date).max() ?? todayStart                   // !!! UPDATED
        let endDay = min(calendar.startOfDay(for: maxDataDate), todayStart)                // !!! UPDATED

        let startDay = calendar.date(
            byAdding: .day,
            value: -(selectedPeriod.days - 1),
            to: endDay
        ) ?? endDay                                                                         // !!! UPDATED

        return last90DaysData
            .filter { entry in
                let d = calendar.startOfDay(for: entry.date)                               // !!! UPDATED
                return d >= startDay && d <= endDay
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

        // !!! UPDATED: nur echte >0 Werte für Skalierung
        let values = filteredLast90DaysData
            .map { Double($0.steps) }
            .filter { $0 > 0 }                                                             // !!! UPDATED

        guard !values.isEmpty else { return dailyScale }
        guard let dailyScaleType else { return dailyScale }

        return MetricScaleHelper.scale(values, for: dailyScaleType)
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            if showHeader {
                SectionHeader(
                    title: sectionTitle,
                    subtitle: nil,
                    tintColor: color,
                    onBack: { onBack?() }
                )
            }

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

                        if let customDailyChartBuilder {
                            customDailyChartBuilder(selectedPeriod, filteredLast90DaysData)
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
        .padding(.horizontal, 8)
    }
}

// ============================================================
// MARK: - Chips / KPI / PeriodPicker
// ============================================================

private extension NutritionSectionCardScaledV2 {

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
                KPICard(title: "Target", valueText: kpiTargetText, unit: nil, domain: .nutrition)
                KPICard(title: "Current", valueText: kpiCurrentText, unit: nil, domain: .nutrition)
                KPICard(
                    title: "Delta",
                    valueText: kpiDeltaText,
                    unit: nil,
                    valueColor: kpiDeltaColor ?? deltaColorFallback,
                    domain: .nutrition
                )
            } else {
                KPICard(title: "Current", valueText: kpiCurrentText, unit: nil, domain: .nutrition)
            }
        }
        .padding(.bottom, 10)
    }

    var deltaColorFallback: Color {
        let current = extractNumber(from: kpiCurrentText)
        let target  = extractNumber(from: kpiTargetText)

        guard let current, let target else {
            return Color.Glu.primaryBlue.opacity(0.75)
        }

        return (current <= target) ? .green : .red
    }

    func extractNumber(from text: String) -> Double? {
        let cleaned = text
            .filter { "0123456789.,-".contains($0) }
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
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
