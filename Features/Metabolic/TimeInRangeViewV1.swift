//
//  TimeInRangeViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct TimeInRangeViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject var settings: SettingsModel

    @StateObject private var viewModel: TimeInRangeViewModelV1

    let onMetricSelected: (String) -> Void

    // ============================================================
    // MARK: - Local UI State (wie SectionCard)
    // ============================================================

    @State private var selectedPeriod: Last90DaysPeriod = .days30
    private let color = Color.Glu.metabolicDomain

    init(
        viewModel: TimeInRangeViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: TimeInRangeViewModelV1())
        }
    }

    // ============================================================
    // MARK: - Derived (90-Day Clamp + Period Filter)
    // ============================================================

    private var filteredLast90DaysData: [DailyStepsEntry] {

        let last90DaysData = viewModel.last90DaysChartData
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
        // TIR ist immer 0..100 — wir erzwingen fix die Skala
        MetricScaleHelper.scale([100], for: .percent0to100)
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
        MetricDetailScaffold(
            headerTitle: "Metabolic",
            headerTint: color,
            onBack: { appState.currentStatsScreen = .none },
            onRefresh: {
                await healthStore.refreshMetabolic(.pullToRefresh)
            },
            background: {
                LinearGradient(
                    colors: [.white, color.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {

                metricChips

                // ============================================================
                // KPI Row (3 KPIs): Goal | Today | Delta  (wie Steps)
                // ============================================================

                HStack(spacing: 12) {

                    KPICard(
                        title: "Goal",
                        valueText: "\(settings.tirTargetPercent)%",
                        unit: nil,
                        domain: .metabolic
                    )

                    KPICard(
                        title: "Today",
                        valueText: viewModel.formattedTodayTIRPercent,
                        unit: nil,
                        domain: .metabolic
                    )

                    KPICard(
                        title: "Delta",
                        valueText: viewModel.kpiDeltaText,
                        unit: nil,
                        valueColor: viewModel.kpiDeltaColor,   // ✅ HIER VOR domain
                        domain: .metabolic
                    )                }
                .padding(.bottom, 8)

                // ============================================================
                // Daily Chart (Last 90 Days) + Period Picker
                // ============================================================

                ChartCard(borderColor: color) {
                    VStack(spacing: 8) {

                        periodPicker

                        Last90DaysScaledBarChart(
                            data: filteredLast90DaysData,
                            yAxisTicks: dailyScaleForSelectedPeriod.yAxisTicks,
                            yMax: dailyScaleForSelectedPeriod.yMax,
                            valueLabel: dailyScaleForSelectedPeriod.valueLabel,
                            barColor: color,
                            goalValue: Double(settings.tirTargetPercent),          // ✅ Target aus Settings
                            barWidth: barWidth,
                            xValue: { $0.date },
                            yValue: { Double($0.steps) }                            // steps == TIR %
                        )
                    }
                    .frame(height: 260)
                }

                // ============================================================
                // Period Average Chart (≤90d)
                // ============================================================

                ChartCard(borderColor: color) {
                    AveragePeriodsScaledBarChart(
                        data: viewModel.periodAverages,
                        metricLabel: "TIR",
                        barColor: color,
                        goalValue: Double(settings.tirTargetPercent),              // ✅ Target auch hier
                        yAxisTicks: MetricScaleHelper.scale([100], for: .percent0to100).yAxisTicks,
                        yMax: MetricScaleHelper.scale([100], for: .percent0to100).yMax,
                        valueLabel: MetricScaleHelper.scale([100], for: .percent0to100).valueLabel
                    )
                    .frame(height: 240)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }
        .task {
            await healthStore.refreshMetabolic(.navigation)
        }
    }
}

// ============================================================
// MARK: - Subviews (lokal, keine SectionCard-Änderung)
// ============================================================

private extension TimeInRangeViewV1 {

    // ----------------------------
    // Metric Chips (2 rows) — wie MetabolicSectionCardScaledV1
    // ----------------------------

    var metricChips: some View {
        VStack(alignment: .leading, spacing: 12) {

            let metrics = AppState.metabolicVisibleMetrics

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
        let isActive = (metric == "TIR")

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
    // Period Picker (≤90d) — wie SectionCard
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

// MARK: - Preview

#Preview("TimeInRangeViewV1 – Metabolic") {
    let previewStore = HealthStore.preview()
    let previewVM = TimeInRangeViewModelV1(healthStore: previewStore)
    let previewState = AppState()
    previewState.currentStatsScreen = .timeInRange

    return TimeInRangeViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
