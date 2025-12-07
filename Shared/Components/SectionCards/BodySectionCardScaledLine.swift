// !!! NEW FILE
//  BodySectionCardScaledLine.swift                                      // !!! NEW
//  GluVibProbe                                                           // !!! NEW
//                                                                        // !!! NEW
//  Helper-basierte SectionCard für Body-Metriken mit LineChart           // !!! NEW
//  (für BMI, Body Fat, Resting Heart Rate).                              // !!! NEW

import SwiftUI                                                            // !!! NEW

struct BodySectionCardScaledLine: View {                                  // !!! NEW

    // MARK: - Eingabewerte                                               // !!! NEW

    let sectionTitle: String                                              // !!! NEW
    let title: String                                                     // !!! NEW

    // KPI-Werte                                                          // !!! NEW
    let kpiTitle: String                                                  // !!! NEW
    let kpiTargetText: String                                             // !!! NEW
    let kpiCurrentText: String                                            // !!! NEW
    let kpiDeltaText: String                                              // !!! NEW
    let hasTarget: Bool                                                   // !!! NEW

    // Originaldaten (90 Tage, Perioden, Monat) – bereits in Display-Einheit  // !!! NEW
    let last90DaysData: [DailyStepsEntry]                                 // !!! NEW
    let periodAverages: [PeriodAverageEntry]                              // !!! NEW
    let monthlyData: [MonthlyMetricEntry]                                 // !!! NEW

    // Skalen aus dem ViewModel                                           // !!! NEW
    let dailyScale: MetricScaleResult                                     // !!! NEW
    let periodScale: MetricScaleResult                                    // !!! NEW
    let monthlyScale: MetricScaleResult                                   // !!! NEW

    /// Zielwert (z. B. Target BMI, Target Body Fat)                      // !!! NEW
    let goalValue: Int?                                                   // !!! NEW

    /// Chip-Callback (z. B. "BMI" / "Body Fat" / "Resting HR")           // !!! NEW
    let onMetricSelected: (String) -> Void                                // !!! NEW
    let metrics: [String]                                                 // !!! NEW

    /// Steuert, ob der Monats-Chart angezeigt wird                        // !!! NEW
    let showMonthlyChart: Bool                                            // !!! NEW

    /// Skala-Typ für die dynamische Periode                              // !!! NEW
    let scaleType: MetricScaleHelper.MetricScaleType                      // !!! NEW

    // Domain-Farbe                                                        // !!! NEW
    private let color = Color.Glu.bodyAccent                              // !!! NEW

    // MARK: - Interner UI-State (Periodenwahl)                            // !!! NEW

    @State private var selectedPeriod: Last90DaysPeriod = .days30         // !!! NEW

    // Gefilterte 90-Tage-Daten basierend auf der aktuellen Periodenwahl  // !!! NEW
    private var filteredLast90DaysData: [DailyStepsEntry] {               // !!! NEW
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

    // MARK: - Adaptive Skala für die aktuell gewählte Periode             // !!! NEW

    private var dailyScaleForSelectedPeriod: MetricScaleResult {          // !!! NEW
        let values = filteredLast90DaysData.map { Double($0.steps) }

        guard !values.isEmpty else {
            return dailyScale
        }

        return MetricScaleHelper.scale(values, for: scaleType)
    }

    // MARK: - Body                                                         // !!! NEW

    var body: some View {                                                 // !!! NEW
        VStack(alignment: .leading, spacing: 16) {

            // SECTION HEADER
            SectionHeader(title: sectionTitle, subtitle: nil)

            // METRIC CHIPS
            metricChips

            // KPI-ZEILE
            kpiHeader

            // TOP: 90-Day Scaled Line Chart + PeriodPicker
            ChartCard(borderColor: color) {
                VStack(spacing: 8) {

                    periodPicker

                    Last90DaysScaledLineChart(
                        data: filteredLast90DaysData,
                        yAxisTicks: dailyScaleForSelectedPeriod.yAxisTicks,
                        yMax: dailyScaleForSelectedPeriod.yMax,
                        valueLabel: dailyScaleForSelectedPeriod.valueLabel,
                        lineColor: color,
                        goalValue: goalValue.map(Double.init),
                        lineWidth: barWidthForSelectedPeriod,
                        xValue: { $0.date },
                        yValue: { Double($0.steps) }
                    )
                }
                .frame(height: 260)
            }

            // MIDDLE: Period Averages Scaled Chart (weiterhin Bar-Chart)
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

    // MARK: - Balken-/Linienbreite je nach Periodenwahl                    // !!! NEW

    private var barWidthForSelectedPeriod: CGFloat {                       // !!! NEW
        switch selectedPeriod {
        case .days7:  return 16
        case .days14: return 12
        case .days30: return 8
        case .days90: return 4
        }
    }
}

// MARK: - Metric Chips                                                    // !!! NEW

private extension BodySectionCardScaledLine {

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

// MARK: - KPI Header                                                      // !!! NEW

private extension BodySectionCardScaledLine {

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

// MARK: - Period Picker                                                   // !!! NEW

private extension BodySectionCardScaledLine {

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

// MARK: - Preview                                                         // !!! NEW

#Preview("BodySectionCardScaledLine – BMI Demo") {                        // !!! NEW
    BodySectionCardScaledLine(
        sectionTitle: "Body",
        title: "BMI",
        kpiTitle: "BMI Today",
        kpiTargetText: "24.0",
        kpiCurrentText: "27.3",
        kpiDeltaText: "+3.3",
        hasTarget: false,
        last90DaysData: [],
        periodAverages: [],
        monthlyData: [],
        dailyScale: MetricScaleResult(
            yAxisTicks: [20, 25, 30],
            yMax: 35,
            valueLabel: { "\($0)" }
        ),
        periodScale: MetricScaleResult(
            yAxisTicks: [20, 25, 30],
            yMax: 35,
            valueLabel: { "\($0)" }
        ),
        monthlyScale: MetricScaleResult(
            yAxisTicks: [20, 25, 30],
            yMax: 35,
            valueLabel: { "\($0)" }
        ),
        goalValue: nil,
        onMetricSelected: { _ in },
        metrics: ["BMI", "Body Fat", "Resting HR"],
        showMonthlyChart: false,
        scaleType: .weightKg
    )
    .padding()
    .background(Color.Glu.backgroundSurface)
}
