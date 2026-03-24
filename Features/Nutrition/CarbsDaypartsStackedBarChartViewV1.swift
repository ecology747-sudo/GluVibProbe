//
//  CarbsDaypartsStackedBarChartViewV1.swift
//  GluVibProbe
//
//  Nutrition — Avg Carbs (g) / Daypart (V1)
//  - Content-only chart (NO extra card background)
//  - Bars: Ø 90 / Ø 30 / Ø 14 / Ø 7
//  - Stacked segments: Morning / Afternoon / Night
//

import SwiftUI
import Charts

struct CarbsDaypartsStackedBarChartViewV1: View {

    let data: [CarbsDaypartPeriodAverageEntryV1]

    private let titleColor = Color.Glu.primaryBlue

    private let morningColor = Color.Glu.bodyDomain.opacity(0.70)
    private let afternoonColor = Color.Glu.metabolicDomain.opacity(0.70)
    private let nightColor = Color.Glu.nutritionDomain.opacity(0.70)

    private let barCornerRadius: CGFloat = 5
    private let barShadowRadius: CGFloat = 2.5
    private let barShadowY: CGFloat = 1.5

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Spacer()
                Text("Ø \(L10n.CarbsDayparts.title) (g)") // 🟨 UPDATED
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(titleColor)
                Spacer()
            }
            .frame(maxWidth: .infinity)

            Chart {
                ForEach(sortedWindows) { w in

                    BarMark(
                        x: .value("Period", windowKey(w.windowDays)),
                        y: .value("Grams", w.morningAvg)
                    )
                    .foregroundStyle(gradient(for: morningColor))
                    .cornerRadius(barCornerRadius)
                    .shadow(color: morningColor.opacity(0.16), radius: barShadowRadius, x: 0, y: barShadowY)
                    .annotation(position: .overlay, alignment: .center) {
                        if w.morningAvg > 0 {
                            Text("\(w.morningAvg)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(titleColor)
                        }
                    }

                    BarMark(
                        x: .value("Period", windowKey(w.windowDays)),
                        y: .value("Grams", w.afternoonAvg)
                    )
                    .foregroundStyle(gradient(for: afternoonColor))
                    .cornerRadius(barCornerRadius)
                    .shadow(color: afternoonColor.opacity(0.16), radius: barShadowRadius, x: 0, y: barShadowY)
                    .annotation(position: .overlay, alignment: .center) {
                        if w.afternoonAvg > 0 {
                            Text("\(w.afternoonAvg)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(titleColor)
                        }
                    }

                    BarMark(
                        x: .value("Period", windowKey(w.windowDays)),
                        y: .value("Grams", w.nightAvg)
                    )
                    .foregroundStyle(gradient(for: nightColor))
                    .cornerRadius(barCornerRadius)
                    .shadow(color: nightColor.opacity(0.16), radius: barShadowRadius, x: 0, y: barShadowY)
                    .annotation(position: .overlay, alignment: .center) {
                        if w.nightAvg > 0 {
                            Text("\(w.nightAvg)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(titleColor)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisTick()
                        .foregroundStyle(titleColor.opacity(0.35))

                    AxisValueLabel {
                        if let raw = value.as(String.self) {
                            HStack(spacing: 0) {
                                Text("Ø ")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(titleColor.opacity(0.95))

                                Text(raw)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(titleColor.opacity(0.95))
                            }
                        }
                    }
                }
            }
            .frame(height: 260)

            HStack(spacing: 12) { // 🟨 UPDATED
                legendItem(
                    color: morningColor,
                    title: L10n.CarbsDayparts.morning,
                    time: L10n.CarbsDayparts.morningWindow
                )
                legendItem(
                    color: afternoonColor,
                    title: L10n.CarbsDayparts.afternoon,
                    time: L10n.CarbsDayparts.afternoonWindow
                )
                legendItem(
                    color: nightColor,
                    title: L10n.CarbsDayparts.night,
                    time: L10n.CarbsDayparts.nightWindow
                )
            }
            .frame(maxWidth: .infinity)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(titleColor.opacity(0.95))
            .padding(.top, 6)
        }
    }

    private var sortedWindows: [CarbsDaypartPeriodAverageEntryV1] {
        let order = [90, 30, 14, 7]
        return data.sorted { (a, b) in
            (order.firstIndex(of: a.windowDays) ?? 999) < (order.firstIndex(of: b.windowDays) ?? 999)
        }
    }

    private func windowKey(_ days: Int) -> String {
        switch days {
        case 7:  return L10n.Common.period7d
        case 14: return L10n.Common.period14d
        case 30: return L10n.Common.period30d
        case 90: return L10n.Common.period90d
        default: return "\(days)"
        }
    }

    private func legendItem(color: Color, title: String, time: String) -> some View {
        VStack(alignment: .center, spacing: 2) {

            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color)
                    .frame(width: 10, height: 10)

                Text(title)
                    .lineLimit(1) // 🟨 UPDATED
                    .minimumScaleFactor(0.72) // 🟨 UPDATED
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text(time)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(titleColor.opacity(0.70))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity) // 🟨 UPDATED
    }

    private func gradient(for base: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                base.opacity(0.45),
                base.opacity(0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview {
    let demo = [
        CarbsDaypartPeriodAverageEntryV1(windowDays: 7,  morningAvg: 61, afternoonAvg: 77, nightAvg: 104),
        CarbsDaypartPeriodAverageEntryV1(windowDays: 14, morningAvg: 50, afternoonAvg: 80, nightAvg: 105),
        CarbsDaypartPeriodAverageEntryV1(windowDays: 30, morningAvg: 48, afternoonAvg: 73, nightAvg: 96),
        CarbsDaypartPeriodAverageEntryV1(windowDays: 90, morningAvg: 37, afternoonAvg: 71, nightAvg: 98),
    ]

    return CarbsDaypartsStackedBarChartViewV1(data: demo)
        .padding()
        .background(Color.white)
}
