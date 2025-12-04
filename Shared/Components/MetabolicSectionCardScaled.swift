//
//  MetabolicSectionCardScaled.swift
//  GluVibProbe
//
//  SectionCard für alle Metabolic-Metriken
//  (z. B. Glucose, Insulin) im neuen *scaled* System.
//
//  - Verwendet:
//      • Last90DaysScaledBarChart
//      • AveragePeriodsScaledBarChart
//      • MonthlyScaledBarChart
//  - Skalen (daily/period/monthly) kommen vollständig aus dem ViewModel
//

import SwiftUI

struct MetabolicSectionCardScaled: View {

    // MARK: - Eingabewerte

    let sectionTitle: String
    let title: String

    // KPI-Werte
    let kpiTitle: String
    let kpiTargetText: String
    let kpiCurrentText: String
    let kpiDeltaText: String
    let hasTarget: Bool

    // Originaldaten (90 Tage, Perioden, Monat)
    let last90DaysData: [DailyStepsEntry]
    let periodAverages: [PeriodAverageEntry]
    let monthlyData: [MonthlyMetricEntry]

    // Skalen aus dem ViewModel
    let dailyScale: MetricScaleResult
    let periodScale: MetricScaleResult
    let monthlyScale: MetricScaleResult

    // Optionaler Zielwert (z. B. Glucose-Target oder Insulin-Target)
    let goalValue: Double?

    // Chip-Handling
    let onMetricSelected: (String) -> Void
    let metrics: [String]

    // Domain-Farbe Metabolic
    private let color = Color.Glu.metabolicAccent

    // MARK: - Interner UI-State (Periodenwahl im 90-Tage-Chart)

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

    // MARK: - Balkenbreite je nach Periodenwahl

    private var barWidthForSelectedPeriod: CGFloat {
        switch selectedPeriod {
        case .days7:  return 16
        case .days14: return 12
        case .days30: return 8
        case .days90: return 4
        }
    }

    // MARK: - Init

