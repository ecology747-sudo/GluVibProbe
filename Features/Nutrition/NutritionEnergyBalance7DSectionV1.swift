//
//  NutritionEnergyBalance7DSectionV1.swift
//  GluVibProbe
//
//  Nutrition — Energy Balance 7D (V1)
//
//  Purpose
//  - Mini bar chart for the last 7 calendar days (oldest → newest), matching the Steps/Weight mini-chart logic.
//  - Shows daily energy balance as a diverging bar chart:
//      • Surplus  (intake > burned)  → bar UP   (red)   + value annotation
//      • Deficit  (burned > intake)  → bar DOWN (green) value annotation (absolute)
//
//  Notes
//  - The View expects the ViewModel to provide the EXACT 7 days window (no slicing inside the View).
//  - "balanceKcal" semantics:
//      • positive  = surplus (intake - burned)
//      • negative  = deficit (intake - burned)
//

import SwiftUI
import Charts

struct NutritionEnergyBalance7DSectionV1: View {

    // ✅ SSoT: VM liefert exakt die 7 Tage, die angezeigt werden sollen (oldest → newest)
    let last7DaysEnergyBalance: [EnergyBalanceTrendPointV1]

    // MARK: - Style

    private let titleColor: Color = Color.Glu.primaryBlue
    private let cardStroke: Color = Color.Glu.nutritionDomain.opacity(0.80)

    private let surplusColor: Color = .red
    private let deficitColor: Color = Color.Glu.successGreen

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 8) {
                Text("Energy Balance 7D")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(titleColor)

                Spacer(minLength: 0)
            }

            NutritionEnergyBalance7DMiniChartV1(
                data: last7DaysEnergyBalance,
                surplusColor: surplusColor,
                deficitColor: deficitColor
            )
            .frame(height: 78)
        }
        .padding(12)
        .background(cardBackground)
    }

    // MARK: - Card background (matches NutritionOverview legacy cards)

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.98))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(cardStroke, lineWidth: 1)
            )
            .shadow(
                color: .black.opacity(0.08),
                radius: 10,
                x: 0,
                y: 6
            )
    }
}

// ============================================================
// MARK: - Model (7D point)
// ============================================================

struct EnergyBalanceTrendPointV1: Identifiable {

    let id = UUID()

    /// startOfDay date
    let date: Date

    /// intake - burned (kcal)
    ///  > 0  = surplus
    ///  < 0  = deficit
    let balanceKcal: Int

    /// if you ever want to hide bars for missing days (like weight),
    /// keep the flag; for now: show all days (0 is valid)
    let hasData: Bool

    init(date: Date, balanceKcal: Int, hasData: Bool = true) {
        self.date = date
        self.balanceKcal = balanceKcal
        self.hasData = hasData
    }
}

// ============================================================
// MARK: - Mini Diverging Bar Chart (Extracted)
// ============================================================

private struct NutritionEnergyBalance7DMiniChartV1: View {

    let data: [EnergyBalanceTrendPointV1]
    let surplusColor: Color
    let deficitColor: Color

    var body: some View {
        Chart {
            ForEach(data) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Balance", point.balanceKcal)
                )
                .cornerRadius(4)
                .opacity(point.hasData ? 1.0 : 0.0)
                .foregroundStyle(barGradient(for: point.balanceKcal))
                .annotation(position: annotationPosition(for: point.balanceKcal), alignment: .center) {
                    if point.hasData {
                        Text(formattedKcalLabel(for: point.balanceKcal))
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(Color.Glu.primaryBlue)
                            .padding(point.balanceKcal < 0 ? .top : .bottom, 2)
                    }
                }
            }
        }

        // ✅ Symmetric scale around 0 (so negative bars are not visually compressed)
        .chartYScale(domain: symmetricYDomain())

        // Weekday labels (wie Steps/Weight Mini-Chart)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                AxisTick().foregroundStyle(Color.clear)
                AxisValueLabel(centered: true) { // 🟨 UPDATED
                    if let date = value.as(Date.self) {
                        Text(weekday2(date))
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                    }
                }
            }
        }

        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.background(Color.clear)
        }
    }

    // MARK: - Helpers

    private func symmetricYDomain() -> ClosedRange<Double> {
        let values = data
            .filter { $0.hasData }
            .map { abs(Double($0.balanceKcal)) }

        let maxAbs = max(values.max() ?? 0, 1)
        let padded = maxAbs * 1.15
        return (-padded)...(padded)
    }

    private func annotationPosition(for v: Int) -> AnnotationPosition {
        if v > 0 { return .top }
        if v < 0 { return .bottom }
        return .bottom
    }

    private func barGradient(for balance: Int) -> LinearGradient {
        let c = (balance >= 0) ? surplusColor : deficitColor

        return LinearGradient(
            colors: [
                c.opacity(0.25),
                c
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func formattedKcalLabel(for balance: Int) -> String {
        let absValue = abs(balance)
        let formatted = formattedInt(absValue)
        return balance > 0 ? "+\(formatted)" : formatted
    }

    private func weekday2(_ date: Date) -> String { // UPDATED
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EE"
        return f.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    private func formattedInt(_ v: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
}

// MARK: - Preview

#Preview("NutritionEnergyBalance7DSectionV1") {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())

    // Preview: 7 full days window (oldest -> newest)
    let sample: [EnergyBalanceTrendPointV1] = (0..<7).map { i in
        let date = cal.date(byAdding: .day, value: -(6 - i), to: today) ?? today
        let vals = [250, -180, 90, -420, 0, 310, -140]
        return EnergyBalanceTrendPointV1(date: date, balanceKcal: vals[i], hasData: true)
    }

    return VStack {
        NutritionEnergyBalance7DSectionV1(last7DaysEnergyBalance: sample)
    }
    .padding()
    .background(Color.white)
}
