//
//  NutritionSectionCardScaledV2.swift
//  GluVibProbe
//
//  V2: Helper-basierte SectionCard für alle Nutrition-Metriken
//  (Carbs, Protein, Fat, Nutrition Energy).
//
//  - PeriodPicker + adaptive Daily-Scale wie ActivitySectionCardScaledV2
//  - Chips Layout via MetricChipGroup (gating-ready)
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

    let monthlyChartTitle: String?

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

    // Optional gating (UI-only)
    let isMetricLocked: ((String) -> Bool)?
    let onLockedMetricSelected: ((String) -> Void)?

    // optional warning badge per metric (UI-only)
    let showsWarningBadgeForMetric: ((String) -> Bool)?

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
        monthlyChartTitle: String? = nil,
        last90DaysData: [GluVib.DailyStepsEntry],
        periodAverages: [GluVib.PeriodAverageEntry],
        monthlyData: [GluVib.MonthlyMetricEntry],
        dailyScale: GluVib.MetricScaleHelper.MetricScaleResult,
        periodScale: GluVib.MetricScaleHelper.MetricScaleResult,
        monthlyScale: GluVib.MetricScaleHelper.MetricScaleResult,
        goalValue: Swift.Int?,
        onMetricSelected: @escaping (Swift.String) -> Void,
        metrics: [Swift.String],
        showsDailyChart: Swift.Bool = true,
        showsPeriodChart: Swift.Bool = true,
        showsMonthlyChart: Swift.Bool = true,
        customKpiContent: SwiftUI.AnyView? = nil,
        customChartContent: SwiftUI.AnyView? = nil,
        customDailyChartBuilder: ((Last90DaysPeriod, [DailyStepsEntry]) -> AnyView)? = nil,
        dailyScaleType: GluVib.MetricScaleHelper.MetricScaleType? = nil,
        showHeader: Swift.Bool = false,
        onBack: (() -> Void)? = nil,
        isMetricLocked: ((String) -> Bool)? = nil,
        onLockedMetricSelected: ((String) -> Void)? = nil,
        showsWarningBadgeForMetric: ((String) -> Bool)? = nil
    ) {
        self.sectionTitle = sectionTitle
        self.title = title

        self.kpiTitle = kpiTitle
        self.kpiTargetText = kpiTargetText
        self.kpiCurrentText = kpiCurrentText
        self.kpiDeltaText = kpiDeltaText
        self.kpiDeltaColor = kpiDeltaColor
        self.hasTarget = hasTarget

        self.monthlyChartTitle = monthlyChartTitle

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

        self.isMetricLocked = isMetricLocked
        self.onLockedMetricSelected = onLockedMetricSelected

        self.showsWarningBadgeForMetric = showsWarningBadgeForMetric
    }

    // ============================================================
    // MARK: - Derived
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
            .filter { entry in
                let d = calendar.startOfDay(for: entry.date)
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

        let values = filteredLast90DaysData
            .map { Double($0.steps) }
            .filter { $0 > 0 }

        guard !values.isEmpty else { return dailyScale }
        guard let dailyScaleType else { return dailyScale }

        return MetricScaleHelper.scale(values, for: dailyScaleType)
    }

    private var resolvedMonthlyChartTitle: String {
        monthlyChartTitle ?? "\(title) / \(L10n.Common.month)"
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
        .padding(.horizontal, 8)
    }
}

// ============================================================
// MARK: - Chips / KPI / PeriodPicker
// ============================================================

private extension NutritionSectionCardScaledV2 {

    var selectedMetricForChips: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = trimmed.firstIndex(of: "(") {
            return trimmed[..<idx].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    var metricChips: some View {
        MetricChipGroup(
            row1: [ // 🟨 UPDATED
                L10n.Carbs.title,
                L10n.Sugar.title
            ],
            row2: [ // 🟨 UPDATED
                L10n.CarbsDayparts.title,
                L10n.Protein.title,
                L10n.Fat.title,
                L10n.NutritionEnergy.title
            ],
            selected: selectedMetricForChips,
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
            showsWarningBadge: { metric in
                showsWarningBadgeForMetric?(metric) ?? false
            }
        )
    }

    var kpiHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            if hasTarget {
                KPICard(title: L10n.Common.target, valueText: kpiTargetText, unit: nil, domain: .nutrition)
                KPICard(title: L10n.Common.current, valueText: kpiCurrentText, unit: nil, domain: .nutrition)
                KPICard(
                    title: L10n.Common.delta,
                    valueText: kpiDeltaText,
                    unit: nil,
                    valueColor: kpiDeltaColor ?? deltaColorFallback,
                    domain: .nutrition
                )
            } else {
                KPICard(title: L10n.Common.current, valueText: kpiCurrentText, unit: nil, domain: .nutrition)
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

        return (current <= target) ? Color.Glu.successGreen : .red
    }

    func extractNumber(from text: String) -> Double? {
        let cleaned = text
            .filter { "0123456789.,-".contains($0) }
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(Last90DaysPeriod.allCases) { period in
                let active = (period == selectedPeriod)

                Button { selectedPeriod = period } label: {
                    Text(
                        period.days == 7 ? L10n.Common.period7d :
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