    init(
        sectionTitle: String = "Metabolic",
        title: String,
        kpiTitle: String,
        kpiTargetText: String,
        kpiCurrentText: String,
        kpiDeltaText: String,
        hasTarget: Bool = true,
        last90DaysData: [DailyStepsEntry],
        periodAverages: [PeriodAverageEntry],
        monthlyData: [MonthlyMetricEntry],
        dailyScale: MetricScaleResult,
        periodScale: MetricScaleResult,
        monthlyScale: MetricScaleResult,
        goalValue: Double? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in },
        metrics: [String] = ["Glucose", "Insulin"]
    ) {
        self.sectionTitle = sectionTitle
        self.title = title
        self.kpiTitle = kpiTitle
        self.kpiTargetText = kpiTargetText
        self.kpiCurrentText = kpiCurrentText
        self.kpiDeltaText = kpiDeltaText
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
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // SECTION HEADER
            SectionHeader(title: sectionTitle, subtitle: nil)

            // METRIC CHIPS (Glucose / Insulin / …)
            metricChips

            // KPI-ZEILE
            kpiHeader

            // TOP: 90-Day Scaled Chart + PeriodPicker in einer Karte
            ChartCard(borderColor: color) {
                VStack(spacing: 8) {

                    periodPicker

                    Last90DaysScaledBarChart(
                        data: filteredLast90DaysData,
                        yAxisTicks: dailyScale.yAxisTicks,
                        yMax: dailyScale.yMax,
                        valueLabel: dailyScale.valueLabel,
                        barColor: color,
                        goalValue: goalValue,
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
                    goalValue: goalValue,
                    yAxisTicks: periodScale.yAxisTicks,
                    yMax: periodScale.yMax,
                    valueLabel: periodScale.valueLabel
                )
                .frame(height: 260)
            }

            // BOTTOM: Monthly Scaled Chart
            ChartCard(borderColor: color) {
                MonthlyScaledBarChart(
                    data: monthlyData,
                    metricLabel: "\(title) / Month",
                    barColor: color,
                    yAxisTicks: monthlyScale.yAxisTicks,
                    yMax: monthlyScale.yMax,
                    valueLabel: monthlyScale.valueLabel,
                    goalValue: goalValue
                )
                .frame(height: 260)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Metric Chips

private extension MetabolicSectionCardScaled {

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
                        .shadow(color: .black.opacity(0.04),
                                radius: 1,
                                x: 0,
                                y: 1)
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

private extension MetabolicSectionCardScaled {

    var kpiHeader: some View {
        HStack(alignment: .top, spacing: 10) {

            if hasTarget {
                // ✅ Standard-Fall: 3 KPIs (Target / Current / Delta)
                KPICard(
                    title: "Target",
                    valueText: kpiTargetText,
                    unit: nil,
                    domain: .metabolic
                )

                KPICard(
                    title: "Current",
                    valueText: kpiCurrentText,
                    unit: nil,
                    domain: .metabolic
                )

                KPICard(
                    title: "Delta",
                    valueText: kpiDeltaText,
                    unit: nil,
                    valueColor: deltaColor,
                    domain: .metabolic
                )
            } else {
                // 🔹 Kein Ziel: nur Current, zentriert
                Spacer(minLength: 0)

                KPICard(
                    title: "Current",
                    valueText: kpiCurrentText,
                    unit: nil,
                    domain: .metabolic
                )

                Spacer(minLength: 0)
            }
        }
        .padding(.bottom, 10)
    }

    /// Domain-Regel für Metabolic:
    /// - current <= target  → GRÜN  (im/unter Zielbereich)
    /// - current  > target  → ROT   (drüber = kritisch)
    ///
    /// Falls Parsing fehlschlägt → neutral blau.
    var deltaColor: Color {
        let current = extractNumber(from: kpiCurrentText)
        let target  = extractNumber(from: kpiTargetText)

        guard let current, let target else {
            return Color.Glu.primaryBlue.opacity(0.75)
        }

        if current <= target {
            return .green
        } else {
            return .red
        }
    }

    /// Hilfsfunktion: extrahiert eine Double-Zahl aus Strings wie
    /// "145 mg/dL", "32 U", "6.5" etc.
    func extractNumber(from text: String) -> Double? {
        let cleaned = text
            .filter { "0123456789.,-".contains($0) }
            .replacingOccurrences(of: ",", with: ".")

        return Double(cleaned)
    }
}

// MARK: - Period Picker (Liquid-Glas Optik, wie Nutrition)

private extension MetabolicSectionCardScaled {

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
                                    // AKTIV: kräftiger Verlauf
                                    ? LinearGradient(
                                        colors: [
                                            color.opacity(0.95),
                                            color.opacity(0.75)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                      )
                                    // INAKTIV: sehr dezenter Glas-Hintergrund
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

#Preview("MetabolicSectionCardScaled – Demo") {
    let demoLast90: [DailyStepsEntry] = []
    let demoPeriod: [PeriodAverageEntry] = []
    let demoMonthly: [MonthlyMetricEntry] = []

    // Dummy-Skala (z. B. für Glucose)
    let scale = MetricScaleResult(
        yAxisTicks: [0, 50, 100, 150, 200],
        yMax: 200,
        valueLabel: { v in "\(Int(v))" }
    )

    return MetabolicSectionCardScaled(
        sectionTitle: "Metabolic",
        title: "Glucose",
        kpiTitle: "Glucose Now",
        kpiTargetText: "120 mg/dL",
        kpiCurrentText: "145 mg/dL",
        kpiDeltaText: "+25 mg/dL",
        hasTarget: true,
        last90DaysData: demoLast90,
        periodAverages: demoPeriod,
        monthlyData: demoMonthly,
        dailyScale: scale,
        periodScale: scale,
        monthlyScale: scale,
        goalValue: 120,
        onMetricSelected: { _ in },
        metrics: ["Glucose", "Insulin"]
    )
    .padding()
    .background(Color.Glu.backgroundSurface)
}
