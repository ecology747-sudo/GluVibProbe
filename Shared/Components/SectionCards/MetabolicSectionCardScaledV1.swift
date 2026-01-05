//
//  MetabolicSectionCardScaledV1.swift
//  GluVibProbe
//
//  V1: Basis-SectionCard für alle Metabolik-Metriken
//
//  - Last 90 Days Daily Chart mit Period Picker (7 / 14 / 30 / 90)
//  - Period Average Chart (max. 90 Tage)
//  - KEIN Monthly
//  - KEINE Datenlogik
//

import SwiftUI

struct MetabolicSectionCardScaledV1: View {

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let title: String

    // KPI
    let kpiTitle: String
    let kpiCurrentText: String
    let kpiSecondaryText: String?

    // Charts
    let last90DaysData: [DailyStepsEntry]              // bewusst generisch (Chart expects DailyStepsEntry)
    let periodAverages: [PeriodAverageEntry]           // Rolling/Averages kommen aus dem VM

    // Scales
    let dailyScale: MetricScaleResult
    let periodScale: MetricScaleResult

    // Target (optional)
    let goalValue: Double?                             // NEW

    // Navigation
    let onMetricSelected: (String) -> Void
    let metrics: [String]

    // Scale Type
    let dailyScaleType: MetricScaleHelper.MetricScaleType

    // ============================================================
    // MARK: - State
    // ============================================================

    @State private var selectedPeriod: Last90DaysPeriod = .days30

    private let color = Color.Glu.metabolicDomain

    // ============================================================
    // MARK: - Derived (90-Day Clamp)
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

    private var dailyScaleForSelectedPeriod: MetricScaleResult {
        let values = filteredLast90DaysData
            .map { Double($0.steps) }
            .filter { $0 > 0 }

        guard !values.isEmpty else { return dailyScale }
        return MetricScaleHelper.scale(values, for: dailyScaleType)
    }

    private var barWidth: CGFloat {
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

            kpiHeader

            // ----------------------------
            // Daily Chart (Last 90 Days)
            // ----------------------------
            ChartCard(borderColor: color) {
                VStack(spacing: 8) {

                    periodPicker

                    Last90DaysScaledBarChart(
                        data: filteredLast90DaysData,
                        yAxisTicks: dailyScaleForSelectedPeriod.yAxisTicks,
                        yMax: dailyScaleForSelectedPeriod.yMax,
                        valueLabel: dailyScaleForSelectedPeriod.valueLabel,
                        barColor: color,
                        goalValue: goalValue,               // NEW
                        barWidth: barWidth,
                        xValue: { $0.date },
                        yValue: { Double($0.steps) }
                    )
                }
                .frame(height: 260)
            }

            // ----------------------------
            // Period Average Chart (≤90d)
            // ----------------------------
            ChartCard(borderColor: color) {
                AveragePeriodsScaledBarChart(
                    data: periodAverages,
                    metricLabel: title,
                    barColor: color,
                    goalValue: goalValue,                   // NEW
                    yAxisTicks: periodScale.yAxisTicks,
                    yMax: periodScale.yMax,
                    valueLabel: periodScale.valueLabel
                )
                .frame(height: 240)
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

    // ----------------------------
    // Metric Chips (2 rows)
    // ----------------------------

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

        let strokeColor: Color = isActive ? Color.white.opacity(0.90) : color.opacity(0.90)
        let lineWidth: CGFloat = isActive ? 1.6 : 1.2

        return Button {
            onMetricSelected(metric)
        } label: {
            Text(metric)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 5)
                .padding(.horizontal, 14)
                .background(Capsule().fill(backgroundFill))
                .overlay(Capsule().stroke(strokeColor, lineWidth: lineWidth))
                .foregroundStyle(isActive ? Color.white : Color.Glu.primaryBlue.opacity(0.95))
                .scaleEffect(isActive ? 1.05 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isActive)
        }
        .buttonStyle(.plain)
    }

    // ----------------------------
    // KPI Header
    // ----------------------------

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

    // ----------------------------
    // Period Picker (≤90d)
    // ----------------------------

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
